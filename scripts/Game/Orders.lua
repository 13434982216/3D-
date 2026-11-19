-- 3D打印工坊 —— 订单派发与制作流程
local M = require("Game.Machines")

local Orders = {}

---@type table<string, Order>
local byId_ = {}
---@type table<string, Machine>
local byCode_ = {}
---@type integer
local nextCode_ = 1
---@type number
local powerDebt_ = 0.0
---@type { kind: string, rent: integer, shortfall: integer|nil }|nil
local dayEvent_ = nil
---@type fun(dt: number)
local UpdateDay

local function BuildIndex()
    byId_ = {}
    byCode_ = {}
    for _, order in ipairs(M.orders) do
        byId_[order.id] = order
    end
    for _, machine in ipairs(M.machines) do
        byCode_[machine.code] = machine
    end
end

---@param machine Machine
local function ResetMachine(machine)
    machine.status = machine.material >= 1 and "空闲" or "缺料"
    machine.progress = 0.0
    machine.batchSize = 0
    machine.batchIndex = 0
    machine.itemStarted = false
    machine.printName = "无"
    machine.orderId = nil
end

function Orders.Init()
    BuildIndex()
    nextCode_ = 1
    powerDebt_ = 0.0
    dayEvent_ = nil
    M.day = 1
    M.dayTimer = 0.0
    M.rentDue = 0
    for _, machine in ipairs(M.machines) do
        local n = tonumber(string.match(machine.code, "%d+") or "")
        if n ~= nil and n >= nextCode_ then
            nextCode_ = math.floor(n) + 1
        end
    end
    for _, order in ipairs(M.orders) do
        order.status = "待制作"
        order.machineCode = nil
        order.progress = 0.0
        order.goodCount = 0
        order.damagedCount = 0
    end
    M.delivered = {}
    for _, machine in ipairs(M.machines) do
        ResetMachine(machine)
    end
end

---@param id string
---@return Order|nil
function Orders.Get(id)
    return byId_[id]
end

---@param code string
---@return Machine|nil
function Orders.GetMachine(code)
    return byCode_[code]
end

