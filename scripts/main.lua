-- 大学生失业1万块开3D打印工作室：3D 项目骨架
local UI = require("urhox-libs/UI")

---@type Scene
local scene_
---@type Node
local cameraNode_
local yaw_ = 0.0
local pitch_ = 0.0

local CONFIG = {
    Title = "大学生失业1万块开3D打印工作室",
    CameraSpeed = 8.0,
    MouseSensitivity = 0.12,
}

function Start()
    graphics.windowTitle = CONFIG.Title

    UI.Init({
        theme = "default-dark",
        scale = UI.Scale.DEFAULT,
    })

    CreateScene()
    CreateWorkshop()
    SetupCameraAndViewport()
    CreateUI()
    SubscribeToEvents()

    print("[工作室项目] 3D 场景骨架已启动：" .. CONFIG.Title)
    print("[工作室项目] 操作：WASD 移动，右键拖动旋转，Shift 加速，Space/C 升降")
end

function Stop()
    UI.Shutdown()
end

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")

    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    local lightGroup = scene_:CreateChild("LightGroup")
    lightGroup:LoadXML(lightGroupFile:GetRoot())
end

function CreateWorkshop()
    -- 简洁工作室布景，当前仅提供项目主题展示，不包含经营玩法。
    CreateBox("WorkshopFloor", Vector3(0.0, -0.18, 0.0), Vector3(14.0, 0.36, 12.0),
        Color(0.24, 0.29, 0.33, 1.0), 0.0, 0.86)
    CreateBox("WorkshopBackWall", Vector3(0.0, 2.45, 2.65), Vector3(14.0, 5.0, 0.18),
        Color(0.78, 0.82, 0.84, 1.0), 0.0, 0.92)
    CreateBox("WallAccent", Vector3(0.0, 1.05, 2.53), Vector3(13.8, 0.08, 0.06),
        Color(0.04, 0.56, 0.62, 1.0), 0.15, 0.42)

    CreateWorkbench()
    CreatePrinter()
end

function CreateWorkbench()
    local wood = Color(0.38, 0.22, 0.12, 1.0)
    local darkMetal = Color(0.10, 0.14, 0.17, 1.0)

    CreateBox("WorkbenchTop", Vector3(0.0, 0.91, 0.0), Vector3(4.4, 0.18, 2.2), wood, 0.0, 0.68)

    local legPositions = {
        Vector3(-2.02, 0.43, -0.91),
        Vector3(2.02, 0.43, -0.91),
        Vector3(-2.02, 0.43, 0.91),
        Vector3(2.02, 0.43, 0.91),
    }
    for index, position in ipairs(legPositions) do
        CreateBox("WorkbenchLeg" .. index, position, Vector3(0.14, 0.86, 0.14), darkMetal, 0.72, 0.34)
    end

    CreateBox("WorkbenchDrawer", Vector3(1.25, 0.67, 0.0), Vector3(1.05, 0.34, 1.35),
        Color(0.17, 0.22, 0.25, 1.0), 0.35, 0.5)
    CreateBox("DrawerHandle", Vector3(1.25, 0.68, -0.69), Vector3(0.42, 0.045, 0.035),
        Color(0.64, 0.72, 0.74, 1.0), 0.82, 0.24)
end

function CreatePrinter()
    local frameColor = Color(0.09, 0.15, 0.18, 1.0)
    local railColor = Color(0.55, 0.64, 0.67, 1.0)
    local accentColor = Color(0.04, 0.61, 0.68, 1.0)

    -- 底座和打印平台
    CreateBox("PrinterBase", Vector3(0.0, 1.08, 0.0), Vector3(1.62, 0.16, 1.36), frameColor, 0.48, 0.36)
    CreateBox("PrinterBed", Vector3(0.0, 1.37, -0.02), Vector3(1.18, 0.08, 0.94),
        Color(0.15, 0.22, 0.25, 1.0), 0.62, 0.3)
    CreateBox("BuildPlate", Vector3(0.0, 1.43, -0.02), Vector3(1.02, 0.035, 0.78),
        Color(0.34, 0.42, 0.44, 1.0), 0.72, 0.24)

    -- 四角立柱、顶部横梁与 X 轴导轨
    local postPositions = {
        Vector3(-0.72, 1.91, -0.56), Vector3(0.72, 1.91, -0.56),
        Vector3(-0.72, 1.91, 0.56), Vector3(0.72, 1.91, 0.56),
    }
    for index, position in ipairs(postPositions) do
        CreateBox("PrinterPost" .. index, position, Vector3(0.10, 1.52, 0.10), frameColor, 0.55, 0.32)
    end
    CreateBox("PrinterTopFront", Vector3(0.0, 2.67, -0.56), Vector3(1.54, 0.12, 0.12), frameColor, 0.55, 0.32)
    CreateBox("PrinterTopBack", Vector3(0.0, 2.67, 0.56), Vector3(1.54, 0.12, 0.12), frameColor, 0.55, 0.32)
    CreateBox("PrinterXRail", Vector3(0.0, 2.34, -0.42), Vector3(1.42, 0.11, 0.13), railColor, 0.82, 0.24)

    -- 打印头与少量打印中的样件，作为场景占位展示
    CreateBox("PrinterHead", Vector3(0.12, 2.16, -0.42), Vector3(0.30, 0.28, 0.25), accentColor, 0.35, 0.34)
    CreateBox("PrinterNozzle", Vector3(0.12, 1.98, -0.42), Vector3(0.09, 0.12, 0.09),
        Color(0.78, 0.53, 0.22, 1.0), 0.86, 0.22)
    CreateCylinder("PrintedSample", Vector3(0.12, 1.66, -0.02), Vector3(0.34, 0.42, 0.34),
        Color(0.96, 0.48, 0.16, 1.0), 0.05, 0.42)

    -- 前侧控制面板
    CreateBox("PrinterControlPanel", Vector3(0.93, 1.48, -0.14), Vector3(0.30, 0.38, 0.13), frameColor, 0.35, 0.4)
    CreateBox("PrinterScreen", Vector3(0.93, 1.50, -0.215), Vector3(0.21, 0.17, 0.025),
        Color(0.08, 0.72, 0.78, 1.0), 0.1, 0.2)
