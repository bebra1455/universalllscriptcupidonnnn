-- [[ ОКНО 1: КОНФИГУРАЦИЯ И СТРУКТУРА НАСТРОЕК ]] --
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

_G.BuildSettings = {
    Size = Vector3.new(4, 4, 4),
    Color = Color3.fromRGB(46, 204, 113),
    Shape = "Block",
    Rotation = 0,
    Visible = true,
    BuildMode = false,
    DeleteMode = false
}

_G.DATA_PREFIX = "MH_"
_G.CurrentPreview = nil
_G.PreviewChildren = {}
_G.ProcessedPackets = {}
_G.MyPlacedObjects = {}

_G.ShapeMap = {["Block"]="1", ["Ball"]="2", ["Cylinder"]="3", ["Wedge"]="4", ["Window"]="5"}
_G.ShapeReverseMap = {["1"]="Block", ["2"]="Ball", ["3"]="Cylinder", ["4"]="Wedge", ["5"]="Window"}
-- [[ ОКНО 2: ГЕНЕРАЦИЯ СТАБИЛЬНОГО ПРЕВЬЮ ]] --
local function clearPreview()
    if _G.CurrentPreview then _G.CurrentPreview:Destroy(); _G.CurrentPreview = nil end
    for _, child in pairs(_G.PreviewChildren) do child:Destroy() end
    table.clear(_G.PreviewChildren)
end

_G.UpdatePreviewShapeGlobal = function()
    clearPreview()
    local shape = _G.BuildSettings.Shape
    local size = _G.BuildSettings.Size
    
    _G.CurrentPreview = Instance.new("Part")
    if shape == "Block" or shape == "Ball" or shape == "Cylinder" then
        _G.CurrentPreview.Shape = Enum.PartType[shape]
        _G.CurrentPreview.Size = size
    elseif shape == "Wedge" then
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.Wedge
        mesh.Scale = Vector3.new(1, 1, 1)
        mesh.Parent = _G.CurrentPreview
        _G.CurrentPreview.Size = size
    elseif shape == "Window" then
        _G.CurrentPreview.Transparency = 1
        _G.CurrentPreview.Size = Vector3.new(size.X, size.Y, 0.4)
        for i = 1, 4 do
            local subPart = Instance.new("Part")
            subPart.Material = Enum.Material.SmoothPlastic
            subPart.CanCollide = false; subPart.CanQuery = false
            subPart.Parent = _G.CurrentPreview
            table.insert(_G.PreviewChildren, subPart)
        end
    end
    _G.CurrentPreview.Name = "Build_Preview"
    _G.CurrentPreview.Material = Enum.Material.SmoothPlastic
    _G.CurrentPreview.Anchored = true; _G.CurrentPreview.CanCollide = false; _G.CurrentPreview.CanQuery = false
    _G.CurrentPreview.Transparency = (shape == "Window") and 1 or 0.5
    _G.CurrentPreview.Parent = workspace
    local SelectionBox = Instance.new("SelectionBox")
    SelectionBox.Color3 = Color3.fromRGB(0, 0, 0); SelectionBox.LineThickness = 0.05
    SelectionBox.Adornee = _G.CurrentPreview; SelectionBox.Parent = _G.CurrentPreview
