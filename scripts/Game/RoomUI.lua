-- 3D打印工坊 —— 机房界面（纯 UI 展示）
local UI = require("urhox-libs/UI")
local M = require("Game.Machines")
local Orders = require("Game.Orders")
local Sfx = require("Game.Sfx")
local Leaderboard = require("Game.Leaderboard")
local OfficialRank = require("Game.OfficialRank")

local compact_ = false
local currentPage_ = "home"
local pendingPage_ = nil
local shopTab_ = "printers"
local orderFilter_ = "all"
local roomFilter_ = "all"
---@type string|nil
local pickerOrderId_
---@type string|nil
local opMachineCode_
local venueOpen_ = false
local refreshTimer_ = 0.0
local fxTime_ = 0.0

-- 富豪榜：nil = 加载中，false = 加载失败（reason 在 richError_）
---@type RichEntry[]|nil|false
local richList_
---@type string|nil
local richError_
---@type integer|nil
local richSelfRank_
--- 上榜总人数（nil = 未知）
---@type integer|nil
local richTotal_
--- 首页排行榜前三：nil = 加载中，false = 加载失败
---@type RankEntry[]|nil|false
local homeRank_ = { { rank = 1, nickname = "玩具大亨", coins = 1280000, isMe = false }, { rank = 2, nickname = "模型大师", coins = 960000, isMe = false }, { rank = 3, nickname = "新手小工坊", coins = 720000, isMe = true } }
--- 金币云同步节流
local cloudSyncTimer_ = 0.0
---@type integer 上次发起同步时的金币值
local cloudSyncSent_ = -1

---@type table<string, string>
local lastStatus_ = {}

---@type Label|nil
local coinChipLabel_
---@type Label|nil
local powerCostLabel_
---@type Label|nil
local materialCostLabel_
---@type Label|nil
local profitChipLabel_
---@type Label|nil
local machineCostLabel_
---@type Label|nil
local venueInfoLabel_
---@type Label|nil
local venueRentLabel_

--- 首页顶部与经营总览的动态标签
---@type Label|nil
local homeCoinLabel_
---@type Label|nil
local homeExpLabel_
---@type Label|nil
local homeProfitLabel_
---@type Label|nil
local homeRevenueLabel_
---@type Label|nil
local homePendingLabel_
---@type Label|nil
local homeSatisfactionLabel_
---@type Label|nil
local homeDeliveredLabel_

---@type fun(page: string)
local ShowPage

---@class RoomCardRefs
---@field machine Machine
---@field card Panel
---@field warnIcon Panel|nil
---@field statusLabel Label
---@field pctLabel Label
---@field rightLabel Label
---@field fill Panel
---@field matFill Panel
---@field matPctLabel Label
---@field collectBtn Button

---@type RoomCardRefs[]
local roomRefs_ = {}

---@class OrderCardRefs
---@field order Order
---@field badge Panel
---@field badgeLabel Label
---@field progressLabel Label
---@field pctLabel Label
---@field fill Panel
---@field actionBtn Button

---@type OrderCardRefs[]
local orderRefs_ = {}

---@class RichEntry
---@field rank integer
---@field userId any
---@field nickname string
---@field coins integer
---@field isMe boolean

local C = {
    ink = { 58, 41, 24, 255 },
    inkSoft = { 102, 80, 54, 255 },
    cream = { 242, 231, 207, 255 },
    orange = { 245, 158, 44, 255 },
    orangeDeep = { 222, 126, 26, 255 },
    metal = { 178, 175, 166, 255 },
    red = { 205, 62, 45, 255 },
    green = { 79, 150, 62, 255 },
    gray = { 118, 118, 112, 255 },
    amber = { 214, 148, 22, 255 },
    blue = { 58, 132, 206, 255 },
    cardBorder = { 74, 52, 30, 255 },
    track = { 214, 199, 168, 255 },
}

local ORANGE_GRAD = { direction = "to-bottom", from = { 249, 174, 76, 255 }, to = { 224, 124, 26, 255 } }
local ORANGE_GRAD_HOVER = { direction = "to-bottom", from = { 252, 187, 94, 255 }, to = { 233, 137, 37, 255 } }
local ORANGE_GRAD_PRESSED = { direction = "to-bottom", from = { 214, 112, 22, 255 }, to = { 197, 99, 16, 255 } }
local CREAM_GRAD = { direction = "to-bottom", from = { 250, 243, 226, 255 }, to = { 233, 220, 193, 255 } }
local CREAM_GRAD_HOVER = { direction = "to-bottom", from = { 255, 249, 235, 255 }, to = { 240, 228, 203, 255 } }

-- 订单页用冷色纸张质感，与机房的暖色奶油卡片区分
local ORDER_GRAD = { direction = "to-bottom", from = { 240, 247, 253, 255 }, to = { 213, 229, 245, 255 } }
local ORDER_BORDER = { 38, 70, 106, 255 }
local ORDER_INNER_BG = { 255, 255, 255, 120 }
local ORDER_INNER_BORDER = { 150, 178, 208, 180 }

---@param text string
---@param size number
---@param color number[]
---@param weight string|nil
---@return Label
local function Txt(text, size, color, weight)
    return UI.Label {
        text = text,
        fontSize = size,
        fontColor = color --[[@as RGBAColor]],
        fontWeight = weight or "normal",
        lineHeight = 1.2,
        maxLines = 1,
        whiteSpace = "nowrap",
    }
end

---@param path string
---@param size number
---@return Panel
local function Icon(path, size)
    return UI.Panel {
        width = size,
        height = size,
        backgroundImage = path,
        backgroundFit = "contain",
        pointerEvents = "none",
    }
end

---@param n number
---@return string
local function FormatNumber(n)
    if n >= 100000000 then
        return string.format("%.2f亿", n / 100000000)
    elseif n >= 10000 then
        return string.format("%.1f万", n / 10000)
    end
    return tostring(math.floor(n))
end

