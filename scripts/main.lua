-- 3D打印工坊 —— 入口
local UI = require("urhox-libs/UI")
local RoomUI = require("Game.RoomUI")

function Start()
    graphics.windowTitle = "3D打印工坊"
    UI.Init({ theme = "default-dark", scale = UI.Scale.DEFAULT })
    RoomUI.Setup()
    SubscribeToEvent("Update", "HandleUpdate")
    print("[3D打印] 启动完成")
end

function Stop()
    UI.Shutdown()
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    if dt > 0.1 then
        dt = 0.1
    end
    RoomUI.Update(dt)
end
