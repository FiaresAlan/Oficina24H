-- Constrói a Praça Central (Workspace.Bairro.Praca): piso, chafariz, canteiros com árvores, bancos, postes e o
-- painel "Melhores oficinas do servidor" (SurfaceGui "Ranking", atualizado pelo servidor em Main.server.lua).
-- Leve para celular: ~60 peças simples, 4 luzes sem sombra, 1 emissor de partículas. Rodar no modo Edit (via MCP).
local Assets = game:GetService("ServerStorage"):WaitForChild("Assets")
local bairro = workspace:WaitForChild("Bairro")

local old = bairro:FindFirstChild("Praca")
if old then
	old:Destroy()
end
-- o conjunto antigo (props soltos na grama) sai; um igual vira enfeite num canto da praça
for _, m in ipairs(bairro.Rua:GetChildren()) do
	if m.Name == "Rua_Praca" and (m:GetPivot().Position - Vector3.new(-430, 0, -110)).Magnitude < 20 then
		m:Destroy()
	end
end

local praca = Instance.new("Model")
praca.Name = "Praca"

local CENTER = Vector3.new(-410, 0, -125)
local GROUND = 0 -- topo do chão do mapa
local root = CFrame.new(CENTER.X, GROUND, CENTER.Z)

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = praca
	return p
end

local PAVE = Color3.fromRGB(214, 206, 192)
local PAVE_DARK = Color3.fromRGB(150, 140, 128)
local STONE = Color3.fromRGB(190, 190, 196)
local GRASS = Color3.fromRGB(96, 158, 72)
local WOOD = Color3.fromRGB(122, 84, 52)
local LEAF = Color3.fromRGB(70, 140, 60)
local WATER = Color3.fromRGB(80, 170, 230)

-- Piso e borda
part("Piso", Vector3.new(60, 0.4, 50), root * CFrame.new(0, 0.2, 0), PAVE, Enum.Material.Pavement)
part("Faixa", Vector3.new(60, 0.42, 4), root * CFrame.new(0, 0.21, 0), PAVE_DARK, Enum.Material.Pavement)
part("Faixa", Vector3.new(4, 0.42, 50), root * CFrame.new(0, 0.21, 0), PAVE_DARK, Enum.Material.Pavement)
-- Caminho até a calçada da rua principal (x = -430, de z = -32 até a praça)
part("Caminho", Vector3.new(8, 0.4, 68), CFrame.new(-430, GROUND + 0.2, -66), PAVE, Enum.Material.Pavement)

-- Chafariz central
part("ChafarizBase", Vector3.new(1.6, 18, 18), root * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), STONE, Enum.Material.Slate, Enum.PartType.Cylinder)
local water = part("ChafarizAgua", Vector3.new(0.2, 15.6, 15.6), root * CFrame.new(0, 1.55, 0) * CFrame.Angles(0, 0, math.rad(90)), WATER, Enum.Material.Glass, Enum.PartType.Cylinder)
water.Transparency = 0.25
water.Reflectance = 0.2
water.CanCollide = false
part("ChafarizColuna", Vector3.new(5, 2.2, 2.2), root * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)), STONE, Enum.Material.Slate, Enum.PartType.Cylinder)
part("ChafarizTaca", Vector3.new(0.8, 7, 7), root * CFrame.new(0, 6.2, 0) * CFrame.Angles(0, 0, math.rad(90)), STONE, Enum.Material.Slate, Enum.PartType.Cylinder)
local spout = part("ChafarizBico", Vector3.new(1, 1, 1), root * CFrame.new(0, 6.8, 0), WATER, Enum.Material.Glass)
spout.Transparency = 1
spout.CanCollide = false
local spray = Instance.new("ParticleEmitter")
spray.Name = "Jato"
spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
spray.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
spray.LightEmission = 0.4
spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.2) })
spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
spray.Lifetime = NumberRange.new(1, 1.4)
spray.Rate = 30
spray.Speed = NumberRange.new(9, 12)
spray.SpreadAngle = Vector2.new(14, 14)
spray.Acceleration = Vector3.new(0, -26, 0)
spray.EmissionDirection = Enum.NormalId.Top
spray.Parent = spout