end
_G.UpdatePreviewShapeGlobal()
-- [[ ОКНО 3: СОЗДАНИЕ ФИЗИЧЕСКИХ ОБЪЕКТОВ ]] --
_G.CreateLocalPartGlobal = function(pos, size, color, shape, rotation, isFromNetwork)
    local baseCFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotation), 0)
    local mainTargetObject = nil
    
    if shape == "Wedge" then
        local part = Instance.new("Part")
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.Wedge
        mesh.Parent = part
        part.Size = size; part.Color = color; part.Anchored = true; part.Material = Enum.Material.SmoothPlastic
        part.CFrame = baseCFrame; part.Parent = workspace; part.Transparency = 1
        TweenService:Create(part, TweenInfo.new(0.15), {Transparency = 0}):Play()
        mainTargetObject = part
    elseif shape == "Window" then
        local folder = Instance.new("Folder")
        folder.Name = "PlacedWindow"; folder.Parent = workspace
        local windowThickness = 0.4 
        local offsets = {
            {s = Vector3.new(0.3, size.Y, windowThickness), p = Vector3.new(-size.X/2 + 0.15, 0, 0)},
            {s = Vector3.new(0.3, size.Y, windowThickness), p = Vector3.new(size.X/2 - 0.15, 0, 0)},
            {s = Vector3.new(size.X, 0.3, windowThickness), p = Vector3.new(0, size.Y/2 - 0.15, 0)},
            {s = Vector3.new(size.X, 0.3, windowThickness), p = Vector3.new(0, -size.Y/2 + 0.15, 0)}
        }
        for _, sub in pairs(offsets) do
            local p = Instance.new("Part")
            p.Size = sub.s; p.Color = color; p.Anchored = true; p.Material = Enum.Material.SmoothPlastic
            p.CFrame = baseCFrame * CFrame.new(sub.p); p.Parent = folder; p.Transparency = 1
            TweenService:Create(p, TweenInfo.new(0.15), {Transparency = 0}):Play()
        end
        mainTargetObject = folder
    else
        local part = Instance.new("Part")
        if shape == "Ball" or shape == "Cylinder" then part.Shape = Enum.PartType[shape] end
        part.Size = size; part.Color = color; part.Anchored = true; part.Material = Enum.Material.SmoothPlastic
        part.CFrame = baseCFrame; part.Parent = workspace; part.Transparency = 1
        TweenService:Create(part, TweenInfo.new(0.15), {Transparency = 0}):Play()
        mainTargetObject = part
    end
    
    if mainTargetObject and not isFromNetwork then
        if mainTargetObject:IsA("Folder") then
            for _, child in pairs(mainTargetObject:GetChildren()) do child:SetAttribute("MyBlock", true) end
        else
            mainTargetObject:SetAttribute("MyBlock", true)
        end
        _G.MyPlacedObjects[mainTargetObject] = true
    end
end
-- [[ ОКНО 4: ЖЕЛЕЗОБЕТОННАЯ СЕТЬ ЧЕРЕЗ TOOL ]] --
local function broadcastPlacementSilent(pos, size, color, shape, rotation)
    local shapeLetter = _G.ShapeMap[shape] or "1"
    local dataStr = string.format("%d_%d_%d_%d_%d_%d_%d_%d_%d_%s_%d",
        math.round(pos.X*10), math.round(pos.Y*10), math.round(pos.Z*10),
        math.round(size.X), math.round(size.Y), math.round(size.Z),
        math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255),
        shapeLetter, rotation
    )
    
    -- Пробиваем FilteringEnabled через принудительную экипировку предмета
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    
    if bp and hum then
        local syncTool = bp:FindFirstChild("SystemSync") or Instance.new("Tool")
        syncTool.Name = _G.DATA_PREFIX .. dataStr
        syncTool.RequiresHandle = false
        syncTool.Parent = char -- Авто-экипировка заставляет сервер разослать имя предмета всем
        RunService.RenderStepped:Wait()
        syncTool.Parent = bp
        syncTool.Name = "SystemSync"
    end
end

local function parseDataString(str)
    if not str or not string.find(str, _G.DATA_PREFIX) then return nil end
    local cleanData = string.gsub(str, _G.DATA_PREFIX, "")
    local sections = string.split(cleanData, "_")
    if #sections >= 11 then
        local pos = Vector3.new(tonumber(sections[1])/10, tonumber(sections[2])/10, tonumber(sections[3])/10)
        local size = Vector3.new(tonumber(sections[4]), tonumber(sections[5]), tonumber(sections[6]))
        local color = Color3.fromRGB(tonumber(sections[7]), tonumber(sections[8]), tonumber(sections[9]))
        local shape = _G.ShapeReverseMap[sections[10]] or "Block"
        local rot = tonumber(sections[11]) or 0
        return pos, size, color, shape, rot, cleanData
    end
    return nil
end

