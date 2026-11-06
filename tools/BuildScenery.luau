-- Preenche o bairro: oficina em cada lote, muros de divisa, postes de luz, árvores e placas das áreas públicas.
-- Roda DEPOIS de BuildWorld. Idempotente (recria Workspace.Scenery e Oficina/Muros de cada lote).
local ServerStorage = game:GetService("ServerStorage")

local function mk(parent, name, size, pos, color, material, shape)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position = name, size, pos
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	if shape then p.Shape = shape end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local old = workspace:FindFirstChild("Scenery")
if old then old:Destroy() end
local scenery = Instance.new("Folder"); scenery.Name = "Scenery"; scenery.Parent = workspace

local accents = {
	Color3.fromRGB(255, 190, 60), Color3.fromRGB(80, 160, 255), Color3.fromRGB(235, 90, 90),
	Color3.fromRGB(100, 210, 140), Color3.fromRGB(190, 120, 240), Color3.fromRGB(255, 140, 60),
}

for _, plot in ipairs(workspace.Plots:GetChildren()) do
	local id = plot:GetAttribute("PlotId")
	local side = plot:GetAttribute("Side")
	local base = plot.Base
	for _, n in ipairs({ "Oficina", "Muros" }) do
		local o = plot:FindFirstChild(n)
		if o then o:Destroy() end
	end

	-- Oficina com interior acessível (ver tools/WorkshopBuilding): fundos do lote, fachada para a rua.
	local accent = accents[((id - 1) % #accents) + 1]
	local builderClone = ServerStorage.Tools.WorkshopBuilding:Clone() -- cópia nova: evita cache de require antigo
	builderClone.Parent = ServerStorage
	local ok, WB = pcall(require, builderClone)
	builderClone:Destroy()
	assert(ok, WB)
	WB.Build(plot, accent)

	-- Muros de divisa (fundo e laterais; a frente fica aberta para a rua)
	local walls = Instance.new("Folder"); walls.Name = "Muros"; walls.Parent = plot
	local half = base.Size.X / 2
	local wallColor = Color3.fromRGB(110, 112, 118)
	local y = base.Position.Y + 2.4
	mk(walls, "Fundo", Vector3.new(base.Size.X, 4, 1), Vector3.new(base.Position.X, y, base.Position.Z + side * (half - 0.5)), wallColor)
	for _, dx in ipairs({ -1, 1 }) do
		mk(walls, "Lateral", Vector3.new(1, 4, base.Size.Z - 24), Vector3.new(base.Position.X + dx * (half - 0.5), y, base.Position.Z + side * 12), wallColor)
	end
end

-- Cones de sinalização nos cantos da frente de cada vaga (modelo oficial da Roblox, em ServerStorage.Assets.Props)
local coneTemplate = ServerStorage.Assets:FindFirstChild("Props") and ServerStorage.Assets.Props:FindFirstChild("Cone")
local coneCount = 0
if coneTemplate then
	for _, plot in ipairs(workspace.Plots:GetChildren()) do
		local floorY = plot.Base.Position.Y + plot.Base.Size.Y / 2
		for _, bay in ipairs(plot:GetChildren()) do
			if bay.Name:match("^Bay%d") then
				for _, dx in ipairs({ -1, 1 }) do
					local cone = coneTemplate:Clone()
					cone.Name = "Cone"
					cone:ScaleTo(1.6)
					local _, s = cone:GetBoundingBox()
					local side = plot:GetAttribute("Side")
					-- As vagas ficam dentro do prédio: os cones ficam do lado de fora, na frente do portão, alinhados à vaga.
						cone:PivotTo(CFrame.new(bay.Position.X + dx * (bay.Size.X / 2 - 1), floorY + s.Y / 2, plot.Base.Position.Z + side * 3))
					cone.Parent = scenery
					coneCount += 1
				end
			end
		end
	end
end

-- Postes de luz ao longo das calçadas
local function streetlight(x, z, faceSide)
	local pole = mk(scenery, "Poste", Vector3.new(0.8, 18, 0.8), Vector3.new(x, 9.4, z), Color3.fromRGB(60, 62, 68), Enum.Material.Metal, Enum.PartType and Enum.PartType.Block)
	local arm = mk(scenery, "Braco", Vector3.new(0.5, 0.5, 5), Vector3.new(x, 18.2, z + faceSide * 2.5), Color3.fromRGB(60, 62, 68), Enum.Material.Metal)
	local lamp = mk(scenery, "Lampada", Vector3.new(2, 0.6, 2), Vector3.new(x, 17.8, z + faceSide * 5), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color, light.Shadows = 36, 1.2, Color3.fromRGB(255, 230, 180), false
	light.Parent = lamp
end
for x = -280, 280, 70 do
	streetlight(x, -24, 1)
	streetlight(x, 24, -1)
end

-- Árvores (tronco + copa), fora das áreas de lote e das ruas
local rng = Random.new(24)
local function tree(x, z)
	local h = rng:NextNumber(10, 18)
	mk(scenery, "Tronco", Vector3.new(1.6, h, 1.6), Vector3.new(x, h / 2, z), Color3.fromRGB(100, 70, 45), Enum.Material.Wood)
	local r = h * 0.55
	mk(scenery, "Copa", Vector3.new(r * 2, r * 1.7, r * 2), Vector3.new(x, h + r * 0.4, z), Color3.fromRGB(60 + rng:NextInteger(0, 30), 120 + rng:NextInteger(0, 40), 70), Enum.Material.Grass, Enum.PartType.Ball)
end
for i = 1, 40 do
	local x = rng:NextNumber(-340, 340)
	local north = rng:NextInteger(0, 1) == 0
	local z = (north and -1 or 1) * rng:NextNumber(135, 320)
	tree(x, z)
end
for i = 1, 8 do tree(rng:NextNumber(250, 330), rng:NextNumber(-100, 80)) end

-- Placas das áreas públicas
local function sign(model, text, color)
	local face = Instance.new("Part")
	face.Name = "Letreiro"
	face.Anchored = true
	face.Size = Vector3.new(model.Size.X * 0.8, 4, 0.6)
	face.Color = Color3.fromRGB(25, 27, 32)
	face.Material = Enum.Material.Metal
	local front = model.Name == "LojaAutopecas" and Vector3.new(0, 0, 1) or Vector3.new(-1, 0, 0)
	if model.Name == "LojaAutopecas" then
		face.CFrame = CFrame.new(model.Position + Vector3.new(0, model.Size.Y / 2 + 3, model.Size.Z / 2 + 0.4))
	else
		face.Size = Vector3.new(0.6, 4, model.Size.Z * 0.8)
		face.CFrame = CFrame.new(model.Position + Vector3.new(-(model.Size.X / 2 + 0.4), model.Size.Y / 2 + 3, 0))
	end
	face.Parent = scenery
	local gui = Instance.new("SurfaceGui")
	gui.Face = model.Name == "LojaAutopecas" and Enum.NormalId.Front or Enum.NormalId.Left
	gui.Parent = face
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1; lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = color; lbl.Text = text; lbl.Parent = gui
	local _ = front
end
sign(workspace.PublicAreas.LojaAutopecas, "AUTOPEÇAS 24H", Color3.fromRGB(255, 190, 60))
sign(workspace.PublicAreas.DistribuidoraEquipamentos, "DISTRIBUIDORA", Color3.fromRGB(80, 160, 255))

local parts = 0
for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
return string.format("Cenário pronto. Partes no Workspace: %d, cones: %d", parts, coneCount)
