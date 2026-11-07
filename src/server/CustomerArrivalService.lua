--!strict
-- CustomerArrivalService: chegada do cliente. Ele vem DIRIGINDO o próprio carro pela rua, encosta no meio-fio em frente
-- à oficina, desce e espera na calçada (balão com a reclamação). A ordem só ABRE quando ele está na calçada, e é aceita
-- na TV de ordens dentro da oficina (StationService). WorkshopService usa o tempo de Arrive() como `ArrivesAt`.
-- Ao aceitar, Claim() entrega carro e cliente ao VehicleService, que o leva de volta ao volante e entra na vaga.
-- Se for dispensado ou cansar de esperar (Depart), ele volta ao carro e vai embora pela rua.
-- O cliente nunca anda até a entrada do lote (nada de enroscar em placas): só contorna o próprio carro.
-- Servidor é a única autoridade; o cliente só vê objetos replicados.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local PlotService = require(script.Parent.PlotService)
local NpcKit = require(script.Parent.NpcKit)
local LotPath = require(script.Parent.LotPath)

local CustomerArrivalService = {}

export type Handoff = {
	Car: Model,
	Npc: Model?,
	Animator: NpcKit.NpcAnimator?,
	SlotX: number,
	Board: { Vector3 }?, -- caminho da calçada até a porta do motorista (nil = já está ao volante)
}

