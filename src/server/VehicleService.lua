--!strict
-- VehicleService: veículos físicos ligados às ordens de serviço. Cada veículo ocupa uma vaga (BayN) do lote do dono.
-- Ao aceitar, o PRÓPRIO CLIENTE volta ao volante e entra de frente na vaga; ao terminar, ele dá ré e vai embora pela rua.
-- Os carros seguem a convenção de ServerStorage.Assets.Veiculos: PrimaryPart "Raiz" ancorada no chão (LookVector = frente),
-- peças visuais soldadas e um "Casco" invisível com colisão (o jogador esbarra no carro, não atravessa).
-- Capacidade operacional = número de vagas do lote. O servidor é a única autoridade sobre spawn/despawn.
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local InspectionPointRules = require(game:GetService("ReplicatedStorage").Shared.InspectionPointRules)
local PlotService = require(script.Parent.PlotService)
local CustomerNpcService = require(script.Parent.CustomerNpcService)
local CustomerArrivalService = require(script.Parent.CustomerArrivalService)
local NpcKit = require(script.Parent.NpcKit)
local LotPath = require(script.Parent.LotPath)
local StationService = require(script.Parent.StationService)

local VehicleService = {}

-- Nome exibido (Catalog.VehicleModels) -> modelo em ServerStorage.Assets.Veiculos.
local MODEL_FOR_NAME = Catalog.VehicleModels
local FALLBACK_MODEL = "Veiculo_Hatch_MG3"

function VehicleService.GetModelName(vehicleName: string): string
	return MODEL_FOR_NAME[vehicleName] or FALLBACK_MODEL
end