--- 购买打印机后放入机房：新机器不带耗材，需要单独加料
---@param printer ShopPrinter
---@return Machine
function Orders.AddMachine(printer)
    local code = string.format("#%03d", nextCode_)
    nextCode_ = nextCode_ + 1

    ---@type Machine
    local machine = {
        code = code,
        model = printer.name,
        short = printer.name,
        sprite = printer.sprite,
        status = "缺料",
        progress = 0.0,
        material = 0,
        materialMax = 1000,
        output = 8 + printer.tier * 2,
        level = printer.tier,
        printName = "无",
        orderId = nil,
        speedMul = printer.speed,
        materialRate = printer.materialRate,
        price = printer.price,
        batchSize = 0,
        batchIndex = 0,
        itemStarted = false,
    }
    M.machines[#M.machines + 1] = machine
    byCode_[code] = machine
    return machine
end

--- 机器打印整单实际需要的耗材克数
---@param machine Machine
---@param order Order
---@return integer
function Orders.EffectiveGrams(machine, order)
    return math.max(1, math.floor(order.grams * machine.materialRate + 0.5))
end

--- 单件耗材克数（逐件扣除，损坏补打需要再耗一份）
---@param machine Machine
---@param order Order
---@return integer
function Orders.ItemGrams(machine, order)
    local total = Orders.EffectiveGrams(machine, order)
    return math.max(1, math.ceil(total / math.max(1, order.quantity)))
end

--- 机器打印整单实际需要的秒数
---@param machine Machine
---@param order Order
---@return number
function Orders.EffectiveSeconds(machine, order)
    if machine.speedMul <= 0 then
        return order.seconds
    end
    return math.max(1.0, order.seconds / machine.speedMul)
end

--- 单件打印秒数
---@param machine Machine
---@param order Order
---@return number
function Orders.ItemSeconds(machine, order)
    return math.max(0.5, Orders.EffectiveSeconds(machine, order) / math.max(1, order.quantity))
end

--- 订单整体进度（按已打好的成品件数）
---@param order Order
---@return number
function Orders.OverallProgress(order)
    local total = math.max(1, order.quantity)
    local good = order.goodCount or 0
    return math.min(1.0, good / total)
end

---@class MachineChoice
---@field machine Machine
---@field ok boolean
---@field reason string
---@field need integer 整单克数参考
---@field itemGrams integer 单件克数
---@field seconds number

--- 列出当前空闲机器，并标注耗材是否满足该订单
---@param order Order
---@return MachineChoice[]
function Orders.IdleChoices(order)
    local list = {}
    for _, machine in ipairs(M.machines) do
        if machine.status == "空闲" or machine.status == "缺料" then
            local itemGrams = Orders.ItemGrams(machine, order)
            local ok = machine.material >= itemGrams
            local reason = ""
            if not ok then
                if machine.material <= 0 then
                    reason = "机器还没加料"
                else
                    reason = string.format("耗材不足，每件需 %dg", itemGrams)
                end
            end
            list[#list + 1] = {
                machine = machine,
                ok = ok,
                reason = reason,
                need = Orders.EffectiveGrams(machine, order),
                itemGrams = itemGrams,
                seconds = Orders.EffectiveSeconds(machine, order),
            }
        end
    end
    return list
end

--- 把订单派给一台机器开始制作
---@param order Order
---@param machine Machine
---@return boolean ok
---@return string message
function Orders.Start(order, machine)
    if order.status ~= "待制作" then
        return false, "该订单已经开始制作了"
    end
    if machine.status == "缺料" then
        return false, "这台机器料仓是空的，请先加料"
    end
    if machine.status ~= "空闲" then
        return false, "这台机器正在忙"
    end

    local need = Orders.ItemGrams(machine, order)
    if machine.material < need then
        return false, string.format("这台机器耗材不足（每件至少 %dg）", need)
    end

    machine.status = "打印中"
    machine.progress = 0.0
    machine.batchSize = order.quantity
    machine.batchIndex = 0
    machine.itemStarted = false
    machine.printName = order.product
    machine.orderId = order.id

    order.status = "制作中"
    order.machineCode = machine.code
    order.progress = 0.0
    order.goodCount = 0
    order.damagedCount = 0
    return true, string.format("订单 %s 已交给 %s 制作", order.id, machine.code)
end

--- 开始补打批次：只打还缺的成品件数
---@param machine Machine
---@param order Order
local function StartNextBatch(machine, order)
    machine.batchSize = math.max(1, order.quantity - order.goodCount)
    machine.batchIndex = 0
    machine.progress = 0.0
    machine.itemStarted = false
    if machine.material >= Orders.ItemGrams(machine, order) then
        machine.status = "打印中"
    else
        machine.status = "缺料"
    end
end

---@param machine Machine
---@param order Order
---@param dt number
---@param completed Order[]
local function UpdatePrinting(machine, order, dt, completed)
    local batchSize = math.max(1, machine.batchSize)

    if not machine.itemStarted then
        if math.random() < M.faultChance then
            machine.status = "故障"
            return
        end
        local need = Orders.ItemGrams(machine, order)
        if machine.material < need then
            machine.status = "缺料"
            return
        end
        machine.material = machine.material - need
        machine.itemStarted = true
    end

    machine.progress = machine.progress + dt / (Orders.ItemSeconds(machine, order) * batchSize)
    local boundary = (machine.batchIndex + 1) / batchSize
    if machine.progress < boundary then
        return
    end

    -- 完成一件：有概率打印损坏，损坏件不计入成品
    machine.progress = boundary
    machine.itemStarted = false
    machine.batchIndex = machine.batchIndex + 1
    if math.random() < M.damageChance then
        order.damagedCount = order.damagedCount + 1
    else
        order.goodCount = order.goodCount + 1
    end

    if machine.batchIndex >= batchSize then
        machine.progress = 1.0
        machine.status = "可收取"
        if order.damagedCount == 0 then
            order.status = "可交付"
        end
        completed[#completed + 1] = order
    end
    order.progress = Orders.OverallProgress(order)
end

--- 推进所有制作中的机器，并结算电费
---@param dt number
---@return Order[] completed 本次打完一批的订单
function Orders.Update(dt)
    local completed = {}
    local printing = 0

    for _, machine in ipairs(M.machines) do
        if machine.status == "打印中" then
            printing = printing + 1
            ---@type Order|nil
            local order = nil
            if machine.orderId ~= nil then
                order = byId_[machine.orderId]
            end
            if order == nil then
                ResetMachine(machine)
            else
                UpdatePrinting(machine, order, dt, completed)
            end
        end
    end

    if printing > 0 then
        local cost = M.powerRatePerSecond * printing * dt
        M.powerCost = M.powerCost + cost
        M.profit = M.profit - cost
        powerDebt_ = powerDebt_ + cost
        if powerDebt_ >= 1.0 then
            local pay = math.floor(powerDebt_)
            powerDebt_ = powerDebt_ - pay
            M.coins = math.max(0, M.coins - pay)
        end
    end

    UpdateDay(dt)

    return completed
end

--- 当前场地
---@return Venue
function Orders.CurrentVenue()
    return M.venues[M.venueIndex] --[[@as Venue]]
end

--- 当前场地可容纳的机器数量
---@return integer
function Orders.Capacity()
    return Orders.CurrentVenue().capacity
end

--- 机器位是否已满
---@return boolean
function Orders.IsFull()
    return #M.machines >= Orders.Capacity()
end

--- 一天结束：结算当天房租
function UpdateDay(dt)
    M.dayTimer = M.dayTimer + dt
    if M.dayTimer < M.daySeconds then
        return
    end
    M.dayTimer = M.dayTimer - M.daySeconds
    M.day = M.day + 1

    local rent = Orders.CurrentVenue().rent
    if M.coins >= rent then
        M.coins = M.coins - rent
        M.profit = M.profit - rent
        dayEvent_ = { kind = "paid", rent = rent }
    else
        -- 钱不够：扣光并记为欠租，机器照常运转
        local shortfall = rent - math.floor(M.coins)
        M.profit = M.profit - M.coins
        M.rentDue = M.rentDue + shortfall
        M.coins = 0
        dayEvent_ = { kind = "unpaid", rent = rent, shortfall = shortfall }
    end
end

--- 取出并清空上一天的结算结果（供 UI 提示）
---@return { kind: string, rent: integer, shortfall: integer|nil }|nil
function Orders.TakeDayEvent()
    local event = dayEvent_
    dayEvent_ = nil
    return event
end

--- 扩建到指定场地
---@param index integer
---@return boolean ok
---@return string message
function Orders.UpgradeVenue(index)
    local venue = M.venues[index]
    if venue == nil then
        return false, "没有这个场地"
    end
    if index <= M.venueIndex then
        return false, "已经拥有该场地"
    end
    if M.coins < venue.price then
        return false, string.format("金币不足，扩建到%s需要 %d 金币", venue.name, venue.price)
    end

    M.coins = M.coins - venue.price
    M.venueCost = M.venueCost + venue.price
    M.profit = M.profit - venue.price
    M.venueIndex = index
    return true, string.format("已扩建到%s，可放置 %d 台机器", venue.name, venue.capacity)
end

--- 从机房卡片收菜：无损坏则结算交付；有损坏则丢弃并补打剩余件数
---@param machine Machine
---@return integer coins
---@return string message
function Orders.Collect(machine)
    if machine.status ~= "可收取" then
        return 0, "暂时没有可收取的东西"
    end

    ---@type Order|nil
    local order = nil
    if machine.orderId ~= nil then
        order = byId_[machine.orderId]
    end
    if order == nil then
        ResetMachine(machine)
        return 0, "机器上没有进行中的订单"
    end

    if order.damagedCount == 0 then
        local reward = order.price
        M.coins = M.coins + reward
        M.profit = M.profit + reward
        M.delivered[order.product] = (M.delivered[order.product] or 0) + order.quantity
        order.status = "已完成"
        order.machineCode = nil
        order.progress = 1.0
        ResetMachine(machine)
        return reward, string.format("交付订单 %s，+%d 金币", order.id, reward)
    end

    local damaged = order.damagedCount
    order.damagedCount = 0
    local remaining = math.max(0, order.quantity - order.goodCount)
    StartNextBatch(machine, order)
    return 0, string.format("打坏 %d 件已丢弃，继续补打剩余 %d 件", damaged, remaining)
end

--- 交付订单（订单页入口，等价于对该订单的机器收菜）
---@param order Order
---@return boolean settled 是否完成结算
---@return string message
function Orders.Deliver(order)
    ---@type Machine|nil
    local machine = nil
    if order.machineCode ~= nil then
        machine = byCode_[order.machineCode]
    end
    if machine == nil then
        return false, "订单没有对应的机器"
    end
    if machine.status ~= "可收取" then
        return false, "成品还没打印完成"
    end
    local _, message = Orders.Collect(machine)
    return order.status == "已完成", message
end

--- 一键收取所有可收取的机器
---@return integer count
---@return integer coins
function Orders.CollectAll()
    local count = 0
    local coins = 0
    for _, machine in ipairs(M.machines) do
        if machine.status == "可收取" then
            local gained = Orders.Collect(machine)
            count = count + 1
            coins = coins + gained
        end
    end
    return count, coins
end

--- 单台机器补满耗材需要的克数（从库存划拨，不直接扣金币）
---@param machine Machine
---@return integer missing
function Orders.RefillPlan(machine)
    return math.max(0, math.floor(machine.materialMax - machine.material + 0.5))
end

--- 给单台机器加料：从耗材库存划拨，缺料停运的机器加满后自动恢复打印
---@param machine Machine
---@return boolean ok
---@return string message
function Orders.Refill(machine)
    local missing = Orders.RefillPlan(machine)
    if missing <= 0 then
        return false, "这台机器耗材已满"
    end
    if M.materialStock < missing then
        return false, string.format("库存耗材不足，还差 %dg，请先去商店购买", missing - M.materialStock)
    end

    M.materialStock = M.materialStock - missing
    machine.material = machine.materialMax
    if machine.status == "缺料" then
        if machine.orderId ~= nil then
            machine.status = "打印中"
        else
            machine.status = "空闲"
        end
    end
    return true, string.format("已加料 %dg，库存剩余 %dg", missing, M.materialStock)
end

--- 为所有机器补满耗材（从库存划拨）
---@return boolean ok
---@return integer grams
---@return integer shortage 库存还差多少克
function Orders.RefillAll()
    local grams = 0
    for _, machine in ipairs(M.machines) do
        grams = grams + Orders.RefillPlan(machine)
    end
    if grams <= 0 then
        return false, 0, 0
    end
    if M.materialStock < grams then
        return false, grams, grams - M.materialStock
    end

    M.materialStock = M.materialStock - grams
    for _, machine in ipairs(M.machines) do
        machine.material = machine.materialMax
        if machine.status == "缺料" then
            if machine.orderId ~= nil then
                machine.status = "打印中"
            else
                machine.status = "空闲"
            end
        end
    end
    return true, grams, 0
end

--- 在商店购买一包耗材，直接入库
---@param material ShopMaterial
---@return boolean ok
---@return string message
function Orders.BuyMaterial(material)
    if M.coins < material.price then
        return false, string.format("金币不足，购买需要 %d 金币", material.price)
    end

    M.coins = M.coins - material.price
    M.materialCost = M.materialCost + material.price
    M.profit = M.profit - material.price
    M.materialStock = M.materialStock + material.grams
    return true, string.format("已购入 %s %dg，库存 %dg",
        material.name, material.grams, M.materialStock)
end

--- 维修一台故障机器，修好后继续打印
---@param machine Machine
---@return boolean ok
---@return string message
function Orders.Repair(machine)
    if machine.status ~= "故障" then
        return false, "机器运行正常，不需要维修"
    end
    local cost = M.repairCost
    if M.coins < cost then
        return false, string.format("金币不足，维修需要 %d 金币", cost)
    end

    M.coins = M.coins - cost
    M.profit = M.profit - cost
    if machine.orderId ~= nil then
        machine.status = "打印中"
    else
        ResetMachine(machine)
    end
    return true, string.format("维修完成，花费 %d 金币", cost)
end

--- 一键维修所有故障机器
---@return integer count
---@return integer spent
function Orders.RepairAll()
    local count = 0
    local spent = 0
    for _, machine in ipairs(M.machines) do
        if machine.status == "故障" and M.coins >= M.repairCost then
            M.coins = M.coins - M.repairCost
            M.profit = M.profit - M.repairCost
            if machine.orderId ~= nil then
                machine.status = "打印中"
            else
                ResetMachine(machine)
            end
            count = count + 1
            spent = spent + M.repairCost
        end
    end
    return count, spent
end

--- 停运机器并撤回订单（订单退回待制作）
---@param machine Machine
---@return boolean ok
---@return string message
function Orders.Stop(machine)
    if machine.orderId == nil then
        return false, "这台机器当前没有订单"
    end
    if machine.status == "可收取" then
        return false, "这一批已经打完，请先收菜结算"
    end

    ---@type Order|nil
    local order = byId_[machine.orderId]
    if order ~= nil then
        order.status = "待制作"
        order.machineCode = nil
        order.progress = 0.0
        order.goodCount = 0
        order.damagedCount = 0
    end
    ResetMachine(machine)
    return true, string.format("已停运 %s，订单 %s 退回待制作", machine.code, order and order.id or "")
end

--- 一键把待制作订单派给空闲机器
---@return integer count
function Orders.AutoStart()
    local count = 0
    for _, order in ipairs(M.orders) do
        if order.status == "待制作" then
            local choices = Orders.IdleChoices(order)
            for _, choice in ipairs(choices) do
                if choice.ok and choice.machine.status == "空闲" then
                    if Orders.Start(order, choice.machine) then
                        count = count + 1
                    end
                    break
                end
            end
        end
    end
    return count
end

--- 统计各状态的订单数量
---@param status string
---@return integer
function Orders.CountByStatus(status)
    local count = 0
    for _, order in ipairs(M.orders) do
        if order.status == status then
            count = count + 1
        end
    end
    return count
end

--- 统计各状态的机器数量
---@param status string
---@return integer
function Orders.CountMachinesByStatus(status)
    local count = 0
    for _, machine in ipairs(M.machines) do
        if machine.status == status then
            count = count + 1
        end
    end
    return count
end

return Orders