RunService.RenderStepped:Connect(function()
    if _G.CurrentPreview and _G.BuildSettings.Visible and _G.BuildSettings.BuildMode and not _G.BuildSettings.DeleteMode then
        _G.CurrentPreview.Parent = workspace; _G.CurrentPreview.Color = _G.BuildSettings.Color
        local offsetHeight = _G.BuildSettings.Size.Y / 2
        if _G.BuildSettings.Shape == "Window" then
            _G.CurrentPreview.Size = Vector3.new(_G.BuildSettings.Size.X, _G.BuildSettings.Size.Y, 0.4)
            for i, child in ipairs(_G.PreviewChildren) do
                child.Color = _G.BuildSettings.Color; child.Transparency = 0.5
                if i == 1 then child.Size = Vector3.new(0.3, _G.BuildSettings.Size.Y, 0.4); child.Position = _G.CurrentPreview.Position - _G.CurrentPreview.CFrame.RightVector * (_G.BuildSettings.Size.X/2 - 0.15)
                elseif i == 2 then child.Size = Vector3.new(0.3, _G.BuildSettings.Size.Y, 0.4); child.Position = _G.CurrentPreview.Position + _G.CurrentPreview.CFrame.RightVector * (_G.BuildSettings.Size.X/2 - 0.15)
                elseif i == 3 then child.Size = Vector3.new(_G.BuildSettings.Size.X, 0.3, 0.4); child.Position = _G.CurrentPreview.Position + _G.CurrentPreview.CFrame.UpVector * (_G.BuildSettings.Size.Y/2 - 0.15)
                elseif i == 4 then child.Size = Vector3.new(_G.BuildSettings.Size.X, 0.3, 0.4); child.Position = _G.CurrentPreview.Position - _G.CurrentPreview.CFrame.UpVector * (_G.BuildSettings.Size.Y/2 - 0.15) end
            end
        else
            _G.CurrentPreview.Size = _G.BuildSettings.Size
            if _G.BuildSettings.Shape == "Ball" then offsetHeight = _G.BuildSettings.Size.X / 2 end
        end
        _G.CurrentPreview.CFrame = CFrame.new(Mouse.Hit.p + Vector3.new(0, offsetHeight, 0)) * CFrame.Angles(0, math.rad(_G.BuildSettings.Rotation), 0)
    elseif _G.CurrentPreview then
        _G.CurrentPreview.Parent = nil
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if _G.BuildSettings.Visible then
            local mLoc = UserInputService:GetMouseLocation()
            local clickedObjects = LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(mLoc.X, mLoc.Y)
            for _, obj in pairs(clickedObjects) do
                if obj:IsDescendantOf(game:GetService("CoreGui"):FindFirstChild("MegaBuildGui")) or obj.Name == "MainFrame" then return end
            end
            if _G.BuildSettings.DeleteMode then
                local target = Mouse.Target
                if target and target:GetAttribute("MyBlock") == true then
                    local parent = target.Parent
                    if parent and parent:IsA("Folder") then parent:Destroy() else target:Destroy() end
                end
            elseif _G.BuildSettings.BuildMode then
                local buildPos = Mouse.Hit.p
                local offsetHeight = _G.BuildSettings.Size.Y / 2
                if _G.BuildSettings.Shape == "Ball" then offsetHeight = _G.BuildSettings.Size.X / 2 end
                local targetPos = buildPos + Vector3.new(0, offsetHeight, 0)
                _G.CreateLocalPartGlobal(targetPos, _G.BuildSettings.Size, _G.BuildSettings.Color, _G.BuildSettings.Shape, _G.BuildSettings.Rotation, false)
                broadcastPlacementSilent(targetPos, _G.BuildSettings.Size, _G.BuildSettings.Color, _G.BuildSettings.Shape, _G.BuildSettings.Rotation)
            end
        end
    elseif input.KeyCode == Enum.KeyCode.K and not UserInputService:GetFocusedTextBox() then
        _G.BuildSettings.Visible = not _G.BuildSettings.Visible
        local targetGui = game:GetService("CoreGui"):FindFirstChild("MegaBuildGui")
        if targetGui then targetGui.Enabled = _G.BuildSettings.Visible end
    elseif input.KeyCode == Enum.KeyCode.R and not UserInputService:GetFocusedTextBox() then
        if _G.BuildSettings.BuildMode and _G.BuildSettings.Visible then
            _G.BuildSettings.Rotation = (_G.BuildSettings.Rotation + 90) % 360
        end
    end
end)

