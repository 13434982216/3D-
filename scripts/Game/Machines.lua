-- 3D打印工坊 —— 机器、订单与商店数据
local M = {}

---@type number
M.coins = 128000
--- 累计耗电成本（金币，打印时按秒计费）
---@type number
M.powerCost = 0.0
--- 累计耗材成本（金币，加料时计入）
---@type number
M.materialCost = 0.0
--- 累计购机成本（金币，购买打印机时计入）
---@type number
M.machineCost = 0.0
--- 经营利润（金币 = 订单收入 - 电费 - 耗材费 - 维修费 - 购机费）
---@type number
M.profit = 0.0
--- 经验（每交付一个订单获得，等于订单收益的 1/10）
---@type number
M.exp = 0.0
--- 累计订单收入（交付成功时累加，不随游戏内天数清零）
---@type number
M.todayRevenue = 0.0
--- 累计交付件数
---@type integer
M.todayDelivered = 0
--- 累计成品件数（用于计算客户满意度）
---@type integer
M.goodsDone = 0
--- 累计损坏件数（用于计算客户满意度）
---@type integer
M.damagedDone = 0
--- 耗材库存（克）：商店购买的耗材入此库，加料时划拨到机器
---@type integer
M.materialStock = 0
--- 图鉴统计：产品名 -> 已交付件数
---@type table<string, integer>
M.delivered = {}

-- 经营参数
M.powerRatePerSecond = 0.2   -- 每台打印中的机器每秒电费
M.repairCost = 150            -- 单台维修费用
M.damageChance = 0.08         -- 每件打印损坏概率
M.faultChance = 0.03          -- 每件开始时的故障概率

-- 机房场地：默认宿舍，容量决定可摆放机器数量，每天交租金
---@class Venue
---@field name string
---@field capacity integer
---@field price integer 一次性扩建价
---@field rent integer 每日租金
---@field desc string

---@type Venue[]
M.venues = {
    { name = "宿舍", capacity = 2, price = 0, rent = 20,
      desc = "一张床一台机，起步的地方" },
    { name = "车库", capacity = 4, price = 3000, rent = 60,
      desc = "腾出停车位，能放下四台打印机" },
    { name = "小厂房", capacity = 7, price = 12000, rent = 180,
      desc = "独立水电，产能翻倍" },
    { name = "中厂房", capacity = 11, price = 40000, rent = 500,
      desc = "正规厂房，稳定接大单" },
    { name = "大厂房", capacity = 16, price = 120000, rent = 1200,
      desc = "整层车间，规模化生产" },
}

--- 当前场地下标（指向 M.venues）
---@type integer
M.venueIndex = 1
--- 累计场地扩建投入
---@type number
M.venueCost = 0.0
--- 当前天数（从第 1 天开始）
---@type integer
M.day = 1
--- 一天持续多少秒
---@type number
M.daySeconds = 60.0
--- 当天已过秒数
---@type number
M.dayTimer = 0.0
--- 累计欠缴租金
---@type integer
M.rentDue = 0

---@class Machine
---@field code string
---@field model string
---@field short string
---@field sprite string
---@field status string 空闲|打印中|缺料|故障|可收取
---@field progress number 当前批次进度 0~1
---@field material number
---@field materialMax integer
---@field output integer
---@field level integer
---@field printName string
---@field orderId string|nil
---@field speedMul number
---@field materialRate number
---@field price integer
---@field batchSize integer 当前批次要打印的件数
---@field batchIndex integer 当前批次已处理件数
---@field itemStarted boolean 当前这一件是否已扣料开打

--- 初始机房为空，玩家在商店购买打印机后加入
---@type Machine[]
M.machines = {}

---@class Order
---@field id string
---@field client string
---@field product string
---@field icon string
---@field quantity integer
---@field unitPrice integer 单件售价（金币）
---@field material string
---@field materialImage string
---@field grams integer
---@field price integer 整单交付奖励
---@field seconds integer
---@field status string 待制作|制作中|可交付|已完成
---@field machineCode string|nil
---@field progress number
---@field goodCount integer 已打好件数
---@field damagedCount integer 本批损坏件数（需补打）
---@field desc string 图鉴简介

