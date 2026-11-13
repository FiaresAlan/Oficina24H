--!strict
-- V2-03: portas e porta-malas dos três carros piloto.
-- Estados e permissões vêm EXCLUSIVAMENTE do servidor (V2State_*).
-- No Studio, marque a malha separada com V2MovingComponent=DoorLeft/DoorRight/Trunk.
-- Caso o asset GLB ainda seja monobloco, usa painel visual cliente não colidível.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Debris = game:GetService("Debris")

local PilotRules = require(ReplicatedStorage.Shared.V2VehiclePilotRules)
local Colors = require(ReplicatedStorage.Shared.V2PilotArtProfiles)
local SoundIds = require(ReplicatedStorage.Shared.SoundIds)

type Assembly = {
    Id: string, Parts: { BasePart }, Relative: { CFrame }, Hinge: Vector3,
    Angle: CFrame, Alpha: number,
}
type Tracked = {
    Root: BasePart, Groups: { Assembly }, Generated: { Instance },
    LastStates: { [string]: string },
}
local tracked: { [Model]: Tracked } = {}
local MAX_DISTANCE = 185

local function sizeOf(model: Model, name: string, fallback: number, minimum: number, maximum: number): number
    local v = model:GetAttribute(name)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return fallback end
    return math.clamp(v, minimum, maximum)
end

local function proxy(car: Model, id: string, size: Vector3, frame: CFrame, color: Color3): Part
    local p = Instance.new("Part")
    p.Name = "V2ArticulationProxy_" .. id
    p.Size = size
    p.Anchored = true
    p.Massless = true
    p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
    p.Color = color
    p.Material = Enum.Material.Metal
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.CastShadow = false
    p.CFrame = frame
    p:SetAttribute("V2GeneratedVisual", true)
    p.Parent = car
    return p
end

local function detachOnClient(root: BasePart, part: BasePart)
    -- Nunca destrói a junta do servidor: alterações locais de apresentação.
    local model = root:FindFirstAncestorWhichIsA("Model")
    if model then
        for _, joint in ipairs(model:GetDescendants()) do
            local attached = false
            if joint:IsA("WeldConstraint") or joint:IsA("Weld") or joint:IsA("Motor6D") then
                attached = joint.Part0 == part or joint.Part1 == part
            elseif joint:IsA("RigidConstraint") then
                local a0, a1 = joint.Attachment0, joint.Attachment1
                attached = (a0 ~= nil and a0:IsDescendantOf(part))
                    or (a1 ~= nil and a1:IsDescendantOf(part))
            end
            if attached then
                joint:Destroy() -- desconecta esta peça somente na simulação do cliente
            end
        end
    end
    part.Anchored = true
    part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
end

