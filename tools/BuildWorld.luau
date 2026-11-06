-- Gera o bairro base (chão, ruas, calçadas, 6 lotes, áreas públicas). Rodar no modo Edit via MCP.
-- Idempotente: apaga Workspace.Map e Workspace.Plots antes de recriar.
local Lighting = game:GetService("Lighting")

for _, n in ipairs({ "Map", "Plots", "PublicAreas" }) do
	local old = workspace:FindFirstChild(n)
	if old then old:Destroy() end
end

local function mk(parent, name, size, pos, color, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position = name, size, pos
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Iluminação
Lighting.ClockTime = 15.5
Lighting.Brightness = 2.2
Lighting.GeographicLatitude = 20
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0.6
Lighting.ShadowSoftness = 0.25
Lighting.ExposureCompensation = 0
Lighting.Ambient = Color3.fromRGB(150, 155, 165)
Lighting.OutdoorAmbient = Color3.fromRGB(165, 170, 180)
for _, c in ipairs(Lighting:GetChildren()) do
	if c:IsA("Atmosphere") or c:IsA("BloomEffect") or c:IsA("ColorCorrectionEffect") or c:IsA("SunRaysEffect") then c:Destroy() end
end
local atm = Instance.new("Atmosphere"); atm.Density = 0.25; atm.Haze = 1.2; atm.Color = Color3.fromRGB(199, 214, 235); atm.Parent = Lighting
local bloom = Instance.new("BloomEffect"); bloom.Intensity = 0.25; bloom.Threshold = 1.6; bloom.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect"); cc.Saturation = 0.08; cc.Contrast = 0.06; cc.Parent = Lighting
local sun = Instance.new("SunRaysEffect"); sun.Intensity = 0.06; sun.Parent = Lighting

local map = Instance.new("Folder"); map.Name = "Map"; map.Parent = workspace
local plots = Instance.new("Folder"); plots.Name = "Plots"; plots.Parent = workspace
local pub = Instance.new("Folder"); pub.Name = "PublicAreas"; pub.Parent = workspace

local ASPHALT = Color3.fromRGB(52, 54, 58)
local SIDEWALK = Color3.fromRGB(160, 160, 155)
local GROUND = Color3.fromRGB(88, 96, 82)

mk(map, "Ground", Vector3.new(900, 2, 700), Vector3.new(0, -1, 0), GROUND, Enum.Material.Grass)
-- Rua principal (eixo X) e secundária (eixo Z em x=220)
mk(map, "MainRoad", Vector3.new(700, 0.4, 40), Vector3.new(0, 0.2, 0), ASPHALT, Enum.Material.Asphalt)
mk(map, "SideRoad", Vector3.new(40, 0.4, 300), Vector3.new(220, 0.2, 130), ASPHALT, Enum.Material.Asphalt)
for x = -330, 330, 24 do
	mk(map, "LaneLine", Vector3.new(10, 0.1, 0.8), Vector3.new(x, 0.45, 0), Color3.fromRGB(230, 200, 60), Enum.Material.SmoothPlastic)
end
-- Calçadas
for _, side in ipairs({ -1, 1 }) do
	mk(map, "Sidewalk", Vector3.new(700, 0.8, 8), Vector3.new(0, 0.4, side * 24), SIDEWALK)
end
mk(map, "SidewalkSide", Vector3.new(8, 0.8, 300), Vector3.new(188, 0.4, 130), SIDEWALK)
mk(map, "SidewalkSide", Vector3.new(8, 0.8, 300), Vector3.new(252, 0.4, 130), SIDEWALK)

-- Seis lotes (3 ao norte, 3 ao sul). Lote 90x90 com folga de expansão para o fundo.
local PLOT = 90
local slots = {}
for i, x in ipairs({ -200, -100, 0 }) do
	table.insert(slots, { x = x, side = -1 })
	table.insert(slots, { x = x, side = 1 })
end
for idx, s in ipairs(slots) do
	local folder = Instance.new("Folder"); folder.Name = "Plot" .. idx; folder.Parent = plots
	folder:SetAttribute("PlotId", idx)
	folder:SetAttribute("OwnerUserId", 0)
	folder:SetAttribute("Side", s.side)
	local cz = s.side * (28 + PLOT / 2)
	local base = mk(folder, "Base", Vector3.new(PLOT, 0.8, PLOT), Vector3.new(s.x, 0.4, cz), Color3.fromRGB(120, 120, 118))
	-- Entrada (voltada para a rua)
	local entry = mk(folder, "Entry", Vector3.new(14, 0.2, 6), Vector3.new(s.x, 0.9, s.side * 32), Color3.fromRGB(255, 190, 60), Enum.Material.Neon)
	entry.CanCollide = false
	-- Vagas de serviço (2 iniciais) e terreno de expansão (fundo do lote)
	for b = 1, 2 do
		local bay = mk(folder, "Bay" .. b, Vector3.new(16, 0.2, 26), Vector3.new(s.x - 20 + (b - 1) * 40, 0.9, s.side * 56), Color3.fromRGB(70, 130, 200), Enum.Material.SmoothPlastic)
		bay.CanCollide = false
		bay:SetAttribute("BayIndex", b)
	end
	local exp = mk(folder, "ExpansionZone", Vector3.new(PLOT - 4, 0.2, 28), Vector3.new(s.x, 0.9, s.side * 104), Color3.fromRGB(95, 95, 95))
	exp.CanCollide = false; exp.Transparency = 0.6
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"; spawn.Anchored = true; spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.Position = Vector3.new(s.x + 30, 1, s.side * 34); spawn.Enabled = false
	spawn.Transparency = 1; spawn.CanCollide = false; spawn.Parent = folder
	-- Placa
	local sign = mk(folder, "Sign", Vector3.new(14, 4, 0.6), Vector3.new(s.x, 4, s.side * 32.5), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
	local gui = Instance.new("SurfaceGui"); gui.Face = s.side == -1 and Enum.NormalId.Front or Enum.NormalId.Back; gui.Parent = sign
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1
	lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = Color3.fromRGB(255, 190, 60)
	lbl.Text = "LOTE " .. idx .. " - LIVRE"; lbl.Name = "Label"; lbl.Parent = gui
	base.Name = "Base"
end

-- Áreas públicas (blocos simples até os modelos serem importados)
local function building(name, size, pos, color)
	local b = mk(pub, name, size, pos, color, Enum.Material.Concrete)
	b.Position = pos + Vector3.new(0, size.Y / 2, 0)
	return b
end
building("LojaAutopecas", Vector3.new(50, 14, 40), Vector3.new(130, 0, -80), Color3.fromRGB(180, 70, 60))
building("DistribuidoraEquipamentos", Vector3.new(60, 18, 50), Vector3.new(300, 0, 120), Color3.fromRGB(110, 120, 135))
mk(pub, "EstacionamentoPublico", Vector3.new(70, 0.2, 50), Vector3.new(130, 0.9, 80), Color3.fromRGB(60, 62, 66), Enum.Material.Asphalt)
return "Bairro criado: " .. #plots:GetChildren() .. " lotes"