--- 金币显示：带千分位的精确数值，滚动时能看清每一位变化
---@param n number
---@return string
local function FormatCoins(n)
    local v = math.floor(n)
    local neg = v < 0
    if neg then
        v = -v
    end
    local s = tostring(v)
    local out = s
    if #s > 3 then
        local head = s:sub(1, #s % 3)
        local rest = s:sub(#s % 3 + 1)
        local parts = {}
        for i = 1, #rest, 3 do
            parts[#parts + 1] = rest:sub(i, i + 2)
        end
        local joined = table.concat(parts, ",")
        if head == "" then
            out = joined
        else
            out = head .. "," .. joined
        end
    end
    return (neg and "-" or "") .. out
end

--- 利润显示：四舍五入，支持负数
---@param n number
---@return string
local function FormatProfit(n)
    local rounded = math.floor(n + 0.5)
    if rounded >= 10000 then
        return string.format("%.1f万", n / 10000)
    elseif rounded <= -10000 then
        return string.format("-%.1f万", -n / 10000)
    end
    return tostring(rounded)
end

--- 首页「待完成订单」：尚未交付的订单数
---@return integer
local function HomePendingCount()
    local n = 0
    for _, order in ipairs(M.orders) do
        if order.status ~= "已完成" then
            n = n + 1
        end
    end
    return n
end

--- 首页「客户满意度」：成品件数 / 总件数，没打过件时视为 100%
---@return integer
local function HomeSatisfaction()
    local total = M.goodsDone + M.damagedDone
    if total <= 0 then
        return 100
    end
    return math.floor(M.goodsDone * 100 / total + 0.5)
end

---@param grams number
---@return string
local function FormatGrams(grams)
    if grams >= 1000 then
        local kg = grams / 1000
        if math.abs(kg - math.floor(kg + 0.5)) < 0.01 then
            return string.format("%dkg", math.floor(kg + 0.5))
        end
        return string.format("%.2fkg", kg)
    end
    return string.format("%dg", math.floor(grams))
end

---@param status string
---@return number[]
local function StatusColor(status)
    if status == "打印中" then
        return C.orangeDeep
    elseif status == "可收取" then
        return C.green
    elseif status == "缺料" then
        return C.amber
    elseif status == "故障" then
        return C.red
    end
    return C.gray
end

---@param status string
---@return number[]
local function OrderStatusColor(status)
    if status == "制作中" then
        return C.orangeDeep
    elseif status == "可交付" then
        return C.green
    elseif status == "已完成" then
        return C.gray
    end
    return C.inkSoft
end

---@param order Order
---@return Machine|nil
local function OrderMachine(order)
    if order.machineCode == nil then
        return nil
    end
    return Orders.GetMachine(order.machineCode)
end

---@param order Order
---@return string
local function OrderActionText(order)
    if order.status == "待制作" then
        return "开始制作"
    elseif order.status == "制作中" then
        local machine = OrderMachine(order)
        if machine ~= nil and machine.status == "可收取" then
            return "清理损坏"
        end
        return "打印中"
    elseif order.status == "可交付" then
        return "交付订单"
    end
    return "已完成"
end

--- 订单能否在订单页直接操作
---@param order Order
---@return boolean
local function OrderCanAct(order)
    if order.status == "待制作" or order.status == "可交付" then
        return true
    end
    if order.status == "制作中" then
        local machine = OrderMachine(order)
        return machine ~= nil and machine.status == "可收取"
    end
    return false
end

--- 订单进度文案
---@param order Order
---@return string
local function OrderProgressText(order)
    if order.status == "待制作" then
        return "选择空闲机器开始制作"
    elseif order.status == "制作中" then
        local text = string.format("机器 %s · 成品 %d/%d", order.machineCode or "--",
            order.goodCount, order.quantity)
        if order.damagedCount > 0 then
            text = text .. string.format(" · 损坏 %d", order.damagedCount)
        end
        return text
    elseif order.status == "可交付" then
        return "打印完成，等待交付"
    end
    return "订单已交付"
end

--- 机器卡片右侧的订单摘要
---@param order Order|nil
---@return string
---@return number[]
local function OrderSummaryText(order)
    if order == nil then
        return "无进行中的订单", C.inkSoft
    end
    local text = string.format("成品 %d/%d", order.goodCount, order.quantity)
    if order.damagedCount > 0 then
        text = text .. string.format(" · 损%d", order.damagedCount)
        return text, C.red
    end
    return text, C.orangeDeep
end

---@param m Machine
---@return integer
local function MaterialPercent(m)
    if m.materialMax <= 0 then
        return 0
    end
    return math.floor(math.min(1.0, m.material / m.materialMax) * 100 + 0.5)
end

---@param m Machine
---@return number[]
local function MaterialColor(m)
    if MaterialPercent(m) <= 20 then
        return C.red
    end
    return { 74, 160, 196, 255 }
end

---@param color number[]
---@param alpha integer
---@return RGBAColor
local function WithAlpha(color, alpha)
    return { color[1] or 0, color[2] or 0, color[3] or 0, alpha }
end

---@param a number[]
---@param b number[]
---@param t number
---@return number[]
local function MixColor(a, b, t)
    local a1 = a[1] or 0
    local a2 = a[2] or 0
    local a3 = a[3] or 0
    local a4 = a[4] or 0
    local b1 = b[1] or 0
    local b2 = b[2] or 0
    local b3 = b[3] or 0
    local b4 = b[4] or 0
    return {
        math.floor(a1 + (b1 - a1) * t + 0.5),
        math.floor(a2 + (b2 - a2) * t + 0.5),
        math.floor(a3 + (b3 - a3) * t + 0.5),
        math.floor(a4 + (b4 - a4) * t + 0.5),
    }
end

--- 机器卡片中心点，作为金币飞出的起点
---@param machine Machine
---@return number|nil x
---@return number|nil y
local function MachineCardPoint(machine)
    for _, ref in ipairs(roomRefs_) do
        if ref.machine == machine and ref.card ~= nil then
            local w, h = ref.card:GetComputedSize()
            local x, y = ref.card:GetAbsolutePosition()
            if w ~= nil and x ~= nil then
                return x + w * 0.5, y + h * 0.36
            end
        end
    end
    return nil, nil
end

local function RefreshRoom()
    for _, ref in ipairs(roomRefs_) do
        local m = ref.machine
        local color = StatusColor(m.status)
        ref.statusLabel:SetText(m.status)
        ref.statusLabel:SetFontColor(color)
        local pct = math.floor(m.progress * 100 + 0.5)
        ref.pctLabel:SetText(string.format("%d%%", pct))
        ref.pctLabel:SetFontColor(color)
        ref.fill:SetStyle { width = string.format("%d%%", pct), backgroundColor = color }
        local matPct = MaterialPercent(m)
        local matColor = MaterialColor(m)
        ref.matFill:SetStyle { width = string.format("%d%%", matPct), backgroundColor = matColor }
        ref.matPctLabel:SetText(string.format("%d%%", matPct))
        ref.matPctLabel:SetFontColor(matColor)

        ---@type Order|nil
        local order = nil
        if m.orderId ~= nil then
            order = Orders.Get(m.orderId)
        end
        if order ~= nil then
            local text, rightColor = OrderSummaryText(order)
            ref.rightLabel:SetText(text)
            ref.rightLabel:SetFontColor(rightColor)
            if m.status == "可收取" and order.damagedCount > 0 then
                ref.collectBtn:SetText("收菜 · 补打")
            else
                ref.collectBtn:SetText("收菜")
            end
        else
            ref.rightLabel:SetText(string.format("产出 %d件", m.output))
            ref.rightLabel:SetFontColor(C.inkSoft)
            ref.collectBtn:SetText("收菜")
        end
        ref.collectBtn:SetDisabled(m.status ~= "可收取")
    end
end

--- 金币数字滚动显示：真实值变了不立刻跳，先按缓动追上去
local coinShown_ = 0
local coinTarget_ = 0
local coinTickCooldown_ = 0.0

--- 收菜金币飞行粒子
---@class CoinFly
---@field fromX number
---@field fromY number
---@field ctrlX number
---@field ctrlY number
---@field toX number
---@field toY number
---@field t number
---@field duration number
---@field delay number
---@field scale number

---@type CoinFly[]
local coinFlies_ = {}
---@type Panel|nil
local rootRef_

local COIN_FLY_IMAGE = "Images/ui/icons/coin.png"

--- NanoVG 上下文与金币贴图（独立渲染层，直接画在 UI 之上）
---@type NVGContextWrapper|nil
local coinVg_
---@type integer
local coinImage_ = -1
---@type number
local coinDpr_ = 1.0

local function EnsureCoinRenderer()
    if coinVg_ ~= nil then
        return
    end
    coinDpr_ = graphics:GetDPR()
    if coinDpr_ == nil or coinDpr_ <= 0 then
        coinDpr_ = 1.0
    end
    coinVg_ = nvgCreate(1)
    if coinVg_ == nil then
        return
    end
    -- 画在 UI 库之上（UI 用 999990）
    nvgSetRenderOrder(coinVg_, 999995)
    coinImage_ = nvgCreateImage(coinVg_, COIN_FLY_IMAGE, 0)
    SubscribeToEvent(coinVg_, "NanoVGRender", "HandleCoinRender")
end

---@class CoinRendererState
local coinRenderState_ = {
    logicalW = 1280.0,
    logicalH = 800.0,
}

--- 金币飞行动画的自绘回调
function HandleCoinRender()
    local vg = coinVg_
    if vg == nil then
        return
    end
    local state = coinRenderState_
    local hasParticles = false
    for _, fly in ipairs(coinFlies_) do
        if fly.delay <= 0 and fly.t > 0 and fly.t < 1.0 then
            hasParticles = true
            break
        end
    end
    if not hasParticles then
        return
    end

    nvgBeginFrame(vg, state.logicalW, state.logicalH, coinDpr_)
    if coinImage_ >= 0 then
        for _, fly in ipairs(coinFlies_) do
            if fly.delay <= 0 and fly.t > 0 and fly.t < 1.0 then
                local t = fly.t
                local mt = 1 - t
                local x = mt * mt * fly.fromX + 2 * mt * t * fly.ctrlX + t * t * fly.toX
                local y = mt * mt * fly.fromY + 2 * mt * t * fly.ctrlY + t * t * fly.toY
                local size = 26 - 10 * t
                local paint = nvgImagePattern(vg, x - size * 0.5, y - size * 0.5, size, size, 0, coinImage_, 1.0)
                nvgBeginPath(vg)
                nvgRect(vg, x - size * 0.5, y - size * 0.5, size, size)
                nvgFillPaint(vg, paint)
                nvgFill(vg)
            end
        end
    end
    nvgEndFrame(vg)
end

--- 顶部金币统计中心点（UI 坐标）
---@return number x
---@return number y
local function CoinTargetPoint()
    if coinChipLabel_ ~= nil then
        local w, h = coinChipLabel_:GetComputedSize()
        local x, y = coinChipLabel_:GetAbsolutePosition()
        if w ~= nil and x ~= nil then
            return x + w * 0.5 + 6, y + h * 0.5
        end
    end
    return 120, 36
end

--- 从某个屏幕坐标撒出一批金币飞向顶部统计
---@param fromX number
---@param fromY number
---@param count integer
local function SpawnCoinFly(fromX, fromY, count)
    EnsureCoinRenderer()
    local n = math.max(1, math.min(8, count))
    local toX, toY = CoinTargetPoint()
    for i = 1, n do
        local jitterX = (math.random() - 0.5) * 46
        local jitterY = (math.random() - 0.5) * 30
        ---@type CoinFly
        local fly = {
            fromX = fromX + jitterX,
            fromY = fromY + jitterY,
            ctrlX = (fromX + toX) * 0.5 + (math.random() - 0.5) * 120,
            ctrlY = math.min(fromY, toY) - 90 - math.random() * 70,
            toX = toX,
            toY = toY,
            t = 0.0,
            duration = 0.48 + math.random() * 0.26,
            delay = (i - 1) * 0.065 + math.random() * 0.03,
            scale = 1.0,
        }
        coinFlies_[#coinFlies_ + 1] = fly
    end
end

---@param dt number
local function UpdateCoinFlies(dt)
    if #coinFlies_ == 0 then
        return
    end
    local alive = {} ---@type CoinFly[]
    local landed = 0
    for _, fly in ipairs(coinFlies_) do
        if fly.delay > 0 then
            fly.delay = fly.delay - dt
            alive[#alive + 1] = fly
        else
            fly.t = fly.t + dt / fly.duration
            if fly.t >= 1.0 then
                landed = landed + 1
            else
                alive[#alive + 1] = fly
            end
        end
    end
    coinFlies_ = alive
    if landed > 0 then
        Sfx.CoinSettle(0.5)
    end
end

---@param target integer
local function SetCoinTarget(target)
    if coinTarget_ == target then
        return
    end
    -- 目标变了才重新起滚动；剩余差值越小，收尾越快
    coinTarget_ = target
end

---@param dt number
local function UpdateCoinCounter(dt)
    if coinShown_ == coinTarget_ then
        return
    end
    local diff = coinTarget_ - coinShown_
    -- 差值越大滚得越快，但整体偏慢，让玩家看清数字跳变
    local speed = math.max(1, math.floor(math.abs(diff) * 2.2 + 30))
    local step = speed * dt * 60
    if math.abs(diff) <= step then
        coinShown_ = coinTarget_
    else
        coinShown_ = math.floor(coinShown_ + (diff > 0 and step or -step))
    end
    if coinChipLabel_ ~= nil then
        coinChipLabel_:SetText(FormatCoins(coinShown_))
    end
    coinTickCooldown_ = coinTickCooldown_ - dt
    if coinTickCooldown_ <= 0 then
        coinTickCooldown_ = 0.045
        Sfx.CounterTick(0.06 + math.min(0.25, math.abs(coinTarget_ - coinShown_) / 4000))
    end
end

local function RefreshTopBar()
    SetCoinTarget(math.floor(M.coins))
    if coinChipLabel_ ~= nil then
        coinChipLabel_:SetText(FormatCoins(coinShown_))
    end
    if powerCostLabel_ ~= nil then
        powerCostLabel_:SetText(FormatNumber(M.powerCost))
    end
    if materialCostLabel_ ~= nil then
        materialCostLabel_:SetText(FormatNumber(M.materialCost))
    end
    if profitChipLabel_ ~= nil then
        profitChipLabel_:SetText(FormatProfit(M.profit))
        profitChipLabel_:SetFontColor(M.profit >= 0 and C.green or C.red)
    end
    if machineCostLabel_ ~= nil then
        machineCostLabel_:SetText(FormatNumber(M.machineCost))
    end
    if venueInfoLabel_ ~= nil then
        local remaining = math.max(0, M.daySeconds - M.dayTimer)
        venueInfoLabel_:SetText(string.format("日租 %d · 第 %d 天 %.0fs",
            Orders.CurrentVenue().rent, M.day, remaining))
    end
    if venueRentLabel_ ~= nil then
        local remaining = math.max(0, M.daySeconds - M.dayTimer)
        local venue = Orders.CurrentVenue()
        if M.rentDue > 0 then
            venueRentLabel_:SetText(string.format("第 %d 天 · %.0f 秒后交租 · 已欠租 %d 金币",
                M.day, remaining, M.rentDue))
            venueRentLabel_:SetFontColor(C.red)
        else
            venueRentLabel_:SetText(string.format("第 %d 天 · %.0f 秒后交租 %d 金币",
                M.day, remaining, venue.rent))
            venueRentLabel_:SetFontColor(C.inkSoft)
        end
    end
    if homeCoinLabel_ ~= nil then
        homeCoinLabel_:SetText(FormatCoins(coinShown_))
    end
    if homeExpLabel_ ~= nil then
        homeExpLabel_:SetText(FormatNumber(M.exp))
    end
    if homeProfitLabel_ ~= nil then
        homeProfitLabel_:SetText(FormatProfit(M.profit))
        homeProfitLabel_:SetFontColor(M.profit >= 0 and C.green or C.red)
    end
    if homeRevenueLabel_ ~= nil then
        homeRevenueLabel_:SetText(FormatCoins(math.floor(M.todayRevenue)))
    end
    if homePendingLabel_ ~= nil then
        homePendingLabel_:SetText(tostring(HomePendingCount()))
    end
    if homeSatisfactionLabel_ ~= nil then
        local pct = HomeSatisfaction()
        homeSatisfactionLabel_:SetText(string.format("%d%%", pct))
        homeSatisfactionLabel_:SetFontColor(pct >= 90 and C.green or (pct >= 70 and C.amber or C.red))
    end
    if homeDeliveredLabel_ ~= nil then
        homeDeliveredLabel_:SetText(string.format("%d 件", M.todayDelivered))
    end
end

--- 缺料/故障卡片：边缘闪烁 + 警示三角晃动
local function UpdateWarningFx()
    if #roomRefs_ == 0 then
        return
    end
    local t = fxTime_
    for _, ref in ipairs(roomRefs_) do
        local status = ref.machine.status
        if status == "缺料" or status == "故障" then
            local warn = status == "缺料" and C.amber or C.red
            local pulse = 0.5 + 0.5 * math.sin(t * 7.0)
            local mix = 0.35 + 0.65 * pulse
            ref.card:SetStyle {
                borderColor = MixColor(C.cardBorder, warn, mix),
                boxShadow = {
                    { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 76 } },
                    { x = 0, y = 0, blur = 6 + 5 * pulse, spread = 0,
                      color = { warn[1], warn[2], warn[3], math.floor(30 + 90 * pulse) } },
                },
            }
            if ref.warnIcon ~= nil then
                ref.warnIcon:SetStyle {
                    right = 3 + math.sin(t * 18.0) * 2.0,
                    top = 3 + math.sin(t * 23.0) * 1.2,
                }
            end
        end
    end
end

local function RefreshOrders()
    for _, ref in ipairs(orderRefs_) do
        local order = ref.order
        local color = OrderStatusColor(order.status)
        ref.badge:SetBackgroundColor(WithAlpha(color, 38))
        ref.badge:SetBorderColor(WithAlpha(color, 150))
        ref.badgeLabel:SetText(order.status)
        ref.badgeLabel:SetFontColor(color)
        local pct = math.floor(order.progress * 100 + 0.5)
        ref.progressLabel:SetText(OrderProgressText(order))
        if order.status == "待制作" then
            ref.pctLabel:SetText("")
        elseif order.status == "制作中" then
            ref.pctLabel:SetText(string.format("%d%%", pct))
            if order.damagedCount > 0 then
                ref.pctLabel:SetFontColor(C.red)
            else
                ref.pctLabel:SetFontColor(color)
            end
        elseif order.status == "可交付" then
            ref.pctLabel:SetText("100%")
        else
            ref.pctLabel:SetText("完成")
        end
        ref.fill:SetStyle { width = string.format("%d%%", pct), backgroundColor = color }
        ref.actionBtn:SetText(OrderActionText(order))
        ref.actionBtn:SetDisabled(not OrderCanAct(order))
    end
end

---@param text string
---@param opts table|nil
---@return Button
local function OrangeButton(text, opts)
    opts = opts or {}
    return UI.Button {
        text = text,
        height = opts.height or 30,
        fontSize = opts.fontSize or 12,
        fontWeight = "bold",
        width = opts.width,
        paddingHorizontal = opts.paddingHorizontal or 12,
        backgroundGradient = ORANGE_GRAD,
        hoverBackgroundGradient = ORANGE_GRAD_HOVER,
        pressedBackgroundGradient = ORANGE_GRAD_PRESSED,
        borderWidth = 2,
        borderColor = C.ink,
        borderRadius = 6,
        textColor = { 62, 40, 18, 255 },
        disabled = opts.disabled,
        disabledBackgroundColor = opts.disabledBackgroundColor,
        disabledBackgroundGradient = opts.disabledBackgroundGradient,
        disabledTextColor = opts.disabledTextColor,
        onClick = opts.onClick,
    }
end

---@param text string
---@param opts table|nil
---@return Button
local function CreamButton(text, opts)
    opts = opts or {}
    return UI.Button {
        text = text,
        height = opts.height or 30,
        fontSize = opts.fontSize or 12,
        fontWeight = "bold",
        width = opts.width,
        paddingHorizontal = opts.paddingHorizontal or 12,
        backgroundGradient = CREAM_GRAD,
        hoverBackgroundGradient = CREAM_GRAD_HOVER,
        borderWidth = 2,
        borderColor = C.ink,
        borderRadius = 6,
        textColor = C.ink,
        disabled = opts.disabled,
        disabledBackgroundColor = opts.disabledBackgroundColor,
        disabledBackgroundGradient = opts.disabledBackgroundGradient,
        disabledTextColor = opts.disabledTextColor,
        onClick = opts.onClick,
    }
end

---@param iconPath string
---@param label string
---@param value number
---@param format? fun(n: number): string 自定义数值格式，默认缩写（12.8万）
---@return Panel
---@return Label
local function ResourceChip(iconPath, label, value, format)
    local iconSize = compact_ and 20 or 24
    local plusSize = compact_ and 22 or 24
    local chipHeight = compact_ and 42 or 46
    local text = (format or FormatNumber)(value)
    local valueLabel = Txt(text, compact_ and 13 or 14, C.ink, "bold")
    local panel = UI.Panel {
        height = chipHeight,
        flexDirection = "row",
        alignItems = "center",
        gap = compact_ and 4 or 6,
        paddingLeft = 6,
        paddingRight = 4,
        borderRadius = 8,
        backgroundGradient = CREAM_GRAD,
        borderWidth = 2,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 2, blur = 3, spread = 0, color = { 0, 0, 0, 70 } } },
        children = {
            Icon(iconPath, iconSize),
            UI.Panel {
                flexDirection = "column",
                gap = 1,
                children = {
                    Txt(label, 9, C.inkSoft),
                    valueLabel,
                },
            },
            UI.Panel {
                width = plusSize,
                height = plusSize,
                borderRadius = 6,
                justifyContent = "center",
                alignItems = "center",
                backgroundGradient = ORANGE_GRAD,
                borderWidth = 2,
                borderColor = C.ink,
                children = { Txt("+", compact_ and 12 or 14, { 62, 40, 18, 255 }, "bold") },
            },
        },
    }
    return panel, valueLabel
end

---@param iconPath string
---@param label string
---@param active boolean
---@param onClick fun()|nil
---@return Panel
local function NavButton(iconPath, label, active, onClick)
    return UI.Panel {
        width = compact_ and 57 or 74,
        height = 54,
        pointerEvents = "box-only",
        flexDirection = "column",
        justifyContent = "center",
        alignItems = "center",
        gap = 2,
        borderRadius = 8,
        backgroundGradient = active and ORANGE_GRAD or CREAM_GRAD,
        borderWidth = 2,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 2, blur = 3, spread = 0, color = { 0, 0, 0, 70 } } },
        onClick = function()
            print("[3D打印] 导航点击：" .. label)
            if onClick ~= nil then
                onClick()
            end
        end,
        children = {
            Icon(iconPath, compact_ and 21 or 24),
            Txt(label, 11, C.ink, "bold"),
        },
    }
end

---@class ChipBadge
---@field count integer
---@field color number[]|nil

--- 机房状态筛选与气泡配色
---@type table<string, number[]>
local ROOM_STATUS_BADGE_COLOR = {
    ["打印中"] = { 58, 132, 206, 255 },
    ["空闲"] = { 118, 118, 112, 255 },
    ["缺料"] = { 214, 148, 22, 255 },
    ["故障"] = { 205, 62, 45, 255 },
    ["可收取"] = { 79, 150, 62, 255 },
}

---@param text string
---@param active boolean
---@param onClick fun()|nil
---@param badge ChipBadge|nil
---@param cool boolean|nil 订单页使用冷色底
---@return Panel
local function FilterChip(text, active, onClick, badge, cool)
    local fontSize = compact_ and 11 or 12
    ---@type Widget[]
    local children = { Txt(text, fontSize, active and { 62, 40, 18, 255 } or C.ink, "bold") }
    if badge ~= nil then
        local color = badge.color or C.inkSoft
        children[#children + 1] = UI.Panel {
            height = 17,
            minWidth = 17,
            paddingHorizontal = 4,
            borderRadius = 9,
            justifyContent = "center",
            alignItems = "center",
            backgroundColor = color,
            borderWidth = 1,
            borderColor = { 255, 248, 235, 190 },
            children = { Txt(tostring(badge.count), 9, { 255, 248, 235, 255 }, "bold") },
        }
    end
    local idleGradient = cool and ORDER_GRAD or CREAM_GRAD
    return UI.Panel {
        height = 34,
        paddingHorizontal = compact_ and 6 or 12,
        flexDirection = "row",
        alignItems = "center",
        gap = compact_ and 4 or 5,
        borderRadius = 6,
        backgroundGradient = active and ORANGE_GRAD or idleGradient,
        borderWidth = 2,
        borderColor = cool and not active and ORDER_BORDER or C.ink,
        onClick = onClick,
        children = children,
    }
end

---@return Panel
local function BuildTopBar()
    local nav = {
        NavButton("Images/ui/icons/home.png", "首页", currentPage_ == "home", function()
            if currentPage_ ~= "home" then
                pendingPage_ = "home"
            end
        end),
        NavButton("Images/ui/icons/room.png", "机房", currentPage_ == "room", function()
            if currentPage_ ~= "room" then
                pendingPage_ = "room"
            end
        end),
        NavButton("Images/ui/icons/box.png", "订单", currentPage_ == "orders", function()
            if currentPage_ ~= "orders" then
                pendingPage_ = "orders"
            end
        end),
        NavButton("Images/ui/icons/shop.png", "商店", currentPage_ == "shop", function()
            if currentPage_ ~= "shop" then
                pendingPage_ = "shop"
            end
        end),
        NavButton("Images/ui/icons/book.png", "图鉴", currentPage_ == "gallery", function()
            if currentPage_ ~= "gallery" then
                pendingPage_ = "gallery"
            end
        end),
        NavButton("Images/ui/icons/diamond.png", "富豪榜", currentPage_ == "rich", function()
            if currentPage_ ~= "rich" then
                pendingPage_ = "rich"
            end
        end),
        NavButton("Images/ui/icons/gear.png", "设置", false, function()
            UI.Toast.Show("「设置」功能开发中", { type = "info", duration = 1.6 })
        end),
    }

    -- 金币用精确千分位，且取当前滚动值，避免切页时先显示缩写再跳变
    local coinChip, coinLabel = ResourceChip("Images/ui/icons/coin.png", "金币", coinShown_, FormatCoins)
    local powerChip, powerLabel = ResourceChip("Images/ui/icons/bolt.png", "耗电成本", M.powerCost)
    local materialChip, materialLabel = ResourceChip("Images/ui/icons/spool.png", "耗材成本", M.materialCost)
    local profitChip, profitLabel = ResourceChip("Images/ui/icons/diamond.png", "经营利润", M.profit)
    profitLabel:SetFontColor(C.green)
    local machineChip, machineLabel = ResourceChip("Images/ui/icons/shop.png", "购机成本", M.machineCost)
    coinChipLabel_ = coinLabel
    powerCostLabel_ = powerLabel
    materialCostLabel_ = materialLabel
    profitChipLabel_ = profitLabel
    machineCostLabel_ = machineLabel

    ---@type Widget[]
    local navChildren = { UI.Spacer() }
    for _, btn in ipairs(nav) do
        navChildren[#navChildren + 1] = btn
    end

    return UI.Panel {
        height = 72,
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        paddingHorizontal = 10,
        backgroundColor = C.metal,
        backgroundImage = "Images/ui/metal_bg.png",
        backgroundImageOpacity = 0.42,
        borderBottomWidth = 3,
        borderBottomColor = C.ink,
        children = {
            coinChip,
            powerChip,
            materialChip,
            machineChip,
            profitChip,
            table.unpack(navChildren),
        },
    }
end

---@param label string
---@param pctText string
---@param pctColor number[]
---@param track Panel
---@param size number
---@return Panel
---@return Label
local function BarGroup(label, pctText, pctColor, track, size)
    local pctLabel = Txt(pctText, size, pctColor, "bold")
    local panel = UI.Panel {
        flexDirection = "column",
        gap = 2,
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                children = {
                    Txt(label, size, C.inkSoft),
                    UI.Spacer(),
                    pctLabel,
                },
            },
            track,
        },
    }
    return panel, pctLabel
