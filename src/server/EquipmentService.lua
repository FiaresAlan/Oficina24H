--!strict
-- EquipmentService: mostra fisicamente no lote os equipamentos que o jogador possui (persistidos em profile.Equipment).
-- Cada equipamento tem um espaço fixo (slot) no pátio do lote. O servidor é o único que cria/remove os modelos.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)

local EquipmentModels = require(script.Parent.EquipmentModels)
local PlotService = require(script.Parent.PlotService)

local EquipmentService = {}

-- Posições no espaço local do prédio (ver shared/Layout): x lateral, z positivo rumo ao fundo, rot = giro em Y (graus).
local SLOTS: { [string]: { x: number, z: number, rot: number } } = Layout.Slots

-- Cópias dos modelos em ReplicatedStorage.EquipmentPreviews para as miniaturas (ViewportFrame) da Loja e do Estoque.
function EquipmentService.PublishPreviews()
	local old = ReplicatedStorage:FindFirstChild("EquipmentPreviews")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "EquipmentPreviews"
	for equipmentId in pairs(SLOTS) do
		local model = EquipmentModels.Has(equipmentId) and EquipmentModels.Build(equipmentId)
		if model then
			model.Name = equipmentId
			model.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
end

function EquipmentService.GetSlot(equipmentId: string): { x: number, z: number, rot: number }?
	return SLOTS[equipmentId]
end

local function equipmentFolder(plot: Folder): Folder
	local f = plot:FindFirstChild("Equipment")
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "Equipment"
	nf.Parent = plot
	return nf
end

local function slotCFrame(plot: Folder, slot: { x: number, z: number, rot: number }): CFrame
	local base = plot:FindFirstChild("Base") :: BasePart
	local side = plot:GetAttribute("Side") :: number
	local floorY = base.Position.Y + base.Size.Y / 2
	-- Mesmo referencial do prédio: lote sul (side=1) fundo é +Z; lote norte (side=-1) é girado 180°, então x também inverte.
	-- A frente do equipamento olha sempre para a rua.
	local world = Vector3.new(base.Position.X + side * slot.x, floorY, base.Position.Z + side * slot.z)
	local facing = side == 1 and math.pi or 0
	return CFrame.new(world) * CFrame.Angles(0, facing + math.rad(slot.rot), 0)
end

-- Cria (se ainda não existe) o modelo de um equipamento no lote. Retorna true se criou agora.
function EquipmentService.Place(plot: Folder, equipmentId: string, animate: boolean?): boolean
	local slot = SLOTS[equipmentId]
	if not slot or not EquipmentModels.Has(equipmentId) then
		return false
	end
	local folder = equipmentFolder(plot)
	if folder:FindFirstChild("Eq_" .. equipmentId) then
		return false
	end
	local model = EquipmentModels.Build(equipmentId)
	if not model then
		return false
	end
	local target = slotCFrame(plot, slot)
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

-- Sincroniza: cria o que o jogador possui e remove o que não possui mais (ex.: item removido do catálogo).
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
	for id, has in pairs(owned) do
		if has then
			EquipmentService.Place(plot, id, false)
		end
	end
end

function EquipmentService.Add(player: Player, equipmentId: string)
	local plot = PlotService.GetPlot(player)
	if plot then
		EquipmentService.Place(plot, equipmentId, true)
	end
end

return EquipmentService