-- Cópia dos modelos em ReplicatedStorage.VehiclePreviews para as miniaturas (ViewportFrame) do HUD.
-- Criada em tempo de execução a partir de ServerStorage (não duplica nada no arquivo do place). Sem o Casco (só visual).
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
			local copy = model:Clone()
			local hull = copy:FindFirstChild("Casco")
			if hull then
				hull:Destroy()
			end
			copy.Parent = nf
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
	local root = car.PrimaryPart :: BasePart
	local anchor = Instance.new("Part")
	anchor.Name = "InteractPoint"
	anchor.Anchored = false
	anchor.Massless = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	local height = tonumber(car:GetAttribute("Altura")) or 5
	anchor.CFrame = root.CFrame * CFrame.new(0, height + 0.5, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = anchor
	weld.Parent = anchor
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
	make("Repair", "Reparar", 0.5) -- o diagnóstico é conversando com o cliente

	-- Pontos palpáveis do carro: usam a mesma PrimaryPart dos veículos já existentes.
	-- Todos os três existem em qualquer carro, portanto sua presença não revela o defeito secreto.
	local inspectionFolder = Instance.new("Folder")
	inspectionFolder.Name = "InspectionPoints"
	inspectionFolder.Parent = car
	local offsets = InspectionPointRules.Offsets(
		tonumber(car:GetAttribute("Largura")) or 8,
		tonumber(car:GetAttribute("Comprimento")) or 18,
		height
	)
	for _, exam in ipairs(InspectionPointRules.Exams) do
		local point = Instance.new("Part")
		point.Name = "Inspect_" .. exam.Id
		point.Size = Vector3.new(0.5, 0.5, 0.5)
		point.Anchored = false
		point.Massless = true
		point.CanCollide, point.CanQuery, point.CanTouch = false, false, false
		point.Transparency = 1
		point.CFrame = root.CFrame * CFrame.new(offsets[exam.Id])
		point:SetAttribute("ExamId", exam.Id)
		point.Parent = inspectionFolder
		local pointWeld = Instance.new("WeldConstraint")
		pointWeld.Part0 = root
		pointWeld.Part1 = point
		pointWeld.Parent = point
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Inspect_" .. exam.Id
		prompt.ActionText = exam.Action
		prompt.ObjectText = exam.Name .. " · " .. job.VehicleName
		prompt.HoldDuration = 0.35
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.Enabled = false
		prompt.Parent = point
		prompt.Triggered:Connect(function(player: Player)
			if interactionHandler then interactionHandler(player, job.Id, prompt.Name) end
		end)
	end
end

local function applyStage(car: Model)
	local stage = car:GetAttribute("Etapa")
	local parked = car:GetAttribute("Estacionado") == true
	local anchor = car:FindFirstChild("InteractPoint")
	if not anchor then
		return
	end
	local diagnose = anchor:FindFirstChild("Diagnose")
	local repair = anchor:FindFirstChild("Repair")
	if diagnose and diagnose:IsA("ProximityPrompt") then
		diagnose.Enabled = parked and stage == "Diagnose"
	end
	if repair and repair:IsA("ProximityPrompt") then
		repair.Enabled = parked and stage == "Repair"
	end
	local inspectionFolder = car:FindFirstChild("InspectionPoints")
	if inspectionFolder then
		local enabled = parked and stage == "Diagnose" and car:GetAttribute("InspectionReady") == true
		for _, point in ipairs(inspectionFolder:GetChildren()) do
			local prompt = point:FindFirstChildWhichIsA("ProximityPrompt")
			if prompt then prompt.Enabled = enabled end
		end
	end
end

-- stage: "Diagnose" | "Repair" | "None". Os prompts só ligam depois que o carro estaciona.
function VehicleService.SetStage(jobId: string, stage: string)
	local car = byJob[jobId]
	if not car then
		return
	end
	car:SetAttribute("Etapa", stage)
	applyStage(car)
	CustomerNpcService.SetDiagnosed(jobId, stage ~= "Diagnose")
end

-- A conversa com o cliente libera pontos de inspeção físicos no carro, sem revelar a falha verdadeira.
function VehicleService.EnableInspection(jobId: string)
	local car = byJob[jobId]
	if not car then return end
	car:SetAttribute("InspectionReady", true)
	applyStage(car)
end

-- Distância de um exame até sua peça lógica, validada em servidor inclusive para o RemoteEvent.
function VehicleService.IsNearInspectionPoint(player: Player, jobId: string, examId: string): boolean
	if not InspectionPointRules.ExamFromKind("Inspect_" .. examId) then return false end
	local car = byJob[jobId]
	if not car or car:GetAttribute("Estacionado") ~= true then return false end
	local folder = car:FindFirstChild("InspectionPoints")
	local point = folder and folder:FindFirstChild("Inspect_" .. examId)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	return point ~= nil and point:IsA("BasePart")
		and hrp ~= nil and hrp:IsA("BasePart")
		and InspectionPointRules.IsNear(point.Position, hrp.Position, InspectionPointRules.MaxDistance) or false
end

-- Efeito do defeito mostrado no carro (VehicleFx no cliente): "Tires" | "Engine" | "Electrical" | "Suspension" |
-- "Bodywork" | "" (nenhum).
function VehicleService.SetSymptom(jobId: string, specialization: string)
	local car = byJob[jobId]
	if car then
		car:SetAttribute("Sintoma", specialization)
	end
end

local function bayOf(car: Model): BasePart?
	local bayName = car:GetAttribute("BayName")
	local plots = workspace:FindFirstChild("Plots")
	if not plots or type(bayName) ~= "string" then
		return nil
	end
	for _, p in ipairs(plots:GetChildren()) do
		local bay = p:FindFirstChild(bayName)
		if bay and bay:IsA("BasePart") and p:GetAttribute("OwnerUserId") == car:GetAttribute("OwnerUserId") then
			return bay
		end
	end
	return nil
end

-- Reparo em andamento: o carro sobe no elevador do box e o cliente vê o trabalho (pneu sai, capô abre, faíscas...).
function VehicleService.SetRepairing(jobId: string, on: boolean)
	local car = byJob[jobId]
	if not car or car:GetAttribute("Estacionado") ~= true then
		return
	end
	car:SetAttribute("Reparando", on)
	local bay = bayOf(car)
	if bay then
		task.spawn(StationService.Lift, bay, car.PrimaryPart, on)
	end
end

-- Distância do personagem até o veículo ESTACIONADO (usada também pelas ações vindas da UI).
function VehicleService.IsNear(player: Player, jobId: string, maxDistance: number): boolean
	local car = byJob[jobId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not car or not root or not root:IsA("BasePart") or car:GetAttribute("Estacionado") ~= true then
		return false
	end
	local carRoot = car.PrimaryPart :: BasePart
	local length = tonumber(car:GetAttribute("Comprimento")) or 18
	local width = tonumber(car:GetAttribute("Largura")) or 8
	local height = tonumber(car:GetAttribute("Altura")) or 5
	-- distância até a caixa do carro (0 se estiver dentro/encostado), não até o centro
	local rel = carRoot.CFrame:PointToObjectSpace(root.Position) - Vector3.new(0, height / 2, 0)
	local dx = math.max(math.abs(rel.X) - width / 2, 0)
	local dy = math.max(math.abs(rel.Y) - height / 2, 0)
	local dz = math.max(math.abs(rel.Z) - length / 2, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz) <= maxDistance
end

function VehicleService.IsParked(jobId: string): boolean
	local car = byJob[jobId]
	return car ~= nil and car:GetAttribute("Estacionado") == true
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

local function findBay(car: Model): BasePart?
	local bayName = car:GetAttribute("BayName")
	local plots = workspace:FindFirstChild("Plots")
	if not plots or type(bayName) ~= "string" then
		return nil
	end
	for _, p in ipairs(plots:GetChildren()) do
		local bay = p:FindFirstChild(bayName)
		if bay and bay:IsA("BasePart") and car:GetAttribute("OwnerUserId") == p:GetAttribute("OwnerUserId") then
			return bay
		end
	end
	-- lote sem dono registrado (ex.: testes): procura pela marca da ordem
	for _, p in ipairs(plots:GetChildren()) do
		local bay = p:FindFirstChild(bayName)
		local mark = bay and bay:GetAttribute("JobId")
		if bay and bay:IsA("BasePart") and (mark == car:GetAttribute("JobId") or mark == "Saindo_" .. tostring(car:GetAttribute("JobId"))) then
			return bay
		end
	end
	return nil
end

-- Pontos (mundo) da porta do motorista e de onde o cliente espera: atrás do carro, perto do portão.
local function standRoute(car: Model, frame: CFrame): { Vector3 }
	local root = car.PrimaryPart :: BasePart
	local seat = car:GetAttribute("Motorista")
	local seatX = typeof(seat) == "Vector3" and seat.X or -1.5
	local seatZ = typeof(seat) == "Vector3" and seat.Z or 0
	local width = tonumber(car:GetAttribute("Largura")) or 8
	local length = tonumber(car:GetAttribute("Comprimento")) or 18
	local side = seatX >= 0 and 1 or -1
	local points = {
		root.CFrame * Vector3.new(side * (width / 2 + 1.2), 0, seatZ),
		root.CFrame * Vector3.new(side * (width / 2 + 1.2), 0, length / 2 + 2.5),
	}
	for i, p in ipairs(points) do
		local l = frame:PointToObjectSpace(p)
		points[i] = LotPath.Ground(frame, l.X, l.Z)
	end
	return points
end

function VehicleService.Spawn(owner: Player, job: any): (boolean, string)
	if byJob[job.Id] then
		return true, "Veículo já está na oficina."
	end
	local plot = PlotService.GetPlot(owner)
	local frame = plot and LotPath.Frame(plot)
	if not plot or not frame then
		return false, "Você não possui terreno."
	end
	local bay = freeBay(plot)
	if not bay then
		return false, "Não há vaga livre na oficina. Conclua um serviço ou expanda."
	end
	if not CustomerArrivalService.Template(job.VehicleName) then
		return false, "Modelo do veículo indisponível."
	end

	-- Reserva a vaga antes de qualquer operação demorada (sem yield até aqui: sem corrida).
	bay:SetAttribute("JobId", job.Id)
	local bayLocal = frame:PointToObjectSpace(bay.Position)
	local handoff = CustomerArrivalService.Claim(job.Id)
	local path = LotPath.Enter(frame, handoff and handoff.SlotX or nil, bayLocal.X, bayLocal.Z)
	local car: Model?, npc: Model?, animator: NpcKit.NpcAnimator? = nil, nil, nil
	if handoff then
		car, npc, animator = handoff.Car, handoff.Npc, handoff.Animator
	else
		car, npc, animator = CustomerArrivalService.BuildCar(job, CFrame.lookAt(path[1], path[2]), job.Id)
	end
	if not car then
		bay:SetAttribute("JobId", nil)
		return false, "Modelo do veículo indisponível."
	end
	local theCar = car :: Model
	theCar.Name = job.Id
	theCar:SetAttribute("JobId", job.Id)
	theCar:SetAttribute("OwnerUserId", owner.UserId)
	theCar:SetAttribute("BayName", bay.Name)
	theCar:SetAttribute("Estacionado", false)
	theCar:SetAttribute("Vip", job.Vip == true)
	theCar.Parent = folder()
	byJob[job.Id] = theCar
	addPrompts(theCar, job)
	VehicleService.SetStage(job.Id, job.Diagnosed and "Repair" or "Diagnose")

	task.spawn(function()
		local stillMine = function(): boolean
			return byJob[job.Id] == theCar and theCar.Parent ~= nil
		end
		if handoff and handoff.Board and npc and npc.Parent then
			NpcKit.Say(npc, job.Vip and "Cuidado com ele, hein!" or "Beleza! Vou colocar na vaga.", 3)
			NpcKit.WalkPath(npc, handoff.Board, animator)
			if npc.Parent and stillMine() then
				npc.Parent = theCar
				NpcKit.SeatIn(npc, theCar, animator)
			end
		end
		if not stillMine() then
			if npc and npc.Parent and npc.Parent ~= theCar then
				npc:Destroy() -- ordem cancelada enquanto ele voltava ao carro: não fica NPC órfão na calçada
			end
			return
		end
		LotPath.Drive(theCar.PrimaryPart :: BasePart, path, LotPath.YardSpeed)
		if not stillMine() then
			return
		end
		theCar:SetAttribute("Estacionado", true)
		if npc and npc.Parent then
			local route = standRoute(theCar, frame)
			npc.Parent = folder()
			NpcKit.Unseat(npc, route[1], route[2])
			NpcKit.WalkPath(npc, { route[2] }, animator)
			if npc.Parent and stillMine() then
				local root = theCar.PrimaryPart :: BasePart
				NpcKit.Place(npc, route[2], route[2] - root.CFrame.LookVector * 5) -- de frente para o portão
				NpcKit.ServerOwned(npc)
				CustomerNpcService.Adopt(npc, animator, job, owner.UserId)
			elseif npc.Parent then
				npc:Destroy()
			end
		end
		applyStage(theCar)
	end)
	return true, (job.CustomerName and (tostring(job.CustomerName) .. " está levando o carro para a ") or "Veículo indo para a ") .. bay.Name .. "."
end

-- `instant` = some na hora (dono saiu). Senão o cliente volta ao volante, dá ré e vai embora pela rua.
function VehicleService.Despawn(jobId: string, instant: boolean?)
	local car = byJob[jobId]
	if not car then
		return
	end
	byJob[jobId] = nil
	local npc, animator = CustomerNpcService.Take(jobId)
	local bay = findBay(car)
	local plot = bay and bay.Parent
	local frame = plot and LotPath.Frame(plot)
	local anchor = car:FindFirstChild("InteractPoint")
	if anchor then
		for _, prompt in ipairs(anchor:GetChildren()) do
			if prompt:IsA("ProximityPrompt") then
				prompt:Destroy()
			end
		end
	end
	if instant or not bay or not frame or car:GetAttribute("Estacionado") ~= true then
		if bay and bay:GetAttribute("JobId") == jobId then
			bay:SetAttribute("JobId", nil)
		end
		if bay and StationService.IsBusy(bay) then
			task.spawn(StationService.Lift, bay, nil, false)
		end
		if npc then
			npc:Destroy()
		end
		car:Destroy()
		return
	end
	-- A vaga fica marcada até o carro sair dela (outro carro não entra por cima).
	local mark = "Saindo_" .. jobId
	local theBay = bay :: BasePart
	local theFrame = frame :: CFrame
	theBay:SetAttribute("JobId", mark)
	local function release()
		if theBay:GetAttribute("JobId") == mark then
			theBay:SetAttribute("JobId", nil)
		end
	end
	task.delay(30, release) -- segurança: nunca prende a vaga
	car:SetAttribute("Reparando", false)
	car:SetAttribute("Sintoma", "")
	task.spawn(function()
		if StationService.IsBusy(theBay) then
			StationService.Lift(theBay, car.PrimaryPart, false) -- desce do elevador antes de sair
		end
		if npc and npc.Parent then
			NpcKit.Say(npc, "Valeu! Ficou ótimo.", 3)
			local route = standRoute(car, theFrame)
			NpcKit.WalkPath(npc, { route[2], route[1] }, animator)
			if npc.Parent and car.Parent then
				npc.Parent = car
				NpcKit.SeatIn(npc, car, animator)
			end
		end
		if not car.Parent then
			release()
			return
		end
		task.wait(0.4)
		local bayLocal = theFrame:PointToObjectSpace(theBay.Position)
		local root = car.PrimaryPart :: BasePart
		local back, offFromX = LotPath.BackOut(theFrame, bayLocal.X, bayLocal.Z)
		LotPath.Drive(root, back, LotPath.YardSpeed * 0.7, true)
		release()
		if car.Parent then
			task.wait(0.3)
			LotPath.Drive(root, LotPath.DriveOff(theFrame, offFromX), LotPath.StreetSpeed)
		end
		car:Destroy()
	end)
end

function VehicleService.DespawnOwner(userId: number)
	for jobId, car in pairs(byJob) do
		if car:GetAttribute("OwnerUserId") == userId then
			VehicleService.Despawn(jobId, true)
		end
	end
end

return VehicleService