-- Canteiros com árvore nos quatro cantos
local function tree(x: number, z: number)
	part("Canteiro", Vector3.new(11, 0.9, 11), root * CFrame.new(x, 0.45, z), STONE, Enum.Material.Slate)
	part("Grama", Vector3.new(10, 0.95, 10), root * CFrame.new(x, 0.5, z), GRASS, Enum.Material.Grass)
	part("Tronco", Vector3.new(7, 1.4, 1.4), root * CFrame.new(x, 4.4, z) * CFrame.Angles(0, 0, math.rad(90)), WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	local crown = part("Copa", Vector3.new(9, 9, 9), root * CFrame.new(x, 10, z), LEAF, Enum.Material.Grass, Enum.PartType.Ball)
	crown.CanCollide = false
	local crown2 = part("Copa", Vector3.new(6, 6, 6), root * CFrame.new(x + 2, 12.5, z - 1.5), LEAF:Lerp(Color3.new(1, 1, 0.6), 0.12), Enum.Material.Grass, Enum.PartType.Ball)
	crown2.CanCollide = false
end
tree(-22, -17)
tree(22, -17)
tree(-22, 17)
tree(22, 17)

-- Bancos de frente para o chafariz
local function bench(x: number, z: number, yawDeg: number)
	local cf = root * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	part("BancoAssento", Vector3.new(7, 0.4, 2), cf * CFrame.new(0, 1.6, 0), WOOD, Enum.Material.Wood)
	part("BancoEncosto", Vector3.new(7, 1.6, 0.35), cf * CFrame.new(0, 2.6, 1), WOOD, Enum.Material.Wood)
	part("BancoPe", Vector3.new(0.4, 1.4, 1.8), cf * CFrame.new(-3, 0.9, 0), PAVE_DARK, Enum.Material.Metal)
	part("BancoPe", Vector3.new(0.4, 1.4, 1.8), cf * CFrame.new(3, 0.9, 0), PAVE_DARK, Enum.Material.Metal)
end
bench(0, -13, 0)
bench(0, 13, 180)
bench(-14, 0, 90) -- o lado leste fica com o conjunto de praça do pacote (que já tem banco)

-- Postes com luz quente (sem sombra: leve no celular)
local function lamp(x: number, z: number)
	part("PostePe", Vector3.new(9, 0.5, 0.5), root * CFrame.new(x, 4.5, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 44, 52), Enum.Material.Metal, Enum.PartType.Cylinder)
	local bulb = part("PosteLuz", Vector3.new(1.4, 1.4, 1.4), root * CFrame.new(x, 9.4, z), Color3.fromRGB(255, 220, 150), Enum.Material.Neon, Enum.PartType.Ball)
	bulb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.4
	light.Color = Color3.fromRGB(255, 214, 160)
	light.Shadows = false
	light.Parent = bulb
end
lamp(-12, -22)
lamp(12, -22)
lamp(-12, 22)
lamp(12, 22)

-- Painel "Melhores oficinas do servidor" (o servidor escreve no TextLabel "Lista")
local board = part("PainelRanking", Vector3.new(16, 9, 0.6), root * CFrame.new(0, 7.5, 24) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(24, 30, 48), Enum.Material.SmoothPlastic)
part("PainelPe", Vector3.new(0.8, 3, 0.8), root * CFrame.new(-6, 1.5, 24), Color3.fromRGB(40, 44, 52), Enum.Material.Metal)
part("PainelPe", Vector3.new(0.8, 3, 0.8), root * CFrame.new(6, 1.5, 24), Color3.fromRGB(40, 44, 52), Enum.Material.Metal)
local gui = Instance.new("SurfaceGui")
gui.Name = "Ranking"
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 40
gui.LightInfluence = 0
local title = Instance.new("TextLabel")
title.Name = "Titulo"
title.Size = UDim2.new(1, 0, 0.2, 0)
title.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
title.TextColor3 = Color3.fromRGB(24, 30, 48)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Text = "MELHORES OFICINAS DO SERVIDOR"
title.Parent = gui
local list = Instance.new("TextLabel")
list.Name = "Lista"
list.Position = UDim2.new(0.04, 0, 0.24, 0)
list.Size = UDim2.new(0.92, 0, 0.72, 0)
list.BackgroundTransparency = 1
list.TextColor3 = Color3.fromRGB(255, 255, 255)
list.Font = Enum.Font.GothamBold
list.TextScaled = true
list.TextXAlignment = Enum.TextXAlignment.Left
list.TextYAlignment = Enum.TextYAlignment.Top
list.Text = "Abra sua oficina e apareça aqui!"
list.Parent = gui
gui.Parent = board

-- Enfeite: o conjunto de praça do pacote num canto, e bancos/lixeira do pacote ao lado do caminho
local function prop(name: string, x: number, z: number, yawDeg: number)
	local template = Assets.Cenario:FindFirstChild(name)
	if template then
		local m = template:Clone()
		m:PivotTo(root * CFrame.new(x, 0.4, z) * CFrame.Angles(0, math.rad(yawDeg), 0))
		m.Parent = praca
	end
end
prop("Rua_Praca", 21, 0, -90)

for _, p in ipairs(praca:GetDescendants()) do
	if p:IsA("BasePart") then
		p.CastShadow = p.Size.Magnitude > 6
	end
end
praca.Parent = bairro
return #praca:GetDescendants()
