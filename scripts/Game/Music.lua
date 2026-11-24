-- 3D打印工坊 —— 背景音乐（循环播放，音量独立控制）
local Music = {}

---@type Node|nil
local node_
---@type SoundSource|nil
local source_
---@type Sound|nil
local clip_
local loaded_ = false
local volume_ = 0.5

--- 开始播放 BGM；重复调用无副作用
function Music.Init()
    if loaded_ then
        return
    end
    loaded_ = true

    local ok, clip = pcall(function()
        return cache:GetResource("Sound", "Sounds/bgm_workshop.ogg")
    end)
    if not ok or clip == nil then
        print("[音乐] BGM 资源加载失败")
        return
    end
    clip_ = clip --[[@as Sound]]
    clip_.looped = true

    local made = pcall(function()
        node_ = Node()
        source_ = node_:CreateComponent("SoundSource") --[[@as SoundSource]]
        source_:SetSoundType(SOUND_MUSIC)
        source_:Play(clip_, 0, 1.0)
    end)
    if not made then
        node_ = nil
        source_ = nil
        print("[音乐] SoundSource 创建失败")
        return
    end
    Music.SetVolume(volume_)
end

--- 某些平台首次播放可能被自动播放策略拦下，用户第一次交互时再试一次
function Music.EnsurePlaying()
    if source_ == nil or clip_ == nil then
        return
    end
    if not source_.playing then
        pcall(function()
            source_:Play(clip_, 0, 1.0)
        end)
    end
end

---@param v number 0~1
function Music.SetVolume(v)
    volume_ = math.max(0, math.min(1, v))
    pcall(function()
        audio:SetMasterGain(SOUND_MUSIC, volume_)
    end)
end

---@return number
function Music.GetVolume()
    return volume_
end

return Music