end

---@param m Machine
---@return Panel
local function BuildCard(m)
    local color = StatusColor(m.status)
    local pct = math.floor(m.progress * 100 + 0.5)
    local imgSize = compact_ and 84 or 92
    local modelFont = compact_ and 12 or 13
    local detailFont = compact_ and 9 or 10
    local barFont = compact_ and 8 or 9
    local cardHeight = compact_ and 178 or 186

    local canCollect = m.status == "可收取"
    local warnImage = nil
    if m.status == "缺料" then
        warnImage = "Images/ui/icons/warn_yellow.png"
    elseif m.status == "故障" then
        warnImage = "Images/ui/icons/warn_red.png"
    end
    local matPct = 0
    if m.materialMax > 0 then
        matPct = math.floor(math.min(1.0, m.material / m.materialMax) * 100 + 0.5)
    end
    local matColor = { 74, 160, 196, 255 }
    if matPct <= 20 then
        matColor = C.red
    end

    local fill = UI.Panel {
        width = string.format("%d%%", pct),
        height = "100%",
        borderRadius = 3,
        backgroundColor = color,
    }
    local track = UI.Panel {
        width = "100%",
        height = 7,
        borderRadius = 4,
        backgroundColor = C.track,
        borderWidth = 2,
        borderColor = C.ink,
        overflow = "hidden",
        children = { fill },
    }
    local matFill = UI.Panel {
        width = string.format("%d%%", matPct),
        height = "100%",
        borderRadius = 3,
        backgroundColor = matColor,
    }
    local matTrack = UI.Panel {
        width = "100%",
        height = 7,
        borderRadius = 4,
        backgroundColor = C.track,
        borderWidth = 2,
        borderColor = C.ink,
        overflow = "hidden",
        children = { matFill },
    }

    local statusLabel = Txt(m.status, 13, color, "bold")

    ---@type Order|nil
    local activeOrder = nil
    if m.orderId ~= nil then
        activeOrder = Orders.Get(m.orderId)
    end
    local rightText = string.format("产出 %d件", m.output)
    local rightColor = C.inkSoft
    if activeOrder ~= nil then
        rightText, rightColor = OrderSummaryText(activeOrder)
    end
    local rightInfo = Txt(rightText, detailFont, rightColor)

    local printBar, pctLabel = BarGroup("打印", string.format("%d%%", pct), color, track, barFont)
    local matBar, matPctLabel = BarGroup("耗材", string.format("%d%%", matPct), matColor, matTrack, barFont)

    local collectBtn = OrangeButton("收菜", {
        height = 30,
        fontSize = 12,
        width = "100%",
        disabled = not canCollect,
        disabledBackgroundGradient = {
            direction = "to-bottom",
            from = { 202, 196, 184, 255 },
            to = { 178, 172, 160, 255 },
        },
        disabledTextColor = { 128, 120, 106, 255 },
        onClick = function()
            local fromX, fromY = MachineCardPoint(m)
            local gained, message = Orders.Collect(m)
            local kind = "info"
            if m.status == "打印中" or m.status == "缺料" then
                kind = "warning"
            elseif gained > 0 then
                kind = "success"
            end
            if gained > 0 then
                local count = math.max(3, math.min(8, math.floor(gained / 90) + 3))
                SpawnCoinFly(fromX or 120, fromY or 120, count)
                Sfx.CoinPickup(0.5)
                RefreshTopBar()
            elseif kind == "warning" then
                Sfx.Bad()
            end
            UI.Toast.Show(message, { type = kind, duration = 2.0 })
            pendingPage_ = "room"
        end,
    })

    local actionBtn = OrangeButton("操作", {
        height = 30,
        fontSize = 12,
        width = "100%",
        onClick = function()
            opMachineCode_ = m.code
            pendingPage_ = "room"
        end,
    })

    local warnBadge = UI.Panel {
        position = "absolute",
        top = 3,
        right = 3,
        width = 28,
        height = 28,
        backgroundImage = warnImage or "Images/ui/icons/warn_yellow.png",
        backgroundFit = "contain",
        pointerEvents = "none",
        zIndex = 5,
    }
    warnBadge:SetVisible(warnImage ~= nil)

    local card = UI.Panel {
        flexGrow = 1,
        flexBasis = 0,
        height = cardHeight,
        flexDirection = "column",
        gap = 4,
        padding = 9,
        borderRadius = 8,
        overflow = "hidden",
        backgroundGradient = CREAM_GRAD,
        borderWidth = 2,
        borderColor = { 74, 52, 30, 255 },
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 76 } } },
        children = {
            UI.Panel {
                height = 30,
                flexDirection = "row",
                alignItems = "center",
                gap = 3,
                overflow = "hidden",
                paddingRight = warnImage ~= nil and 24 or 0,
                children = {
                    Txt(m.code, 11, C.inkSoft),
                    Txt(compact_ and m.short or m.model, modelFont, C.ink, "bold"),
                    UI.Spacer(),
                    Txt(string.format("Lv.%d", m.level), 10, C.inkSoft),
                },
            },
            UI.Panel {
                height = imgSize,
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                overflow = "hidden",
                children = {
                    Icon(m.sprite, imgSize),
                    UI.Panel {
                        flexGrow = 1,
                        flexBasis = 0,
                        flexDirection = "column",
                        gap = 6,
                        justifyContent = "center",
                        children = {
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                children = {
                                    statusLabel,
                                    UI.Spacer(),
                                    rightInfo,
                                },
                            },
                            UI.Panel {
                                flexDirection = "column",
                                gap = 4,
                                children = { printBar, matBar },
                            },
                        },
                    },
                },
            },
            UI.Panel {
                flexDirection = "row",
                gap = 6,
                height = 30,
                children = {
                    UI.Panel { flexGrow = 1, flexBasis = 0, children = { actionBtn } },
                    UI.Panel { flexGrow = 1, flexBasis = 0, children = { collectBtn } },
                },
            },
            warnBadge,
        },
    }

    roomRefs_[#roomRefs_ + 1] = {
        machine = m,
        card = card,
        warnIcon = warnImage ~= nil and warnBadge or nil,
        statusLabel = statusLabel,
        pctLabel = pctLabel,
        rightLabel = rightInfo,
        fill = fill,
        matFill = matFill,
        matPctLabel = matPctLabel,
        collectBtn = collectBtn,
    }
    return card
end

---@param rowsWidth number
---@return Panel
local function BuildRows(rowsWidth)
    ---@type Machine[]
    local visible = {}
    for _, machine in ipairs(M.machines) do
        if roomFilter_ == "all" or machine.status == roomFilter_ then
            visible[#visible + 1] = machine
        end
    end

    local rows = {}
    local index = 1
    while index <= #visible do
        local cards = {}
        for i = index, math.min(index + 3, #visible) do
            local machine = visible[i]
            if machine ~= nil then
                cards[#cards + 1] = BuildCard(machine)
            end
        end
        for _ = #cards + 1, 4 do
            cards[#cards + 1] = UI.Panel { flexGrow = 1, flexBasis = 0 }
        end
        rows[#rows + 1] = UI.Panel {
            width = rowsWidth,
            flexDirection = "row",
            gap = 8,
            children = cards,
        }
        index = index + 4
    end

    return UI.Panel {
        width = rowsWidth,
        flexDirection = "column",
        gap = 8,
        children = rows,
    }
end

---@type { key: string, label: string }[]
local ROOM_FILTERS = {
    { key = "all", label = "全部" },
    { key = "打印中", label = "打印中" },
    { key = "空闲", label = "空闲" },
    { key = "缺料", label = "缺料" },
    { key = "故障", label = "故障" },
    { key = "可收取", label = "可收取" },
}

---@param key string
---@return integer
local function RoomFilterCount(key)
    if key == "all" then
        return #M.machines
    end
    return Orders.CountMachinesByStatus(key)
end

---@return Panel
local function BuildMainFrame()
    local titlePlate = UI.Panel {
        height = 48,
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        paddingHorizontal = 12,
        borderRadius = 8,
        backgroundGradient = CREAM_GRAD,
        borderWidth = 3,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 80 } } },
        children = {
            Icon("Images/ui/icons/room.png", 30),
            Txt(string.format("打印机列表 · %d/%d 台", #M.machines, Orders.Capacity()), 22, C.ink, "bold"),
        },
    }

    local venue = Orders.CurrentVenue()
    local venueInfo = Txt(string.format("日租 %d · 第 %d 天 %.0fs",
        venue.rent, M.day, math.max(0, M.daySeconds - M.dayTimer)), 9, C.inkSoft)
    venueInfoLabel_ = venueInfo

    local venueChip = UI.Panel {
        height = 48,
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        paddingHorizontal = 12,
        borderRadius = 8,
        backgroundGradient = CREAM_GRAD,
        borderWidth = 3,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 80 } } },
        onClick = function()
            venueOpen_ = true
            pendingPage_ = "room"
        end,
        children = {
            UI.Panel {
                flexDirection = "column",
                gap = 1,
                children = {
                    Txt(venue.name, 15, C.ink, "bold"),
                    venueInfo,
                },
            },
            Txt("扩建 >", 11, C.orangeDeep, "bold"),
        },
    }

    local viewportWidth = UI.GetWidth()
    if viewportWidth < 200 then
        viewportWidth = 1280
    end
    local rowsWidth = viewportWidth - 56

    local content
    local visibleCount = 0
    for _, machine in ipairs(M.machines) do
        if roomFilter_ == "all" or machine.status == roomFilter_ then
            visibleCount = visibleCount + 1
        end
    end
    if #M.machines == 0 then
        content = UI.Panel {
            width = rowsWidth,
            height = 340,
            justifyContent = "center",
            alignItems = "center",
            gap = 10,
            children = {
                Icon("Images/ui/printers/ender3v3.png", 110),
                Txt("机房还没有打印机", 20, C.ink, "bold"),
                Txt("去商店购买第一台打印机，然后接单赚钱", 12, C.inkSoft),
                OrangeButton("前往商店", {
                    height = 40,
                    fontSize = 14,
                    paddingHorizontal = 28,
                    onClick = function()
                        pendingPage_ = "shop"
                    end,
                }),
            },
        }
    elseif visibleCount == 0 then
        content = UI.Panel {
            width = rowsWidth,
            height = 220,
            justifyContent = "center",
            alignItems = "center",
            gap = 8,
            children = {
                Icon("Images/ui/icons/room.png", 52),
                Txt("当前筛选下没有机器", 16, C.ink, "bold"),
                CreamButton("查看全部", {
                    height = 36,
                    fontSize = 13,
                    paddingHorizontal = 22,
                    onClick = function()
                        roomFilter_ = "all"
                        pendingPage_ = "room"
                    end,
                }),
            },
        }
    else
        content = BuildRows(rowsWidth)
    end

    local chips = {}
    for _, filter in ipairs(ROOM_FILTERS) do
        ---@type ChipBadge|nil
        local badge = nil
        if filter.key == "all" then
            badge = { count = RoomFilterCount(filter.key), color = C.inkSoft }
        else
            badge = { count = RoomFilterCount(filter.key), color = ROOM_STATUS_BADGE_COLOR[filter.key] }
        end
        chips[#chips + 1] = FilterChip(filter.label, roomFilter_ == filter.key, function()
            if roomFilter_ ~= filter.key then
                roomFilter_ = filter.key
                pendingPage_ = "room"
            end
        end, badge)
    end

    ---@type Widget
    local chipsRow
    if compact_ then
        chipsRow = UI.ScrollView {
            flexGrow = 1,
            flexBasis = 0,
            height = 36,
            scrollX = true,
            showScrollbar = false,
            bounces = false,
            children = {
                UI.Panel {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = 6,
                    children = chips,
                },
            },
        }
    else
        chipsRow = UI.Panel {
            flexGrow = 1,
            flexBasis = 0,
            flexDirection = "row",
            alignItems = "center",
            gap = 6,
            children = chips,
        }
    end

    local scroll = UI.ScrollView {
        id = "machineScroll",
        flexGrow = 1,
        flexBasis = 0,
        scrollY = true,
        showScrollbar = true,
        bounces = true,
        children = { content },
    }

    return UI.Panel {
        flexGrow = 1,
        flexBasis = 0,
        marginHorizontal = 10,
        marginVertical = 8,
        padding = 8,
        flexDirection = "column",
        gap = 8,
        borderRadius = 8,
        backgroundColor = C.metal,
        backgroundImage = "Images/ui/metal_bg.png",
        backgroundImageOpacity = 0.36,
        borderWidth = 3,
        borderColor = C.ink,
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 10,
                children = {
                    titlePlate,
                    venueChip,
                    -- 窄屏时筛选标签改用横向滚动，避免被裁掉
                    chipsRow,
                },
            },
            scroll,
        },
    }
end

