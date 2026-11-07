--!strict
-- StationService: o que fica FÍSICO em cada lote, montado pelo servidor (não depende do arquivo do place):
--   * TV de ordens (prompt "Ver ordens"; aceitar ordem só perto dela), prateleira do estoque (prompt "Estoque"),
--     quadro de funcionários (prompts "Contratar"/"Demitir");
--   * placa 3D da oficina (totem) que se atualiza sozinha com nível, nota, clientes atendidos e posição no servidor;
--   * plataforma elevatória em cada box (o carro sobe durante o reparo);
--   * anexo da expansão (Bay3) quando comprado.
-- Posições no espaço local do lote (shared/Layout). Prompts das estações só aparecem para o dono (atributo OwnerUserId).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Config = require(ReplicatedStorage.Shared.Config)

local StationService = {}

local DARK = Color3.fromRGB(28, 31, 38)
local STEEL = Color3.fromRGB(150, 156, 166)
local YELLOW = Color3.fromRGB(255, 196, 40)
local WOOD = Color3.fromRGB(150, 110, 70)

local promptHandler: ((Player, Instance, string) -> ())? = nil -- (jogador, lote, ação)

function StationService.SetPromptHandler(handler: (Player, Instance, string) -> ())
	promptHandler = handler
end

local function frameOf(plot: Instance): CFrame?
	local base = plot:FindFirstChild("Base")
	if not base or not base:IsA("BasePart") then
		return nil
	end
	local side = plot:GetAttribute("Side")
	return CFrame.new(base.Position.X, base.Position.Y + base.Size.Y / 2, base.Position.Z)
		* CFrame.Angles(0, side == -1 and math.pi or 0, 0)
end
StationService.FrameOf = frameOf

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
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
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function addPrompt(anchor: BasePart, plot: Instance, action: string, text: string, object: string, hold: number, opensPanel: string?)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = action
	prompt.ActionText = text
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = Config.StationDistance - 2
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Style = Enum.ProximityPromptStyle.Custom -- o HUD desenha (e só para o dono)
	if opensPanel then
		prompt:SetAttribute("OpensPanel", opensPanel)
	end
	prompt:SetAttribute("OwnerUserId", plot:GetAttribute("OwnerUserId") or 0)
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player: Player)
		if plot:GetAttribute("OwnerUserId") == player.UserId and promptHandler then
			promptHandler(player, plot, action)
		end
	end)
end

local function label(partOn: BasePart, face: Enum.NormalId, name: string, ppsOrNil: number?): Frame
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppsOrNil or 40
	gui.LightInfluence = 0
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	gui.Parent = partOn
	return frame
end

local function text(parent: Instance, name: string, pos: UDim2, size: UDim2, color: Color3, font: Enum.Font, value: string): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Position = pos
	t.Size = size
	t.BackgroundTransparency = 1
	t.TextColor3 = color
	t.Font = font
	t.TextScaled = true
	t.Text = value
	t.Parent = parent
	return t
end

