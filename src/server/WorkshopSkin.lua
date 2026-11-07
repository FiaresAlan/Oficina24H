--!strict
-- WorkshopSkin: aparência da oficina conforme o tipo (Catalog.WorkshopTier, derivado do nível empresarial que já existe).
--   1 Oficina de bairro: simples (pilha de pneus, placa de preços, lixeira, barril).
--   2 Centro automotivo: fachada de alumínio azul e branco, marquise, totem, elevador e jardineiras.
--   3 Oficina premium: fachada grafite com LED dourado, letreiro de teto, vitrine com carro de exibição e refletores.
-- Só muda a APARÊNCIA (modelo "Skin" dentro do lote); capacidade, vagas, preços e progressão não são tocados.
-- O servidor é o único que cria/remove a fachada; ela some quando o lote é liberado (PlotService.Release).
local ServerStorage = game:GetService("ServerStorage")

local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local PlotService = require(script.Parent.PlotService)

local WorkshopSkin = {}

local DARK = Color3.fromRGB(30, 32, 38)
local GRAPHITE = Color3.fromRGB(44, 46, 54)
local STEEL = Color3.fromRGB(150, 154, 162)
local WHITE = Color3.fromRGB(236, 239, 244)
local BLUE = Color3.fromRGB(28, 92, 178)
local CYAN = Color3.fromRGB(70, 190, 255)
local GOLD = Color3.fromRGB(255, 196, 70)

-- Referencial do prédio (mesmo de tools/WorkshopBuilding): origem no centro da base, +X lateral, +Z para o fundo.
-- A rua fica em -Z; a fachada está em z = 6.
local function rootOf(plot: Instance): CFrame?
	local base = plot:FindFirstChild("Base")
	local side = plot:GetAttribute("Side")
	if not base or not base:IsA("BasePart") or type(side) ~= "number" then
		return nil
	end
	local floorY = base.Position.Y + base.Size.Y / 2
	return CFrame.new(base.Position.X, floorY, base.Position.Z) * CFrame.Angles(0, side == -1 and math.pi or 0, 0)
end

local function assetsFolder(name: string): Instance?
	local assets = ServerStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild(name)
end

type Ctx = { Root: CFrame, Model: Model }

local function box(ctx: Ctx, name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	p.CFrame = ctx.Root * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.Anchored = true
	p.CanCollide = collide == true
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CastShadow = false
	p.Parent = ctx.Model
	return p
end

local function neon(ctx: Ctx, name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3): Part
	return box(ctx, name, x0, x1, y0, y1, z0, z1, color, Enum.Material.Neon, false)
end

-- Texto em uma face da peça (face Front = lado da rua).
local function label(part: Part, text: string, color: Color3, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Texto"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.TextScaled = true
	text_.Font = Enum.Font.GothamBlack
	text_.TextColor3 = color
	text_.Text = text
	text_.Parent = gui
	gui.Parent = part
end

-- Prop do pacote (ServerStorage.Assets.Oficina / Cenario). Frente do asset = LookVector; sem yaw ele olha para a rua (-Z local).
local function prop(ctx: Ctx, folderName: string, name: string, x: number, z: number, yawDeg: number?, scale: number?)
	local folder = assetsFolder(folderName)
	local template = folder and folder:FindFirstChild(name)
	if not template or not template:IsA("Model") then
		return
	end
	local m = template:Clone()
	if scale and scale ~= 1 then
		m:ScaleTo(scale)
	end
	m:PivotTo(ctx.Root * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yawDeg or 0), 0))
	m.Parent = ctx.Model
end

local function carModel(ctx: Ctx, vehicleName: string, x: number, y: number, z: number, yawDeg: number)
	local assets = assetsFolder("Veiculos")
	local template = assets and assets:FindFirstChild(vehicleName)
	if not template or not template:IsA("Model") then
		return
	end
	local m = template:Clone()
	-- Raiz no chão, frente = LookVector (-Z local): sem giro o carro olha para a rua
	m:PivotTo(ctx.Root * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg), 0))
	m.Parent = ctx.Model
end

local builders: { [number]: (Ctx) -> () } = {}

builders[1] = function(ctx)
	prop(ctx, "Oficina", "Of_PilhaPneus", 41, 1.5)
	prop(ctx, "Oficina", "Of_Placa", -12, -3.5, 8)
	prop(ctx, "Oficina", "Of_PisoMolhado", -5.5, -2.2, -20)
	prop(ctx, "Oficina", "Of_Lixeira", 25, 1.5)
	prop(ctx, "Oficina", "Of_Barril", 29.5, 2.2)
	prop(ctx, "Oficina", "Of_Galao", 27, -1.5, 35)
end

