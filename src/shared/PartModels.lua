--!strict
-- Modelos 3D procedurais das 14 peças do catálogo, usados só nas miniaturas (ViewportFrame) da Loja e do Estoque.
-- Cada modelo representa a peça real (não há imagem genérica). Centrados na origem, ~4 studs no maior eixo.
local PartModels = {}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local METAL = c(176, 182, 192)
local DARK_METAL = c(70, 76, 86)
local RUBBER = c(30, 32, 36)

local function block(model: Model, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Cilindro com eixo vertical (Y), altura `height`, raio `radius`.
local function cylinder(model: Model, radius: number, height: number, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local p = block(model, Vector3.new(height, radius * 2, radius * 2), offset * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Cilindro com eixo na direção X (roda, rolo).
local function axleCylinder(model: Model, radius: number, width: number, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local p = block(model, Vector3.new(width, radius * 2, radius * 2), offset, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local builders: { [string]: (Model) -> () } = {
	TirePatch = function(m)
		cylinder(m, 1.5, 0.18, CFrame.new(0, -0.5, 0), RUBBER, Enum.Material.Rubber)
		cylinder(m, 1.0, 0.22, CFrame.new(0, -0.45, 0), c(70, 72, 78), Enum.Material.Rubber)
		cylinder(m, 0.35, 0.26, CFrame.new(0, -0.42, 0), c(240, 190, 40))
		cylinder(m, 0.45, 1.8, CFrame.new(1.3, 0.2, 0.4) * CFrame.Angles(0, 0, math.rad(60)), c(220, 60, 50), Enum.Material.SmoothPlastic)
		cylinder(m, 0.2, 0.5, CFrame.new(1.85, 1.1, 0.4) * CFrame.Angles(0, 0, math.rad(60)), c(240, 240, 240))
	end,
	Tire = function(m)
		axleCylinder(m, 2, 1.5, CFrame.new(), RUBBER, Enum.Material.Rubber)
		axleCylinder(m, 1.3, 1.62, CFrame.new(), METAL, Enum.Material.Metal)
		axleCylinder(m, 0.9, 1.7, CFrame.new(), DARK_METAL, Enum.Material.Metal)
		axleCylinder(m, 0.35, 1.8, CFrame.new(), METAL, Enum.Material.Metal)
		for i = 0, 4 do
			local a = math.rad(i * 72)
			axleCylinder(m, 0.12, 1.75, CFrame.new(0, math.sin(a) * 0.62, math.cos(a) * 0.62), METAL, Enum.Material.Metal)
		end
	end,
	Battery = function(m)
		block(m, Vector3.new(3.4, 2.2, 2.1), CFrame.new(), c(28, 30, 36), Enum.Material.SmoothPlastic)
		block(m, Vector3.new(3.5, 0.3, 2.2), CFrame.new(0, 1.2, 0), c(60, 64, 74))
		cylinder(m, 0.28, 0.5, CFrame.new(-1.1, 1.55, 0), c(220, 50, 50), Enum.Material.Metal)
		cylinder(m, 0.28, 0.5, CFrame.new(1.1, 1.55, 0), c(30, 30, 34), Enum.Material.Metal)
		block(m, Vector3.new(1.6, 1.2, 0.05), CFrame.new(0, 0, 1.08), c(250, 200, 30), Enum.Material.Neon)
	end,
	SuspensionKit = function(m)
		cylinder(m, 0.22, 3.6, CFrame.new(), c(60, 64, 74), Enum.Material.Metal)
		cylinder(m, 0.12, 4.2, CFrame.new(), METAL, Enum.Material.Metal)
		for i = 0, 6 do
			local ring = axleCylinder(m, 0.95, 0.22, CFrame.new(0, -1.5 + i * 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), c(235, 150, 30), Enum.Material.Metal)
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.22, 1.9, 1.9)
		end
		cylinder(m, 1.1, 0.25, CFrame.new(0, -1.85, 0), DARK_METAL, Enum.Material.Metal)
		cylinder(m, 1.1, 0.25, CFrame.new(0, 1.85, 0), DARK_METAL, Enum.Material.Metal)
	end,
	SparkPlug = function(m)
		cylinder(m, 0.62, 0.9, CFrame.new(0, -0.9, 0), METAL, Enum.Material.Metal)
		cylinder(m, 0.45, 1.1, CFrame.new(0, -1.7, 0), METAL, Enum.Material.Metal)
		cylinder(m, 0.1, 0.5, CFrame.new(0, -2.3, 0.15), c(60, 60, 64), Enum.Material.Metal)
		cylinder(m, 0.5, 1.9, CFrame.new(0, 0.5, 0), c(240, 240, 235), Enum.Material.SmoothPlastic)
		cylinder(m, 0.58, 0.18, CFrame.new(0, 0.1, 0), c(240, 240, 235))
		cylinder(m, 0.22, 0.7, CFrame.new(0, 1.7, 0), METAL, Enum.Material.Metal)
	end,
	Fuse = function(m)
		block(m, Vector3.new(1.8, 2.4, 0.7), CFrame.new(), c(230, 60, 50), Enum.Material.SmoothPlastic)
		block(m, Vector3.new(1.2, 1.4, 0.72), CFrame.new(0, 0.3, 0), c(250, 120, 110), Enum.Material.Glass).Transparency = 0.35
		block(m, Vector3.new(0.12, 0.9, 0.1), CFrame.new(0, 0.3, 0), c(80, 80, 84), Enum.Material.Metal)
		block(m, Vector3.new(0.4, 0.8, 0.2), CFrame.new(-0.6, -1.5, 0), METAL, Enum.Material.Metal)
		block(m, Vector3.new(0.4, 0.8, 0.2), CFrame.new(0.6, -1.5, 0), METAL, Enum.Material.Metal)
	end,
	FillerPutty = function(m)
		cylinder(m, 1.3, 1.8, CFrame.new(0, -0.3, 0), c(165, 170, 180), Enum.Material.Metal)
		cylinder(m, 1.38, 0.35, CFrame.new(0, 0.75, 0), c(120, 126, 136), Enum.Material.Metal)
		cylinder(m, 1.32, 0.7, CFrame.new(0, -0.3, 0), c(240, 130, 30))
		cylinder(m, 0.45, 0.25, CFrame.new(0, 1.0, 0), METAL, Enum.Material.Metal)
	end,
	BodyPanel = function(m)
		block(m, Vector3.new(4.2, 2.6, 0.2), CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(8), 0, 0), c(80, 130, 210), Enum.Material.Metal)
		block(m, Vector3.new(4.2, 0.5, 0.3), CFrame.new(0, -1.3, 0.1), c(60, 100, 180), Enum.Material.Metal)
		block(m, Vector3.new(4.2, 0.3, 0.4), CFrame.new(0, 0.2, 0.15) * CFrame.Angles(math.rad(8), 0, 0), c(110, 160, 235), Enum.Material.Metal)
		cylinder(m, 0.22, 0.25, CFrame.new(-1.6, 0.9, 0.2) * CFrame.Angles(math.rad(90), 0, 0), c(30, 34, 44))
		cylinder(m, 0.22, 0.25, CFrame.new(1.6, 0.9, 0.2) * CFrame.Angles(math.rad(90), 0, 0), c(30, 34, 44))
	end,
	PaintCan = function(m)
		cylinder(m, 1.2, 2.4, CFrame.new(0, -0.2, 0), c(190, 196, 206), Enum.Material.Metal)
		cylinder(m, 1.28, 0.3, CFrame.new(0, 1.1, 0), c(130, 136, 146), Enum.Material.Metal)
		cylinder(m, 1.24, 0.9, CFrame.new(0, -0.3, 0), c(220, 50, 60))
		cylinder(m, 0.55, 0.12, CFrame.new(0, 1.28, 0), c(220, 50, 60))
		block(m, Vector3.new(2.6, 0.12, 0.12), CFrame.new(0, 1.7, 0), c(90, 94, 104), Enum.Material.Metal)
	end,
	WheelWeight = function(m)
		block(m, Vector3.new(2.4, 0.7, 0.9), CFrame.new(), c(120, 124, 132), Enum.Material.Metal)
		block(m, Vector3.new(2.4, 0.1, 0.9), CFrame.new(0, -0.4, 0), c(240, 230, 120))
		for i = -2, 2 do
			block(m, Vector3.new(0.08, 0.5, 0.92), CFrame.new(i * 0.46, 0.05, 0), c(90, 94, 102), Enum.Material.Metal)
		end
	end,
	BrakePad = function(m)
		block(m, Vector3.new(3.4, 0.35, 1.6), CFrame.new(0, 0.3, 0), c(150, 156, 166), Enum.Material.Metal)
		block(m, Vector3.new(3.2, 0.7, 1.45), CFrame.new(0, -0.2, 0), c(52, 54, 60), Enum.Material.SmoothPlastic)
		block(m, Vector3.new(0.5, 0.2, 0.5), CFrame.new(-1.4, 0.55, 0.45), c(220, 70, 40), Enum.Material.Metal)
		block(m, Vector3.new(0.5, 0.2, 0.5), CFrame.new(1.4, 0.55, -0.45), c(220, 70, 40), Enum.Material.Metal)
	end,
	Coolant = function(m)
		block(m, Vector3.new(2.4, 3, 1.5), CFrame.new(0, -0.2, 0), c(40, 170, 220), Enum.Material.SmoothPlastic)
		block(m, Vector3.new(2.0, 1.6, 0.05), CFrame.new(0, -0.3, 0.78), c(240, 250, 255))
		cylinder(m, 0.38, 0.5, CFrame.new(-0.6, 1.5, 0), c(240, 130, 30))
		block(m, Vector3.new(0.35, 1.3, 1.0), CFrame.new(1.35, 0.4, 0), c(30, 120, 170), Enum.Material.SmoothPlastic)
	end,
	SuspensionArm = function(m)
		block(m, Vector3.new(4.4, 0.55, 0.9), CFrame.new() * CFrame.Angles(0, math.rad(12), 0), DARK_METAL, Enum.Material.Metal)
		axleCylinder(m, 0.62, 1.1, CFrame.new(-2.1, 0, 0.45) * CFrame.Angles(math.rad(90), 0, 0), RUBBER, Enum.Material.Rubber).Orientation = Vector3.new(0, 0, 90)
		axleCylinder(m, 0.5, 1.1, CFrame.new(2.1, 0, -0.45) * CFrame.Angles(math.rad(90), 0, 0), RUBBER, Enum.Material.Rubber).Orientation = Vector3.new(0, 0, 90)
		cylinder(m, 0.2, 0.9, CFrame.new(0.2, 0.4, 0), METAL, Enum.Material.Metal)
	end,
	EngineKit = function(m)
		block(m, Vector3.new(3.6, 1.6, 2.2), CFrame.new(0, -0.9, 0), c(120, 126, 138), Enum.Material.Metal)
		for i = 0, 3 do
			local x = -1.35 + i * 0.9
			cylinder(m, 0.34, 1.5, CFrame.new(x, 0.55, 0), METAL, Enum.Material.Metal)
			cylinder(m, 0.4, 0.2, CFrame.new(x, -0.05, 0), c(220, 150, 40), Enum.Material.Metal)
		end
		block(m, Vector3.new(3.9, 0.2, 0.9), CFrame.new(0, 1.45, 0), c(60, 64, 74), Enum.Material.Metal)
		block(m, Vector3.new(0.3, 0.9, 1.0), CFrame.new(2.0, -0.7, 0), c(220, 70, 40), Enum.Material.Metal)
	end,
}

function PartModels.Has(partId: string): boolean
	return builders[partId] ~= nil
end

function PartModels.Build(partId: string): Model?
	local builder = builders[partId]
	if not builder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Part_" .. partId
	builder(model)
	return model
end

return PartModels