-- Estações dentro do prédio ------------------------------------------------------------------------------------
local function buildStations(plot: Instance, root: CFrame): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Estacoes"
	-- TV de ordens: tela grande na parede do fundo
	local s = Layout.Stations.Orders
	local tvCf = root * CFrame.new(s.x, s.y, s.z) * CFrame.Angles(0, math.rad(s.yaw), 0)
	local tv = part(folder, "TV_Ordens", Vector3.new(8, 4.6, 0.4), tvCf, DARK, Enum.Material.SmoothPlastic)
	part(folder, "TV_Moldura", Vector3.new(8.4, 5, 0.3), tvCf * CFrame.new(0, 0, 0.12), Color3.fromRGB(12, 12, 16))
	local screen = label(tv, Enum.NormalId.Front, "Tela")
	text(screen, "Titulo", UDim2.fromScale(0.04, 0.05), UDim2.fromScale(0.92, 0.2), YELLOW, Enum.Font.GothamBlack, "ORDENS DE SERVIÇO")
	text(screen, "Lista", UDim2.fromScale(0.04, 0.3), UDim2.fromScale(0.92, 0.65), Color3.new(1, 1, 1), Enum.Font.GothamBold, "Nenhum cliente esperando.")
	addPrompt(tv, plot, "Ordens", "Ver ordens", "TV da oficina", 0, "orders")
	-- Prateleira do estoque
	local k = Layout.Stations.Stock
	local shelfCf = root * CFrame.new(k.x, 0, k.z) * CFrame.Angles(0, math.rad(k.yaw), 0)
	local shelf = Instance.new("Model")
	shelf.Name = "Prateleira"
	for _, x in ipairs({ -2.9, 2.9 }) do
		part(shelf, "Coluna", Vector3.new(0.25, 7.5, 1.8), shelfCf * CFrame.new(x, 3.75, 0), STEEL, Enum.Material.Metal)
	end
	local boxColors = { Color3.fromRGB(200, 70, 50), Color3.fromRGB(60, 120, 200), Color3.fromRGB(230, 170, 40), Color3.fromRGB(70, 160, 90) }
	for i, y in ipairs({ 0.4, 2.3, 4.2, 6.1 }) do
		part(shelf, "Tabua", Vector3.new(6, 0.2, 1.8), shelfCf * CFrame.new(0, y, 0), WOOD, Enum.Material.Wood)
		for j = -2, 2 do
			if (i + j) % 3 ~= 0 then
				part(shelf, "Caixa", Vector3.new(0.9, 0.9, 1.1), shelfCf * CFrame.new(j * 1.15, y + 0.55, 0.1), boxColors[(i + j) % 4 + 1])
			end
		end
	end
	local shelfAnchor = part(shelf, "PromptPonto", Vector3.new(1, 1, 1), shelfCf * CFrame.new(0, 3.5, 0), DARK)
	shelfAnchor.Transparency = 1
	shelfAnchor.CanCollide = false
	addPrompt(shelfAnchor, plot, "Estoque", "Abrir estoque", "Prateleira de peças", 0, "stock")
	local tag = part(shelf, "Placa", Vector3.new(4, 0.8, 0.1), shelfCf * CFrame.new(0, 7.7, 0.9), YELLOW)
	local tagFace = label(tag, Enum.NormalId.Back, "Texto")
	text(tagFace, "T", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), DARK, Enum.Font.GothamBlack, "ESTOQUE")
	shelf.Parent = folder
	-- Quadro de funcionários
	local f = Layout.Stations.Staff
	local boardCf = root * CFrame.new(f.x, f.y, f.z) * CFrame.Angles(0, math.rad(f.yaw), 0)
	local board = part(folder, "QuadroFuncionarios", Vector3.new(4.5, 3.2, 0.25), boardCf, Color3.fromRGB(40, 90, 60))
	local boardFace = label(board, Enum.NormalId.Front, "Texto")
	text(boardFace, "Titulo", UDim2.fromScale(0.05, 0.05), UDim2.fromScale(0.9, 0.3), Color3.new(1, 1, 1), Enum.Font.GothamBlack, "FUNCIONÁRIOS")
	text(boardFace, "Info", UDim2.fromScale(0.05, 0.4), UDim2.fromScale(0.9, 0.55), Color3.fromRGB(220, 240, 220), Enum.Font.GothamBold,
		string.format("Contratar: %d\nSalário: %d / %d min", Config.EmployeeHireCost, Config.EmployeeSalary, Config.PaydaySeconds // 60))
	-- Dois pontos nas pontas do quadro; só o mais próximo aparece (o HUD desenha um prompt por vez, também no celular).
	for i, spec in ipairs({
		{ "Contratar", "Contratar mecânico", string.format("%d moedas", Config.EmployeeHireCost), 1, -1.6 },
		{ "Demitir", "Demitir mecânico", "Funcionários", 1.5, 1.6 },
	}) do
		local anchor = part(folder, "Quadro_" .. spec[1], Vector3.new(0.4, 0.4, 0.4), boardCf * CFrame.new(spec[5], -1.3, -0.3), Color3.fromRGB(40, 90, 60))
		anchor.Color = i == 1 and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(230, 80, 70)
		anchor.Material = Enum.Material.Neon
		anchor.CanCollide = false
		addPrompt(anchor, plot, spec[1], spec[2], spec[3], spec[4])
		local prompt = anchor:FindFirstChild(spec[1]) :: ProximityPrompt
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
		prompt.MaxActivationDistance = 6
	end
	folder.Parent = plot
	return folder
end

-- Placa 3D da oficina (totem) ----------------------------------------------------------------------------------
local function buildSign(plot: Instance, root: CFrame): Model
	local sign = Instance.new("Model")
	sign.Name = "Totem"
	local cf = root * CFrame.new(Layout.Sign.x, 0, Layout.Sign.z)
	part(sign, "Base", Vector3.new(14, 1, 3), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(110, 112, 118), Enum.Material.Slate)
	for _, x in ipairs({ -5.6, 5.6 }) do
		part(sign, "Poste", Vector3.new(1, 15, 1), cf * CFrame.new(x, 8, 0), DARK, Enum.Material.Metal)
	end
	local panel = part(sign, "Painel", Vector3.new(13, 8, 0.8), cf * CFrame.new(0, 11, 0), DARK, Enum.Material.SmoothPlastic)
	local header = part(sign, "Faixa", Vector3.new(13.4, 2, 1), cf * CFrame.new(0, 16, 0), YELLOW, Enum.Material.Neon)
	local crown = part(sign, "Luz", Vector3.new(13.4, 0.25, 1.1), cf * CFrame.new(0, 6.85, 0), YELLOW, Enum.Material.Neon)
	local _ = crown
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local h = label(header, face, "Topo" .. face.Name, 30)
		text(h, "Tipo", UDim2.fromScale(0.03, 0.05), UDim2.fromScale(0.94, 0.9), DARK, Enum.Font.GothamBlack, "LOTE LIVRE")
		local p = label(panel, face, "Info" .. face.Name, 30)
		text(p, "Nome", UDim2.fromScale(0.04, 0.04), UDim2.fromScale(0.92, 0.26), Color3.new(1, 1, 1), Enum.Font.GothamBlack, "Vire dono deste terreno!")
		text(p, "Linha1", UDim2.fromScale(0.04, 0.34), UDim2.fromScale(0.92, 0.18), YELLOW, Enum.Font.GothamBold, "")
		text(p, "Linha2", UDim2.fromScale(0.04, 0.55), UDim2.fromScale(0.92, 0.18), Color3.fromRGB(200, 220, 255), Enum.Font.GothamBold, "")
		text(p, "Linha3", UDim2.fromScale(0.04, 0.76), UDim2.fromScale(0.92, 0.18), Color3.fromRGB(150, 255, 170), Enum.Font.GothamBold, "")
	end
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 10
	light.Brightness = 1.2
	light.Color = YELLOW
	light.Parent = header
	sign.Parent = plot
	return sign
end

export type SignData = { Title: string, Name: string, Line1: string, Line2: string, Line3: string, Color: Color3? }

function StationService.SetSign(plot: Instance, data: SignData)
	local sign = plot:FindFirstChild("Totem")
	if not sign then
		return
	end
	local header = sign:FindFirstChild("Faixa")
	local panel = sign:FindFirstChild("Painel")
	if header and header:IsA("BasePart") and data.Color then
		header.Color = data.Color
		local crown = sign:FindFirstChild("Luz")
		if crown and crown:IsA("BasePart") then
			crown.Color = data.Color
		end
	end
	for _, gui in ipairs((header :: Instance):GetChildren()) do
		local t = gui:FindFirstChild("Tipo", true)
		if t and t:IsA("TextLabel") then
			t.Text = data.Title
		end
	end
	for _, gui in ipairs((panel :: Instance):GetChildren()) do
		for _, key in ipairs({ "Nome", "Linha1", "Linha2", "Linha3" }) do
			local t = gui:FindFirstChild(key, true)
			if t and t:IsA("TextLabel") then
				t.Text = key == "Nome" and data.Name or (data :: any)[key]
			end
		end
	end
end

-- Lista curta na TV de ordens (texto já pronto).
function StationService.SetOrdersScreen(plot: Instance, value: string)
	local folder = plot:FindFirstChild("Estacoes")
	local tv = folder and folder:FindFirstChild("TV_Ordens")
	local list = tv and tv:FindFirstChild("Lista", true)
	if list and list:IsA("TextLabel") then
		list.Text = value
	end
end

-- Plataforma elevatória por box ---------------------------------------------------------------------------------
local LIFT_HEIGHT = 4.5

local function buildLift(bay: BasePart)
	if bay:FindFirstChild("Elevador") then
		return
	end
	local top = bay.Position.Y + bay.Size.Y / 2
	local base = bay.CFrame - Vector3.new(0, bay.Position.Y - top, 0)
	local lift = Instance.new("Model")
	lift.Name = "Elevador"
	local platform = part(lift, "Plataforma", Vector3.new(7.5, 0.3, bay.Size.Z - 4), base * CFrame.new(0, 0.15, 0), Color3.fromRGB(70, 74, 84), Enum.Material.DiamondPlate)
	part(lift, "FaixaA", Vector3.new(0.4, 0.32, bay.Size.Z - 4), base * CFrame.new(-3.55, 0.16, 0), YELLOW, Enum.Material.SmoothPlastic)
	part(lift, "FaixaB", Vector3.new(0.4, 0.32, bay.Size.Z - 4), base * CFrame.new(3.55, 0.16, 0), YELLOW, Enum.Material.SmoothPlastic)
	local column = part(lift, "Pistao", Vector3.new(0.05, 1.2, 1.2), base * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 205, 212), Enum.Material.Metal, Enum.PartType.Cylinder)
	column.CanCollide = false
	lift:SetAttribute("Altura", 0)
	lift.PrimaryPart = platform
	lift.Parent = bay
end

-- Sobe (true) ou desce o elevador do box junto com o carro (Raiz). Retorna quando termina.
-- Alturas ABSOLUTAS (a partir da posição de montagem): uma inversão no meio do movimento cancela o tween anterior e nunca
-- deixa o elevador (nem o carro) fora do lugar. Pedir de novo o mesmo alvo enquanto ele se move só espera terminar.
local active: { [Instance]: { Tweens: { Tween }, Done: BindableEvent } } = {}

function StationService.Lift(bay: BasePart, carRoot: BasePart?, up: boolean)
	local lift = bay:FindFirstChild("Elevador")
	if not lift then
		return
	end
	local target = up and LIFT_HEIGHT or 0
	local running = active[lift]
	if running and lift:GetAttribute("Altura") == target then
		running.Done.Event:Wait() -- já indo para lá: espera chegar
		return
	end
	if not running and (tonumber(lift:GetAttribute("Altura")) or 0) == target then
		return
	end
	if running then
		for _, tw in ipairs(running.Tweens) do
			tw:Cancel()
		end
		running.Done:Fire()
	end
	lift:SetAttribute("Altura", target)
	local info = TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local tweens: { Tween } = {}
	for _, p in ipairs(lift:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "Pistao" then
			local base = p:GetAttribute("Base")
			if typeof(base) ~= "CFrame" then
				base = p.CFrame
				p:SetAttribute("Base", base)
			end
			table.insert(tweens, TweenService:Create(p, info, { CFrame = (base :: CFrame) + Vector3.new(0, target, 0) }))
		end
	end
	local column = lift:FindFirstChild("Pistao")
	if column and column:IsA("BasePart") then
		local top = bay.Position.Y + bay.Size.Y / 2
		table.insert(tweens, TweenService:Create(column, info, {
			Size = Vector3.new(math.max(0.05, target), column.Size.Y, column.Size.Z),
			CFrame = CFrame.new(column.Position.X, top + target / 2, column.Position.Z) * column.CFrame.Rotation,
		}))
	end
	if carRoot then
		-- a Raiz do carro fica no topo da plataforma (topo do box + 0,3) mais a altura do elevador
		local floorY = bay.Position.Y + bay.Size.Y / 2 + 0.3
		local cf = carRoot.CFrame
		table.insert(tweens, TweenService:Create(carRoot, info, { CFrame = cf + Vector3.new(0, floorY + target - cf.Position.Y, 0) }))
	end
	local entry = { Tweens = tweens, Done = Instance.new("BindableEvent") }
	active[lift] = entry
	for _, tw in ipairs(tweens) do
		tw:Play()
	end
	local sound = Instance.new("Sound")
	sound.SoundId = require(ReplicatedStorage.Shared.SoundIds).Lift
	sound.Volume = 0.5
	sound.RollOffMaxDistance = 60
	sound.Parent = lift:FindFirstChild("Plataforma")
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 7)
	task.delay(2.45, function()
		if active[lift] == entry then
			active[lift] = nil
			entry.Done:Fire()
		end
	end)
	entry.Done.Event:Wait()
	entry.Done:Destroy()
end

-- O elevador está em cima OU se mexendo (quem vai tirar o carro deve chamar Lift(bay, raiz, false) e esperar).
function StationService.IsBusy(bay: BasePart): boolean
	local lift = bay:FindFirstChild("Elevador")
	return lift ~= nil and (active[lift] ~= nil or (tonumber(lift:GetAttribute("Altura")) or 0) > 0)
end

function StationService.IsLifted(bay: BasePart): boolean
	local lift = bay:FindFirstChild("Elevador")
	return lift ~= nil and (tonumber(lift:GetAttribute("Altura")) or 0) > 0
end

-- Expansão: anexo com o Bay3 -----------------------------------------------------------------------------------
-- Placa "Área de expansão" com o prompt de compra (some quando o anexo é construído).
local function expansionSign(plot: Instance, root: CFrame)
	if plot:FindFirstChild("PlacaExpansao") then
		return
	end
	local b = Layout.AnnexBay
	local sign = Instance.new("Model")
	sign.Name = "PlacaExpansao"
	local cf = root * CFrame.new(b.x, 0, Layout.Annex.z0 + 4)
	part(sign, "Poste", Vector3.new(0.5, 5, 0.5), cf * CFrame.new(0, 2.5, 0), STEEL, Enum.Material.Metal)
	local board = part(sign, "Placa", Vector3.new(7, 3.4, 0.3), cf * CFrame.new(0, 5.6, 0), Color3.fromRGB(20, 110, 70))
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local f = label(board, face, "Texto" .. face.Name, 30)
		text(f, "T", UDim2.fromScale(0.05, 0.06), UDim2.fromScale(0.9, 0.4), Color3.new(1, 1, 1), Enum.Font.GothamBlack, "ÁREA DE EXPANSÃO")
		text(f, "C", UDim2.fromScale(0.05, 0.52), UDim2.fromScale(0.9, 0.4), YELLOW, Enum.Font.GothamBold,
			string.format("Box 3 coberto: %d moedas", Config.ExpansionCosts[1] or 0))
	end
	-- marcação no chão do futuro box
	local floor = part(sign, "Marcacao", Vector3.new(b.w, 0.06, b.d), root * CFrame.new(b.x, 0.05, b.z), YELLOW, Enum.Material.SmoothPlastic)
	floor.Transparency = 0.75
	floor.CanCollide = false
	addPrompt(board, plot, "Expandir", "Expandir oficina", string.format("%d moedas", Config.ExpansionCosts[1] or 0), 1.5)
	sign.Parent = plot
end

function StationService.ApplyExpansion(plot: Instance, level: number)
	local existing = plot:FindFirstChild("Anexo")
	local bay3 = plot:FindFirstChild("Bay3")
	local root = frameOf(plot)
	if not root then
		return
	end
	if level < 1 then
		if existing then
			existing:Destroy()
		end
		if bay3 then
			bay3:Destroy()
		end
		expansionSign(plot, root)
		return
	end
	local oldSign = plot:FindFirstChild("PlacaExpansao")
	if oldSign then
		oldSign:Destroy()
	end
	if existing then
		return
	end
	local a = Layout.Annex
	local anexo = Instance.new("Model")
	anexo.Name = "Anexo"
	local cx, cz = (a.x0 + a.x1) / 2, (a.z0 + a.z1) / 2
	local w, d, h = a.x1 - a.x0, a.z1 - a.z0, 12
	local wall = Color3.fromRGB(226, 222, 212)
	part(anexo, "Piso", Vector3.new(w, 0.3, d), root * CFrame.new(cx, 0.15, cz), Color3.fromRGB(150, 150, 150), Enum.Material.Concrete)
	part(anexo, "Fundo", Vector3.new(w, h, 1), root * CFrame.new(cx, h / 2, a.z1 - 0.5), wall, Enum.Material.Brick)
	part(anexo, "Lateral", Vector3.new(1, h, d), root * CFrame.new(a.x0 + 0.5, h / 2, cz), wall, Enum.Material.Brick)
	part(anexo, "Teto", Vector3.new(w + 1, 0.6, d + 1), root * CFrame.new(cx, h + 0.3, cz), Color3.fromRGB(70, 76, 88), Enum.Material.Metal)
	local frontBeam = part(anexo, "Viga", Vector3.new(w, 2.2, 1), root * CFrame.new(cx, h - 1.1, a.z0 + 0.5), YELLOW, Enum.Material.SmoothPlastic)
	local face = label(frontBeam, Enum.NormalId.Front, "Texto", 30)
	text(face, "T", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), DARK, Enum.Font.GothamBlack, "BOX 3 · ANEXO")
	local lamp = part(anexo, "Luminaria", Vector3.new(8, 0.3, 1), root * CFrame.new(cx, h - 0.3, cz), Color3.fromRGB(255, 245, 220), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = lamp
	anexo.Parent = plot
	if not bay3 then
		local b = Layout.AnnexBay
		local bay = Instance.new("Part")
		bay.Name = "Bay3"
		bay.Anchored = true
		bay.CanCollide = false
		bay.Size = Vector3.new(b.w, 0.1, b.d)
		bay.CFrame = root * CFrame.new(b.x, 0.35, b.z)
		bay.Color = Color3.fromRGB(255, 200, 60)
		bay.Material = Enum.Material.SmoothPlastic
		bay.Transparency = 0.6
		bay:SetAttribute("Anexo", true)
		bay.Parent = plot
		buildLift(bay)
	end
end

-- Montagem inicial de todos os lotes (idempotente): estações, totem, elevadores, tamanho das vagas, placa antiga
-- escondida. Também acompanha a troca de dono para o HUD mostrar os prompts só para quem é dono.
function StationService.Start()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local root = frameOf(plot)
		if root then
			for i, spec in ipairs(Layout.Bays) do
				local bay = plot:FindFirstChild("Bay" .. i)
				if bay and bay:IsA("BasePart") then
					bay.Size = Vector3.new(spec.w, bay.Size.Y, spec.d)
					buildLift(bay)
				end
			end
			-- a placa antiga e a entrada saem do caminho; o totem novo assume
			for _, name in ipairs({ "Sign", "Entry" }) do
				local p = plot:FindFirstChild(name)
				if p and p:IsA("BasePart") then
					local l = root:ToObjectSpace(p.CFrame)
					p.CFrame = root * (CFrame.new(Layout.Sign.x, l.Y, Layout.Sign.z) * l.Rotation)
					if name == "Sign" then
						p.Transparency = 1
						p.CanCollide = false
						for _, d in ipairs(p:GetDescendants()) do
							if d:IsA("SurfaceGui") then
								d.Enabled = false
							end
						end
					end
				end
			end
			if not plot:FindFirstChild("Estacoes") then
				buildStations(plot, root)
			end
			if not plot:FindFirstChild("Totem") then
				buildSign(plot, root)
			end
			if not plot:FindFirstChild("Anexo") then
				StationService.ApplyExpansion(plot, 0)
			end
			local function syncOwner()
				local owner = plot:GetAttribute("OwnerUserId") or 0
				for _, holder in ipairs({ plot:FindFirstChild("Estacoes"), plot:FindFirstChild("PlacaExpansao") }) do
					for _, d in ipairs(holder and holder:GetDescendants() or {}) do
						if d:IsA("ProximityPrompt") then
							d:SetAttribute("OwnerUserId", owner)
							d.Enabled = owner ~= 0 and owner ~= -1
						end
					end
				end
			end
			plot:GetAttributeChangedSignal("OwnerUserId"):Connect(syncOwner)
			syncOwner()
		end
	end
end

-- Posição (mundo) de uma estação do lote: "Orders" | "Stock" | "Staff".
function StationService.StationPosition(plot: Instance, kind: string): Vector3?
	local root = frameOf(plot)
	local s = (Layout.Stations :: any)[kind]
	if not root or not s then
		return nil
	end
	return (root * CFrame.new(s.x, math.max(s.y, 2.5), s.z)).Position
end

function StationService.IsNear(player: Player, plot: Instance?, kind: string, maxDistance: number?): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local pos = plot and StationService.StationPosition(plot, kind)
	if not hrp or not hrp:IsA("BasePart") or not pos then
		return false
	end
	return (hrp.Position - pos).Magnitude <= (maxDistance or Config.StationDistance)
end

return StationService
