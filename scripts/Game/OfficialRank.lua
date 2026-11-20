-- 3D打印工坊 —— 官方排行榜（开发者后台·游戏排行，与 clientCloud 云变量榜分开）
--
-- 官方 API 由 TapTap 宿主运行时提供全局 `tap` 对象（仅真机/内嵌宿主可用）：
--   tap.getLeaderboardManager()
--     :submitScores({ scores = { { leaderboardId = id, score = n } }, callback = {...} })
--     :openLeaderboard({ leaderboardId = id, collection = "public", callback = {...} })
local M = {}

--- 开发者后台「游戏服务 → 游戏排行」创建的排行榜 ID
local RANK_ID = "p1frcv85aclssra65f"

--- 当前环境是否有官方排行榜能力
---@return boolean
function M.IsAvailable()
    if type(tap) ~= "table" or type(tap.getLeaderboardManager) ~= "function" then
        return false
    end
    local ok, mgr = pcall(tap.getLeaderboardManager, tap)
    return ok and mgr ~= nil
end

--- 提交分数到官方排行榜
---@param score integer 整数分数
---@param callback fun(success: boolean, message: string|nil)|nil
---@return boolean 是否成功发起
function M.Submit(score, callback)
    if not M.IsAvailable() then
        if callback then callback(false, "当前环境不支持官方排行榜") end
        return false
    end
    local ok, mgr = pcall(tap.getLeaderboardManager, tap)
    if not ok or mgr == nil then
        if callback then callback(false, "排行榜管理器不可用") end
        return false
    end
    local callOk, err = pcall(function()
        mgr.submitScores({
            scores = {
                { leaderboardId = RANK_ID, score = math.floor(score) },
            },
            callback = {
                onSuccess = function(res)
                    print("[官方排行榜] 分数提交成功: " .. tostring(score))
                    if callback then callback(true, nil) end
                end,
                onFailure = function(code, message)
                    print("[官方排行榜] 分数提交失败: " .. tostring(code) .. " " .. tostring(message))
                    if callback then callback(false, tostring(message or code)) end
                end,
            },
        })
    end)
    if not callOk then
        print("[官方排行榜] submitScores 调用异常: " .. tostring(err))
        if callback then callback(false, tostring(err)) end
        return false
    end
    return true
end

--- 拉起官方排行榜面板（TapTap 官方 UI，含总榜/好友榜）
---@param collection string|nil "public"（默认，总榜）或 "friends"
---@param callback fun(success: boolean, message: string|nil)|nil
---@return boolean 是否成功发起
function M.Open(collection, callback)
    if not M.IsAvailable() then
        if callback then callback(false, "当前环境不支持官方排行榜") end
        return false
    end
    local ok, mgr = pcall(tap.getLeaderboardManager, tap)
    if not ok or mgr == nil then
        if callback then callback(false, "排行榜管理器不可用") end
        return false
    end
    local callOk, err = pcall(function()
        mgr.openLeaderboard({
            leaderboardId = RANK_ID,
            collection = collection or "public",
            callback = {
                onSuccess = function(res)
                    print("[官方排行榜] 面板打开成功")
                    if callback then callback(true, nil) end
                end,
                onFailure = function(code, message)
                    print("[官方排行榜] 面板打开失败: " .. tostring(code) .. " " .. tostring(message))
                    if callback then callback(false, tostring(message or code)) end
                end,
            },
        })
    end)
    if not callOk then
        print("[官方排行榜] openLeaderboard 调用异常: " .. tostring(err))
        if callback then callback(false, tostring(err)) end
        return false
    end
    return true
end

return M
