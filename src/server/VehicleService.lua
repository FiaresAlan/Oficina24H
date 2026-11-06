--!strict
-- VehicleService: veículos físicos ligados às ordens de serviço. Cada veículo ocupa uma vaga (BayN) do lote do dono.
-- Capacidade operacional = número de vagas do lote. O servidor é a única autoridade sobre spawn/despawn.
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local PlotService = require(script.Parent.PlotService)
local CustomerNpcService = require(script.Parent.CustomerNpcService)

local VehicleService = {}

local SCALE = 3.5
VehicleService.Scale = SCALE -- também usada pelo carro da rua (CustomerArrivalService)
-- Nome exibido (Catalog.VehicleNames) -> modelo em ServerStorage.Assets.Veiculos.
-- Não há picape nos assets disponíveis; usa o compacto como substituto (limitação registrada em docs/PROGRESSO.md).
local MODEL_FOR_NAME = Catalog.VehicleModels

function VehicleService.GetModelName(vehicleName: string): string
	return MODEL_FOR_NAME[vehicleName] or "Veiculo_Hatch"
end

-- Cópia dos modelos em ReplicatedStorage.VehiclePreviews para as miniaturas (ViewportFrame) do HUD.
-- Criada em tempo de execução a partir de ServerStorage (não duplica nada no arquivo do place).
function VehicleService.PublishPreviews()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local assets = ServerStorage:FindFirstChild("Assets")
	local source = assets and assets:FindFirstChild("Veiculos")
	if not source then
		return
	end
	local folder = ReplicatedStorage:FindFirstChild("VehiclePreviews")
	if folder then
		folder:Destroy()
	end
	local nf = Instance.new("Folder")
	nf.Name = "VehiclePreviews"
	for _, model in ipairs(source:GetChildren()) do
		if model:IsA("Model") then
			model:Clone().Parent = nf
		end
	end
	nf.Parent = ReplicatedStorage
end

local vehiclesFolder: Folder? = nil
local byJob: { [string]: Model } = {}
-- Quem usa o prompt é decidido pelo servidor (Triggered só dispara se o jogador estiver dentro da distância).
local interactionHandler: ((Player, string, string) -> ())? = nil

function VehicleService.SetInteractionHandler(handler: (Player, string, string) -> ())
	interactionHandler = handler
end

-- "Conversar" com o cliente NPC = iniciar o diagnóstico (mesma validação do prompt do carro).
CustomerNpcService.SetTalkHandler(function(player: Player, jobId: string)
	if interactionHandler then
		interactionHandler(player, jobId, "Diagnose")
	end
end)

local function addPrompts(car: Model, job: any)
	local anchor = Instance.new("Part")
	anchor.Name = "InteractPoint"
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	local cf, size = car:GetBoundingBox()
	anchor.Position = cf.Position + Vector3.new(0, size.Y / 2, 0)
	anchor.Parent = car
	local function make(name: string, actionText: string, hold: number)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
		prompt.ActionText = actionText
		prompt.ObjectText = job.VehicleName
		prompt.HoldDuration = hold
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Style = Enum.ProximityPromptStyle.Custom -- o HUD (client/UI/HUD) desenha o prompt contextual
		prompt.Enabled = false
		prompt.Parent = anchor
		prompt.Triggered:Connect(function(player: Player)
			if interactionHandler then
				interactionHandler(player, job.Id, name)
			end
		end)
	end
	make("Diagnose", "Diagnosticar", 1.2)
	make("Repair", "Reparar", 0.5)
end

-- stage: "Diagnose" | "Repair" | "None"
function VehicleService.SetStage(jobId: string, stage: string)
	local car = byJob[jobId]
	local anchor = car and car:FindFirstChild("InteractPoint")
	if not anchor then
		return
	end
	local diagnose = anchor:FindFirstChild("Diagnose")
	local repair = anchor:FindFirstChild("Repair")
	if diagnose and diagnose:IsA("ProximityPrompt") then
		diagnose.Enabled = stage == "Diagnose"
	end
	if repair and repair:IsA("ProximityPrompt") then
		repair.Enabled = stage == "Repair"
	end
	CustomerNpcService.SetDiagnosed(jobId, stage ~= "Diagnose")
end