-- Слушаем экипировку предметов других игроков (Синхронизация по сети)
local function watchPlayer(p)
    p.CharacterAdded:Connect(function(char)
        char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                local pos, size, color, shape, rot, packetId = parseDataString(child.Name)
                if pos and not _G.ProcessedPackets[packetId] then
                    _G.ProcessedPackets[packetId] = true
                    _G.CreateLocalPartGlobal(pos, size, color, shape, rot, true)
                    task.delay(4, function() _G.ProcessedPackets[packetId] = nil end)
                end
            end
        end)
    end)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, p in pairs(Players:GetPlayers()) do if p ~= LocalPlayer then watchPlayer(p) end end
-- [[ ОКНО 5: ГРАФИЧЕСКИЙ ИНТЕРФЕЙС ]] --
local CoreGui = game:GetService("CoreGui")
if CoreGui:FindFirstChild("MegaBuildGui") then CoreGui.MegaBuildGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MegaBuildGui"; ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 400, 0, 460); MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24); MainFrame.Active = true; MainFrame.Draggable = true; MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 45); Title.Text = "📐 MonsterHub (bugs fixed)"; Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundTransparency = 1; Title.Font = Enum.Font.SourceSansBold; Title.TextSize = 14; Title.Parent = MainFrame

local ToggleBuildBtn = Instance.new("TextButton")
ToggleBuildBtn.Size = UDim2.new(0, 175, 0, 35); ToggleBuildBtn.Position = UDim2.new(0, 20, 0, 45)
ToggleBuildBtn.BackgroundColor3 = Color3.fromRGB(192, 57, 43); ToggleBuildBtn.Text = "🚫 СТРОЙКА: ВЫКЛ"
ToggleBuildBtn.TextColor3 = Color3.fromRGB(255, 255, 255); ToggleBuildBtn.Font = Enum.Font.SourceSansBold; ToggleBuildBtn.TextSize = 11; ToggleBuildBtn.Parent = MainFrame
Instance.new("UICorner", ToggleBuildBtn).CornerRadius = UDim.new(0, 6)

local DeleteModeBtn = Instance.new("TextButton")
DeleteModeBtn.Size = UDim2.new(0, 175, 0, 35); DeleteModeBtn.Position = UDim2.new(0, 205, 0, 45)
DeleteModeBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 54); DeleteModeBtn.Text = "⛏ РЕЖИМ КИРКИ: ВЫКЛ"
DeleteModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); DeleteModeBtn.Font = Enum.Font.SourceSansBold; DeleteModeBtn.TextSize = 10; DeleteModeBtn.Parent = MainFrame
Instance.new("UICorner", DeleteModeBtn).CornerRadius = UDim.new(0, 6)

DeleteModeBtn.MouseButton1Click:Connect(function()
    _G.BuildSettings.DeleteMode = not _G.BuildSettings.DeleteMode
    if _G.BuildSettings.DeleteMode then
        _G.BuildSettings.BuildMode = false
        ToggleBuildBtn.Text = "🚫 СТРОЙКА: ВЫКЛ"; ToggleBuildBtn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
        DeleteModeBtn.Text = "⛏ КИРКА: КЛИКНИ НА БЛОК"; DeleteModeBtn.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
    else
        DeleteModeBtn.Text = "⛏ РЕЖИМ КИРКИ: ВЫКЛ"; DeleteModeBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 54)
    end
end)

ToggleBuildBtn.MouseButton1Click:Connect(function()
    _G.BuildSettings.BuildMode = not _G.BuildSettings.BuildMode
    if _G.BuildSettings.BuildMode then
        _G.BuildSettings.DeleteMode = false
        DeleteModeBtn.Text = "⛏ РЕЖИМ КИРКИ: ВЫКЛ"; DeleteModeBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 54)
        ToggleBuildBtn.Text = "🔨 СТРОЙКА: ВКЛ"; ToggleBuildBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        if _G.UpdatePreviewShapeGlobal then _G.UpdatePreviewShapeGlobal() end
    else
        ToggleBuildBtn.Text = "🚫 СТРОЙКА: ВЫКЛ"; ToggleBuildBtn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
    end
end)

local ShapeTitle = Instance.new("TextLabel")
ShapeTitle.Size = UDim2.new(0, 150, 0, 20); ShapeTitle.Position = UDim2.new(0, 20, 0, 95); ShapeTitle.Text = "ГЕОМЕТРИЧЕСКАЯ ФОРМА:"
ShapeTitle.TextColor3 = Color3.fromRGB(160, 160, 160); ShapeTitle.BackgroundTransparency = 1; ShapeTitle.Font = Enum.Font.SourceSansBold; ShapeTitle.TextSize = 11; ShapeTitle.TextXAlignment = Enum.TextXAlignment.Left; ShapeTitle.Parent = MainFrame

