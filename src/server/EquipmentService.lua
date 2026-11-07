--!strict
-- EquipmentService: mostra fisicamente no lote os equipamentos que o jogador possui (persistidos em profile.Equipment).
-- Ficam na SALA DOS FUNDOS do prédio, um ao lado do outro (shared/WorkshopLevels.EquipmentSlots: mais espaço a cada
-- nível). Cada equipamento (menos o kit de ferramentas, que é de mão) tem o prompt "Usar": o reparo que precisa dele é
-- feito ali, interagindo com a máquina. O servidor é o único que cria/remove os modelos.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local WorkshopLevels = require(ReplicatedStorage.Shared.WorkshopLevels)

local EquipmentModels = require(script.Parent.EquipmentModels)
local PlotService = require(script.Parent.PlotService)
local StationService = require(script.Parent.StationService)

local EquipmentService = {}

local useHandler: ((Player, string) -> ())? = nil

-- Quem trata o "Usar <equipamento>" (WorkshopService.UseEquipment valida dono, ordem, distância...).
function EquipmentService.SetUseHandler(handler: (Player, string) -> ())
	useHandler = handler
end

-- Ordem fixa dos equipamentos na sala dos fundos: kit de ferramentas primeiro, depois do mais barato ao mais caro.
local ORDER: { string } = {}
for id in pairs(Catalog.Equipment) do
	table.insert(ORDER, id)
end
table.sort(ORDER, function(a, b)
	if a == "BasicToolset" or b == "BasicToolset" then
		return a == "BasicToolset"
	end
	local ca, cb = Catalog.Equipment[a].Cost, Catalog.Equipment[b].Cost
	if ca ~= cb then
		return ca < cb
	end
	return a < b
end)
EquipmentService.Order = ORDER

-- Cópias dos modelos em ReplicatedStorage.EquipmentPreviews para as miniaturas (ViewportFrame) da Loja e do Estoque.
function EquipmentService.PublishPreviews()
	local old = ReplicatedStorage:FindFirstChild("EquipmentPreviews")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "EquipmentPreviews"
	for _, equipmentId in ipairs(ORDER) do
		local model = EquipmentModels.Has(equipmentId) and EquipmentModels.Build(equipmentId)
		if model then
			model.Name = equipmentId
			model.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
end

local function equipmentFolder(plot: Instance): Folder
	local f = plot:FindFirstChild("Equipment")
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "Equipment"
	nf.Parent = plot
	return nf
end

-- Índice de cada equipamento possuído na fileira (na ORDER, contando só os que o jogador tem).
local function slotIndexes(owned: { [string]: boolean }): { [string]: number }
	local map, n = {}, 0
	for _, id in ipairs(ORDER) do
		if owned[id] then
			n += 1
			map[id] = n
		end
	end
	return map
end

local function slotCFrame(plot: Instance, index: number): CFrame?
	local root = StationService.FrameOf(plot)
	local slots = WorkshopLevels.EquipmentSlots(StationService.LevelOf(plot))
	local slot = slots[index]
	if not root or not slot then
		return nil
	end
	-- a frente dos modelos de equipamento é +Z: gira 180° para olhar para os boxes (rumo à rua)
	return root * CFrame.new(slot.X, 0.3, slot.Y) * CFrame.Angles(0, math.pi, 0)
end

local function addUsePrompt(plot: Instance, model: Model, equipmentId: string)
	if equipmentId == "BasicToolset" then
		return -- ferramenta de mão: o reparo é no próprio carro
	end
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Usar"
	prompt.ActionText = "Usar"
	prompt.ObjectText = Catalog.Equipment[equipmentId].DisplayName
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("OwnerUserId", plot:GetAttribute("OwnerUserId") or 0)
	prompt:SetAttribute("EquipmentId", equipmentId)
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player: Player)
		if plot:GetAttribute("OwnerUserId") == player.UserId and useHandler then
			useHandler(player, equipmentId)
		end
	end)
end

-- Cria (se ainda não existe) o modelo de um equipamento no lote. Retorna true se criou agora.
function EquipmentService.Place(plot: Instance, equipmentId: string, index: number, animate: boolean?): boolean
	if not EquipmentModels.Has(equipmentId) then
		return false
	end
	local folder = equipmentFolder(plot)
	local target = slotCFrame(plot, index)
	local existing = folder:FindFirstChild("Eq_" .. equipmentId)
	if existing and existing:IsA("Model") then
		if target then
			existing:PivotTo(target) -- o prédio mudou de tamanho: só reposiciona
		end
		return false
	end
	if not target then
		return false -- não cabe no prédio deste nível
	end
	local model = EquipmentModels.Build(equipmentId)
	if not model then
		return false
	end
	model:SetAttribute("EquipmentId", equipmentId)
	addUsePrompt(plot, model, equipmentId)
	if animate then
		-- "Cai do céu" rapidamente: feedback visual de compra.
		model:PivotTo(target + Vector3.new(0, 14, 0))
		model.Parent = folder
		local value = Instance.new("CFrameValue")
		value.Value = model:GetPivot()
		value.Changed:Connect(function(cf)
			if model.Parent then
				model:PivotTo(cf)
			end
		end)
		local tween = TweenService:Create(value, TweenInfo.new(0.55, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Value = target })
		tween:Play()
		tween.Completed:Connect(function()
			value:Destroy()
		end)
	else
		model:PivotTo(target)
		model.Parent = folder
	end
	return true
end

-- Sincroniza: cria o que o jogador possui (na posição do nível atual) e remove o que não possui mais.
function EquipmentService.Sync(player: Player, owned: { [string]: boolean })
	local plot = PlotService.GetPlot(player)
	if not plot then
		return
	end
	local folder = equipmentFolder(plot)
	for _, child in ipairs(folder:GetChildren()) do
		local id = child:GetAttribute("EquipmentId")
		if type(id) ~= "string" or not owned[id] then
			child:Destroy()
		end
	end
	for id, index in pairs(slotIndexes(owned)) do
		EquipmentService.Place(plot, id, index, false)
	end
	StationService.SyncOwner(plot)
end

-- Comprou um equipamento: todos podem mudar de lugar (a ordem é fixa), o novo "cai do céu".
function EquipmentService.Add(player: Player, owned: { [string]: boolean }, equipmentId: string)
	local plot = PlotService.GetPlot(player)
	if not plot then
		return
	end
	local indexes = slotIndexes(owned)
	for id, index in pairs(indexes) do
		EquipmentService.Place(plot, id, index, id == equipmentId)
	end
	StationService.SyncOwner(plot)
end

-- Posição do equipamento instalado no lote (para conferir se o jogador está usando a máquina de perto).
function EquipmentService.Position(plot: Instance, equipmentId: string): Vector3?
	local folder = plot:FindFirstChild("Equipment")
	local model = folder and folder:FindFirstChild("Eq_" .. equipmentId)
	if model and model:IsA("Model") then
		return model:GetPivot().Position
	end
	return nil
end

-- Libera o lote (dono saiu): remove os modelos.
function EquipmentService.Clear(plot: Instance)
	local folder = plot:FindFirstChild("Equipment")
	if folder then
		folder:Destroy()
	end
end

return EquipmentService