builders[2] = function(ctx)
	-- Fachada de alumínio: faixa azul sobre o portão e a porta, com friso branco
	box(ctx, "FaixaAzul", -8.4, 21.6, 11.2, 14.4, 4.9, 6.1, BLUE)
	box(ctx, "FrisoBranco", -8.4, 21.6, 10.7, 11.2, 4.9, 6.1, WHITE)
	box(ctx, "PilarEsq", -21.8, -19.2, 0, 14.4, 4.9, 6.3, WHITE)
	box(ctx, "PilarMeio", -3.2, -0.8, 0, 11.2, 4.9, 6.3, BLUE)
	box(ctx, "PilarDir", 19.8, 22, 0, 14.4, 4.9, 6.3, WHITE)
	neon(ctx, "LedLateralEsq", -21.9, -21.5, 0.5, 14, 4.7, 4.9, CYAN)
	neon(ctx, "LedLateralDir", 21.5, 21.9, 0.5, 14, 4.7, 4.9, CYAN)
	-- Marquise sobre a porta de pessoas
	box(ctx, "MarquiseLaje", -11, 1, 10.2, 10.8, -4.5, 6.1, WHITE)
	box(ctx, "MarquiseBorda", -11, 1, 10.1, 10.9, -4.7, -4.4, BLUE)
	box(ctx, "MarquiseColunaEsq", -10.7, -10.1, 0, 10.2, -4.2, -3.6, STEEL)
	box(ctx, "MarquiseColunaDir", -2.6, -2.0, 0, 10.2, -4.2, -3.6, STEEL) -- fora do corredor dos carros (Layout.Driveway)
	neon(ctx, "MarquiseLed", -10, 0, 10.05, 10.2, -4.3, 5.5, CYAN)
	-- Totem
	box(ctx, "TotemPoste", 37.4, 38.6, 0, 20, -9.4, -8.2, DARK, Enum.Material.Metal, true)
	local panel = box(ctx, "TotemPainel", 31.5, 44.5, 15, 22, -9.2, -8.6, BLUE, Enum.Material.SmoothPlastic)
	label(panel, "CENTRO\nAUTOMOTIVO", WHITE, Enum.NormalId.Front)
	label(panel, "CENTRO\nAUTOMOTIVO", WHITE, Enum.NormalId.Back)
	neon(ctx, "TotemLed", 31.3, 44.7, 14.6, 15, -9.3, -8.5, CYAN)
	prop(ctx, "Oficina", "Of_PilhaPneus", 41, 0)
	prop(ctx, "Oficina", "Of_Placa", -14, -6, 10)
	prop(ctx, "Oficina", "Of_Elevador", 31, -3.5)
	prop(ctx, "Oficina", "Of_CarrinhoFerramenta", 22.5, -2.5, -30)
	prop(ctx, "Oficina", "Of_Lixeira", 40, 3)
	prop(ctx, "Cenario", "Rua_Jardineira", -16, -30, 0, 0.4)
	prop(ctx, "Cenario", "Rua_Jardineira", 28, -9, 0, 0.4)
end