type State = {
	JobId: string,
	OwnerUserId: number,
	Slot: number,
	SlotX: number,
	Frame: CFrame,
	Phase: string, -- "Arriving" | "Waiting"
	Car: Model?,
	Npc: Model?,
	Animator: NpcKit.NpcAnimator?,
	Job: any,
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

-- Carros que já saíram do controle desta cena mas ainda estão parados no meio-fio (cliente voltando ao volante).
local lingering: { [string]: { Car: Model, At: Vector3 } } = {}

local function linger(state: State)
	local car = state.Car
	if car and car.PrimaryPart then
		lingering[state.OwnerUserId .. ":" .. state.Slot] = { Car = car, At = car.PrimaryPart.Position }
	end
end

local function freeSlot(ownerUserId: number): number?
	for slot = 1, #LotPath.SlotX do
		local used = false
		for _, state in pairs(states) do
			if state.OwnerUserId == ownerUserId and state.Slot == slot then
				used = true
			end
		end
		local key = ownerUserId .. ":" .. slot
		local still = lingering[key]
		if still then
			local root = still.Car.PrimaryPart
			if still.Car.Parent and root and (root.Position - still.At).Magnitude < 12 then
				used = true -- o carro ainda não saiu da vaga do meio-fio
			else
				lingering[key] = nil
			end
		end
		if not used then
			return slot
		end
	end
	return nil
end

function CustomerArrivalService.Template(vehicleName: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local vehicles = assets and assets:FindFirstChild("Veiculos")
	local template = vehicles and vehicles:FindFirstChild(Catalog.VehicleModels[vehicleName] or "")
	if template and template:IsA("Model") and template.PrimaryPart then
		return template
	end
	return nil
end

-- Pontos (mundo) da porta do motorista e do caminho até a calçada, para o carro parado no meio-fio.
-- O carro estacionado aponta para +X do lote; o lado direito do carro (+X da Raiz) é o da calçada.
local function doorPoint(car: Model): (Vector3, number)
	local root = car.PrimaryPart :: BasePart
	local seat = car:GetAttribute("Motorista")
	local seatX = typeof(seat) == "Vector3" and seat.X or -1.5
	local seatZ = typeof(seat) == "Vector3" and seat.Z or 0
	local width = tonumber(car:GetAttribute("Largura")) or 8
	local side = seatX >= 0 and 1 or -1
	return root.CFrame * Vector3.new(side * (width / 2 + 1.6), 0, seatZ), side
end

local function sidewalkRoute(state: State, car: Model): { Vector3 }
	local root = car.PrimaryPart :: BasePart
	local door, side = doorPoint(car)
	local width = tonumber(car:GetAttribute("Largura")) or 8
	local length = tonumber(car:GetAttribute("Comprimento")) or 18
	local route = { door }
	if side < 0 then
		-- motorista do lado da rua: contorna pela frente do carro
		table.insert(route, root.CFrame * Vector3.new(-(width / 2 + 1.6), 0, -(length / 2 + 2.2)))
		table.insert(route, root.CFrame * Vector3.new(width / 2 + 1.6, 0, -(length / 2 + 2.2)))
	end
	table.insert(route, LotPath.Ground(state.Frame, state.SlotX + 2, LotPath.CurbZ))
	for i, p in ipairs(route) do
		local local3 = state.Frame:PointToObjectSpace(p)
		route[i] = LotPath.Ground(state.Frame, local3.X, local3.Z)
	end
	return route
end

local function reverseRoute(route: { Vector3 }): { Vector3 }
	local out = {}
	for i = #route, 1, -1 do
		table.insert(out, route[i])
	end
	return out
end

local function removePrompt(npc: Model?)
	local anchor = npc and npc:FindFirstChild("HumanoidRootPart")
	local prompt = anchor and anchor:FindFirstChild("Atender")
	if prompt then
		prompt:Destroy()
	end
end

-- Clona o carro com o cliente ao volante, pronto para andar (Raiz em `cf`).
function CustomerArrivalService.BuildCar(job: any, cf: CFrame, name: string): (Model?, Model?, NpcKit.NpcAnimator?)
	local template = CustomerArrivalService.Template(job.VehicleName)
	if not template then
		return nil, nil, nil
	end
	local car = template:Clone()
	car.Name = name
	car:PivotTo(cf)
	car:SetAttribute("JobId", job.Id)
	car.Parent = folder()
	local npc = NpcKit.Clone(job.CustomerGender, tostring(job.CustomerName), "Cliente_" .. job.Id)
	local animator: NpcKit.NpcAnimator? = nil
	if npc then
		npc:SetAttribute("JobId", job.Id)
		npc:SetAttribute("OwnerUserId", job.OwnerUserId)
		npc.Parent = car
		animator = NpcKit.Animate(npc)
		NpcKit.SeatIn(npc, car, animator)
		NpcKit.NameTag(npc, tostring(job.CustomerName), job.Vip == true)
	end
	return car, npc, animator
end

-- Começa a chegada de um cliente (job: Id, OwnerUserId, VehicleName, CustomerName, CustomerGender, Complaint, Vip).
-- Retorna os segundos até ele estar na calçada (0 = sem cena: o cliente conta como já chegado).
function CustomerArrivalService.Arrive(job: any): number
	local owner = Players:GetPlayerByUserId(job.OwnerUserId)
	local plot = owner and PlotService.GetPlot(owner)
	local frame = plot and LotPath.Frame(plot)
	if not frame or states[job.Id] then
		return 0
	end
	local slot = freeSlot(job.OwnerUserId)
	if not slot or not CustomerArrivalService.Template(job.VehicleName) then
		return 0
	end
	local slotX = LotPath.SlotX[slot]
	local path = LotPath.Arrival(frame, slotX)
	local state: State = {
		JobId = job.Id,
		OwnerUserId = job.OwnerUserId,
		Slot = slot,
		SlotX = slotX,
		Frame = frame,
		Phase = "Arriving",
		Job = job,
	}
	states[job.Id] = state
	local eta = LotPath.Duration(path, LotPath.StreetSpeed) + 3.5

	task.spawn(function()
		local first, second = path[1], path[2]
		local car, npc, animator = CustomerArrivalService.BuildCar(job, CFrame.lookAt(first, second), "CarroRua_" .. job.Id)
		if not car then
			states[job.Id] = nil
			return
		end
		state.Car, state.Npc, state.Animator = car, npc, animator
		LotPath.Drive(car.PrimaryPart :: BasePart, path, LotPath.StreetSpeed)
		if states[job.Id] ~= state then
			return -- cancelado durante a chegada (quem cancelou já cuidou do que existia)
		end
		if npc then
			task.wait(0.4)
			if states[job.Id] ~= state or not car.Parent or not car.PrimaryPart then
				return
			end
			local route = sidewalkRoute(state, car)
			npc.Parent = folder()
			NpcKit.Unseat(npc, route[1], route[2] or route[1])
			NpcKit.WalkPath(npc, route, animator)
			if states[job.Id] ~= state or not npc.Parent then
				return
			end
			local feet = route[#route]
			NpcKit.Place(npc, feet, feet + state.Frame.LookVector * -6) -- olha para a oficina (+Z do lote)
			NpcKit.ServerOwned(npc)
			if animator then
				animator.Idle()
			end
			state.Phase = "Waiting"
			local greeting = job.Regular and "Voltei! Só confio em você. " or (job.Referral and "Me indicaram sua oficina! " or "")
			NpcKit.Say(npc, greeting .. tostring(job.Complaint or "Olá! Pode olhar meu carro?"), nil,
				job.Vip and Color3.fromRGB(255, 200, 40) or (job.Regular and Color3.fromRGB(240, 90, 130) or nil))
			-- aceitar é só pela TV de ordens dentro da oficina (pedido do PO); aqui o cliente só espera
		else
			state.Phase = "Waiting"
		end
	end)
	return eta
end

-- O jogador aceitou a ordem: entrega carro e cliente (que ainda está na calçada) para entrar na vaga.
-- Retorna nil se a cena ainda não terminou (o VehicleService então traz o carro direto da rua).
function CustomerArrivalService.Claim(jobId: string): Handoff?
	local state = states[jobId]
	if not state then
		return nil
	end
	states[jobId] = nil
	removePrompt(state.Npc)
	local car = state.Car
	if state.Phase ~= "Waiting" or not car or not car.Parent then
		if state.Npc then
			state.Npc:Destroy()
		end
		if car then
			car:Destroy()
		end
		return nil
	end
	linger(state)
	local npc = state.Npc
	local board = nil
	if npc and npc.Parent then
		board = reverseRoute(sidewalkRoute(state, car)) -- caminho de volta ao volante (quem recebe faz a caminhada)
	end
	return { Car = car, Npc = npc, Animator = state.Animator, SlotX = state.SlotX, Board = board }
end

-- Dispensado ou cansou de esperar: o cliente volta ao carro e vai embora pela rua.
function CustomerArrivalService.Depart(jobId: string)
	local state = states[jobId]
	if not state then
		return
	end
	states[jobId] = nil
	removePrompt(state.Npc)
	local car, npc = state.Car, state.Npc
	if state.Phase ~= "Waiting" then
		-- ainda chegando: o laço de Arrive move o carro; some na hora para não haver dois comandos no mesmo carro
		if npc then
			npc:Destroy()
		end
		if car then
			car:Destroy()
		end
		return
	end
	linger(state)
	task.spawn(function()
		if npc and npc.Parent and car and car.Parent then
			NpcKit.Say(npc, "Que pena... até mais!", 2.5)
			NpcKit.WalkPath(npc, reverseRoute(sidewalkRoute(state, car)), state.Animator)
			if npc.Parent then
				npc.Parent = car
				NpcKit.SeatIn(npc, car, state.Animator)
			end
		end
		if car and car.Parent then
			LotPath.Drive(car.PrimaryPart :: BasePart, LotPath.LeaveCurb(state.Frame, state.SlotX), LotPath.StreetSpeed)
			car:Destroy()
		end
		if npc and npc.Parent then
			npc:Destroy()
		end
	end)
end

-- Dono saiu: limpa tudo dele na hora, sem animação.
function CustomerArrivalService.Clear(ownerUserId: number)
	for jobId, state in pairs(states) do
		if state.OwnerUserId == ownerUserId then
			states[jobId] = nil
			if state.Npc then
				state.Npc:Destroy()
			end
			if state.Car then
				state.Car:Destroy()
			end
		end
	end
end

-- O cliente já está na calçada esperando (a ordem pode ser aceita mesmo que o relógio de ArrivesAt arredonde para cima).
function CustomerArrivalService.IsWaiting(jobId: string): boolean
	local state = states[jobId]
	return state ~= nil and state.Phase == "Waiting"
end

-- O cliente ainda está chegando (dirigindo ou descendo do carro): a ordem não pode ser aceita nem dispensada.
function CustomerArrivalService.IsArriving(jobId: string): boolean
	local state = states[jobId]
	return state ~= nil and state.Phase ~= "Waiting"
end

function CustomerArrivalService.Count(): number
	local n = 0
	for _ in pairs(states) do
		n += 1
	end
	return n
end

return CustomerArrivalService
