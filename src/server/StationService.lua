--!strict
-- StationService: o que fica FÍSICO em cada lote, montado pelo servidor (não depende do arquivo do place):
--   * TV de ordens (prompt "Ver ordens"; aceitar ordem só perto dela), prateleira do estoque (prompt "Estoque"),
--     quadro de funcionários (prompts "Contratar"/"Demitir");
--   * placa 3D da oficina (totem) que se atualiza sozinha com nível, nota, clientes atendidos e posição no servidor;
--   * plataforma elevatória em cada box (o carro sobe durante o reparo);
--   * o PRÉDIO da oficina conforme o nível (shared/WorkshopLevels: 1, 2, 4 ou 6 boxes), com materiais de verdade
--     (tijolo, concreto, metal, vidro), portas de enrolar, letreiro, luzes, sala dos fundos dos equipamentos e o pátio
--     com portões de entrada e saída.
-- Posições no espaço local do lote. Prompts das estações só aparecem para o dono (atributo OwnerUserId).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Layout = require(ReplicatedStorage.Shared.Layout)
local WorkshopLevels = require(ReplicatedStorage.Shared.WorkshopLevels)
local Config = require(ReplicatedStorage.Shared.Config)
local LocationRules = require(ReplicatedStorage.Shared.LocationRules)

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
	prompt.MaxActivationDistance = 8 -- curto: as estações ficam perto umas das outras e o HUD mostra um prompt por vez
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
	gui.MaxDistance = 140 -- longe, o texto nem é desenhado (celular agradece)
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
type Spec = { x: number, y: number, z: number, yaw: number }
local function stationSpecs(level: number): { Orders: Spec, Stock: Spec, Staff: Spec? }
	local L = WorkshopLevels.Levels[level] or WorkshopLevels.Levels[0]
	local back = WorkshopLevels.BackWallZ - 0.7
	return {
		Orders = { x = L.X0 + 5.5, y = 9, z = back, yaw = 0 }, -- TV na parede do fundo, acima dos equipamentos
		Stock = { x = L.X0 + 1.4, y = 0, z = 18, yaw = -90 }, -- prateleira na sala lateral, de frente para dentro
		Staff = L.MaxEmployees > 0 and { x = L.X1 - 5, y = 8.5, z = back, yaw = 0 } or nil,
	}
end

local function buildStations(plot: Instance, root: CFrame, level: number): Folder
	local specs = stationSpecs(level)
	local folder = Instance.new("Folder")
	folder.Name = "Estacoes"
	-- TV de ordens: tela grande na parede do fundo
	local s = specs.Orders
	local tvCf = root * CFrame.new(s.x, s.y, s.z) * CFrame.Angles(0, math.rad(s.yaw), 0)
	local tv = part(folder, "TV_Ordens", Vector3.new(8, 4.6, 0.4), tvCf, DARK, Enum.Material.SmoothPlastic)
	part(folder, "TV_Moldura", Vector3.new(8.4, 5, 0.3), tvCf * CFrame.new(0, 0, 0.12), Color3.fromRGB(12, 12, 16))
	local screen = label(tv, Enum.NormalId.Front, "Tela")
	text(screen, "Titulo", UDim2.fromScale(0.04, 0.05), UDim2.fromScale(0.92, 0.2), YELLOW, Enum.Font.GothamBlack, "ORDENS DE SERVIÇO")
	text(screen, "Lista", UDim2.fromScale(0.04, 0.3), UDim2.fromScale(0.92, 0.65), Color3.new(1, 1, 1), Enum.Font.GothamBold, "Nenhum cliente esperando.")
	addPrompt(tv, plot, "Ordens", "Ver ordens", "TV da oficina", 0, "orders")
    -- V2-02: balcão físico da recepção, funcional mesmo sem pack GLB importado.
    -- Montado na mesma área da TV para respeitar a checagem de proximidade do servidor.
    local deskCf = root * CFrame.new(s.x + 3.4, 0, s.z - 3.3)
    local desk = part(folder, "RecepcaoBalcao", Vector3.new(5.4, 1.1, 1.8),
        deskCf * CFrame.new(0, 1.2, 0), Color3.fromRGB(52, 58, 65), Enum.Material.Metal)
    part(folder, "RecepcaoTampo", Vector3.new(5.9, 0.18, 2.1),
        deskCf * CFrame.new(0, 1.82, 0), WOOD, Enum.Material.Wood)
    local badge = part(folder, "RecepcaoPlaca", Vector3.new(4.5, 0.65, 0.12),
        deskCf * CFrame.new(0, 1.32, -0.97), YELLOW)
    badge.CanCollide = false
    local badgeGui = label(badge, Enum.NormalId.Front, "Recepcao")
    text(badgeGui, "Titulo", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1),
        DARK, Enum.Font.GothamBlack, "RECEPÇÃO · ORDENS")
    local deskPrompt = part(folder, "RecepcaoAcesso", Vector3.new(0.4, 0.4, 0.4),
        deskCf * CFrame.new(0, 2.3, -1.4), YELLOW)
    deskPrompt.CanCollide = false
    deskPrompt.Transparency = 1
    addPrompt(deskPrompt, plot, "Recepcao", "Gerenciar fila", "Balcão de recepção", 0.3, "orders")
	-- Prateleira do estoque
	local k = specs.Stock
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
	-- Quadro de funcionários: disponível quando o nível atual permite contratação (2 boxes ou mais).
	local f = specs.Staff
	if not f then
		folder.Parent = plot
		return folder
	end
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
		prompt.MaxActivationDistance = 5
	end
	folder.Parent = plot
	return folder