--- 订单模板库：图鉴按此展示全部型号，订单从模板生成
---@type Order[]
M.orderCatalog = {
    { id = "A-1001", client = "潮玩集合店", product = "关节章鱼", icon = "Images/ui/products/octopus.png",
      quantity = 12, unitPrice = 28, material = "PETG 蓝色", materialImage = "Images/ui/materials/petg.png",
      grams = 420, price = 336, seconds = 34, status = "待制作", machineCode = nil, progress = 0.0,
      goodCount = 0, damagedCount = 0, desc = "多关节可动，潮玩店常备款" },
    { id = "A-1002", client = "整活玩具铺", product = "马桶鱼摆件", icon = "Images/ui/products/toilet_fish.png",
      quantity = 6, unitPrice = 48, material = "光敏树脂", materialImage = "Images/ui/materials/resin.png",
      grams = 300, price = 288, seconds = 42, status = "待制作", machineCode = nil, progress = 0.0,
      goodCount = 0, damagedCount = 0, desc = "整活界顶流摆件" },
    { id = "A-1003", client = "奇幻手作馆", product = "彩虹飞龙", icon = "Images/ui/products/dragon.png",
      quantity = 8, unitPrice = 56, material = "高韧树脂 透明蓝", materialImage = "Images/ui/materials/resin_clear.png",
      grams = 460, price = 448, seconds = 46, status = "待制作", machineCode = nil, progress = 0.0,
      goodCount = 0, damagedCount = 0, desc = "半透明渐变鳞片" },
    { id = "A-1004", client = "医学模型社", product = "关节骷髅", icon = "Images/ui/products/skeleton.png",
      quantity = 10, unitPrice = 33, material = "PLA 白色", materialImage = "Images/ui/materials/pla.png",
      grams = 380, price = 330, seconds = 36, status = "待制作", machineCode = nil, progress = 0.0,
      goodCount = 0, damagedCount = 0, desc = "医用教具同款模型" },
    { id = "A-1005", client = "整蛊玩具店", product = "搞怪蜥蜴", icon = "Images/ui/products/lizard.png",
      quantity = 18, unitPrice = 19, material = "夜光 PLA 绿色", materialImage = "Images/ui/materials/glow.png",
      grams = 260, price = 342, seconds = 26, status = "待制作", machineCode = nil, progress = 0.0,
      goodCount = 0, damagedCount = 0, desc = "夜光绿皮肤，暗处发光" },
    { id = "A-1006", client = "漫画周边店", product = "超级英雄立体漫画", icon = "Images/ui/products/spiderman.png",
      quantity = 6, unitPrice = 88, material = "光敏树脂", materialImage = "Images/ui/materials/resin.png",
      grams = 500, price = 528, seconds = 52, status = "待制作", machineCode = nil, progress = 0.0,
      goodCount = 0, damagedCount = 0, desc = "漫画封面跃出墙面，立体浮雕" },
    { id = "A-1007", client = "潮玩集合店", product = "粉红电气鼠玩偶", icon = "Images/ui/products/pikachu.png",
      quantity = 8, unitPrice = 56, material = "TPU 橙色", materialImage = "Images/ui/materials/tpu.png",
      grams = 380, price = 448, seconds = 40, status = "待制作", machineCode = nil, progress = 0.0,
      goodCount = 0, damagedCount = 0, desc = "软萌勾线玩偶，粉色款超圈粉" },
    { id = "A-1008", client = "手办收藏馆", product = "小丑骑单车手办", icon = "Images/ui/products/joker.png",
      quantity = 5, unitPrice = 96, material = "光敏树脂", materialImage = "Images/ui/materials/resin.png",
      grams = 460, price = 480, seconds = 54, status = "待制作", machineCode = nil, progress = 0.0,
      goodCount = 0, damagedCount = 0, desc = "电影同款反派，骑着单车登场" },
    { id = "A-1009", client = "手办收藏馆", product = "小丑女手办", icon = "Images/ui/products/harley.png",
      quantity = 5, unitPrice = 108, material = "高韧树脂 透明蓝", materialImage = "Images/ui/materials/resin_clear.png",
      grams = 480, price = 540, seconds = 56, status = "待制作", machineCode = nil, progress = 0.0,
      goodCount = 0, damagedCount = 0, desc = "棒球棍造型，配色大胆" },
    { id = "A-1010", client = "复古礼品店", product = "经典白裙手办", icon = "Images/ui/products/monroe.png",
      quantity = 4, unitPrice = 128, material = "光敏树脂", materialImage = "Images/ui/materials/resin.png",
      grams = 520, price = 512, seconds = 60, status = "待制作", machineCode = nil, progress = 0.0,
      goodCount = 0, damagedCount = 0, desc = "白裙飞扬的经典瞬间" },
    { id = "A-1011", client = "整蛊玩具店", product = "幽灵小玩偶", icon = "Images/ui/products/ghost.png",
      quantity = 10, unitPrice = 42, material = "TPU 橙色", materialImage = "Images/ui/materials/tpu.png",
      grams = 330, price = 420, seconds = 34, status = "待制作", machineCode = nil, progress = 0.0,
      goodCount = 0, damagedCount = 0, desc = "呆萌幽灵，床头整蛊神器" },
    { id = "A-1012", client = "整活玩具铺", product = "皇冠鸭鸭手办", icon = "Images/ui/products/psyduck.png",
      quantity = 8, unitPrice = 66, material = "TPU 橙色", materialImage = "Images/ui/materials/tpu.png",
      grams = 400, price = 528, seconds = 44, status = "待制作", machineCode = nil, progress = 0.0,
      goodCount = 0, damagedCount = 0, desc = "戴皇冠的呆萌鸭，整活爆款" },
}

