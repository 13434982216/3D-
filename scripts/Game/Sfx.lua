-- 3D打印工坊 —— 界面音效（本地合成的 WAV 资源）
local Sfx = {}

---@type SoundSource|nil
local source_
local ready_ = false

---@type table<string, Sound[]>
local clips_ = {}

---@type table<string, string[]>
local CLIP_PATHS = {
    coin_pickup = {
        "Sounds/coin_pickup_1.wav",
        "Sounds/coin_pickup_2.wav",
        "Sounds/coin_pickup_3.wav",
        "Sounds/coin_pickup_4.wav",
    },
    coin_settle = {
        "Sounds/coin_settle_1.wav",
        "Sounds/coin_settle_2.wav",
    },
    counter_tick = {
        "Sounds/counter_tick_1.wav",
        "Sounds/counter_tick_2.wav",
        "Sounds/counter_tick_3.wav",
    },
    print_bad = {
        "Sounds/print_bad.wav",
    },
}

local function Init()
    if ready_ then
        return
    end
    ready_ = true

    for name, paths in pairs(CLIP_PATHS) do
        local list = {} ---@type Sound[]
        for _, path in ipairs(paths) do
            local ok, clip = pcall(function()
                return cache:GetResource("Sound", path)
            end)
            if ok and clip ~= nil then
                list[#list + 1] = clip --[[@as Sound]]
            end
        end
        clips_[name] = list
    end

    local made = pcall(function()
        local node = Node()
        source_ = node:CreateComponent("SoundSource") --[[@as SoundSource]]
        source_:SetSoundType(SOUND_EFFECT)
    end)
    if not made then
        source_ = nil
    end
end

---@param name string
---@param gain number
---@param pitch number
local function Play(name, gain, pitch)
    Init()
    if source_ == nil then
        return
    end
    local list = clips_[name]
    if list == nil or #list == 0 then
        return
    end
    local clip = list[math.random(1, #list)]
    if clip == nil then
        return
    end
    local sound = clip --[[@as Sound]]
    pcall(function()
        source_:Play(sound, sound:GetFrequency() * pitch, gain)
    end)
end

--- 收菜单枚金币的音效
---@param gain number|nil
function Sfx.CoinPickup(gain)
    Play("coin_pickup", gain or 0.55, 0.97 + math.random() * 0.09)
end

--- 结算入账的音效
---@param gain number|nil
function Sfx.CoinSettle(gain)
    Play("coin_settle", gain or 0.65, 0.98 + math.random() * 0.05)
end

--- 数字滚动的轻微 tick，gain 随滚动速度变化
---@param gain number
function Sfx.CounterTick(gain)
    Play("counter_tick", math.min(0.5, gain), 0.9 + math.random() * 0.25)
end

--- 打印损坏 / 操作失败的提示音
function Sfx.Bad()
    Play("print_bad", 0.5, 0.95 + math.random() * 0.1)
end

--- 提前加载音效资源
function Sfx.Warmup()
    Init()
end

return Sfx
