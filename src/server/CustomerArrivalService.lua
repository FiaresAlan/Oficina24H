--!strict
-- CustomerArrivalService: chegada VISUAL do cliente. O carro entra pela rua e para no meio-fio em frente à oficina, o cliente
-- desce, atravessa a calçada com animação de caminhada e espera na entrada do lote. A ordem só ABRE (aparece na lista e pode
-- ser aceita) quando ele chega: WorkshopService usa o tempo estimado devolvido por Arrive() como `ArrivesAt`.
-- O carro da rua é só cenário (não dirige de verdade, sem colisão). Ao aceitar (Claim) o carro vai embora e o cliente "entra";
-- se for dispensado ou cansar de esperar (Depart) o cliente volta ao carro e os dois vão embora.
-- Servidor é a única autoridade; o cliente só vê objetos replicados (não existe NPC sem ordem).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage")

local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local PlotService = require(script.Parent.PlotService)
local VehicleService = require(script.Parent.VehicleService)
local NpcKit = require(script.Parent.NpcKit)

local CustomerArrivalService = {}

local ROAD_TOP = 0.4 -- topo do asfalto
local LANE_Z = 10 -- faixa do lado do lote (a rua principal vai de z=-20 a z=20)
local SIDEWALK_Z = 24
local DRIVE_DISTANCE = 130
local DRIVE_SECONDS = 3.5
local CAR_FLIP = 0 -- 0 ou math.pi: ajusta a frente do modelo (conferido no teste visual)
local SLOT_SHIFT = { 0, 20, -20 } -- até 3 clientes por oficina, lado a lado no meio-fio

type State = {
	JobId: string,
	OwnerUserId: number,
	Slot: number,
	Phase: string, -- "Arriving" | "Waiting"
	Car: Model?,
	Root: BasePart?,
	Npc: Model?,
	Animator: NpcKit.NpcAnimator?,
	ParkCf: CFrame,
	AwayCf: CFrame,
	ExitPoint: Vector3,
	DoorPoint: Vector3,
	Interior: Vector3, -- direção do interior do lote (para o cliente olhar para dentro)
}

local states: { [string]: State } = {}

local function folder(): Folder
	local f = workspace:FindFirstChild("Arrivals")
	if not f then
		local created = Instance.new("Folder")
		created.Name = "Arrivals"
		created.Parent = workspace
		return created
	end
	return f :: Folder
end

local function freeSlot(ownerUserId: number): number?
	for slot = 1, #SLOT_SHIFT do
		local used = false
		for _, state in pairs(states) do
			if state.OwnerUserId == ownerUserId and state.Slot == slot then
				used = true
			end
		end
		if not used then
			return slot
		end
	end
	return nil
end