builders[3] = function(ctx)
	-- Fachada grafite com LED dourado
	box(ctx, "FaixaGrafite", -22, 22, 12.3, 15.6, 4.6, 6.4, GRAPHITE) -- acima do quadro de preços (topo em y = 12)
	box(ctx, "PilarEsq", -22.2, -19.4, 0, 15.6, 4.6, 6.6, GRAPHITE)
	box(ctx, "PilarMeio", -3.4, -0.6, 0, 11.2, 4.6, 6.6, GRAPHITE)
	box(ctx, "PilarDir", 19.6, 22.2, 0, 15.6, 4.6, 6.6, GRAPHITE)
	neon(ctx, "LedBaixo", -22, 22, 12.0, 12.3, 4.4, 4.7, GOLD)
	neon(ctx, "LedCima", -22, 22, 15.6, 15.9, 4.4, 4.7, GOLD)
	for _, x in ipairs({ -21.0, -2.0, 21.0 }) do
		neon(ctx, "LedPilar", x - 0.12, x + 0.12, 0.4, 11, 4.3, 4.5, GOLD)
	end
	-- Letreiro de teto
	local sign = box(ctx, "Letreiro", -16, 16, 16.4, 21.6, 5.0, 5.7, DARK, Enum.Material.SmoothPlastic)
	label(sign, "PERFORMANCE", GOLD, Enum.NormalId.Front)
	neon(ctx, "LetreiroMoldura", -16.4, 16.4, 21.6, 21.9, 4.9, 5.8, GOLD)
	neon(ctx, "LetreiroMolduraBaixo", -16.4, 16.4, 16.1, 16.4, 4.9, 5.8, GOLD)
	box(ctx, "LetreiroSuporteEsq", -12, -11.4, 15.6, 16.4, 5.1, 5.6, DARK)
	box(ctx, "LetreiroSuporteDir", 11.4, 12, 15.6, 16.4, 5.1, 5.6, DARK)
	-- Marquise grafite
	box(ctx, "MarquiseLaje", -11.5, 1.5, 10.2, 10.9, -5, 6.4, GRAPHITE)
	neon(ctx, "MarquiseLed", -11.5, 1.5, 10.0, 10.2, -5, 6.2, GOLD)
	box(ctx, "MarquiseColunaEsq", -11.2, -10.4, 0, 10.2, -4.6, -3.8, DARK)
	box(ctx, "MarquiseColunaDir", -2.8, -2.0, 0, 10.2, -4.6, -3.8, DARK) -- fora do corredor dos carros (Layout.Driveway)
	-- Plataforma de exibição com carro, refletores e piso de LED
	box(ctx, "VitrinePiso", 20, 46, 0, 0.35, -24, -2, DARK, Enum.Material.SmoothPlastic).Reflectance = 0.2
	local ring = Instance.new("Part")
	ring.Name = "VitrineAnel"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 19, 19)
	ring.CFrame = ctx.Root * CFrame.new(33, 0.5, -13) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Color = GOLD
	ring.Material = Enum.Material.Neon
	ring.CastShadow = false
	ring.Parent = ctx.Model
	local plate = Instance.new("Part")
	plate.Name = "VitrinePlataforma"
	plate.Shape = Enum.PartType.Cylinder
	plate.Size = Vector3.new(0.6, 17.4, 17.4)
	plate.CFrame = ctx.Root * CFrame.new(33, 0.7, -13) * CFrame.Angles(0, 0, math.rad(90))
	plate.Anchored = true
	plate.CanCollide = true
	plate.Color = GRAPHITE
	plate.Material = Enum.Material.SmoothPlastic
	plate.Reflectance = 0.25
	plate.CastShadow = false
	plate.Parent = ctx.Model
	carModel(ctx, "Veiculo_VIP_Corvette", 33, 1.0, -13, 25)
	for _, spot in ipairs({ { 24, -22 }, { 42, -22 }, { 33, -3 } }) do
		local post = box(ctx, "RefletorPoste", spot[1] - 0.25, spot[1] + 0.25, 0, 8, spot[2] - 0.25, spot[2] + 0.25, DARK)
		local head = box(ctx, "Refletor", spot[1] - 0.7, spot[1] + 0.7, 8, 8.8, spot[2] - 0.7, spot[2] + 0.7, DARK)
		local light = Instance.new("SpotLight")
		light.Angle = 55
		light.Range = 26
		light.Brightness = 2.5
		light.Color = Color3.fromRGB(255, 232, 190)
		light.Face = Enum.NormalId.Bottom
		light.Shadows = false
		light.Parent = head
		local _ = post
	end
	neon(ctx, "LedChao1", -40, 18, 0.35, 0.5, -18, -17.6, GOLD)
	neon(ctx, "LedChao2", -40, 18, 0.35, 0.5, -6, -5.6, GOLD)
	prop(ctx, "Oficina", "Of_Placa", -14, -7, 6)
	prop(ctx, "Cenario", "Rua_Jardineira", -30, -30, 0, 0.4)
	prop(ctx, "Cenario", "Rua_Jardineira", -16, -30, 0, 0.4)
end

local function clear(plot: Instance)
	local old = plot:FindFirstChild("Skin")
	if old then
		old:Destroy()
	end
end

-- Constrói (ou refaz) a fachada do tipo `tier` no lote. Retorna true se mudou.
function WorkshopSkin.Apply(plot: Instance, tier: number): boolean
	local existing = plot:FindFirstChild("Skin")
	if existing and existing:GetAttribute("Tier") == tier then
		return false
	end
	local root = rootOf(plot)
	local build = builders[tier]
	if not root or not build then
		return false
	end
	clear(plot)
	local model = Instance.new("Model")
	model.Name = "Skin"
	model:SetAttribute("Tier", tier)
	build({ Root = root, Model = model })
	model.Parent = plot
	return true
end

-- Atualiza a oficina do jogador conforme o total ganho. Retorna (mudou, nome do tipo).
function WorkshopSkin.Update(player: Player, totalEarned: number): (boolean, string)
	local plot = PlotService.GetPlot(player)
	local tier, name = Catalog.WorkshopTier(totalEarned)
	if not plot then
		return false, name
	end
	local existing = plot:FindFirstChild("Skin")
	local previous = existing and existing:GetAttribute("Tier")
	local changed = WorkshopSkin.Apply(plot, tier)
	return changed and previous ~= nil, name -- primeira montagem não conta como "evoluiu"
end

return WorkshopSkin
