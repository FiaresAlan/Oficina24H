--!strict
-- V2-03: cofre do motor com peças específicas visíveis ao abrir o capô.
-- O cliente nunca cria/remova estoque, defeitos, valores ou flags de reparo.
-- Substituir proxies por BaseParts com V2EngineBayRole nas malhas importadas.
local RunService = game:GetService("RunService")

type Component = { Part: BasePart, Offset: CFrame }
type Tracked = { Root: BasePart, Parts: { Component }, Generated: { Instance } }
local cars: { [Model]: Tracked } = {}
local MAX_DISTANCE = 142

local specs = {
    { Role = "EngineBlock", Size = Vector3.new(2.6, 0.85, 2.6),
        Color = Color3.fromRGB(79, 87, 96), Material = Enum.Material.Metal,
        X = 0, Y = 0.77, Z = -0.28 },
    { Role = "Battery", Size = Vector3.new(1.45, 0.88, 1.26),
        Color = Color3.fromRGB(40, 46, 56), Material = Enum.Material.SmoothPlastic,
        X = -0.25, Y = 0.79, Z = -0.40 },
    { Role = "Coolant", Size = Vector3.new(0.85, 0.83, 1.10),
        Color = Color3.fromRGB(177, 188, 196), Material = Enum.Material.Glass,
        X = 0.25, Y = 0.80, Z = -0.41 },
    { Role = "Intake", Size = Vector3.new(1.0, 0.35, 1.65),
        Color = Color3.fromRGB(37, 43, 47), Material = Enum.Material.SmoothPlastic,
        X = 0.08, Y = 0.94, Z = -0.18 },
    { Role = "Alternator", Size = Vector3.new(0.84, 0.84, 0.84),
        Color = Color3.fromRGB(118, 128, 136), Material = Enum.Material.Metal,
        X = 0.22, Y = 0.86, Z = -0.33 },
}

local function dimension(car: Model, name: string, fallback: number, lo: number, hi: number): number
    local v = car:GetAttribute(name)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return fallback end
    return math.clamp(v, lo, hi)
end

local function nativeRoles(car: Model): { [string]: boolean }
    local tagged: { [string]: boolean } = {}
    for _, d in ipairs(car:GetDescendants()) do
        if d:IsA("BasePart") then
            local role = d:GetAttribute("V2EngineBayRole")
            if type(role) == "string" then tagged[role] = true end
        end
    end
    return tagged
end

local function setup(car: Model)
    if cars[car] or type(car:GetAttribute("V2PilotId")) ~= "string" then return end
    local root = car.PrimaryPart
    if not root or root.Name ~= "Raiz" then return end
    local L = dimension(car, "Comprimento", 18, 8, 32)
    local W = dimension(car, "Largura", 8, 4, 14)
    local H = dimension(car, "Altura", 5, 2, 9)
    local existing = nativeRoles(car)
    local created: { Instance } = {}
    local components: { Component } = {}
    for _, spec in ipairs(specs) do
        if existing[spec.Role] then continue end
        local part = Instance.new("Part")
        part.Name = "V2EngineProxy_" .. spec.Role
        part.Size = spec.Size
        part.Anchored = true
        part.Massless = true
        part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
        part.Material = spec.Material
        part.Color = spec.Color
        part.CastShadow = false
        part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        -- Peças no compartimento do motor: offsets parametrizados pela escala real do carro.
        local localOffset = CFrame.new(spec.X * W, spec.Y * H, spec.Z * L)
        part.CFrame = root.CFrame * localOffset
        part.Transparency = 1
        part:SetAttribute("V2GeneratedVisual", true)
        part:SetAttribute("V2EngineBayRole", spec.Role)
        part.Parent = car
        table.insert(created, part)
        table.insert(components, { Part = part, Offset = localOffset })
    end
    cars[car] = { Root = root, Parts = components, Generated = created }
end

local function hook(folder: Instance)
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") then task.defer(setup, child) end
    end
    folder.ChildAdded:Connect(function(child)
        if child:IsA("Model") then task.defer(setup, child) end
    end)
end
local f = workspace:FindFirstChild("Vehicles")
if f then hook(f) end
workspace.ChildAdded:Connect(function(inst)
    if inst.Name == "Vehicles" then hook(inst) end
end)

local clock = 0
RunService.Heartbeat:Connect(function(dt: number)
    clock += dt
    if clock < 0.08 then return end
    clock = 0
    local camera = workspace.CurrentCamera
    if not camera then return end
    for car, entry in pairs(cars) do
        if not car.Parent or not entry.Root.Parent then
            for _, inst in ipairs(entry.Generated) do inst:Destroy() end
            cars[car] = nil
            continue
        end
        local visible = car:GetAttribute("Estacionado") == true
            and car:GetAttribute("V2State_Hood") == "Open"
            and (camera.CFrame.Position - entry.Root.Position).Magnitude <= MAX_DISTANCE
        for _, component in ipairs(entry.Parts) do
            if component.Part.Parent then
                if visible then component.Part.CFrame = entry.Root.CFrame * component.Offset end
                component.Part.Transparency = visible and 0 or 1
            end
        end
    end
end)