-- Distância do personagem até o veículo (usada também pelas ações vindas da UI).
function VehicleService.IsNear(player: Player, jobId: string, maxDistance: number): boolean
	local car = byJob[jobId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not car or not root or not root:IsA("BasePart") then
		return false
	end
	local cf, size = car:GetBoundingBox()
	-- distância até a caixa do carro (0 se estiver dentro/encostado), não até o centro
	local rel = cf:PointToObjectSpace(root.Position)
	local half = size / 2
	local dx = math.max(math.abs(rel.X) - half.X, 0)
	local dy = math.max(math.abs(rel.Y) - half.Y, 0)
	local dz = math.max(math.abs(rel.Z) - half.Z, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz) <= maxDistance
end

-- Destaque visual temporário (diagnóstico = azul, reparo concluído = verde).
function VehicleService.Flash(jobId: string, color: Color3)
	local car = byJob[jobId]
	if not car then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.55
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = car
	local tween = TweenService:Create(highlight, TweenInfo.new(1.4), { FillTransparency = 1, OutlineTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		highlight:Destroy()
	end)

	-- Faíscas: explosão curta de partículas sobre o carro, na mesma cor do realce.
	local anchor = car:FindFirstChild("InteractPoint")
	if anchor and anchor:IsA("BasePart") then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = 0
		emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
		emitter.Lifetime = NumberRange.new(0.6, 1.1)
		emitter.Speed = NumberRange.new(12, 24)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, -28, 0)
		emitter.Parent = anchor
		emitter:Emit(45)
		task.delay(1.6, function()
			emitter:Destroy()
		end)
	end
end

local function folder(): Folder
	if not vehiclesFolder then
		local f = workspace:FindFirstChild("Vehicles")
		if not f then
			f = Instance.new("Folder")
			f.Name = "Vehicles"
			f.Parent = workspace
		end
		vehiclesFolder = f :: Folder
	end
	return vehiclesFolder :: Folder
end

local function freeBay(plot: Folder): BasePart?
	local best: BasePart? = nil
	for _, child in ipairs(plot:GetChildren()) do
		if child:IsA("BasePart") and child.Name:match("^Bay%d+$") and child:GetAttribute("JobId") == nil then
			if not best or child.Name < best.Name then
				best = child
			end
		end
	end
	return best
end

function VehicleService.GetFreeBayCount(plot: Folder): number
	local n = 0
	for _, child in ipairs(plot:GetChildren()) do
		if child:IsA("BasePart") and child.Name:match("^Bay%d+$") and child:GetAttribute("JobId") == nil then
			n += 1
		end
	end
	return n
end

function VehicleService.Spawn(owner: Player, job: any): (boolean, string)
	if byJob[job.Id] then
		return true, "Veículo já está na oficina."
	end
	local plot = PlotService.GetPlot(owner)
	if not plot then
		return false, "Você não possui terreno."
	end
	local bay = freeBay(plot)
	if not bay then
		return false, "Não há vaga livre na oficina. Conclua um serviço ou expanda."
	end
	local vehiclesAssets = ServerStorage:FindFirstChild("Assets") and ServerStorage.Assets:FindFirstChild("Veiculos")
	local template = vehiclesAssets and vehiclesAssets:FindFirstChild(MODEL_FOR_NAME[job.VehicleName] or "Veiculo_Hatch")
	if not template or not template:IsA("Model") then
		return false, "Modelo do veículo indisponível."
	end

	-- Reserva a vaga antes de qualquer operação demorada (sem yield até aqui: sem corrida).
	bay:SetAttribute("JobId", job.Id)

	local car = template:Clone()
	car.Name = job.Id
	car:ScaleTo(SCALE)
	local _, size = car:GetBoundingBox()
	-- Eixo longo do carro alinhado ao eixo Z da vaga.
	local rotation = size.X > size.Z and CFrame.Angles(0, math.rad(90), 0) or CFrame.new()
	car:PivotTo(CFrame.new(bay.Position.X, bay.Position.Y + bay.Size.Y / 2 + size.Y / 2, bay.Position.Z) * rotation)
	-- O pivô dos GLB importados não fica no centro: reajusta pelo bounding box real (centro na vaga, base no piso).
	local boxCf, boxSize = car:GetBoundingBox()
	local floorY = bay.Position.Y + bay.Size.Y / 2
	car:PivotTo(car:GetPivot() + Vector3.new(
		bay.Position.X - boxCf.Position.X,
		floorY - (boxCf.Position.Y - boxSize.Y / 2),
		bay.Position.Z - boxCf.Position.Z
	))
	for _, d in ipairs(car:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	car:SetAttribute("JobId", job.Id)
	car:SetAttribute("OwnerUserId", owner.UserId)
	car:SetAttribute("BayName", bay.Name)
	car.Parent = folder()
	byJob[job.Id] = car
	addPrompts(car, job)
	VehicleService.SetStage(job.Id, job.Diagnosed and "Repair" or "Diagnose")
	CustomerNpcService.Spawn(car, job, owner.UserId)
	return true, "Veículo posicionado na " .. bay.Name .. "."
end

function VehicleService.Despawn(jobId: string)
	local car = byJob[jobId]
	if not car then
		return
	end
	byJob[jobId] = nil
	CustomerNpcService.Leave(jobId)
	-- Libera a vaga imediatamente; a animação de saída é só visual.
	local bayName = car:GetAttribute("BayName")
	local plots = workspace:FindFirstChild("Plots")
	if plots and type(bayName) == "string" then
		for _, p in ipairs(plots:GetChildren()) do
			local bay = p:FindFirstChild(bayName)
			if bay and bay:GetAttribute("JobId") == jobId then
				bay:SetAttribute("JobId", nil)
			end
		end
	end
	task.spawn(function()
		local pivot = car:GetPivot()
		local value = Instance.new("CFrameValue")
		value.Value = pivot
		value.Changed:Connect(function(cf)
			if car.Parent then
				car:PivotTo(cf)
			end
		end)
		local tween = TweenService:Create(value, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Value = pivot + Vector3.new(0, 0, -(pivot.Position.Z > 0 and -60 or 60)),
		})
		tween:Play()
		tween.Completed:Wait()
		value:Destroy()
		car:Destroy()
	end)
end

function VehicleService.DespawnOwner(userId: number)
	for jobId, car in pairs(byJob) do
		if car:GetAttribute("OwnerUserId") == userId then
			VehicleService.Despawn(jobId)
		end
	end
end

return VehicleService