local function CollectAllMachines()
    -- 每台待收取机器各自喷一串金币，视觉上指向顶部统计
    ---@type { x: number, y: number, machine: Machine }[]
    local origins = {}
    for _, machine in ipairs(M.machines) do
        if machine.status == "可收取" then
            local x, y = MachineCardPoint(machine)
            origins[#origins + 1] = { x = x or 200, y = y or 200, machine = machine }
        end
    end

    local count, coins = Orders.CollectAll()
    if count > 0 then
        local kind = coins > 0 and "success" or "warning"
        if coins > 0 then
            for i, origin in ipairs(origins) do
                local countPer = math.max(2, math.min(6, math.floor(coins / math.max(1, #origins) / 120) + 2))
                local _ = origin.machine
                SpawnCoinFly(origin.x, origin.y, countPer)
                if i == 1 then
                    Sfx.CoinPickup(0.5)
                end
            end
            RefreshTopBar()
        else
            Sfx.Bad()
        end
        UI.Toast.Show(string.format("已收取 %d 台机器，+%d 金币", count, coins),
            { type = kind, duration = 2.0 })
        pendingPage_ = "room"
    else
        UI.Toast.Show("暂时没有可收取的机器", { type = "info", duration = 1.4 })
    end
end

local function BuyMaterial(material)
    local ok, message = Orders.BuyMaterial(material)
    UI.Toast.Show(message, { type = ok and "success" or "error", duration = 2.0 })
    pendingPage_ = "shop"
end

local function RefillAllMachines()
    if #M.machines == 0 then
        UI.Toast.Show("机房还是空的，先去商店购买打印机", { type = "info", duration = 1.8 })
        return
    end

    local ok, grams, shortage = Orders.RefillAll()
    if ok then
        UI.Toast.Show(string.format("已加料 %dg，库存剩余 %dg", grams, M.materialStock),
            { type = "success", duration = 1.8 })
        pendingPage_ = "room"
    elseif grams <= 0 then
        UI.Toast.Show("所有机器耗材都是满的", { type = "info", duration = 1.4 })
    else
        UI.Toast.Show(string.format("库存耗材不足，还差 %dg，请去商店购买", shortage),
            { type = "error", duration = 2.0 })
    end
end

local function RepairAllMachines()
    if #M.machines == 0 then
        UI.Toast.Show("机房还是空的，先去商店购买打印机", { type = "info", duration = 1.8 })
        return
    end

    local faults = Orders.CountMachinesByStatus("故障")
    if faults == 0 then
        UI.Toast.Show("没有故障的机器", { type = "info", duration = 1.4 })
        return
    end

    local count, spent = Orders.RepairAll()
    if count > 0 then
        UI.Toast.Show(string.format("已维修 %d 台机器，花费 %d 金币", count, spent),
            { type = "success", duration = 1.8 })
        pendingPage_ = "room"
    else
        UI.Toast.Show(string.format("金币不足，维修一台需要 %d 金币", M.repairCost),
            { type = "error", duration = 1.8 })
    end
end

---@return Panel
local function BuildBottomBar()
    return UI.Panel {
        height = 64,
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        paddingHorizontal = 12,
        backgroundColor = C.metal,
        backgroundImage = "Images/ui/metal_bg.png",
        backgroundImageOpacity = 0.42,
        borderTopWidth = 3,
        borderTopColor = C.ink,
        children = {
            CreamButton("批量维修", { height = 40, fontSize = 13, paddingHorizontal = 18, onClick = RepairAllMachines }),
            CreamButton("批量加料", { height = 40, fontSize = 13, paddingHorizontal = 18, onClick = RefillAllMachines }),
            UI.Spacer(),
            OrangeButton("一键收菜", { height = 40, fontSize = 14, paddingHorizontal = 28, onClick = CollectAllMachines }),
        },
    }
end

---@param n integer
---@return string
local function FormatPrice(n)
    if n >= 1000 then
        return string.format("%d,%03d", math.floor(n / 1000), n % 1000)
    end
    return tostring(n)
end

---@param text string
---@param active boolean
---@param key string
---@return Panel
local function ShopTab(text, active, key)
    return UI.Panel {
        height = 34,
        paddingHorizontal = 14,
        justifyContent = "center",
        alignItems = "center",
        borderRadius = 6,
        backgroundGradient = active and ORANGE_GRAD or ORDER_GRAD,
        borderWidth = 2,
        borderColor = active and C.ink or ORDER_BORDER,
        onClick = function()
            shopTab_ = key
            pendingPage_ = "shop"
        end,
        children = { Txt(text, 12, active and { 62, 40, 18, 255 } or C.ink, "bold") },
    }
end

---@param text string
---@param color number[]
---@return Panel
local function MiniBadge(text, color)
    return UI.Panel {
        height = 16,
        paddingHorizontal = 6,
        borderRadius = 8,
        backgroundColor = WithAlpha(color, 34),
        borderWidth = 1,
        borderColor = WithAlpha(color, 120),
        justifyContent = "center",
        children = { Txt(text, 9, color, "bold") },
    }
end

---@param p ShopPrinter
---@return Panel
local function BuildPrinterBadges(p)
    local speedPct = math.floor((p.speed - 1.0) * 100 + 0.5)
    local speedText = "标准速度"
    local speedColor = C.inkSoft
    if speedPct > 0 then
        speedText = string.format("速度 +%d%%", speedPct)
        speedColor = C.green
    elseif speedPct < 0 then
        speedText = string.format("速度 %d%%", speedPct)
        speedColor = C.red
    end

    local matPct = math.floor((1.0 - p.materialRate) * 100 + 0.5)
    local matText = "标准耗材"
    local matColor = C.inkSoft
    if matPct > 0 then
        matText = string.format("省料 %d%%", matPct)
        matColor = { 74, 160, 196, 255 }
    elseif matPct < 0 then
        matText = string.format("多耗 %d%%", -matPct)
        matColor = C.orangeDeep
    end

    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = 4,
        children = { MiniBadge(speedText, speedColor), MiniBadge(matText, matColor) },
    }
end

---@param name string
---@param tag string
---@param image string
---@param spec string
---@param price integer
---@param ref string
---@param badgeRow Panel|nil
---@param onBuy fun()|nil
---@return Panel
local function ShopCard(name, tag, image, spec, price, ref, badgeRow, onBuy)
    ---@type Widget[]
    local children = {
        UI.Panel {
            height = 22,
            flexDirection = "row",
            alignItems = "center",
            gap = 4,
            overflow = "hidden",
            children = {
                Txt(name, compact_ and 12 or 13, C.ink, "bold"),
                UI.Spacer(),
                UI.Panel {
                    height = 16,
                    paddingHorizontal = 5,
                    borderRadius = 8,
                    backgroundColor = { 245, 158, 44, 38 },
                    borderWidth = 1,
                    borderColor = { 222, 126, 26, 150 },
                    justifyContent = "center",
                    children = { Txt(tag, 9, C.orangeDeep, "bold") },
                },
            },
        },
        UI.Panel {
            flexGrow = 1,
            flexBasis = 0,
            borderRadius = 6,
            backgroundColor = ORDER_INNER_BG,
            borderWidth = 1,
            borderColor = ORDER_INNER_BORDER,
            justifyContent = "center",
            alignItems = "center",
            overflow = "hidden",
            children = { Icon(image, compact_ and 90 or 102) },
        },
        Txt(spec, compact_ and 9 or 10, C.inkSoft),
    }
    if badgeRow ~= nil then
        children[#children + 1] = badgeRow
    end
    children[#children + 1] = UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = 4,
        children = {
            Icon("Images/ui/icons/coin.png", 14),
            Txt(FormatPrice(price), 15, C.ink, "bold"),
            Txt("≈" .. ref, 9, C.inkSoft),
            UI.Spacer(),
        },
    }
    children[#children + 1] = OrangeButton("购买", {
        height = 30,
        fontSize = 12,
        width = "100%",
        onClick = onBuy,
    })

    return UI.Panel {
        flexGrow = 1,
        flexBasis = 0,
        height = compact_ and 240 or 252,
        flexDirection = "column",
        gap = 4,
        padding = 9,
        borderRadius = 8,
        overflow = "hidden",
        backgroundGradient = ORDER_GRAD,
        borderWidth = 2,
        borderColor = ORDER_BORDER,
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 76 } } },
        children = children,
    }
end

---@param rowsWidth number
---@param cards Panel[]
---@return Panel
local function BuildCardRows(rowsWidth, cards)
    local rows = {}
    local index = 1
    while index <= #cards do
        local rowCards = {}
        for i = index, math.min(index + 3, #cards) do
            rowCards[#rowCards + 1] = cards[i]
        end
        for _ = #rowCards + 1, 4 do
            rowCards[#rowCards + 1] = UI.Panel { flexGrow = 1, flexBasis = 0 }
        end
        rows[#rows + 1] = UI.Panel {
            width = rowsWidth,
            flexDirection = "row",
            gap = 8,
            children = rowCards,
        }
        index = index + 4
    end
    return UI.Panel {
        width = rowsWidth,
        flexDirection = "column",
        gap = 8,
        children = rows,
    }
end

---@param printer ShopPrinter
local function BuyPrinter(printer)
    if Orders.IsFull() then
        local venue = Orders.CurrentVenue()
        UI.Toast.Show(string.format("%s只能放 %d 台机器，先扩建更大场地", venue.name, venue.capacity),
            { type = "warning", duration = 2.4 })
        return
    end
    if M.coins < printer.price then
        UI.Toast.Show(string.format("金币不足，购买需要 %d 金币", printer.price),
            { type = "error", duration = 1.8 })
        return
    end

    M.coins = M.coins - printer.price
    M.machineCost = M.machineCost + printer.price
    M.profit = M.profit - printer.price
    local machine = Orders.AddMachine(printer)
    UI.Toast.Show(string.format("已购买 %s，放入机房 %s，记得单独加料", printer.name, machine.code),
        { type = "success", duration = 2.4 })
    pendingPage_ = "shop"
end

---@return Panel
local function BuildShopFrame()
    local titlePlate = UI.Panel {
        height = 48,
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        paddingHorizontal = 12,
        borderRadius = 8,
        backgroundGradient = ORDER_GRAD,
        borderWidth = 3,
        borderColor = ORDER_BORDER,
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 80 } } },
        children = {
            Icon("Images/ui/icons/shop.png", 30),
            Txt("商店", 22, C.ink, "bold"),
        },
    }

    local balance = UI.Panel {
        height = 42,
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        paddingHorizontal = 10,
        borderRadius = 8,
        backgroundGradient = ORDER_GRAD,
        borderWidth = 2,
        borderColor = ORDER_BORDER,
        children = {
            Icon("Images/ui/icons/coin.png", 20),
            Txt("金币", 9, C.inkSoft),
            Txt(FormatCoins(coinShown_), 13, C.ink, "bold"),
        },
    }

    local stock = UI.Panel {
        height = 42,
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        paddingHorizontal = 10,
        borderRadius = 8,
        backgroundGradient = ORDER_GRAD,
        borderWidth = 2,
        borderColor = ORDER_BORDER,
        children = {
            Icon("Images/ui/icons/spool.png", 20),
            Txt("耗材库存", 9, C.inkSoft),
            Txt(string.format("%dg", M.materialStock), 13, C.ink, "bold"),
        },
    }

    local viewportWidth = UI.GetWidth()
    if viewportWidth < 200 then
        viewportWidth = 1280
    end
    local rowsWidth = viewportWidth - 56
    local cards = {}
    if shopTab_ == "materials" then
        for _, mt in ipairs(M.shopMaterials) do
            cards[#cards + 1] = ShopCard(mt.name, mt.tag, mt.image, mt.spec, mt.price, mt.ref, nil, function()
                BuyMaterial(mt)
            end)
        end
    else
        for _, p in ipairs(M.shopPrinters) do
            cards[#cards + 1] = ShopCard(p.name, p.tag, p.sprite, p.spec, p.price, p.ref,
                BuildPrinterBadges(p), function()
                    BuyPrinter(p)
                end)
        end
    end

    local scroll = UI.ScrollView {
        id = "shopScroll",
        flexGrow = 1,
        flexBasis = 0,
        scrollY = true,
        showScrollbar = true,
        bounces = true,
        children = { BuildCardRows(rowsWidth, cards) },
    }

    return UI.Panel {
        flexGrow = 1,
        flexBasis = 0,
        marginHorizontal = 10,
        marginVertical = 8,
        padding = 8,
        flexDirection = "column",
        gap = 8,
        borderRadius = 8,
        backgroundColor = { 96, 118, 142, 255 },
        backgroundImage = "Images/ui/metal_bg.png",
        backgroundImageOpacity = 0.32,
        borderWidth = 3,
        borderColor = ORDER_BORDER,
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 10,
                children = {
                    titlePlate,
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 6,
                        children = {
                            ShopTab("打印机", shopTab_ == "printers", "printers"),
                            ShopTab("耗材", shopTab_ == "materials", "materials"),
                        },
                    },
                    UI.Spacer(),
                    stock,
                    balance,
                },
            },
            scroll,
        },
    }
end

-- ============================================================================
-- 订单页
-- ============================================================================

---@type { key: string, label: string }[]
local ORDER_FILTERS = {
    { key = "all", label = "全部" },
    { key = "pending", label = "待制作" },
    { key = "making", label = "制作中" },
    { key = "ready", label = "可交付" },
    { key = "done", label = "已完成" },
}

---@param order Order
---@param key string
---@return boolean
local function OrderMatchesFilter(order, key)
    if key == "pending" then
        return order.status == "待制作"
    elseif key == "making" then
        return order.status == "制作中"
    elseif key == "ready" then
        return order.status == "可交付"
    elseif key == "done" then
        return order.status == "已完成"
    end
    return true
end

---@param key string
---@return integer
local function OrderFilterCount(key)
    if key == "pending" then
        return Orders.CountByStatus("待制作")
    elseif key == "making" then
        return Orders.CountByStatus("制作中")
    elseif key == "ready" then
        return Orders.CountByStatus("可交付")
    elseif key == "done" then
        return Orders.CountByStatus("已完成")
    end
    return #M.orders
end

---@type fun(order: Order)
local OnOrderAction