local function setup(car: Model)
    if tracked[car] or type(car:GetAttribute("V2PilotId")) ~= "string" then return end
    local root = car.PrimaryPart
    if not root or root.Name ~= "Raiz" then return end
    local L = sizeOf(car, "Comprimento", 18, 8, 32)
    local W = sizeOf(car, "Largura", 8, 4, 14)
    local H = sizeOf(car, "Altura", 5, 2, 9)
    local colors = Colors.Styles[car:GetAttribute("V2PilotId")]
    local color = colors and colors.Paint or Color3.fromRGB(95, 110, 125)
    local groups: { Assembly } = {}
    local generated: { Instance } = {}
    local states: { [string]: string } = {}
    for _, id in ipairs({ "DoorLeft", "DoorRight", "Trunk" }) do
        local pivot = PilotRules.Resolve(car, "V2Pivot_" .. id)
        if not pivot then continue end
        local native: { BasePart } = {}
        for _, child in ipairs(car:GetDescendants()) do
            if child:IsA("BasePart") and child ~= root
                and child:GetAttribute("V2MovingComponent") == id
                and not child:GetAttribute("V2GeneratedVisual") then
                local owner = child:FindFirstAncestorWhichIsA("Model")
                if owner == car or (owner and not owner:FindFirstChildOfClass("Humanoid")) then
                    table.insert(native, child)
                end
            end
        end
        local side = id == "DoorLeft" and -1 or 1
        if #native == 0 then
            local center = id == "Trunk" and Vector3.new(0, H * 0.74, L * 0.34)
                or Vector3.new(side * W * 0.51, H * 0.51, -L * 0.03)
            local dimensions = id == "Trunk" and Vector3.new(W * 0.7, 0.13, L * 0.23)
                or Vector3.new(0.13, H * 0.56, L * 0.31)
            local placeholder = proxy(car, id, dimensions, root.CFrame * CFrame.new(center), color)
            table.insert(native, placeholder)
            table.insert(generated, placeholder)
        else
            for _, part in ipairs(native) do detachOnClient(root, part) end
        end
        local hinge = root.CFrame:PointToObjectSpace(pivot.Position)
        local attachment = car:FindFirstChild("V2Pivot_" .. id, true)
        if attachment and attachment:GetAttribute("V2Generated") == true then
            -- pivô automático = centro: levar à borda dianteira do painel.
            hinge += Vector3.new(0, 0, -(id == "Trunk" and L * 0.10 or L * 0.16))
        end
        local relative: { CFrame } = {}
        for _, part in ipairs(native) do
            table.insert(relative, CFrame.new(hinge):ToObjectSpace(root.CFrame:ToObjectSpace(part.CFrame)))
        end
        table.insert(groups, {
            Id = id, Parts = native, Relative = relative, Hinge = hinge,
            Angle = id == "DoorLeft" and CFrame.Angles(0, -math.rad(70), 0)
                or id == "DoorRight" and CFrame.Angles(0, math.rad(70), 0)
                or CFrame.Angles(-math.rad(58), 0, 0),
            Alpha = 0,
        })
        states[id] = tostring(car:GetAttribute("V2State_" .. id) or "Closed")
    end
    tracked[car] = { Root = root, Groups = groups, Generated = generated, LastStates = states }
end

local function watch(folderName: string)
    local function hook(folder: Instance)
        for _, item in ipairs(folder:GetChildren()) do
            if item:IsA("Model") then task.defer(setup, item) end
        end
        folder.ChildAdded:Connect(function(item)
            if item:IsA("Model") then task.defer(setup, item) end
        end)
    end
    local existing = workspace:FindFirstChild(folderName)
    if existing then hook(existing) end
    workspace.ChildAdded:Connect(function(c)
        if c.Name == folderName then hook(c) end
    end)
end
watch("Vehicles")

local elapsed = 0
RunService.RenderStepped:Connect(function(dt: number)
    elapsed += dt
    if elapsed < 1 / 30 then return end
    local step = elapsed
    elapsed = 0
    local cam = workspace.CurrentCamera
    if not cam then return end
    for car, entry in pairs(tracked) do
        if not car.Parent or not entry.Root.Parent then
            for _, p in ipairs(entry.Generated) do p:Destroy() end
            tracked[car] = nil
            continue
        end
        local distance = (cam.CFrame.Position - entry.Root.Position).Magnitude
        local far = distance > MAX_DISTANCE or GuiService.ReducedMotionEnabled
        local parked = car:GetAttribute("Estacionado") == true
        for _, group in ipairs(entry.Groups) do
            local state = tostring(car:GetAttribute("V2State_" .. group.Id) or "Closed")
            local open = parked and state == "Open"
            local desired = open and 1 or 0
            if distance <= MAX_DISTANCE and state ~= entry.LastStates[group.Id] and parked then
                local s = Instance.new("Sound")
                s.SoundId = SoundIds.Ratchet
                s.Volume = 0.18
                s.RollOffMaxDistance = 50
                s.Parent = entry.Root
                s:Play()
                Debris:AddItem(s, 4)
            end
            entry.LastStates[group.Id] = state
            group.Alpha = far and desired or group.Alpha +
                (desired - group.Alpha) * math.min(1, step * 7)
            local rotated = CFrame.identity:Lerp(group.Angle, group.Alpha)
            local frame = entry.Root.CFrame * CFrame.new(group.Hinge) * rotated
            for i, part in ipairs(group.Parts) do
                if part.Parent then part.CFrame = frame * group.Relative[i] end
            end
        end
    end
end)