local Shapes = {{Name = "Куб", Type = "Block"}, {Name = "Шар", Type = "Ball"}, {Name = "Цилиндр", Type = "Cylinder"}, {Name = "Крыша", Type = "Wedge"}, {Name = "Окно", Type = "Window"}}
for i, shp in ipairs(Shapes) do
    local ShpBtn = Instance.new("TextButton")
    ShpBtn.Size = UDim2.new(0, 66, 0, 28); ShpBtn.Position = UDim2.new(0, 20 + (i - 1) * 72, 0, 120); ShpBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    ShpBtn.Text = shp.Name; ShpBtn.TextColor3 = Color3.fromRGB(255, 255, 255); ShpBtn.Font = Enum.Font.SourceSansBold; ShpBtn.TextSize = 11; ShpBtn.Parent = MainFrame
    Instance.new("UICorner", ShpBtn).CornerRadius = UDim.new(0, 5)
    ShpBtn.MouseButton1Click:Connect(function() _G.BuildSettings.Shape = shp.Type; if _G.UpdatePreviewShapeGlobal then _G.UpdatePreviewShapeGlobal() end end)
end

local PresetTitle = Instance.new("TextLabel")
PresetTitle.Size = UDim2.new(0, 200, 0, 20); PresetTitle.Position = UDim2.new(0, 20, 0, 160); PresetTitle.Text = "БЫСТРЫЕ ШАБЛОНЫ РАЗМЕРОВ:"
PresetTitle.TextColor3 = Color3.fromRGB(160, 160, 160); PresetTitle.BackgroundTransparency = 1; PresetTitle.Font = Enum.Font.SourceSansBold; PresetTitle.TextSize = 11; PresetTitle.TextXAlignment = Enum.TextXAlignment.Left; PresetTitle.Parent = MainFrame

local Presets = {{Name = "🧱 СТЕНА (12x7x1)", Size = Vector3.new(12, 7, 1)}, {Name = "🗺 ПОЛ (16x1x16)", Size = Vector3.new(16, 1, 16)}, {Name = "📦 КУБИК (4x4x4)", Size = Vector3.new(4, 4, 4)}}
for i, prst in ipairs(Presets) do
    local PrstBtn = Instance.new("TextButton")
    PrstBtn.Size = UDim2.new(0, 112, 0, 28); PrstBtn.Position = UDim2.new(0, 20 + (i - 1) * 120, 0, 185); PrstBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 54)
    PrstBtn.Text = prst.Name; PrstBtn.TextColor3 = Color3.fromRGB(255, 255, 255); PrstBtn.Font = Enum.Font.SourceSansBold; PrstBtn.TextSize = 10; PrstBtn.Parent = MainFrame
    Instance.new("UICorner", PrstBtn).CornerRadius = UDim.new(0, 5)
    PrstBtn.MouseButton1Click:Connect(function() _G.BuildSettings.Size = prst.Size; if _G.UpdatePreviewShapeGlobal then _G.UpdatePreviewShapeGlobal() end end)
end

local RotBtn = Instance.new("TextButton")
RotBtn.Size = UDim2.new(1, -40, 0, 30); RotBtn.Position = UDim2.new(0, 20, 0, 225); RotBtn.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
RotBtn.Text = "🔄 ПОВЕРНУТЬ МАКЕТ НА 90° [КЛАВИША R]"; RotBtn.TextColor3 = Color3.fromRGB(255, 255, 255); RotBtn.Font = Enum.Font.SourceSansBold; RotBtn.TextSize = 12; RotBtn.Parent = MainFrame
Instance.new("UICorner", RotBtn).CornerRadius = UDim.new(0, 6)
RotBtn.MouseButton1Click:Connect(function() _G.BuildSettings.Rotation = (_G.BuildSettings.Rotation + 90) % 360 end)