---@param order Order
---@return Panel
local function BuildOrderCard(order)
    local color = OrderStatusColor(order.status)
    local badgeLabel = Txt(order.status, 10, color, "bold")
    local badge = UI.Panel {
        height = 18,
        paddingHorizontal = 6,
        borderRadius = 9,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = WithAlpha(color, 38),
        borderWidth = 1,
        borderColor = WithAlpha(color, 150),
        children = { badgeLabel },
    }

    local pct = math.floor(order.progress * 100 + 0.5)
    local fill = UI.Panel {
        width = string.format("%d%%", pct),
        height = "100%",
        borderRadius = 3,
        backgroundColor = color,
    }
    local track = UI.Panel {
        width = "100%",
        height = 7,
        borderRadius = 4,
        backgroundColor = C.track,
        borderWidth = 2,
        borderColor = C.ink,
        overflow = "hidden",
        children = { fill },
    }

    local progressLabel = Txt(OrderProgressText(order), compact_ and 9 or 10, C.inkSoft)
    local pctLabel = Txt("", compact_ and 9 or 10, C.inkSoft, "bold")
    if order.status == "待制作" then
        pctLabel:SetText("")
    elseif order.status == "制作中" then
        pctLabel:SetText(string.format("%d%%", pct))
        if order.damagedCount > 0 then
            pctLabel:SetFontColor(C.red)
        end
    elseif order.status == "可交付" then
        pctLabel:SetText("100%")
    else
        pctLabel:SetText("完成")
    end

    local actionBtn = OrangeButton(OrderActionText(order), {
        height = 30,
        fontSize = 12,
        width = "100%",
        disabled = not OrderCanAct(order),
        disabledBackgroundGradient = {
            direction = "to-bottom",
            from = { 202, 196, 184, 255 },
            to = { 178, 172, 160, 255 },
        },
        disabledTextColor = { 128, 120, 106, 255 },
        onClick = function()
            OnOrderAction(order)
        end,
    })

    orderRefs_[#orderRefs_ + 1] = {
        order = order,
        badge = badge,
        badgeLabel = badgeLabel,
        progressLabel = progressLabel,
        pctLabel = pctLabel,
        fill = fill,
        actionBtn = actionBtn,
    }

    return UI.Panel {
        flexGrow = 1,
        flexBasis = 0,
        height = compact_ and 228 or 240,
        flexDirection = "column",
        gap = 5,
        padding = 9,
        borderRadius = 8,
        overflow = "hidden",
        backgroundGradient = ORDER_GRAD,
        borderWidth = 2,
        borderColor = ORDER_BORDER,
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 76 } } },
        children = {
            UI.Panel {
                height = 20,
                flexDirection = "row",
                alignItems = "center",
                gap = 5,
                overflow = "hidden",
                children = {
                    Txt("#" .. order.id, 11, C.inkSoft),
                    Txt(order.client, compact_ and 9 or 10, C.inkSoft),
                    UI.Spacer(),
                    badge,
                },
            },
            UI.Panel {
                height = compact_ and 82 or 88,
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                overflow = "hidden",
                children = {
                    Icon(order.icon, compact_ and 78 or 84),
                    UI.Panel {
                        flexGrow = 1,
                        flexBasis = 0,
                        flexDirection = "column",
                        gap = 5,
                        justifyContent = "center",
                        overflow = "hidden",
                        children = {
                            Txt(order.product, compact_ and 14 or 15, C.ink, "bold"),
                            Txt(string.format("需求 ×%d 件 · 单价 ¥%d/件", order.quantity, order.unitPrice),
                                compact_ and 10 or 11, C.inkSoft),
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                gap = 4,
                                overflow = "hidden",
                                children = {
                                    Icon(order.materialImage, 18),
                                    Txt(order.material, compact_ and 9 or 10, C.inkSoft),
                                    UI.Spacer(),
                                    Txt(string.format("%dg", order.grams), compact_ and 10 or 11, C.ink, "bold"),
                                },
                            },
                        },
                    },
                },
            },
            UI.Panel {
                height = 26,
                flexDirection = "row",
                alignItems = "center",
                gap = 5,
                paddingHorizontal = 7,
                borderRadius = 6,
                backgroundColor = ORDER_INNER_BG,
                borderWidth = 1,
                borderColor = ORDER_INNER_BORDER,
                children = {
                    Icon("Images/ui/icons/coin.png", 16),
                    Txt(FormatPrice(order.price), 16, C.ink, "bold"),
                    Txt("交付奖励", 9, C.inkSoft),
                    UI.Spacer(),
                    Txt("消耗 " .. order.material, compact_ and 8 or 9, C.inkSoft),
                },
            },
            UI.Panel {
                flexDirection = "column",
                gap = 2,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        children = { progressLabel, UI.Spacer(), pctLabel },
                    },
                    track,
                },
            },
            actionBtn,
        },
    }
end

---@return Panel
local function BuildOrdersFrame()
    local titlePlate = UI.Panel {
        height = 48,
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        paddingHorizontal = 12,
        borderRadius = 8,
        backgroundGradient = ORDER_GRAD,
        borderWidth = 3,
        borderColor = ORDER_BORDER,
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 80 } } },
        children = {
            Icon("Images/ui/icons/box.png", 30),
            Txt("订单列表", 22, C.ink, "bold"),
        },
    }

    local chips = {}
    for _, filter in ipairs(ORDER_FILTERS) do
        chips[#chips + 1] = FilterChip(
            string.format("%s %d", filter.label, OrderFilterCount(filter.key)),
            orderFilter_ == filter.key,
            function()
                if orderFilter_ ~= filter.key then
                    orderFilter_ = filter.key
                    pendingPage_ = "orders"
                end
            end,
            nil,
            true
        )
    end

    local cards = {}
    for _, order in ipairs(M.orders) do
        if OrderMatchesFilter(order, orderFilter_) then
            cards[#cards + 1] = BuildOrderCard(order)
        end
    end

    local viewportWidth = UI.GetWidth()
    if viewportWidth < 200 then
        viewportWidth = 1280
    end
    local rowsWidth = viewportWidth - 56

    local content
    if #cards == 0 then
        content = UI.Panel {
            width = rowsWidth,
            height = 200,
            justifyContent = "center",
            alignItems = "center",
            gap = 6,
            children = {
                Icon("Images/ui/icons/box.png", 48),
                Txt("当前分类下没有订单", 14, C.inkSoft, "bold"),
            },
        }
    else
        content = BuildCardRows(rowsWidth, cards)
    end

    local scroll = UI.ScrollView {
        id = "orderScroll",
        flexGrow = 1,
        flexBasis = 0,
        scrollY = true,
        showScrollbar = true,
        bounces = true,
        children = { content },
    }

    return UI.Panel {
        flexGrow = 1,
        flexBasis = 0,
        marginHorizontal = 10,
        marginVertical = 8,
        padding = 8,
        flexDirection = "column",
        gap = 8,
        borderRadius = 8,
        backgroundColor = { 96, 118, 142, 255 },
        backgroundImage = "Images/ui/metal_bg.png",
        backgroundImageOpacity = 0.32,
        borderWidth = 3,
        borderColor = ORDER_BORDER,
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 10,
                children = {
                    titlePlate,
                    UI.Panel {
                        flexGrow = 1,
                        flexBasis = 0,
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 6,
                        children = chips,
                    },
                },
            },
            scroll,
        },
    }
end

local function DeliverAllOrders()
    local count = 0
    local coins = 0
    for _, order in ipairs(M.orders) do
        if order.status == "可交付" then
            local settled = Orders.Deliver(order)
            if settled then
                count = count + 1
                coins = coins + order.price
            end
        end
    end
    if count > 0 then
        if coins > 0 then
            SpawnCoinFly(640, 300, math.max(4, math.min(10, count * 3)))
            Sfx.CoinPickup(0.5)
            RefreshTopBar()
        end
        UI.Toast.Show(string.format("已交付 %d 张订单，+%d 金币", count, coins),
            { type = "success", duration = 1.8 })
        pendingPage_ = "orders"
    else
        UI.Toast.Show("没有等待交付的订单", { type = "info", duration = 1.4 })
    end
end

local function AutoStartOrders()
    local count = Orders.AutoStart()
    if count > 0 then
        UI.Toast.Show(string.format("已安排 %d 张订单开始制作", count),
            { type = "success", duration = 1.8 })
        pendingPage_ = "orders"
    else
        UI.Toast.Show("没有空闲机器，或耗材不足", { type = "warning", duration = 1.6 })
    end
end

---@return Panel
local function BuildOrdersBottomBar()
    return UI.Panel {
        height = 64,
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        paddingHorizontal = 12,
        backgroundColor = { 96, 118, 142, 255 },
        backgroundImage = "Images/ui/metal_bg.png",
        backgroundImageOpacity = 0.32,
        borderTopWidth = 3,
        borderTopColor = ORDER_BORDER,
        children = {
            Txt("点击「开始制作」，为订单挑选一台空闲机器", 12, C.inkSoft),
            UI.Spacer(),
            CreamButton("批量交付", {
                height = 40,
                fontSize = 13,
                paddingHorizontal = 20,
                onClick = DeliverAllOrders,
            }),
            OrangeButton("一键开始", {
                height = 40,
                fontSize = 14,
                paddingHorizontal = 28,
                onClick = AutoStartOrders,
            }),
        },
    }
end

-- ============================================================================
-- 图鉴页
-- ============================================================================

--- 单件耗材克数（图鉴展示用）
---@param order Order
---@return integer
local function OrderItemGrams(order)
    return math.max(1, math.ceil(order.grams / math.max(1, order.quantity)))
end

---@param order Order
---@return Panel
local function BuildGalleryCard(order)
    local delivered = M.delivered[order.product] or 0
    local produced = delivered > 0
    local statusText = produced and string.format("已交付 %d 件", delivered) or "未生产"
    local statusColor = produced and C.green or C.inkSoft

    return UI.Panel {
        flexGrow = 1,
        flexBasis = 0,
        height = compact_ and 268 or 264,
        flexDirection = "column",
        gap = 5,
        padding = 9,
        borderRadius = 8,
        overflow = "hidden",
        backgroundGradient = ORDER_GRAD,
        borderWidth = 2,
        borderColor = ORDER_BORDER,
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 76 } } },
        children = {
            UI.Panel {
                height = 22,
                flexDirection = "row",
                alignItems = "center",
                gap = 5,
                overflow = "hidden",
                children = {
                    Txt(order.product, compact_ and 13 or 14, C.ink, "bold"),
                    UI.Spacer(),
                    UI.Panel {
                        height = 17,
                        paddingHorizontal = 6,
                        borderRadius = 9,
                        backgroundColor = WithAlpha(statusColor, 38),
                        borderWidth = 1,
                        borderColor = WithAlpha(statusColor, 140),
                        justifyContent = "center",
                        children = { Txt(statusText, 9, statusColor, "bold") },
                    },
                },
            },
            UI.Panel {
                flexGrow = 1,
                flexBasis = 0,
                borderRadius = 6,
                backgroundColor = ORDER_INNER_BG,
                borderWidth = 1,
                borderColor = ORDER_INNER_BORDER,
                justifyContent = "center",
                alignItems = "center",
                overflow = "hidden",
                children = { Icon(order.icon, compact_ and 88 or 98) },
            },
            -- 价格：单价醒目 + 整单参考
            UI.Panel {
                height = 28,
                flexDirection = "row",
                alignItems = "center",
                gap = 5,
                paddingHorizontal = 7,
                borderRadius = 6,
                backgroundColor = { 255, 236, 204, 210 },
                borderWidth = 2,
                borderColor = { 222, 126, 26, 170 },
                children = {
                    Icon("Images/ui/icons/coin.png", 16),
                    Txt(string.format("¥%d", order.unitPrice), 17, { 176, 92, 16, 255 }, "bold"),
                    Txt("/ 件", 10, C.inkSoft),
                    UI.Spacer(),
                    Txt(string.format("整单 ¥%d", order.price), 9, C.inkSoft),
                },
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                overflow = "hidden",
                children = {
                    Icon(order.materialImage, 16),
                    Txt(order.material, compact_ and 9 or 10, C.inkSoft),
                    UI.Spacer(),
                    Txt(string.format("约 %dg/件", OrderItemGrams(order)), compact_ and 9 or 10, C.ink, "bold"),
                },
            },
            Txt(order.desc, compact_ and 9 or 10, C.inkSoft),
        },
    }
end

---@return Panel
local function BuildGalleryFrame()
    local producedModels = 0
    local totalDelivered = 0
    for _, order in ipairs(M.orders) do
        local n = M.delivered[order.product] or 0
        if n > 0 then
            producedModels = producedModels + 1
        end
        totalDelivered = totalDelivered + n
    end

    local titlePlate = UI.Panel {
        height = 48,
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        paddingHorizontal = 12,
        borderRadius = 8,
        backgroundGradient = ORDER_GRAD,
        borderWidth = 3,
        borderColor = ORDER_BORDER,
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 80 } } },
        children = {
            Icon("Images/ui/icons/book.png", 30),
            Txt("玩具图鉴", 22, C.ink, "bold"),
        },
    }

    local summary = UI.Panel {
        height = 42,
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        paddingHorizontal = 12,
        borderRadius = 8,
        backgroundGradient = ORDER_GRAD,
        borderWidth = 2,
        borderColor = ORDER_BORDER,
        children = {
            Txt(string.format("收录 %d / %d 型号", producedModels, #M.orders), 12, C.ink, "bold"),
            UI.Panel {
                width = 2,
                height = 18,
                backgroundColor = WithAlpha(ORDER_BORDER, 90),
            },
            Txt(string.format("累计交付 %d 件", totalDelivered), 12, C.inkSoft),
        },
    }

    local viewportWidth = UI.GetWidth()
    if viewportWidth < 200 then
        viewportWidth = 1280
    end
    local rowsWidth = viewportWidth - 56

    local cards = {}
    for _, order in ipairs(M.orders) do
        cards[#cards + 1] = BuildGalleryCard(order)
    end

    local scroll = UI.ScrollView {
        id = "galleryScroll",
        flexGrow = 1,
        flexBasis = 0,
        scrollY = true,
        showScrollbar = true,
        bounces = true,
        children = { BuildCardRows(rowsWidth, cards) },
    }

    return UI.Panel {
        flexGrow = 1,
        flexBasis = 0,
        marginHorizontal = 10,
        marginVertical = 8,
        padding = 8,
        flexDirection = "column",
        gap = 8,
        borderRadius = 8,
        backgroundColor = { 96, 118, 142, 255 },
        backgroundImage = "Images/ui/metal_bg.png",
        backgroundImageOpacity = 0.32,
        borderWidth = 3,
        borderColor = ORDER_BORDER,
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 10,
                children = {
                    titlePlate,
                    UI.Spacer(),
                    summary,
                },
            },
            scroll,
        },
    }
end

OnOrderAction = function(order)
    if order.status == "待制作" then
        pickerOrderId_ = order.id
        pendingPage_ = "orders"
    elseif order.status == "可交付" then
        local before = M.coins
        local settled, message = Orders.Deliver(order)
        local gained = math.floor(M.coins - before)
        if settled and gained > 0 then
            SpawnCoinFly(640, 300, math.max(3, math.min(8, math.floor(gained / 90) + 3)))
            Sfx.CoinPickup(0.5)
            RefreshTopBar()
        elseif not settled then
            Sfx.Bad()
        end
        UI.Toast.Show(message, { type = settled and "success" or "info", duration = 2.0 })
        pendingPage_ = "orders"
    elseif order.status == "制作中" then
        local machine = OrderMachine(order)
        if machine ~= nil and machine.status == "可收取" then
            local before = M.coins
            local gained, message = Orders.Collect(machine)
            local profit = math.floor(M.coins - before)
            if gained > 0 and profit > 0 then
                SpawnCoinFly(640, 300, math.max(3, math.min(8, math.floor(profit / 90) + 3)))
                Sfx.CoinPickup(0.5)
                RefreshTopBar()
            else
                Sfx.Bad()
            end
            UI.Toast.Show(message, { type = gained > 0 and "success" or "warning", duration = 2.0 })
            pendingPage_ = "orders"
        else
            local pct = math.floor(order.progress * 100 + 0.5)
            UI.Toast.Show(string.format("订单 %s 正在 %s 上制作（成品 %d/%d，%d%%）",
                order.id, order.machineCode or "--", order.goodCount, order.quantity, pct),
                { type = "info", duration = 1.6 })
        end
    end
end

-- ============================================================================
-- 选机器浮层
-- ============================================================================

local function ClosePicker()
    pickerOrderId_ = nil
    pendingPage_ = "orders"
end

---@param order Order
---@param machine Machine
local function StartWithMachine(order, machine)
    local ok, message = Orders.Start(order, machine)
    if ok then
        pickerOrderId_ = nil
        UI.Toast.Show(message, { type = "success", duration = 1.8 })
    else
        UI.Toast.Show(message, { type = "error", duration = 1.8 })
    end
    pendingPage_ = "orders"
end

---@param choice MachineChoice
---@param order Order
---@return Panel
local function BuildMachineChoiceRow(choice, order)
    local machine = choice.machine
    local matPct = MaterialPercent(machine)
    local matColor = MaterialColor(machine)

    local row = UI.Panel {
        width = "100%",
        height = 92,
        flexDirection = "row",
        alignItems = "center",
        gap = 10,
        padding = 8,
        borderRadius = 8,
        backgroundGradient = CREAM_GRAD,
        borderWidth = 2,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 2, blur = 3, spread = 0, color = { 0, 0, 0, 60 } } },
        children = {
            Icon(machine.sprite, 58),
            UI.Panel {
                flexGrow = 1,
                flexBasis = 0,
                flexDirection = "column",
                gap = 4,
                overflow = "hidden",
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 5,
                        children = {
                            Txt(machine.code, 11, C.inkSoft),
                            Txt(compact_ and machine.short or machine.model, 13, C.ink, "bold"),
                            UI.Spacer(),
                            Txt(string.format("Lv.%d", machine.level), 10, C.inkSoft),
                        },
                    },
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 6,
                        children = {
                            Txt(string.format("耗材 %dg / %dg", machine.material, machine.materialMax),
                                10, matColor, "bold"),
                            UI.Panel {
                                flexGrow = 1,
                                height = 6,
                                borderRadius = 3,
                                backgroundColor = C.track,
                                borderWidth = 1,
                                borderColor = C.ink,
                                overflow = "hidden",
                                children = {
                                    UI.Panel {
                                        width = string.format("%d%%", matPct),
                                        height = "100%",
                                        borderRadius = 2,
                                        backgroundColor = matColor,
                                    },
                                },
                            },
                        },
                    },
                    Txt(string.format("速度 ×%.2f · 每件 %dg · 整单约 %dg",
                        machine.speedMul, choice.itemGrams, choice.need),
                        9, C.inkSoft),
                },
            },
            UI.Panel {
                width = 104,
                flexDirection = "column",
                alignItems = "flex-end",
                gap = 3,
                children = {
                    OrangeButton("选择", {
                        width = 88,
                        height = 32,
                        fontSize = 13,
                        disabled = not choice.ok,
                        disabledBackgroundGradient = {
                            direction = "to-bottom",
                            from = { 202, 196, 184, 255 },
                            to = { 178, 172, 160, 255 },
                        },
                        disabledTextColor = { 128, 120, 106, 255 },
                        onClick = function()
                            StartWithMachine(order, machine)
                        end,
                    }),
                    Txt(choice.ok and "可立即开始" or choice.reason, 9,
                        choice.ok and C.green or C.red),
                },
            },
        },
    }
    return row
