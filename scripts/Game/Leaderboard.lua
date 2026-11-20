-- 3D打印工坊 —— 富豪榜（云端金币排行榜）
local M = {}

--- 云端排行榜 key（iscore，整数金币）
local RANK_KEY = "coins"

--- 上次上传的金币值，无变化不重复写云
---@type integer
local lastSynced_ = -1

---@return boolean
local function HasCloud()
    return clientCloud ~= nil
end

--- 把当前金币绝对值写入云端排行榜
---@param coins number
---@return boolean 是否成功发起
function M.PushCoins(coins)
    if not HasCloud() then
        return false
    end
    coins = math.floor(coins)
    if coins == lastSynced_ then
        return true
    end
    lastSynced_ = coins
    clientCloud:SetInt(RANK_KEY, coins, {
        ok = function() end,
        error = function(code, reason)
            print("[富豪榜] 金币上传失败: " .. tostring(reason))
        end,
    })
    return true
end

---@class RankEntry
---@field rank integer
---@field userId any
---@field nickname string
---@field coins integer
---@field isMe boolean

--- 拉取前 topN 名，回调 entries（失败回调 nil, reason）
---@param topN integer
---@param callback fun(entries: RankEntry[]|nil, reason: string|nil)
function M.FetchTop(topN, callback)
    if not HasCloud() then
        callback(nil, "云端服务不可用")
        return
    end
    clientCloud:GetRankList(RANK_KEY, 0, topN, {
        ok = function(rankList)
            local entries = {}
            local userIds = {}
            for i, item in ipairs(rankList or {}) do
                table.insert(entries, {
                    rank = i,
                    userId = item.userId,
                    nickname = nil,
                    coins = (item.iscore and item.iscore[RANK_KEY]) or 0,
                    isMe = item.userId == clientCloud.userId,
                })
                table.insert(userIds, item.userId)
            end
            if #userIds == 0 then
                callback(entries)
                return
            end
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local map = {}
                    for _, info in ipairs(nicknames or {}) do
                        map[info.userId] = info.nickname or ""
                    end
                    for _, entry in ipairs(entries) do
                        entry.nickname = map[entry.userId]
                        if entry.nickname == nil or entry.nickname == "" then
                            entry.nickname = "玩家" .. tostring(entry.userId)
                        end
                    end
                    callback(entries)
                end,
                onError = function(errorCode)
                    -- 昵称查询失败也照常展示榜单
                    for _, entry in ipairs(entries) do
                        entry.nickname = "玩家" .. tostring(entry.userId)
                    end
                    callback(entries)
                end,
            })
        end,
        error = function(code, reason)
            callback(nil, tostring(reason))
        end,
        timeout = function()
            callback(nil, "网络超时，请稍后重试")
        end,
    })
end

--- 查询我自己的名次（rank 为 nil 表示未上榜）---@param callback fun(rank: integer|nil, coins: integer|nil)
function M.FetchMyRank(callback)
    if not HasCloud() then
        callback(nil, nil)
        return
    end
    clientCloud:GetUserRank(clientCloud.userId, RANK_KEY, {
        ok = function(rank, scoreValue)
            callback(rank, scoreValue)
        end,
        error = function()
            callback(nil, nil)
        end,
        timeout = function()
            callback(nil, nil)
        end,
    })
end

--- 查询上榜总人数（失败回调 nil）
---@param callback fun(total: integer|nil)
function M.FetchTotal(callback)
    if not HasCloud() then
        callback(nil)
        return
    end
    clientCloud:GetRankTotal(RANK_KEY, {
        ok = function(total)
            callback(total)
        end,
        error = function()
            callback(nil)
        end,
        timeout = function()
            callback(nil)
        end,
    })
end

return M