local SliderTitle = Instance.new("TextLabel")
SliderTitle.Size = UDim2.new(1, -40, 0, 20); SliderTitle.Position = UDim2.new(0, 20, 0, 265)
SliderTitle.Text = "МАСШТАБ ДЛИНЫ И ШИРИНЫ: 4"; SliderTitle.TextColor3 = Color3.fromRGB(160, 160, 160)
SliderTitle.BackgroundTransparency = 1; SliderTitle.Font = Enum.Font.SourceSansBold; SliderTitle.TextSize = 11; SliderTitle.TextXAlignment = Enum.TextXAlignment.Left; SliderTitle.Parent = MainFrame

local SliderTrack = Instance.new("Frame")
SliderTrack.Size = UDim2.new(1, -40, 0, 6); SliderTrack.Position = UDim2.new(0, 20, 0, 295); SliderTrack.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
SliderTrack.BorderSizePixel = 0; SliderTrack.Parent = MainFrame; Instance.new("UICorner", SliderTrack)

local SliderButton = Instance.new("TextButton")
SliderButton.Size = UDim2.new(0, 18, 0, 18); SliderButton.Position = UDim2.new(0, 0, 0.5, -9); SliderButton.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
SliderButton.Text = ""; SliderButton.Parent = SliderTrack; Instance.new("UICorner", SliderButton).CornerRadius = UDim.new(1, 0)

local isDragging = false
local function updateSlider(input)
    local percentage = math.clamp((input.Position.X - SliderTrack.AbsolutePosition.X) / SliderTrack.AbsoluteSize.X, 0, 1)
    local val = math.round(1 + (percentage * 499))
    SliderButton.Position = UDim2.new(percentage, -9, 0.5, -9); SliderTitle.Text = "МАСШТАБ ДЛИНЫ И ШИРИНЫ: " .. tostring(val)
    
    local oldY = _G.BuildSettings.Size.Y
    if oldY == 1 and _G.BuildSettings.Shape == "Block" then
        _G.BuildSettings.Size = Vector3.new(val, 1, val)
    elseif _G.BuildSettings.Size.Z == 1 and _G.BuildSettings.Shape == "Block" then
        _G.BuildSettings.Size = Vector3.new(val, val, 1)
    else
        _G.BuildSettings.Size = Vector3.new(val, val, val)
    end
end
SliderButton.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = true end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end end)
UserInputService.InputChanged:Connect(function(input) if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then updateSlider(input) end end)

local ColorTitle = Instance.new("TextLabel")
ColorTitle.Size = UDim2.new(1, -40, 0, 20); ColorTitle.Position = UDim2.new(0, 20, 0, 320); ColorTitle.Text = "ВЫБЕРИТЕ ЦВЕТ ОБЪЕКТА:"
ColorTitle.TextColor3 = Color3.fromRGB(160, 160, 160); ColorTitle.BackgroundTransparency = 1; ColorTitle.Font = Enum.Font.SourceSansBold; ColorTitle.TextSize = 11; ColorTitle.TextXAlignment = Enum.TextXAlignment.Left; ColorTitle.Parent = MainFrame

local ColorPalette = {Color3.fromRGB(231, 76, 60), Color3.fromRGB(211, 47, 47), Color3.fromRGB(230, 126, 34), Color3.fromRGB(241, 196, 15), Color3.fromRGB(46, 204, 113), Color3.fromRGB(39, 174, 96), Color3.fromRGB(52, 152, 219), Color3.fromRGB(41, 128, 185), Color3.fromRGB(155, 89, 182), Color3.fromRGB(232, 67, 147), Color3.fromRGB(255, 255, 255), Color3.fromRGB(45, 52, 54)}
for i, color in ipairs(ColorPalette) do
    local ColorBtn = Instance.new("TextButton")
    ColorBtn.Size = UDim2.new(0, 48, 0, 40)
    local row = math.ceil(i / 6); local col = (i - 1) % 6 + 1; ColorBtn.Position = UDim2.new(0, 20 + (col - 1) * 58, 0, 350 + (row - 1) * 48); ColorBtn.BackgroundColor3 = color; ColorBtn.Text = ""; ColorBtn.Parent = MainFrame
    Instance.new("UICorner", ColorBtn).CornerRadius = UDim.new(0, 8)
    local Stroke = Instance.new("UIStroke"); Stroke.Color = Color3.fromRGB(60, 60, 65); Stroke.Thickness = 1; Stroke.Parent = ColorBtn
    ColorBtn.MouseButton1Click:Connect(function() _G.BuildSettings.Color = color end)
end