--- 当前订单列表：开局 3 单，每成功交付 1 单奖励 2 单
---@type Order[]
M.orders = {}

---@class ShopPrinter
---@field name string
---@field sprite string
---@field tag string
---@field spec string
---@field price integer
---@field ref string
---@field speed number 打印速度倍率
---@field materialRate number 耗材消耗倍率
---@field tier integer 机型档位

---@type ShopPrinter[]
M.shopPrinters = {
    { name = "Anycubic Kobra 2", sprite = "Images/ui/printers/kobra2.png", tag = "入门高速", spec = "FDM · 220×220×250mm", price = 1199, ref = "¥1,199",
      speed = 0.95, materialRate = 1.08, tier = 1 },
    { name = "Creality Ender-3 V3", sprite = "Images/ui/printers/ender3v3.png", tag = "入门", spec = "FDM · 220×220×250mm", price = 1299, ref = "¥1,299",
      speed = 1.00, materialRate = 1.05, tier = 1 },
    { name = "Elegoo Mars 4", sprite = "Images/ui/printers/mars4.png", tag = "光固化", spec = "树脂 · 153×77×175mm", price = 1299, ref = "¥1,299",
      speed = 0.90, materialRate = 0.98, tier = 2 },
    { name = "Elegoo Neptune 4 Plus", sprite = "Images/ui/printers/neptune4.png", tag = "大尺寸", spec = "FDM · 320×320×385mm", price = 1999, ref = "¥1,999",
      speed = 1.10, materialRate = 1.00, tier = 3 },
    { name = "Bambu Lab A1", sprite = "Images/ui/printers/a1.png", tag = "家用全自动", spec = "FDM · 256×256×256mm", price = 2199, ref = "¥2,199",
      speed = 1.25, materialRate = 0.95, tier = 4 },
    { name = "Creality K1", sprite = "Images/ui/printers/k1.png", tag = "封闭 CoreXY", spec = "FDM · 220×220×250mm", price = 2499, ref = "¥2,499",
      speed = 1.40, materialRate = 0.92, tier = 5 },
    { name = "Bambu Lab P1S", sprite = "Images/ui/printers/p1s.png", tag = "封闭高速", spec = "FDM · 256×256×256mm", price = 4299, ref = "¥4,299",
      speed = 1.55, materialRate = 0.88, tier = 6 },
    { name = "Prusa MK4", sprite = "Images/ui/printers/mk4.png", tag = "开源旗舰", spec = "FDM · 250×210×220mm", price = 5999, ref = "¥5,999",
      speed = 1.65, materialRate = 0.85, tier = 7 },
}

---@class ShopMaterial
---@field name string
---@field image string
---@field tag string
---@field spec string
---@field price integer
---@field ref string
---@field grams integer 每包克数

---@type ShopMaterial[]
M.shopMaterials = {
    { name = "PLA 白色", image = "Images/ui/materials/pla.png", tag = "玩具常用", spec = "1kg · 通用易打印", price = 59, ref = "¥59", grams = 1000 },
    { name = "PETG 蓝色", image = "Images/ui/materials/petg.png", tag = "韧性", spec = "1kg · 耐热耐摔", price = 79, ref = "¥79", grams = 1000 },
    { name = "ABS 黑色", image = "Images/ui/materials/abs.png", tag = "耐冲击", spec = "1kg · 结构件常用", price = 69, ref = "¥69", grams = 1000 },
    { name = "TPU 橙色", image = "Images/ui/materials/tpu.png", tag = "柔性", spec = "1kg · 软胶玩具", price = 119, ref = "¥119", grams = 1000 },
    { name = "光敏树脂", image = "Images/ui/materials/resin.png", tag = "高精度", spec = "1kg · 手办细节", price = 139, ref = "¥139", grams = 1000 },
    { name = "夜光 PLA 绿色", image = "Images/ui/materials/glow.png", tag = "夜光", spec = "1kg · 夜光玩具", price = 89, ref = "¥89", grams = 1000 },
    { name = "木纹 PLA 棕色", image = "Images/ui/materials/wood.png", tag = "木纹", spec = "1kg · 木纹质感", price = 99, ref = "¥99", grams = 1000 },
    { name = "高韧树脂 透明蓝", image = "Images/ui/materials/resin_clear.png", tag = "高韧", spec = "1kg · 耐摔手办", price = 149, ref = "¥149", grams = 1000 },
}

return M