end

-- Placa 3D da oficina (totem) ----------------------------------------------------------------------------------
local function buildSign(plot: Instance, root: CFrame): Model
	local sign = Instance.new("Model")
	sign.Name = "Totem"
	local cf = root * CFrame.new(Layout.Sign.x, 0, Layout.Sign.z)
	part(sign, "Base", Vector3.new(16, 1, 3), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(110, 112, 118), Enum.Material.Slate)
	for _, x in ipairs({ -7.1, 7.1 }) do -- postes por fora do painel (não cobrem o texto)
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
		local values = { Nome = data.Name, Linha1 = data.Line1, Linha2 = data.Line2, Linha3 = data.Line3 }
		for key, value in pairs(values) do
			local t = gui:FindFirstChild(key, true)
			if t and t:IsA("TextLabel") then
				t.Text = tostring(value or "")
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

-- Prédio da oficina por nível ----------------------------------------------------------------------------------
local BRICK = Color3.fromRGB(176, 92, 70)
local PLASTER = Color3.fromRGB(232, 226, 214)
local CONCRETE = Color3.fromRGB(150, 150, 152)
local ROOF = Color3.fromRGB(62, 66, 76)
local DOOR = Color3.fromRGB(196, 200, 206)

local function buildBuilding(plot: Instance, root: CFrame, level: number, ownerName: string?): Model
	local L = WorkshopLevels.Levels[level] or WorkshopLevels.Levels[0]
	local m = Instance.new("Model")
	m.Name = "Predio"
	m:SetAttribute("Nivel", level)
	local x0, x1, z0, z1, h = L.X0, L.X1, WorkshopLevels.FrontZ, WorkshopLevels.BackWallZ, L.Height
	local w, d, cx, cz = x1 - x0, z1 - z0, (x0 + x1) / 2, (z0 + z1) / 2
	local function at(x: number, y: number, z: number): CFrame
		return root * CFrame.new(x, y, z)
	end
	-- piso de concreto polido
	part(m, "Piso", Vector3.new(w, 0.3, d), at(cx, 0.15, cz), Color3.fromRGB(176, 178, 182), Enum.Material.Concrete)
	-- paredes de tijolo (fundo e laterais) com rodapé de concreto
	part(m, "Fundo", Vector3.new(w, h, 1), at(cx, h / 2, z1 - 0.5), BRICK, Enum.Material.Brick)
	part(m, "LateralEsq", Vector3.new(1, h, d), at(x0 + 0.5, h / 2, cz), BRICK, Enum.Material.Brick)
	part(m, "LateralDir", Vector3.new(1, h, d), at(x1 - 0.5, h / 2, cz), BRICK, Enum.Material.Brick)
	for _, spec in ipairs({ { cx, z1 - 1.05, w, 0.1 }, { x0 + 1.05, cz, 0.1, d }, { x1 - 1.05, cz, 0.1, d } }) do
		local skirt = part(m, "Rodape", Vector3.new(spec[3], 1.2, spec[4]), at(spec[1], 0.6, spec[2]), CONCRETE, Enum.Material.Concrete)
		skirt.CanCollide = false
	end
	-- mureta amarela separando os boxes da sala dos fundos (equipamentos)
	local backRoomZ = WorkshopLevels.BayZ + WorkshopLevels.BayDepth / 2 + 0.3
	for _, x in ipairs(L.Bays) do
		part(m, "Mureta", Vector3.new(WorkshopLevels.BayWidth - 1, 1.1, 0.4), at(x, 0.85, backRoomZ), Color3.fromRGB(255, 196, 40), Enum.Material.SmoothPlastic)
	end
	-- fachada: sala lateral de reboco com vitrine, pilares de concreto entre os boxes, portas de enrolar recolhidas
	local firstBay = L.Bays[1] - WorkshopLevels.BayWidth / 2 - 1
	part(m, "FachadaSala", Vector3.new(firstBay - x0, h, 1), at((x0 + firstBay) / 2, h / 2, z0 + 0.5), PLASTER, Enum.Material.Plaster)
	local glass = part(m, "Vitrine", Vector3.new(math.max(2, firstBay - x0 - 4), 4, 0.3), at((x0 + firstBay) / 2, 3.2, z0 - 0.05), Color3.fromRGB(150, 200, 230), Enum.Material.Glass)
	glass.Transparency = 0.45
	glass.CanCollide = false
	local edges = { firstBay }
	for _, x in ipairs(L.Bays) do
		table.insert(edges, x + WorkshopLevels.BayWidth / 2 + 1)
	end
	for i, ex in ipairs(edges) do
		local px = i == 1 and ex + 0.5 or ex - 0.5
		part(m, "Pilar", Vector3.new(1.4, h, 1.4), at(px, h / 2, z0 + 0.5), CONCRETE, Enum.Material.Concrete)
	end
	for _, x in ipairs(L.Bays) do
		local doorTop = h - 2.4
		part(m, "PortaCaixa", Vector3.new(WorkshopLevels.BayWidth + 1, 1.2, 1.2), at(x, doorTop - 0.6, z0 + 0.5), DOOR, Enum.Material.CorrodedMetal)
		for k = 0, 2 do
			part(m, "PortaRipa", Vector3.new(WorkshopLevels.BayWidth + 1, 0.25, 0.3), at(x, doorTop - 1.5 - k * 0.5, z0 + 0.2), DOOR, Enum.Material.DiamondPlate).CanCollide = false
		end
		part(m, "FaixaChao", Vector3.new(WorkshopLevels.BayWidth, 0.32, 0.5), at(x, 0.16, z0 + 0.2), Color3.fromRGB(255, 196, 40), Enum.Material.SmoothPlastic)
	end
	-- viga do letreiro com LED na cor do nível
	local beam = part(m, "Letreiro", Vector3.new(w, 2.4, 1.2), at(cx, h - 1.2, z0 + 0.5), Color3.fromRGB(30, 34, 44), Enum.Material.Metal)
	part(m, "LedLetreiro", Vector3.new(w, 0.25, 1.3), at(cx, h - 2.45, z0 + 0.5), L.Color, Enum.Material.Neon).CanCollide = false
	local face = label(beam, Enum.NormalId.Front, "Texto", 24)
	text(face, "T", UDim2.fromScale(0.02, 0.08), UDim2.fromScale(0.96, 0.84), Color3.new(1, 1, 1), Enum.Font.GothamBlack,
		string.upper(ownerName and ("Oficina de " .. ownerName) or L.Name) .. "  ·  " .. string.upper(L.Name))
	-- telhado de metal com platibanda
	part(m, "Telhado", Vector3.new(w + 1.4, 0.6, d + 1.4), at(cx, h + 0.3, cz), ROOF, Enum.Material.CorrodedMetal)
	part(m, "Platibanda", Vector3.new(w + 1.6, 1, 0.6), at(cx, h + 1.1, z0 - 0.2), Color3.fromRGB(40, 44, 54), Enum.Material.Metal)
	-- iluminação: luminária por box (luz em boxes alternados, sem sombra: leve no celular)
	for i, x in ipairs(L.Bays) do
		local lamp = part(m, "Luminaria", Vector3.new(6, 0.2, 1), at(x, h - 0.25, WorkshopLevels.BayZ), Color3.fromRGB(255, 246, 225), Enum.Material.Neon)
		lamp.CanCollide = false
		if i % 2 == 1 then
			local light = Instance.new("PointLight")
			light.Range = 20
			light.Brightness = 1.1
			light.Shadows = false
			light.Parent = lamp
		end
	end
	part(m, "LuminariaFundos", Vector3.new(math.min(w - 2, 30), 0.2, 1), at(cx, h - 0.25, 38), Color3.fromRGB(255, 246, 225), Enum.Material.Neon).CanCollide = false
	-- pátio de asfalto com placas e setas de ENTRADA / SAÍDA
	local yard = part(m, "Patio", Vector3.new(90, 0.06, z0 + 45), at(0, 0.03, (z0 - 45) / 2), Color3.fromRGB(60, 62, 66), Enum.Material.Asphalt)
	yard.CanCollide = false
	for _, spec in ipairs({ { WorkshopLevels.GateIn, "ENTRADA", Color3.fromRGB(70, 200, 110), 5 }, { WorkshopLevels.GateOut, "SAÍDA", Color3.fromRGB(230, 90, 70), -5 } }) do
		local post = part(m, "PortaoPoste", Vector3.new(0.4, 4, 0.4), at(spec[1] + spec[4], 2, -43), Color3.fromRGB(40, 44, 54), Enum.Material.Metal)
		local plate = part(m, "PortaoPlaca", Vector3.new(4.5, 1.4, 0.2), post.CFrame * CFrame.new(0, 2.4, 0), spec[3], Enum.Material.SmoothPlastic)
		for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			text(label(plate, f, "T" .. f.Name, 40), "T", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.new(1, 1, 1), Enum.Font.GothamBlack, spec[2])
		end
		for k = 0, 2 do
			local arrow = part(m, "Seta", Vector3.new(1, 0.08, 3), at(spec[1], 0.08, -40 + k * 9) * CFrame.Angles(0, spec[2] == "ENTRADA" and 0 or math.pi, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
			arrow.CanCollide = false
		end
	end
	m.Parent = plot
	return m
end

local function rebuildBays(plot: Instance, root: CFrame, level: number)
	for _, child in ipairs(plot:GetChildren()) do
		if child:IsA("BasePart") and child.Name:match("^Bay%d+$") then
			child:Destroy()
		end
	end
	local L = WorkshopLevels.Levels[level] or WorkshopLevels.Levels[0]
	-- Bay1 = o mais perto do portão de entrada (maior x): é o primeiro a ser ocupado
	local xs = table.clone(L.Bays)
	table.sort(xs, function(a, b)
		return a > b
	end)
	for i, x in ipairs(xs) do
		local bay = Instance.new("Part")
		bay.Name = "Bay" .. i
		bay.Anchored = true
		bay.CanCollide = false
		bay.CanQuery = false
		bay.Size = Vector3.new(WorkshopLevels.BayWidth, 0.1, WorkshopLevels.BayDepth)
		bay.CFrame = root * CFrame.new(x, 0.35, WorkshopLevels.BayZ)
		bay.Color = Color3.fromRGB(70, 110, 160)
		bay.Material = Enum.Material.SmoothPlastic
		bay.Transparency = 1 -- só referência de posição: a marcação visível é a faixa amarela e o elevador
		bay.Parent = plot
		buildLift(bay)
	end
end

local function syncOwner(plot: Instance)
	local owner = plot:GetAttribute("OwnerUserId") or 0
	for _, holder in ipairs({ plot:FindFirstChild("Estacoes"), plot:FindFirstChild("Equipment") }) do
		for _, d in ipairs(holder and holder:GetDescendants() or {}) do
			if d:IsA("ProximityPrompt") then
				d:SetAttribute("OwnerUserId", owner)
				d.Enabled = owner ~= 0 and owner ~= -1
			end
		end
	end
end
StationService.SyncOwner = syncOwner

-- Monta (ou refaz) o lote no nível dado: prédio, boxes com elevador e estações. Só chamar com os boxes livres.
function StationService.ApplyLevel(plot: Instance, level: number, ownerName: string?)
	local root = frameOf(plot)
	if not root then
		return
	end
	for _, name in ipairs({ "Predio", "Estacoes", "Oficina", "Skin", "Anexo", "PlacaExpansao" }) do
		local old = plot:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	plot:SetAttribute("Nivel", level)
	buildBuilding(plot, root, level, ownerName)
	rebuildBays(plot, root, level)
	buildStations(plot, root, level)
	syncOwner(plot)
end

function StationService.LevelOf(plot: Instance): number
	return tonumber(plot:GetAttribute("Nivel")) or 0
end

-- Prédios públicos do bairro (Loja de Autopeças e Construtora) ---------------------------------------------------
-- Os blocos lisos de PublicAreas viram colisores invisíveis e ganham uma fachada de verdade (tijolo, vitrine, toldo,
-- letreiro iluminado). A frente é o lado voltado para a rua principal (z = 0).
local function storefront(block: BasePart, title: string, subtitle: string, color: Color3)
	if block.Parent and block.Parent:FindFirstChild("Fachada_" .. block.Name) then
		return
	end
	local m = Instance.new("Model")
	m.Name = "Fachada_" .. block.Name
	local size = block.Size
	local face = block.Position.Z < 0 and 1 or -1 -- direção da rua
	local base = CFrame.lookAt(Vector3.new(block.Position.X, block.Position.Y - size.Y / 2, block.Position.Z),
		Vector3.new(block.Position.X, block.Position.Y - size.Y / 2, block.Position.Z + face))
	-- no referencial `base`, -Z local = rua (LookVector)
	local w, d, h = size.X, size.Z, size.Y
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	part(m, "Parede", Vector3.new(w, h, 1), at(0, h / 2, d / 2 - 0.5), BRICK, Enum.Material.Brick)
	part(m, "ParedeE", Vector3.new(1, h, d), at(-w / 2 + 0.5, h / 2, 0), BRICK, Enum.Material.Brick)
	part(m, "ParedeD", Vector3.new(1, h, d), at(w / 2 - 0.5, h / 2, 0), BRICK, Enum.Material.Brick)
	part(m, "Telhado", Vector3.new(w + 1, 0.8, d + 1), at(0, h + 0.4, 0), ROOF, Enum.Material.Metal)
	part(m, "Platibanda", Vector3.new(w + 1.2, 2.4, 0.8), at(0, h + 1.2, -d / 2), Color3.fromRGB(36, 40, 50), Enum.Material.Metal)
	-- fachada: base de concreto, vitrines com caixilhos e porta
	part(m, "Soco", Vector3.new(w, 1.2, 1), at(0, 0.6, -d / 2 + 0.5), CONCRETE, Enum.Material.Concrete)
	part(m, "Topo", Vector3.new(w, h - 9, 1), at(0, 9 + (h - 9) / 2, -d / 2 + 0.5), PLASTER, Enum.Material.Plaster)
	local panes = math.max(3, math.floor(w / 9))
	local paneW = w / panes
	for i = 1, panes do
		local x = -w / 2 + paneW * (i - 0.5)
		local glass = part(m, "Vidro", Vector3.new(paneW - 0.6, 7.8, 0.3), at(x, 5.1, -d / 2 + 0.5), Color3.fromRGB(140, 190, 220), Enum.Material.Glass)
		glass.Transparency = 0.35
		part(m, "Caixilho", Vector3.new(0.5, 7.8, 0.6), at(-w / 2 + paneW * i, 5.1, -d / 2 + 0.5), Color3.fromRGB(40, 44, 54), Enum.Material.Metal)
	end
	-- toldo listrado e letreiro iluminado
	for i = 0, math.floor(w / 3) - 1 do
		local stripe = part(m, "Toldo", Vector3.new(3, 0.25, 3.4), at(-w / 2 + 1.5 + i * 3, 9.2, -d / 2 - 1.4) * CFrame.Angles(math.rad(-12), 0, 0),
			i % 2 == 0 and color or Color3.fromRGB(245, 245, 245), Enum.Material.Fabric)
		stripe.CanCollide = false
	end
	local sign = part(m, "Letreiro", Vector3.new(math.min(w - 4, 34), 3.2, 0.6), at(0, h - 1.6, -d / 2 - 0.2), Color3.fromRGB(28, 31, 38), Enum.Material.SmoothPlastic)
	local gui = label(sign, Enum.NormalId.Front, "Texto", 26)
	text(gui, "T", UDim2.fromScale(0.03, 0.05), UDim2.fromScale(0.94, 0.6), color, Enum.Font.GothamBlack, title)
	text(gui, "S", UDim2.fromScale(0.03, 0.66), UDim2.fromScale(0.94, 0.3), Color3.new(1, 1, 1), Enum.Font.GothamBold, subtitle)
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Range = 14
	glow.Brightness = 1.4
	glow.Color = color
	glow.Parent = sign
	m.Parent = block.Parent
	-- o bloco antigo vira só colisor (e âncora dos prompts)
	block.Transparency = 1
	for _, d2 in ipairs(block:GetChildren()) do
		if d2:IsA("SurfaceGui") or d2:IsA("Decal") then
			d2:Destroy()
		end
	end
end

local function construtoraBlock(): BasePart?
	local areas = workspace:FindFirstChild("PublicAreas")
	local block = areas and areas:FindFirstChild("DistribuidoraEquipamentos")
	return block and block:IsA("BasePart") and block or nil
end

function StationService.NearConstrutora(player: Player): boolean
	local block = construtoraBlock()
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not block then
		-- Falta do prédio só é tolerada no ambiente de teste do Studio.
		return LocationRules.MissingBlockAllowed(RunService:IsStudio())
	end
	if not hrp or not hrp:IsA("BasePart") then
		return false
	end
	return LocationRules.IsNearBlock(block.CFrame, block.Size, hrp.Position, Config.ShopDistance)
end

local function buildPublicAreas()
	local areas = workspace:FindFirstChild("PublicAreas")
	if not areas then
		return
	end
	local shop = areas:FindFirstChild("LojaAutopecas")
	if shop and shop:IsA("BasePart") then
		storefront(shop, "AUTOPEÇAS 24H", "Peças e equipamentos para a sua oficina", Color3.fromRGB(255, 196, 40))
	end
	local block = construtoraBlock()
	if block then
		storefront(block, "CONSTRUTORA", "Amplie sua oficina: 2, 4 e 6 boxes", Color3.fromRGB(80, 200, 120))
		if not block:FindFirstChild("ConstrutoraPrompt") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "ConstrutoraPrompt"
			prompt.ActionText = "Ampliar oficina"
			prompt.ObjectText = "Construtora"
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = block.Size.Z / 2 + 16 -- medido do centro do prédio: alcança a calçada da frente
			prompt.RequiresLineOfSight = false
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt:SetAttribute("OpensPanel", "construtora")
			prompt.Parent = block
		end
	end
end

-- Montagem inicial de todos os lotes (idempotente): estações, totem, elevadores, tamanho das vagas, placa antiga
-- escondida. Também acompanha a troca de dono para o HUD mostrar os prompts só para quem é dono.
function StationService.Start()
	buildPublicAreas()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local root = frameOf(plot)
		if root then
			local zone = plot:FindFirstChild("ExpansionZone")
			if zone and zone:IsA("BasePart") then
				zone.Transparency = 1
				zone.CanCollide = false
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
			if not plot:FindFirstChild("Predio") then
				StationService.ApplyLevel(plot, 0) -- lote livre mostra a garagem de bairro
			end
			if not plot:FindFirstChild("Totem") then
				buildSign(plot, root)
			end
			plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
				syncOwner(plot)
			end)
			syncOwner(plot)
		end
	end
end

-- Posição (mundo) de uma estação do lote: "Orders" | "Stock" | "Staff".
function StationService.StationPosition(plot: Instance, kind: string): Vector3?
	local root = frameOf(plot)
	local s = (stationSpecs(StationService.LevelOf(plot)) :: any)[kind]
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