end

function CreateBox(name, position, scale, color, metallic, roughness)
    local node = scene_:CreateChild(name)
    node.position = position
    node.scale = scale

    local staticModel = node:CreateComponent("StaticModel")
    staticModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(color))
    material:SetShaderParameter("MatSpecColor", Variant(Color(0.5, 0.5, 0.5, 1.0)))
    material:SetShaderParameter("Metallic", Variant(metallic))
    material:SetShaderParameter("Roughness", Variant(roughness))
    staticModel:SetMaterial(material)
    staticModel.castShadows = true
    return node
end

function CreateCylinder(name, position, scale, color, metallic, roughness)
    local node = scene_:CreateChild(name)
    node.position = position
    node.scale = scale

    local staticModel = node:CreateComponent("StaticModel")
    staticModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))

    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(color))
    material:SetShaderParameter("MatSpecColor", Variant(Color(0.5, 0.5, 0.5, 1.0)))
    material:SetShaderParameter("Metallic", Variant(metallic))
    material:SetShaderParameter("Roughness", Variant(roughness))
    staticModel:SetMaterial(material)
    staticModel.castShadows = true
    return node
end

function SetupCameraAndViewport()
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(4.2, 3.15, -7.2)
    cameraNode_:LookAt(Vector3(0.0, 1.35, 0.15))

    local camera = cameraNode_:CreateComponent("Camera")
    camera.nearClip = 0.1
    camera.farClip = 200.0
    camera.fov = 55.0

    renderer:SetViewport(0, Viewport:new(scene_, camera))
    yaw_ = cameraNode_.rotation:YawAngle()
    pitch_ = cameraNode_.rotation:PitchAngle()
end

function CreateUI()
    UI.SetRoot(UI.Panel {
        id = "workshopProjectRoot",
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            UI.Panel {
                position = "absolute",
                top = 18,
                left = 18,
                width = 500,
                padding = 18,
                gap = 8,
                backgroundColor = { 14, 22, 28, 226 },
                borderColor = { 255, 255, 255, 32 },
                borderWidth = 1,
                borderRadius = 10,
                children = {
                    UI.Label {
                        text = CONFIG.Title,
                        fontSize = 22,
                        fontWeight = "bold",
                        fontColor = { 246, 249, 250, 255 },
                    },
                    UI.Label {
                        text = "大学生创业模拟 · 3D 打印工作室",
                        fontSize = 14,
                        fontColor = { 139, 218, 220, 255 },
                    },
                    UI.Label {
                        text = "开局设定：¥10,000     项目状态：骨架阶段",
                        fontSize = 13,
                        fontColor = { 220, 226, 229, 255 },
                        marginTop = 4,
                    },
                },
            },
            UI.Panel {
                position = "absolute",
                right = 18,
                bottom = 18,
                padding = 12,
                backgroundColor = { 14, 22, 28, 210 },
                borderRadius = 8,
                children = {
                    UI.Label {
                        text = "WASD 移动 · 按住鼠标右键旋转 · Shift 加速 · Space/C 升降",
                        fontSize = 12,
                        fontColor = { 226, 233, 236, 255 },
                    },
                },
            },
        },
    })
end

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    HandleCameraMovement(dt)
end

function HandleCameraMovement(dt)
    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        yaw_ = yaw_ + input.mouseMoveX * CONFIG.MouseSensitivity
        pitch_ = Clamp(pitch_ + input.mouseMoveY * CONFIG.MouseSensitivity, -82.0, 82.0)
        cameraNode_.rotation = Quaternion(pitch_, yaw_, 0.0)
    end

    local moveSpeed = CONFIG.CameraSpeed
    if input:GetKeyDown(KEY_SHIFT) then
        moveSpeed = moveSpeed * 2.0
    end
    local step = moveSpeed * dt

    if input:GetKeyDown(KEY_W) then
        cameraNode_:Translate(Vector3(0.0, 0.0, step))
    end
    if input:GetKeyDown(KEY_S) then
        cameraNode_:Translate(Vector3(0.0, 0.0, -step))
    end
    if input:GetKeyDown(KEY_A) then
        cameraNode_:Translate(Vector3(-step, 0.0, 0.0))
    end
    if input:GetKeyDown(KEY_D) then
        cameraNode_:Translate(Vector3(step, 0.0, 0.0))
    end
    if input:GetKeyDown(KEY_SPACE) then
        cameraNode_:Translate(Vector3(0.0, step, 0.0), TS_WORLD)
    end
    if input:GetKeyDown(KEY_C) then
        cameraNode_:Translate(Vector3(0.0, -step, 0.0), TS_WORLD)
    end
end
