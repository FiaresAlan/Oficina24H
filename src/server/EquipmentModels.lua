--!strict
-- Modelos procedurais (Parts) dos equipamentos do Catalog. Sem upload, sem licença, versionados em código.
-- Cada função devolve um Model com PrimaryPart "Base" apoiado no piso (origem no centro da base, base em y=0).
local ServerStorage = game:GetService("ServerStorage")
local EquipmentModels = {}

-- Modelo 3D real (pacote de oficina CC0, tratado no Blender) em ServerStorage.Assets.Equipamentos["Eq_<Id>"], se existir.
-- A frente do asset é o LookVector; o jogo posiciona equipamentos com a frente em +Z, então giramos 180 graus uma vez aqui.
local function realModel(equipmentId: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Equipamentos")
	local template = folder and folder:FindFirstChild("Eq_" .. equipmentId)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

local function part(parent: Instance, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local RED = Color3.fromRGB(190, 45, 45)
local DARK = Color3.fromRGB(38, 40, 46)
local STEEL = Color3.fromRGB(150, 154, 162)
local YELLOW = Color3.fromRGB(235, 185, 40)
local BLUE = Color3.fromRGB(70, 150, 255)
local GREEN = Color3.fromRGB(90, 230, 140)

local builders: { [string]: (Model) -> () } = {}

builders.BasicToolset = function(m) -- baú de ferramentas com gavetas
	part(m, "Base", Vector3.new(3.4, 0.4, 2.2), CFrame.new(0, 0.2, 0), DARK)
	part(m, "Corpo", Vector3.new(3.2, 3.2, 2), CFrame.new(0, 2, 0), RED)
	part(m, "Tampo", Vector3.new(3.4, 0.3, 2.2), CFrame.new(0, 3.75, 0), DARK)
	for i = 0, 3 do
		part(m, "Gaveta", Vector3.new(3, 0.12, 0.1), CFrame.new(0, 1 + i * 0.7, -1.02), DARK, Enum.Material.SmoothPlastic)
		part(m, "Puxador", Vector3.new(1.2, 0.15, 0.15), CFrame.new(0, 1.3 + i * 0.7, -1.1), STEEL)
	end
end

builders.Jack = function(m) -- macaco hidráulico de oficina
	part(m, "Base", Vector3.new(4.2, 0.5, 1.6), CFrame.new(0, 0.5, 0), RED)
	part(m, "Corpo", Vector3.new(1.4, 1, 1.2), CFrame.new(-1.2, 1.2, 0), RED)
	part(m, "Braco", Vector3.new(2.8, 0.35, 0.5), CFrame.new(0.4, 1.7, 0), STEEL)
	part(m, "Sela", Vector3.new(0.9, 0.35, 0.9), CFrame.new(1.8, 1.95, 0), YELLOW, Enum.Material.Plastic)
	part(m, "Cabo", Vector3.new(0.25, 0.25, 3), CFrame.new(-2.2, 1.6, 0) * CFrame.Angles(0, math.rad(90), math.rad(-30)), DARK)
	for _, x in ipairs({ -1.6, 1.6 }) do
		part(m, "Roda", Vector3.new(0.5, 0.6, 0.6), CFrame.new(x, 0.3, 0.9) * CFrame.Angles(0, 0, math.rad(90)), DARK, Enum.Material.Rubber, Enum.PartType.Cylinder)
	end
end

builders.TireMachine = function(m) -- desmontadora de pneus
	part(m, "Base", Vector3.new(4.4, 2.6, 4.4), CFrame.new(0, 1.3, 0), Color3.fromRGB(60, 66, 76))
	part(m, "Prato", Vector3.new(0.4, 3.4, 3.4), CFrame.new(0, 2.8, 0) * CFrame.Angles(0, 0, math.rad(90)), STEEL, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, "Coluna", Vector3.new(0.8, 4.5, 0.8), CFrame.new(2.1, 4.8, 0), YELLOW)
	part(m, "Braco", Vector3.new(0.7, 0.7, 2.6), CFrame.new(2.1, 6.8, 1.2), YELLOW)
	part(m, "Pneu", Vector3.new(1.2, 3.2, 3.2), CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(20, 20, 22), Enum.Material.Rubber, Enum.PartType.Cylinder)
	part(m, "Pedal", Vector3.new(1.4, 0.3, 0.8), CFrame.new(-1.4, 0.15, -2.4), DARK)
end

builders.Scanner = function(m) -- scanner de diagnóstico em carrinho
	part(m, "Base", Vector3.new(2.8, 0.4, 2.2), CFrame.new(0, 0.5, 0), DARK)
	for _, p in ipairs({ { -1.1, -0.8 }, { 1.1, -0.8 }, { -1.1, 0.8 }, { 1.1, 0.8 } }) do
		part(m, "Roda", Vector3.new(0.4, 0.5, 0.5), CFrame.new(p[1], 0.25, p[2]) * CFrame.Angles(0, 0, math.rad(90)), DARK, Enum.Material.Rubber, Enum.PartType.Cylinder)
	end
	part(m, "Mastro", Vector3.new(0.5, 3.6, 0.5), CFrame.new(0, 2.5, 0.4), STEEL)
	part(m, "Corpo", Vector3.new(2.2, 1.8, 1), CFrame.new(0, 4.2, 0.1), DARK, Enum.Material.SmoothPlastic)
	part(m, "Tela", Vector3.new(1.9, 1.4, 0.1), CFrame.new(0, 4.2, -0.42), BLUE, Enum.Material.Neon)
	part(m, "Cabo", Vector3.new(0.15, 0.15, 2.2), CFrame.new(1.3, 3, -0.4), DARK)
end

builders.EngineBench = function(m) -- bancada de motor com bloco
	part(m, "Base", Vector3.new(6.4, 0.5, 3.2), CFrame.new(0, 0.25, 0), DARK)
	for _, x in ipairs({ -2.8, 2.8 }) do
		part(m, "Perna", Vector3.new(0.5, 2.6, 2.6), CFrame.new(x, 1.8, 0), STEEL)
	end
	part(m, "Tampo", Vector3.new(6.4, 0.4, 3.2), CFrame.new(0, 3.3, 0), Color3.fromRGB(110, 90, 70), Enum.Material.Wood)
	part(m, "Bloco", Vector3.new(3.2, 1.6, 1.8), CFrame.new(0, 4.3, 0), Color3.fromRGB(95, 100, 108), Enum.Material.Metal)
	for i = -1, 1 do
		part(m, "Cilindro", Vector3.new(0.9, 1, 0.9), CFrame.new(i * 1.0, 5.3, 0), STEEL, Enum.Material.Metal, Enum.PartType.Cylinder).CFrame = CFrame.new(i * 1.0, 5.3, 0) * CFrame.Angles(0, 0, math.rad(90))
	end
end

builders.ElectricalBench = function(m) -- bancada elétrica com painel
	part(m, "Base", Vector3.new(6, 0.5, 2.8), CFrame.new(0, 0.25, 0), DARK)
	part(m, "Corpo", Vector3.new(6, 2.4, 2.6), CFrame.new(0, 1.7, 0), YELLOW)
	part(m, "Tampo", Vector3.new(6.2, 0.35, 2.8), CFrame.new(0, 3.1, 0), STEEL)
	part(m, "Painel", Vector3.new(5, 2.4, 0.3), CFrame.new(0, 4.5, 1.2), DARK, Enum.Material.SmoothPlastic)
	for i = -2, 2 do
		part(m, "Led", Vector3.new(0.4, 0.4, 0.15), CFrame.new(i * 0.9, 5.1, 1.0), i % 2 == 0 and GREEN or BLUE, Enum.Material.Neon, Enum.PartType.Ball)
	end
	part(m, "Osciloscopio", Vector3.new(1.8, 1.2, 1.2), CFrame.new(-1.6, 3.9, 0), DARK, Enum.Material.SmoothPlastic)
end

builders.SuspensionLift = function(m) -- elevador de dois postes
	part(m, "Base", Vector3.new(9, 0.4, 5), CFrame.new(0, 0.2, 0), DARK)
	for _, x in ipairs({ -3.6, 3.6 }) do
		part(m, "Poste", Vector3.new(1.1, 11, 1.1), CFrame.new(x, 5.9, 0), YELLOW)
		part(m, "Carro", Vector3.new(1.4, 1.2, 1.4), CFrame.new(x, 3.2, 0), STEEL)
		part(m, "Braco", Vector3.new(0.6, 0.5, 3.4), CFrame.new(x, 3.4, 1.8), YELLOW)
		part(m, "BracoTras", Vector3.new(0.6, 0.5, 3.4), CFrame.new(x, 3.4, -1.8), YELLOW)
	end
	part(m, "Travessa", Vector3.new(9, 0.7, 0.7), CFrame.new(0, 11.2, 0), STEEL)
end

builders.Balancer = function(m) -- balanceadora de rodas
	part(m, "Base", Vector3.new(3.4, 2.4, 3), CFrame.new(0, 1.2, 0), Color3.fromRGB(70, 76, 88))
	part(m, "Capa", Vector3.new(3.4, 0.4, 3.1), CFrame.new(0, 2.6, 0), DARK)
	part(m, "Eixo", Vector3.new(0.4, 0.4, 2), CFrame.new(0, 3.3, -1.8), STEEL)
	part(m, "Roda", Vector3.new(1.1, 3, 3), CFrame.new(0, 3.3, -2.2) * CFrame.Angles(0, 0, 0), Color3.fromRGB(20, 20, 22), Enum.Material.Rubber, Enum.PartType.Cylinder).CFrame = CFrame.new(0, 3.3, -2.4) * CFrame.Angles(0, math.rad(90), 0)
	part(m, "Painel", Vector3.new(2, 1.2, 0.4), CFrame.new(0, 3.5, 1.1), DARK, Enum.Material.SmoothPlastic)
	part(m, "Visor", Vector3.new(1.6, 0.8, 0.1), CFrame.new(0, 3.5, 0.88), BLUE, Enum.Material.Neon)
	part(m, "Protecao", Vector3.new(0.3, 3.6, 3.6), CFrame.new(0, 4.4, -2.4), STEEL, Enum.Material.Metal).Transparency = 0.6
end

builders.Compressor = function(m) -- compressor de ar com reservatório horizontal
	for _, x in ipairs({ -1.8, 1.8 }) do
		part(m, "Perna", Vector3.new(0.5, 1.6, 2), CFrame.new(x, 0.8, 0), DARK)
	end
	local tank = part(m, "Base", Vector3.new(5.4, 2.4, 2.4), CFrame.new(0, 2.8, 0), RED, Enum.Material.Metal, Enum.PartType.Cylinder)
	tank.CFrame = CFrame.new(0, 2.8, 0)
	part(m, "Motor", Vector3.new(1.6, 1.4, 1.6), CFrame.new(0, 4.6, 0), DARK)
	part(m, "Cabecote", Vector3.new(1, 1.2, 1), CFrame.new(0, 5.8, 0), STEEL)
	part(m, "Manometro", Vector3.new(0.8, 0.8, 0.2), CFrame.new(2.0, 3.8, -1.1) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(m, "Mangueira", Vector3.new(0.25, 0.25, 3), CFrame.new(-2.9, 2, 0), YELLOW, Enum.Material.Plastic)
end

builders.BodyworkKit = function(m) -- bancada de funilaria com painel de lataria e pistola
	part(m, "Base", Vector3.new(4.6, 0.4, 3), CFrame.new(0, 0.2, 0), DARK)
	part(m, "Corpo", Vector3.new(4.4, 2.2, 2.8), CFrame.new(0, 1.5, 0), Color3.fromRGB(60, 110, 190))
	part(m, "Tampo", Vector3.new(4.6, 0.3, 3), CFrame.new(0, 2.75, 0), STEEL)
	part(m, "Painel", Vector3.new(3.4, 1.8, 0.35), CFrame.new(0, 3.9, 0.2) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(190, 195, 205), Enum.Material.Metal)
	part(m, "Amassado", Vector3.new(0.9, 0.5, 0.2), CFrame.new(0.6, 4, -0.1) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(160, 165, 175), Enum.Material.Metal, Enum.PartType.Ball)
	part(m, "Pistola", Vector3.new(0.4, 0.9, 1.4), CFrame.new(-1.5, 3.2, -0.6), RED, Enum.Material.Plastic)
	part(m, "Martelo", Vector3.new(0.3, 0.3, 1.4), CFrame.new(1.5, 3, -0.7), Color3.fromRGB(110, 80, 50), Enum.Material.Wood)
end

builders.AlignmentRig = function(m) -- alinhador: dois pratos giratórios e mastro com alvo
	part(m, "Base", Vector3.new(11, 0.3, 4), CFrame.new(0, 0.15, 0), DARK)
	for _, x in ipairs({ -4, 4 }) do
		part(m, "Prato", Vector3.new(0.35, 3.2, 3.2), CFrame.new(x, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), STEEL, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	part(m, "Mastro", Vector3.new(0.7, 7, 0.7), CFrame.new(0, 3.8, -2.2), YELLOW)
	part(m, "Camera", Vector3.new(7, 0.8, 0.8), CFrame.new(0, 6.8, -2.2), DARK)
	for _, x in ipairs({ -3.2, 3.2 }) do
		part(m, "Alvo", Vector3.new(0.9, 0.9, 0.2), CFrame.new(x, 6.8, -2.7), BLUE, Enum.Material.Neon)
	end
	part(m, "Tela", Vector3.new(2.2, 1.4, 0.2), CFrame.new(0, 3.6, -2.7), BLUE, Enum.Material.Neon)
end

function EquipmentModels.Has(equipmentId: string): boolean
	return builders[equipmentId] ~= nil or realModel(equipmentId) ~= nil
end

-- Constrói o modelo na origem; quem chama posiciona com PivotTo.
function EquipmentModels.Build(equipmentId: string): Model?
	local real = realModel(equipmentId)
	if real then
		local copy = real:Clone()
		copy.Name = "Eq_" .. equipmentId
		copy:PivotTo(CFrame.Angles(0, math.pi, 0))
		copy.WorldPivot = CFrame.new()
		copy:SetAttribute("EquipmentId", equipmentId)
		return copy
	end
	local build = builders[equipmentId]
	if not build then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Eq_" .. equipmentId
	build(model)
	-- Construído com o piso em y=0 e centrado em x/z=0: o pivô na origem permite PivotTo(CFrame no piso do lote).
	model.WorldPivot = CFrame.new()
	model:SetAttribute("EquipmentId", equipmentId)
	return model
end

return EquipmentModels