end

---@param order Order
---@return Panel
local function BuildPickerOverlay(order)
    local choices = Orders.IdleChoices(order)
    local listChildren = {}
    if #choices == 0 then
        listChildren[1] = UI.Panel {
            width = "100%",
            height = 140,
            justifyContent = "center",
            alignItems = "center",
            gap = 6,
            children = {
                Icon("Images/ui/printers/ender3v3.png", 54),
                Txt("暂无空闲机器", 14, C.ink, "bold"),
                Txt("去商店购买打印机，或等待现有机器打印完成", 11, C.inkSoft),
            },
        }
    else
        for _, choice in ipairs(choices) do
            listChildren[#listChildren + 1] = BuildMachineChoiceRow(choice, order)
        end
    end

    local summary = UI.Panel {
        height = 66,
        flexDirection = "row",
        alignItems = "center",
        gap = 10,
        paddingHorizontal = 10,
        paddingVertical = 8,
        borderRadius = 8,
        backgroundColor = { 255, 255, 255, 82 },
        borderWidth = 2,
        borderColor = { 190, 170, 138, 180 },
        children = {
            Icon(order.icon, 50),
            UI.Panel {
                flexGrow = 1,
                flexBasis = 0,
                flexDirection = "column",
                gap = 3,
                overflow = "hidden",
                children = {
                    Txt(string.format("%s ×%d 件 · ¥%d/件", order.product, order.quantity, order.unitPrice),
                        15, C.ink, "bold"),
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 4,
                        children = {
                            Icon(order.materialImage, 16),
                            Txt(string.format("需要 %s %dg", order.material, order.grams), 10, C.inkSoft),
                        },
                    },
                },
            },
            UI.Panel {
                flexDirection = "column",
                alignItems = "flex-end",
                gap = 2,
                children = {
                    Txt("交付奖励", 9, C.inkSoft),
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 3,
                        children = {
                            Icon("Images/ui/icons/coin.png", 14),
                            Txt(FormatPrice(order.price), 15, C.ink, "bold"),
                        },
                    },
                },
            },
        },
    }

    local listTitle = UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        children = {
            Txt("选择空闲机器", 14, C.ink, "bold"),
            Txt(string.format("%d 台可用", #choices), 11, C.inkSoft),
        },
    }

    local listHeight = 140
    if #choices > 0 then
        listHeight = math.min(#choices * 100, 400)
    end

    local dialog = UI.Panel {
        width = 660,
        flexDirection = "column",
        gap = 10,
        padding = 14,
        borderRadius = 12,
        backgroundGradient = CREAM_GRAD,
        borderWidth = 3,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 6, blur = 12, spread = 0, color = { 0, 0, 0, 120 } } },
        onClick = function(_, event)
            if event ~= nil then
                event:StopPropagation()
            end
        end,
        children = {
            UI.Panel {
                height = 34,
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                children = {
                    Icon("Images/ui/icons/box.png", 24),
                    Txt("开始制作", 20, C.ink, "bold"),
                    UI.Spacer(),
                    UI.Panel {
                        width = 32,
                        height = 32,
                        justifyContent = "center",
                        alignItems = "center",
                        borderRadius = 6,
                        backgroundGradient = CREAM_GRAD,
                        borderWidth = 2,
                        borderColor = C.ink,
                        onClick = function()
                            ClosePicker()
                        end,
                        children = { Txt("×", 18, C.ink, "bold") },
                    },
                },
            },
            summary,
            listTitle,
            UI.ScrollView {
                width = "100%",
                height = listHeight,
                scrollY = true,
                showScrollbar = true,
                bounces = true,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        gap = 8,
                        children = listChildren,
                    },
                },
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                children = {
                    Txt("开始制作会扣除机器内对应重量的耗材", 10, C.inkSoft),
                    UI.Spacer(),
                    CreamButton("取消", {
                        height = 36,
                        fontSize = 13,
                        paddingHorizontal = 22,
                        onClick = function()
                            ClosePicker()
                        end,
                    }),
                },
            },
        },
    }

    return UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 150 },
        zIndex = 100,
        onClick = function()
            ClosePicker()
        end,
        children = { dialog },
    }
end

-- ============================================================================
-- 机房扩建浮层
-- ============================================================================

local function CloseVenue()
    venueOpen_ = false
    pendingPage_ = "room"
end

---@param venue Venue
---@param index integer
---@return Panel
local function BuildVenueRow(venue, index)
    local owned = index <= M.venueIndex
    local isCurrent = index == M.venueIndex
    local affordable = M.coins >= venue.price

    local statusText = ""
    local statusColor = C.inkSoft
    if isCurrent then
        statusText = "当前"
        statusColor = C.green
    elseif owned then
        statusText = "已拥有"
        statusColor = C.inkSoft
    end

    ---@type Widget[]
    local rightChildren
    if owned then
        rightChildren = {
            UI.Panel {
                width = 92,
                height = 32,
                borderRadius = 6,
                justifyContent = "center",
                alignItems = "center",
                backgroundColor = WithAlpha(statusColor, 36),
                borderWidth = 2,
                borderColor = WithAlpha(statusColor, 120),
                children = { Txt(statusText, 12, statusColor, "bold") },
            },
        }
    else
        rightChildren = {
            OrangeButton(string.format("扩建 %d", venue.price), {
                width = 92,
                height = 32,
                fontSize = 12,
                disabled = not affordable,
                disabledBackgroundGradient = {
                    direction = "to-bottom",
                    from = { 202, 196, 184, 255 },
                    to = { 178, 172, 160, 255 },
                },
                disabledTextColor = { 128, 120, 106, 255 },
                onClick = function()
                    local ok, message = Orders.UpgradeVenue(index)
                    UI.Toast.Show(message, { type = ok and "success" or "error", duration = 2.2 })
                    if ok then
                        RefreshTopBar()
                    end
                    pendingPage_ = "room"
                end,
            }),
        }
    end

    return UI.Panel {
        width = "100%",
        height = 72,
        flexDirection = "row",
        alignItems = "center",
        gap = 10,
        paddingHorizontal = 10,
        borderRadius = 8,
        backgroundGradient = CREAM_GRAD,
        borderWidth = 2,
        borderColor = isCurrent and C.ink or C.cardBorder,
        children = {
            Icon("Images/ui/icons/room.png", 34),
            UI.Panel {
                flexGrow = 1,
                flexBasis = 0,
                flexDirection = "column",
                gap = 2,
                overflow = "hidden",
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 6,
                        children = {
                            Txt(venue.name, 16, C.ink, "bold"),
                            Txt(string.format("可放 %d 台", venue.capacity), 10, C.inkSoft),
                        },
                    },
                    Txt(venue.desc, 9, C.inkSoft),
                    Txt(string.format("日租 %d 金币", venue.rent), 10, C.orangeDeep, "bold"),
                },
            },
            UI.Panel {
                flexDirection = "column",
                alignItems = "flex-end",
                gap = 3,
                children = rightChildren,
            },
        },
    }
end

---@return Panel
local function BuildVenueOverlay()
    local rows = {}
    for index, venue in ipairs(M.venues) do
        rows[#rows + 1] = BuildVenueRow(venue, index)
    end

    local venue = Orders.CurrentVenue()
    local remaining = math.max(0, M.daySeconds - M.dayTimer)
    local rentNote = M.rentDue > 0
        and string.format("第 %d 天 · %.0f 秒后交租 · 已欠租 %d 金币", M.day, remaining, M.rentDue)
        or string.format("第 %d 天 · %.0f 秒后交租 %d 金币", M.day, remaining, venue.rent)
    local rentLabel = Txt(rentNote, 10, M.rentDue > 0 and C.red or C.inkSoft,
        M.rentDue > 0 and "bold" or "normal")
    venueRentLabel_ = rentLabel

    local dialog = UI.Panel {
        width = 620,
        flexDirection = "column",
        gap = 10,
        padding = 14,
        borderRadius = 12,
        backgroundGradient = CREAM_GRAD,
        borderWidth = 3,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 6, blur = 12, spread = 0, color = { 0, 0, 0, 120 } } },
        onClick = function(_, event)
            if event ~= nil then
                event:StopPropagation()
            end
        end,
        children = {
            UI.Panel {
                height = 34,
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                children = {
                    Icon("Images/ui/icons/room.png", 24),
                    Txt("机房扩建", 20, C.ink, "bold"),
                    UI.Spacer(),
                    UI.Panel {
                        width = 32,
                        height = 32,
                        justifyContent = "center",
                        alignItems = "center",
                        borderRadius = 6,
                        backgroundGradient = CREAM_GRAD,
                        borderWidth = 2,
                        borderColor = C.ink,
                        onClick = function()
                            CloseVenue()
                        end,
                        children = { Txt("×", 18, C.ink, "bold") },
                    },
                },
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                paddingHorizontal = 10,
                paddingVertical = 8,
                borderRadius = 8,
                backgroundColor = { 255, 255, 255, 82 },
                borderWidth = 2,
                borderColor = { 190, 170, 138, 180 },
                children = {
                    Txt(string.format("当前：%s · 机器 %d/%d 台", venue.name, #M.machines, venue.capacity),
                        11, C.ink, "bold"),
                    UI.Spacer(),
                    rentLabel,
                },
            },
            UI.ScrollView {
                width = "100%",
                height = math.min(#rows * 80, 400),
                scrollY = true,
                showScrollbar = true,
                bounces = true,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        gap = 8,
                        children = rows,
                    },
                },
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                children = {
                    Txt(string.format("累计场地投入 %s 金币", FormatCoins(M.venueCost)), 9, C.inkSoft),
                    UI.Spacer(),
                    CreamButton("关闭", {
                        height = 36,
                        fontSize = 13,
                        paddingHorizontal = 22,
                        onClick = function()
                            CloseVenue()
                        end,
                    }),
                },
            },
        },
    }

    return UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 150 },
        zIndex = 100,
        onClick = function()
            CloseVenue()
        end,
        children = { dialog },
    }
end

-- ============================================================================
-- 机器操作浮层（加料 / 维修 / 停运改单）
-- ============================================================================

local function CloseOperation()
    opMachineCode_ = nil
    pendingPage_ = "room"
end

---@param machine Machine
---@return Panel
local function BuildOperationOverlay(machine)
    local statusColor = StatusColor(machine.status)
    local matPct = MaterialPercent(machine)
    local matColor = MaterialColor(machine)
    local missing = Orders.RefillPlan(machine)

    ---@type Order|nil
    local order = nil
    if machine.orderId ~= nil then
        order = Orders.Get(machine.orderId)
    end

    local orderInfoText = "当前没有订单"
    local orderInfoColor = C.inkSoft
    if order ~= nil then
        orderInfoText = string.format("订单 %s · %s · 成品 %d/%d 件",
            order.id, order.product, order.goodCount, order.quantity)
        orderInfoColor = C.ink
        if order.damagedCount > 0 then
            orderInfoText = orderInfoText .. string.format(" · 损坏 %d", order.damagedCount)
            orderInfoColor = C.red
        end
    end

    local summary = UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = 10,
        padding = 10,
        borderRadius = 8,
        backgroundColor = { 255, 255, 255, 82 },
        borderWidth = 2,
        borderColor = { 190, 170, 138, 180 },
        children = {
            Icon(machine.sprite, 64),
            UI.Panel {
                flexGrow = 1,
                flexBasis = 0,
                flexDirection = "column",
                gap = 5,
                overflow = "hidden",
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 6,
                        children = {
                            Txt(machine.code, 12, C.inkSoft),
                            Txt(machine.model, 15, C.ink, "bold"),
                            UI.Spacer(),
                            Txt(machine.status, 13, statusColor, "bold"),
                        },
                    },
                    Txt(orderInfoText, 10, orderInfoColor),
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 6,
                        children = {
                            Txt(string.format("耗材 %dg / %dg", machine.material, machine.materialMax),
                                10, matColor, "bold"),
                            UI.Panel {
                                flexGrow = 1,
                                height = 7,
                                borderRadius = 4,
                                backgroundColor = C.track,
                                borderWidth = 1,
                                borderColor = C.ink,
                                overflow = "hidden",
                                children = {
                                    UI.Panel {
                                        width = string.format("%d%%", matPct),
                                        height = "100%",
                                        borderRadius = 3,
                                        backgroundColor = matColor,
                                    },
                                },
                            },
                        },
                    },
                    Txt(string.format("打印耗电 %.1f 金币/秒 · 单件损坏率 %d%% · 单件故障率 %d%% · 库存耗材 %dg",
                        M.powerRatePerSecond, math.floor(M.damageChance * 100 + 0.5),
                        math.floor(M.faultChance * 100 + 0.5), M.materialStock),
                        9, C.inkSoft),
                },
            },
        },
    }

    local refillText = "料仓已满"
    if missing > 0 then
        refillText = string.format("加料 %dg", missing)
    end
    local refillBtn = OrangeButton(refillText, {
        height = 36,
        fontSize = 12,
        width = "100%",
        disabled = missing <= 0,
        disabledBackgroundGradient = {
            direction = "to-bottom",
            from = { 202, 196, 184, 255 },
            to = { 178, 172, 160, 255 },
        },
        disabledTextColor = { 128, 120, 106, 255 },
        onClick = function()
            local ok, message = Orders.Refill(machine)
            UI.Toast.Show(message, { type = ok and "success" or "error", duration = 1.8 })
            pendingPage_ = "room"
        end,
    })

    local repairBtn = OrangeButton(string.format("维修 · %d金币", M.repairCost), {
        height = 36,
        fontSize = 12,
        width = "100%",
        onClick = function()
            local ok, message = Orders.Repair(machine)
            UI.Toast.Show(message, { type = ok and "success" or "info", duration = 1.8 })
            pendingPage_ = "room"
        end,
    })

    local stopBtn = CreamButton(order ~= nil and "停运改单" or "去接单", {
        height = 36,
        fontSize = 12,
        width = "100%",
        onClick = function()
            if machine.orderId == nil then
                opMachineCode_ = nil
                UI.Toast.Show("去订单页挑选一张订单开始制作", { type = "info", duration = 1.6 })
                pendingPage_ = "orders"
                return
            end
            local ok, message = Orders.Stop(machine)
            if ok then
                opMachineCode_ = nil
            end
            UI.Toast.Show(message, { type = ok and "success" or "error", duration = 2.0 })
            pendingPage_ = "room"
        end,
    })

    ---@param button Button
    ---@param caption string
    ---@param captionColor number[]
    ---@return Panel
    local function ActionColumn(button, caption, captionColor)
        return UI.Panel {
            flexGrow = 1,
            flexBasis = 0,
            flexDirection = "column",
            gap = 5,
            padding = 8,
            borderRadius = 8,
            backgroundColor = { 255, 255, 255, 72 },
            borderWidth = 1,
            borderColor = { 190, 170, 138, 180 },
            children = {
                button,
                Txt(caption, 9, captionColor),
            },
        }
    end

    local dialog = UI.Panel {
        width = 580,
        flexDirection = "column",
        gap = 10,
        padding = 14,
        borderRadius = 12,
        backgroundGradient = CREAM_GRAD,
        borderWidth = 3,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 6, blur = 12, spread = 0, color = { 0, 0, 0, 120 } } },
        onClick = function(_, event)
            if event ~= nil then
                event:StopPropagation()
            end
        end,
        children = {
            UI.Panel {
                height = 34,
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                children = {
                    Icon("Images/ui/icons/upgrade.png", 24),
                    Txt("机器操作", 20, C.ink, "bold"),
                    UI.Spacer(),
                    UI.Panel {
                        width = 32,
                        height = 32,
                        justifyContent = "center",
                        alignItems = "center",
                        borderRadius = 6,
                        backgroundGradient = CREAM_GRAD,
                        borderWidth = 2,
                        borderColor = C.ink,
                        onClick = function()
                            CloseOperation()
                        end,
                        children = { Txt("×", 18, C.ink, "bold") },
                    },
                },
            },
            summary,
            UI.Panel {
                flexDirection = "row",
                alignItems = "stretch",
                gap = 8,
                children = {
                    ActionColumn(refillBtn,
                        machine.status == "缺料" and "加满后自动恢复打印" or "从库存划拨耗材", C.inkSoft),
                    ActionColumn(repairBtn,
                        machine.status == "故障" and "维修后继续打印" or "仅在故障时有效",
                        machine.status == "故障" and C.red or C.inkSoft),
                    ActionColumn(stopBtn,
                        order ~= nil and "退回订单，已耗耗材不返还" or "当前机器空闲", C.inkSoft),
                },
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                children = {
                    Txt(string.format("耗电 %s · 耗材 %s · 购机 %s · 经营利润 %s",
                        FormatNumber(M.powerCost), FormatNumber(M.materialCost),
                        FormatNumber(M.machineCost), FormatProfit(M.profit)),
                        9, C.inkSoft),
                    UI.Spacer(),
                    CreamButton("关闭", {
                        height = 36,
                        fontSize = 13,
                        paddingHorizontal = 22,
                        onClick = function()
                            CloseOperation()
                        end,
                    }),
                },
            },
        },
    }

    return UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 150 },
        zIndex = 100,
        onClick = function()
            CloseOperation()
        end,
        children = { dialog },
    }