local function buildCar(template: Model, cf: CFrame): (Model, BasePart)
	local car = template:Clone()
	car:ScaleTo(VehicleService.Scale)
	local _, size = car:GetBoundingBox()
	local yaw = (size.Z > size.X and math.rad(90) or 0) + CAR_FLIP -- eixo longo ao longo da rua (X)
	car:PivotTo(CFrame.Angles(0, yaw, 0))
	local boxCf, boxSize = car:GetBoundingBox()
	car:PivotTo(car:GetPivot() + Vector3.new(-boxCf.Position.X, -(boxCf.Position.Y - boxSize.Y / 2), -boxCf.Position.Z))
	local root = Instance.new("Part")
	root.Name = "ArrivalRoot"
	root.Anchored = true
	root.CanCollide, root.CanQuery, root.CanTouch = false, false, false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new(0, 0, 0)
	root.Parent = car
	for _, d in ipairs(car:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
			d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = root
		end
	end
	car.PrimaryPart = root
	car:PivotTo(cf)
	return car, root
end

local function tweenRoot(root: BasePart, target: CFrame, seconds: number, style: Enum.EasingStyle, direction: Enum.EasingDirection)
	local tween = TweenService:Create(root, TweenInfo.new(seconds, style, direction), { CFrame = target })
	tween:Play()
	tween.Completed:Wait()
end

local function destroyVisuals(state: State)
	if state.Npc then
		state.Npc:Destroy()
		state.Npc = nil
	end
	if state.Car then
		state.Car:Destroy()
		state.Car = nil
	end
end

local function driveAwayAndDestroy(state: State)
	local car, root = state.Car, state.Root
	state.Car, state.Root = nil, nil
	if not car or not root then
		return
	end
	task.spawn(function()
		if root.Parent then
			tweenRoot(root, state.AwayCf, DRIVE_SECONDS - 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		car:Destroy()
	end)
end

-- Começa a chegada de um cliente (job: Id, OwnerUserId, VehicleName, CustomerName, Complaint).
-- Retorna os segundos até ele chegar à entrada (0 = sem cena: o cliente conta como já chegado).
function CustomerArrivalService.Arrive(job: any): number
	local owner = Players:GetPlayerByUserId(job.OwnerUserId)
	local plot = owner and PlotService.GetPlot(owner)
	local entry = plot and plot:FindFirstChild("Entry")
	if not plot or not entry or not entry:IsA("BasePart") or states[job.Id] then
		return 0
	end
	local slot = freeSlot(job.OwnerUserId)
	local assets = ServerStorage:FindFirstChild("Assets")
	local vehicles = assets and assets:FindFirstChild("Veiculos")
	local template = vehicles and vehicles:FindFirstChild(Catalog.VehicleModels[job.VehicleName] or "Veiculo_Hatch")
	if not slot or not template or not template:IsA("Model") or not NpcKit.Pick(tostring(job.CustomerName)) then
		return 0
	end

	local dir = entry.Position.Z >= 0 and 1 or -1 -- lado do lote em relação à rua (z do lote tem o mesmo sinal)
	local shift = SLOT_SHIFT[slot]
	local parkX = entry.Position.X + shift
	local parkCf = CFrame.new(parkX, ROAD_TOP, dir * LANE_Z)
	local fromX = parkX + DRIVE_DISTANCE
	local state: State = {
		JobId = job.Id,
		OwnerUserId = job.OwnerUserId,
		Slot = slot,
		Phase = "Arriving",
		ParkCf = parkCf,
		AwayCf = CFrame.new(parkX - DRIVE_DISTANCE, ROAD_TOP, dir * LANE_Z),
		ExitPoint = Vector3.new(parkX, ROAD_TOP, dir * (LANE_Z + 4.5)),
		DoorPoint = Vector3.new(entry.Position.X + shift, entry.Position.Y + entry.Size.Y / 2, entry.Position.Z - dir * 2),
		Interior = Vector3.new(0, 0, dir),
	}
	states[job.Id] = state

	local walkDistance = ((state.DoorPoint - state.ExitPoint) * Vector3.new(1, 0, 1)).Magnitude
	local eta = DRIVE_SECONDS + 0.6 + walkDistance / NpcKit.WalkSpeed + 0.4

	task.spawn(function()
		local car, root = buildCar(template, CFrame.new(fromX, ROAD_TOP, dir * LANE_Z))
		car.Name = "CarroRua_" .. job.Id
		car.Parent = folder()
		state.Car, state.Root = car, root
		tweenRoot(root, parkCf, DRIVE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.wait(0.6)
		if states[job.Id] ~= state then
			return -- cancelado durante a chegada (quem cancelou já cuidou do que existia)
		end

		local npc = NpcKit.Clone(tostring(job.CustomerName), "ClienteRua_" .. job.Id)
		if not npc then
			state.Phase = "Waiting"
			return
		end
		NpcKit.Place(npc, state.ExitPoint, state.DoorPoint)
		npc.Parent = folder()
		NpcKit.ServerOwned(npc)
		state.Npc = npc
		local animator = NpcKit.Animate(npc)
		state.Animator = animator
		animator.Walk()
		local arrived = NpcKit.WalkTo(npc, state.DoorPoint, 14)
		if states[job.Id] ~= state or not npc.Parent then
			return
		end
		if not arrived then
			NpcKit.Place(npc, state.DoorPoint, state.DoorPoint + state.Interior) -- travou: teletransporta (a ordem já abriu)
		else
			NpcKit.Place(npc, state.DoorPoint, state.DoorPoint + state.Interior)
		end
		animator.Idle()
		NpcKit.ServerOwned(npc)
		state.Phase = "Waiting"
		NpcKit.Say(npc, tostring(job.Complaint or "Olá! Pode olhar meu carro?"), nil)
	end)
	return eta
end

-- O jogador aceitou a ordem: o carro da rua vai embora (o carro entra na vaga) e o cliente entra na oficina.
function CustomerArrivalService.Claim(jobId: string)
	local state = states[jobId]
	if not state then
		return
	end
	states[jobId] = nil
	if state.Npc then
		NpcKit.FadeOut(state.Npc, 0.5)
		state.Npc = nil
	end
	driveAwayAndDestroy(state)
end

-- Dispensado ou cansou de esperar: o cliente volta ao carro e os dois vão embora.
function CustomerArrivalService.Depart(jobId: string)
	local state = states[jobId]
	if not state then
		return
	end
	states[jobId] = nil
	local npc = state.Npc
	if not npc or state.Phase ~= "Waiting" then
		if npc then
			NpcKit.FadeOut(npc, 0.4)
		end
		state.Npc = nil
		driveAwayAndDestroy(state)
		return
	end
	state.Npc = nil
	task.spawn(function()
		NpcKit.Say(npc, "Que pena... até mais!", 2.5)
		local animator = state.Animator
		if animator then
			animator.Walk()
		end
		NpcKit.WalkTo(npc, state.ExitPoint, 8)
		NpcKit.FadeOut(npc, 0.4)
		driveAwayAndDestroy(state)
	end)
end

-- Dono saiu: limpa tudo dele na hora, sem animação.
function CustomerArrivalService.Clear(ownerUserId: number)
	for jobId, state in pairs(states) do
		if state.OwnerUserId == ownerUserId then
			states[jobId] = nil
			destroyVisuals(state)
		end
	end
end

function CustomerArrivalService.Count(): number
	local n = 0
	for _ in pairs(states) do
		n += 1
	end
	return n
end

return CustomerArrivalService