end

--- 先上传当前金币再拉取榜单（保证自己的名次是最新的）
local function RefreshRich()
    richList_ = nil
    richError_ = nil
    richSelfRank_ = nil
    richTotal_ = nil
    Leaderboard.PushCoins(M.coins)
    -- 官方排行榜（游戏排行）独立提交，与 clientCloud 云变量榜互不影响
    OfficialRank.Submit(M.coins, nil)
    Leaderboard.FetchTotal(function(total)
        richTotal_ = total
        if currentPage_ == "rich" then
            pendingPage_ = "rich"
        end
    end)
    Leaderboard.FetchMyRank(function(rank)
        richSelfRank_ = rank
        if currentPage_ == "rich" then
            pendingPage_ = "rich"
        end
    end)
    Leaderboard.FetchTop(20, function(entries, reason)
        if entries == nil then
            richList_ = false
            richError_ = reason or "加载失败"
        else
            richList_ = entries
        end
        if currentPage_ == "rich" then
            pendingPage_ = "rich"
        end
    end)
end

--- 前三名奖牌配色
local RANK_COLORS = {
    { 250, 173, 20, 255 },  -- 金
    { 168, 170, 175, 255 }, -- 银
    { 205, 127, 50, 255 },  -- 铜
}

---@param entry RichEntry
---@return Panel
local function BuildRichRow(entry)
    local medalColor = RANK_COLORS[entry.rank]
    local rowChildren = {
        UI.Panel {
            width = 34,
            height = 34,
            borderRadius = 17,
            justifyContent = "center",
            alignItems = "center",
            backgroundColor = medalColor or C.track,
            borderWidth = 2,
            borderColor = entry.isMe and C.orangeDeep or C.ink,
            children = { Txt(tostring(entry.rank), 15, entry.rank <= 3 and { 255, 255, 255, 255 } or C.ink, "bold") },
        },
        Txt(entry.nickname, 14, entry.isMe and C.orangeDeep or C.ink, entry.isMe and "bold" or "normal"),
        UI.Spacer(),
        Icon("Images/ui/icons/coin.png", 16),
        Txt(FormatCoins(entry.coins), 14, entry.isMe and C.orangeDeep or C.inkSoft, "bold"),
    }
    return UI.Panel {
        height = 46,
        minHeight = 46,
        flexDirection = "row",
        alignItems = "center",
        gap = 10,
        paddingHorizontal = 10,
        borderRadius = 8,
        backgroundGradient = entry.isMe and ORANGE_GRAD or CREAM_GRAD,
        borderWidth = 2,
        borderColor = entry.isMe and C.orangeDeep or C.cardBorder,
        pointerEvents = "box-only",
        children = rowChildren,
    }
end

---@return Panel
local function BuildRichFrame()
    local titlePlate = UI.Panel {
        height = 48,
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        paddingHorizontal = 12,
        borderRadius = 8,
        backgroundGradient = ORANGE_GRAD,
        borderWidth = 3,
        borderColor = C.cardBorder,
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 80 } } },
        children = {
            Icon("Images/ui/icons/diamond.png", 30),
            Txt("富豪榜", 22, { 62, 40, 18, 255 }, "bold"),
        },
    }

    local selfText = "我的名次：加载中…"
    if richSelfRank_ ~= nil then
        selfText = string.format("我的名次：第 %d 名 · 身家 %s", richSelfRank_, FormatCoins(math.floor(M.coins)))
    elseif richList_ == false then
        selfText = string.format("我的身家 %s", FormatCoins(math.floor(M.coins)))
    end
    local summary = UI.Panel {
        height = 42,
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        paddingHorizontal = 12,
        borderRadius = 8,
        backgroundGradient = CREAM_GRAD,
        borderWidth = 2,
        borderColor = C.cardBorder,
        children = {
            Txt(selfText, 12, C.ink, "bold"),
            UI.Spacer(),
            UI.Panel {
                height = 30,
                paddingHorizontal = 10,
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                borderRadius = 6,
                backgroundGradient = CREAM_GRAD,
                borderWidth = 2,
                borderColor = C.ink,
                onClick = function()
                    print("[3D打印] 打开官方排行榜")
                    OfficialRank.Submit(M.coins, function(success, message)
                        OfficialRank.Open("public", function(opened, openMsg)
                            if not opened then
                                UI.Toast.Show("官方排行榜打开失败：" .. tostring(openMsg),
                                    { type = "warning", duration = 2.4 })
                            end
                        end)
                    end)
                end,
                children = {
                    Icon("Images/ui/icons/diamond.png", 14),
                    Txt("官方榜", 12, C.ink, "bold"),
                },
            },
            UI.Panel {
                height = 30,
                paddingHorizontal = 10,
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                borderRadius = 6,
                backgroundGradient = ORANGE_GRAD,
                borderWidth = 2,
                borderColor = C.ink,
                onClick = function()
                    print("[3D打印] 刷新富豪榜")
                    RefreshRich()
                end,
                children = {
                    Icon("Images/ui/icons/upgrade.png", 14),
                    Txt("刷新", 12, { 62, 40, 18, 255 }, "bold"),
                },
            },
        },
    }

    local rows
    if richList_ == nil then
        rows = {
            UI.Panel {
                height = 60,
                justifyContent = "center",
                alignItems = "center",
                children = { Txt("云端榜单加载中…", 14, C.inkSoft) },
            },
        }
    elseif richList_ == false then
        rows = {
            UI.Panel {
                height = 60,
                justifyContent = "center",
                alignItems = "center",
                children = { Txt("榜单加载失败：" .. richError_, 14, C.red, "bold") },
            },
        }
    elseif #richList_ == 0 then
        rows = {
            UI.Panel {
                height = 60,
                justifyContent = "center",
                alignItems = "center",
                children = { Txt("还没有人上榜，快去赚金币吧！", 14, C.inkSoft) },
            },
        }
    else
        rows = {}
        for _, entry in ipairs(richList_) do
            rows[#rows + 1] = BuildRichRow(entry)
        end
    end

    local scroll = UI.ScrollView {
        id = "richScroll",
        flexGrow = 1,
        flexBasis = 0,
        scrollY = true,
        showScrollbar = true,
        bounces = true,
        children = {
            UI.Panel {
                flexDirection = "column",
                gap = 6,
                children = rows,
            },
        },
    }

    --- 已上榜人数统计条
    local totalChip = UI.Panel {
        height = 40,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        gap = 8,
        borderRadius = 8,
        backgroundGradient = CREAM_GRAD,
        borderWidth = 2,
        borderColor = C.cardBorder,
        children = {
            Icon("Images/ui/icons/diamond.png", 18),
            Txt(richTotal_ ~= nil and string.format("已有 %d 人上榜", richTotal_) or "上榜人数统计中…", 13, C.ink, "bold"),
        },
    }

    return UI.Panel {
        flexGrow = 1,
        flexBasis = 0,
        marginHorizontal = 10,
        marginVertical = 8,
        padding = 8,
        flexDirection = "column",
        gap = 8,
        borderRadius = 8,
        backgroundColor = { 96, 118, 142, 255 },
        backgroundImage = "Images/ui/metal_bg.png",
        backgroundImageOpacity = 0.32,
        borderWidth = 3,
        borderColor = C.cardBorder,
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 10,
                children = {
                    titlePlate,
                    UI.Spacer(),
                    summary,
                },
            },
            totalChip,
            scroll,
        },
    }
end

-- ============================================================================
-- 首页
-- ============================================================================

--- 首页货币胶囊（无 + 按钮）
---@param iconPath string
---@param label string
---@param value string
---@param color number[]|nil
---@return Panel
---@return Label
local function HomeCurrency(iconPath, label, value, color)
    local valueLabel = Txt(value, compact_ and 15 or 17, color or C.ink, "bold")
    local panel = UI.Panel {
        height = compact_ and 40 or 46,
        flexDirection = "row",
        alignItems = "center",
        gap = compact_ and 5 or 7,
        paddingLeft = 5,
        paddingRight = compact_ and 12 or 16,
        borderRadius = 23,
        backgroundGradient = CREAM_GRAD,
        borderWidth = 2,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 2, blur = 3, spread = 0, color = { 0, 0, 0, 70 } } },
        children = {
            Icon(iconPath, compact_ and 24 or 30),
            UI.Panel {
                flexDirection = "column",
                children = {
                    Txt(label, 9, C.inkSoft),
                    valueLabel,
                },
            },
        },
    }
    return panel, valueLabel
end

---@return Panel
local function BuildHomeTopBar()
    local logo = UI.Panel {
        height = compact_ and 46 or 54,
        flexDirection = "row",
        alignItems = "center",
        gap = 7,
        paddingLeft = 3,
        paddingRight = compact_ and 10 or 14,
        borderRadius = 10,
        backgroundGradient = CREAM_GRAD,
        borderWidth = 3,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 80 } } },
        children = {
            Icon("Images/ui/icons/home.png", compact_ and 38 or 46),
            Txt("玩具打印工坊", compact_ and 18 or 24, C.ink, "bold"),
        },
    }

    local coinChip, coinLabel = HomeCurrency("Images/ui/icons/coin.png", "金币", FormatCoins(coinShown_))
    local expChip, expLabel = HomeCurrency("Images/ui/icons/exp.png", "经验", FormatNumber(M.exp))
    local profitChip, profitLabel = HomeCurrency("Images/ui/icons/profit.png", "经营利润",
        FormatProfit(M.profit), M.profit >= 0 and C.green or C.red)
    homeCoinLabel_ = coinLabel
    homeExpLabel_ = expLabel
    homeProfitLabel_ = profitLabel

    local gearButton = UI.Panel {
        width = compact_ and 38 or 44,
        height = compact_ and 38 or 44,
        borderRadius = 22,
        justifyContent = "center",
        alignItems = "center",
        backgroundGradient = CREAM_GRAD,
        borderWidth = 2,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 2, blur = 3, spread = 0, color = { 0, 0, 0, 70 } } },
        onClick = function()
            UI.Toast.Show("「设置」功能开发中", { type = "info", duration = 1.6 })
        end,
        children = { Icon("Images/ui/icons/gear.png", compact_ and 22 or 26) },
    }

    return UI.Panel {
        height = compact_ and 64 or 76,
        flexDirection = "row",
        alignItems = "center",
        gap = compact_ and 6 or 10,
        paddingHorizontal = compact_ and 8 or 14,
        backgroundColor = C.metal,
        backgroundImage = "Images/ui/metal_bg.png",
        backgroundImageOpacity = 0.42,
        borderBottomWidth = 3,
        borderBottomColor = C.ink,
        children = {
            logo,
            UI.Spacer(),
            coinChip,
            expChip,
            profitChip,
            gearButton,
        },
    }
end

---@param labelText string
---@param valueLabel Label
---@return Panel
local function HomeStatRow(labelText, valueLabel)
    return UI.Panel {
        height = compact_ and 22 or 26,
        flexDirection = "row",
        alignItems = "center",
        children = {
            Txt(labelText, compact_ and 11 or 12, C.inkSoft),
            UI.Spacer(),
            valueLabel,
        },
    }
end

---@return Panel
local function BuildHomeOverview()
    local revenueLabel = UI.Label {
        text = FormatCoins(math.floor(M.todayRevenue)),
        fontSize = compact_ and 24 or 32,
        fontColor = C.orangeDeep --[[@as RGBAColor]],
        fontWeight = "bold",
        lineHeight = 1.2,
        maxLines = 1,
        whiteSpace = "nowrap",
        width = "100%",
        textAlign = "center",
    }
    local pendingLabel = Txt(tostring(HomePendingCount()), compact_ and 13 or 14, C.ink, "bold")
    local satisfactionLabel = Txt(string.format("%d%%", HomeSatisfaction()), compact_ and 13 or 14, C.green, "bold")
    local deliveredLabel = Txt(string.format("%d 件", M.todayDelivered), compact_ and 13 or 14, C.ink, "bold")
    homeRevenueLabel_ = revenueLabel
    homePendingLabel_ = pendingLabel
    homeSatisfactionLabel_ = satisfactionLabel
    homeDeliveredLabel_ = deliveredLabel

    local venue = Orders.CurrentVenue()

    return UI.Panel {
        width = compact_ and 186 or 240,
        flexShrink = 0,
        flexDirection = "column",
        padding = compact_ and 10 or 12,
        gap = compact_ and 6 or 8,
        borderRadius = 10,
        backgroundGradient = CREAM_GRAD,
        backgroundImage = "Images/ui/paper_bg.png",
        backgroundImageOpacity = 0.5,
        borderWidth = 3,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 80 } } },
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 6,
                children = {
                    Icon("Images/ui/icons/overview.png", compact_ and 18 or 22),
                    Txt("经营总览", compact_ and 14 or 16, C.ink, "bold"),
                },
            },
            UI.Panel {
                width = "100%",
                flexDirection = "column",
                alignItems = "center",
                gap = 1,
                children = {
                    UI.Label {
                        text = "今日收益",
                        fontSize = compact_ and 10 or 11,
                        fontColor = C.inkSoft --[[@as RGBAColor]],
                        lineHeight = 1.2,
                        maxLines = 1,
                        whiteSpace = "nowrap",
                        width = "100%",
                        textAlign = "center",
                    },
                    revenueLabel,
                },
            },
            UI.Panel { height = 2, backgroundColor = C.track, flexShrink = 0 },
            HomeStatRow("待完成订单", pendingLabel),
            HomeStatRow("客户满意度", satisfactionLabel),
            HomeStatRow("今日交付", deliveredLabel),
            HomeStatRow("打印机", Txt(string.format("%d 台", #M.machines), compact_ and 13 or 14, C.ink, "bold")),
            HomeStatRow("耗材库存", Txt(FormatGrams(M.materialStock), compact_ and 13 or 14, C.ink, "bold")),
            UI.Spacer(),
            Txt(string.format("第 %d 天 · %s", M.day, venue.name), compact_ and 9 or 10, C.inkSoft),
        },
    }
end

---@return Panel
local function BuildHomeHero()
    return UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        flexDirection = "column",
        alignItems = "center",
        padding = compact_ and 8 or 10,
        gap = 3,
        borderRadius = 10,
        backgroundGradient = CREAM_GRAD,
        backgroundImage = "Images/ui/paper_bg.png",
        backgroundImageOpacity = 0.5,
        borderWidth = 3,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 80 } } },
        children = {
            Txt("今日玩具订单", compact_ and 22 or 30, C.ink, "bold"),
            UI.Panel { width = compact_ and 72 or 110, height = 5, borderRadius = 3, backgroundColor = C.orange },
            Txt("打印更多塑料玩具，冲刺排行榜", compact_ and 10 or 12, C.inkSoft),
            UI.Panel {
                width = "100%",
                flexGrow = 1,
                flexShrink = 1,
                flexBasis = 0,
                backgroundImage = "Images/ui/home/hero.png",
                backgroundFit = "contain",
                pointerEvents = "none",
            },
            OrangeButton("去接订单", {
                height = compact_ and 30 or 36,
                fontSize = compact_ and 12 or 14,
                paddingHorizontal = 26,
                onClick = function()
                    print("[3D打印] 首页：去接订单")
                    pendingPage_ = "orders"
                end,
            }),
        },
    }
end

---@param rank integer
---@param nickname string
---@param coins integer
---@param isMe boolean
---@return Panel
local function HomeRankRow(rank, nickname, coins, isMe)
    local medal = RANK_COLORS[rank] or C.track
    return UI.Panel {
        minHeight = compact_ and 40 or 44,
        flexGrow = 1,
        flexBasis = 0,
        flexShrink = 0,
        flexDirection = "row",
        alignItems = "center",
        gap = 7,
        paddingHorizontal = 8,
        borderRadius = 8,
        backgroundGradient = isMe and ORANGE_GRAD or CREAM_GRAD,
        borderWidth = 2,
        borderColor = isMe and C.orangeDeep or C.cardBorder,
        children = {
            UI.Panel {
                width = compact_ and 22 or 24,
                height = compact_ and 22 or 24,
                borderRadius = 12,
                justifyContent = "center",
                alignItems = "center",
                backgroundColor = medal,
                borderWidth = 2,
                borderColor = isMe and C.orangeDeep or C.ink,
                children = { Txt(tostring(rank), compact_ and 11 or 12, { 255, 255, 255, 255 }, "bold") },
            },
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                flexBasis = 0,
                overflow = "hidden",
                children = {
                    Txt(nickname, compact_ and 11 or 13, isMe and C.orangeDeep or C.ink,
                        isMe and "bold" or "normal"),
                },
            },
            Icon("Images/ui/icons/coin.png", compact_ and 12 or 14),
            Txt(FormatCoins(coins), compact_ and 11 or 13, C.inkSoft, "bold"),
        },
    }
end

---@return Panel
local function BuildHomeRankCard()
    ---@type Widget[]
    local rows = {}
    if homeRank_ == nil then
        rows[1] = UI.Panel {
            flexGrow = 1,
            flexBasis = 0,
            justifyContent = "center",
            alignItems = "center",
            children = { Txt("云端榜单加载中…", compact_ and 11 or 12, C.inkSoft) },
        }
    elseif homeRank_ == false then
        for i = 1, 3 do
            rows[#rows + 1] = HomeRankRow(i, "虚位以待", 0, false)
        end
    else
        for i = 1, 3 do
            local entry = homeRank_[i]
            if entry == nil then
                rows[#rows + 1] = HomeRankRow(i, "虚位以待", 0, false)
            else
                rows[#rows + 1] = HomeRankRow(i, entry.nickname or "玩家", entry.coins, entry.isMe)
            end
        end
    end

    ---@type Widget[]
    local children = {
        UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = 6,
            children = {
                Icon("Images/ui/icons/trophy.png", compact_ and 18 or 22),
                Txt("玩具打印排行榜", compact_ and 13 or 15, C.ink, "bold"),
            },
        },
    }
    for _, row in ipairs(rows) do
        children[#children + 1] = row
    end
    children[#children + 1] = UI.Spacer()
    children[#children + 1] = OrangeButton("查看完整榜单", {
        height = compact_ and 30 or 34,
        fontSize = compact_ and 12 or 13,
        width = "100%",
        onClick = function()
            print("[3D打印] 首页：打开完整榜单")
            pendingPage_ = "rich"
        end,
    })

    return UI.Panel {
        width = compact_ and 230 or 286,
        flexShrink = 0,
        flexDirection = "column",
        padding = compact_ and 8 or 10,
        gap = compact_ and 5 or 7,
        borderRadius = 10,
        backgroundGradient = CREAM_GRAD,
        backgroundImage = "Images/ui/paper_bg.png",
        backgroundImageOpacity = 0.5,
        borderWidth = 3,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 80 } } },
        children = children,
    }
end

---@param iconPath string
---@param title string
---@param hint string
---@param onClick fun()
---@return Panel
local function HomeNavTile(iconPath, title, hint, onClick)
    return UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        height = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = compact_ and 10 or 16,
        gap = 6,
        borderRadius = 10,
        backgroundGradient = CREAM_GRAD,
        borderWidth = 3,
        borderColor = C.ink,
        boxShadow = { { x = 0, y = 3, blur = 4, spread = 0, color = { 0, 0, 0, 80 } } },
        onClick = onClick,
        children = {
            UI.Panel {
                flexDirection = "column",
                gap = 1,
                flexShrink = 1,
                children = {
                    Txt(title, compact_ and 14 or 17, C.ink, "bold"),
                    Txt(hint, compact_ and 9 or 10, C.inkSoft),
                },
            },
            UI.Spacer(),
            Icon(iconPath, compact_ and 38 or 50),
        },
    }
end

---@return Panel
local function BuildHomeFrame()
    local body = UI.Panel {
        flexGrow = 1,
        flexBasis = 0,
        flexDirection = "row",
        alignItems = "stretch",
        gap = compact_ and 8 or 10,
        marginTop = compact_ and 8 or 10,
        marginHorizontal = compact_ and 8 or 12,
        children = {
            BuildHomeOverview(),
            BuildHomeHero(),
            BuildHomeRankCard(),
        },
    }

    local navRow = UI.Panel {
        height = compact_ and 78 or 92,
        flexDirection = "row",
        gap = compact_ and 8 or 10,
        marginTop = compact_ and 8 or 10,
        marginHorizontal = compact_ and 8 or 12,
        marginBottom = compact_ and 8 or 12,
        children = {
            HomeNavTile("Images/ui/icons/nav_printer.png", "打印机房", "管理设备", function()
                print("[3D打印] 首页导航：打印机房")
                pendingPage_ = "room"
            end),
            HomeNavTile("Images/ui/icons/nav_orders.png", "订单中心", "接单交付", function()
                print("[3D打印] 首页导航：订单中心")
                pendingPage_ = "orders"
            end),
            HomeNavTile("Images/ui/icons/nav_materials.png", "材料仓库", "补充耗材", function()
                print("[3D打印] 首页导航：材料仓库")
                shopTab_ = "materials"
                pendingPage_ = "shop"
            end),
            HomeNavTile("Images/ui/icons/nav_shop.png", "商店升级", "购置升级", function()
                print("[3D打印] 首页导航：商店升级")
                shopTab_ = "printers"
                pendingPage_ = "shop"
            end),
        },
    }

    return UI.Panel {
        flexGrow = 1,
        flexBasis = 0,
        flexDirection = "column",
        children = { body, navRow },
    }
end

--- 拉取首页排行榜前三
local function RefreshHomeRank()
    homeRank_ = nil
    Leaderboard.PushCoins(M.coins)
    Leaderboard.FetchTop(3, function(entries, reason)
        if entries == nil then
            homeRank_ = false
            print("[3D打印] 首页榜单加载失败: " .. tostring(reason))
        else
            homeRank_ = entries
        end
        if currentPage_ == "home" then
            pendingPage_ = "home"
        end
    end)
end

---@return Panel
local function BuildRoot()
    local page
    if currentPage_ == "home" then
        page = BuildHomeFrame()
    elseif currentPage_ == "shop" then
        page = BuildShopFrame()
    elseif currentPage_ == "orders" then
        page = BuildOrdersFrame()
    elseif currentPage_ == "gallery" then
        page = BuildGalleryFrame()
    elseif currentPage_ == "rich" then
        page = BuildRichFrame()
    else
        page = BuildMainFrame()
    end

    local children = { currentPage_ == "home" and BuildHomeTopBar() or BuildTopBar(), page }
    if currentPage_ == "orders" then
        children[#children + 1] = BuildOrdersBottomBar()
    elseif currentPage_ ~= "home" and currentPage_ ~= "shop" and currentPage_ ~= "gallery" and currentPage_ ~= "rich" then
        children[#children + 1] = BuildBottomBar()
    end

    if pickerOrderId_ ~= nil then
        local order = Orders.Get(pickerOrderId_)
        if order ~= nil and order.status == "待制作" then
            children[#children + 1] = BuildPickerOverlay(order)
        else
            pickerOrderId_ = nil
        end
    end

    if opMachineCode_ ~= nil and currentPage_ == "room" then
        local machine = Orders.GetMachine(opMachineCode_)
        if machine ~= nil then
            children[#children + 1] = BuildOperationOverlay(machine)
        else
            opMachineCode_ = nil
        end
    end

    if venueOpen_ and currentPage_ == "room" then
        children[#children + 1] = BuildVenueOverlay()
    end

    local root = UI.Panel {
        width = "100%",
        height = "100%",
        flexDirection = "column",
        backgroundColor = { 140, 137, 128, 255 },
        backgroundImage = "Images/ui/metal_bg.png",
        backgroundFit = "cover",
        backgroundImageOpacity = 0.55,
        children = children,
    }
    rootRef_ = root
    return root
end

ShowPage = function(page)
    local prevPage = currentPage_
    currentPage_ = page
    roomRefs_ = {}
    orderRefs_ = {}
    lastStatus_ = {}
    for _, machine in ipairs(M.machines) do
        lastStatus_[machine.code] = machine.status
    end
    if page ~= "orders" then
        pickerOrderId_ = nil
    end
    if page ~= "room" then
        opMachineCode_ = nil
        venueOpen_ = false
    end
    -- 进入富豪榜页时先上传最新金币，再拉取榜单与我的名次
    if page == "rich" then
        RefreshRich()
    end
    -- 从其他页面回到首页时刷新排行榜前三
    if page == "home" and prevPage ~= "home" then
        RefreshHomeRank()
    end
    -- 重建会销毁旧控件，先清空标签引用，避免操作已释放的对象
    coinChipLabel_ = nil
    powerCostLabel_ = nil
    materialCostLabel_ = nil
    profitChipLabel_ = nil
    machineCostLabel_ = nil
    venueInfoLabel_ = nil
    venueRentLabel_ = nil
    homeCoinLabel_ = nil
    homeExpLabel_ = nil
    homeProfitLabel_ = nil
    homeRevenueLabel_ = nil
    homePendingLabel_ = nil
    homeSatisfactionLabel_ = nil
    homeDeliveredLabel_ = nil
    -- 重建页面不会影响 NanoVG 金币层；只需按新布局刷新飞行终点
    if #coinFlies_ > 0 then
        local toX, toY = CoinTargetPoint()
        for _, fly in ipairs(coinFlies_) do
            fly.toX = toX
            fly.toY = toY
        end
    end
    UI.SetRoot(BuildRoot(), true)
    -- 同步逻辑分辨率（金币层按 UI 逻辑坐标绘制）
    coinRenderState_.logicalW = UI.GetWidth()
    coinRenderState_.logicalH = UI.GetHeight()
end

local RoomUI = {}

function RoomUI.Setup()
    compact_ = UI.GetWidth() < 1200
    Orders.Init()
    coinShown_ = math.floor(M.coins)
    coinTarget_ = coinShown_
    ShowPage(currentPage_)
    UI.Toast.GetGlobal({ position = "top", maxToasts = 3 })
    EnsureCoinRenderer()
    Sfx.Warmup()
    print("[3D打印] 界面已加载")
end

---@param dt number
function RoomUI.Update(dt)
    fxTime_ = fxTime_ + dt
    local completed = Orders.Update(dt)
    local needRebuild = false

    local dayEvent = Orders.TakeDayEvent()
    if dayEvent ~= nil then
        if dayEvent.kind == "paid" then
            UI.Toast.Show(string.format("第 %d 天 · 已交房租 %d 金币", M.day, dayEvent.rent),
                { type = "info", duration = 2.2 })
        else
            UI.Toast.Show(string.format("第 %d 天 · 金币不足，欠租 %d 金币", M.day, dayEvent.shortfall),
                { type = "error", duration = 2.8 })
        end
        needRebuild = true
    end

    if #completed > 0 then
        for _, order in ipairs(completed) do
            local damaged = order.damagedCount or 0
            if damaged > 0 then
                UI.Toast.Show(string.format("订单 %s 打完一批，损坏 %d 件，收菜后补打剩余",
                    order.id, damaged), { type = "warning", duration = 2.4 })
            else
                UI.Toast.Show(string.format("订单 %s 打印完成，等待交付", order.id),
                    { type = "success", duration = 2.2 })
            end
        end
        needRebuild = true
    end

    for _, machine in ipairs(M.machines) do
        if lastStatus_[machine.code] ~= machine.status then
            lastStatus_[machine.code] = machine.status
            needRebuild = true
        end
    end

    if needRebuild and pickerOrderId_ == nil then
        pendingPage_ = currentPage_
    end

    refreshTimer_ = refreshTimer_ + dt
    if refreshTimer_ >= 0.2 then
        refreshTimer_ = 0.0
        RefreshRoom()
        RefreshOrders()
        RefreshTopBar()
    end

    -- 金币变化后每 15 秒向云端富豪榜同步一次
    local coinsNow = math.floor(M.coins)
    if coinsNow ~= cloudSyncSent_ then
        cloudSyncTimer_ = cloudSyncTimer_ + dt
        if cloudSyncTimer_ >= 15.0 then
            cloudSyncTimer_ = 0.0
            if Leaderboard.PushCoins(M.coins) then
                cloudSyncSent_ = coinsNow
            end
        end
    end

    if pendingPage_ ~= nil then
        local page = pendingPage_
        pendingPage_ = nil
        ShowPage(page)
        UI.Toast.GetGlobal({ position = "top", maxToasts = 3 })
    end

    UpdateCoinCounter(dt)
    UpdateCoinFlies(dt)
    UpdateWarningFx()
end

return RoomUI
