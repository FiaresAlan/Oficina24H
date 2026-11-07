--!strict
-- RivalService: oficinas rivais controladas pelo servidor (NPC) para o bairro nunca parecer vazio no começo do jogo.
-- Cada rival ocupa um lote livre (OwnerUserId = -1, OwnerName = nome do dono), tem placa 3D, fachada do tipo certo,
-- clientes chegando de carro, mecânico trabalhando e estatísticas que crescem. Também DISPUTA clientes no mercado
-- (WorkshopService.DispatchCustomers) e aparece no ranking e no painel da praça.
-- Nunca ocupa todos os lotes: sempre sobram Config.RivalKeepFreePlots livres; quando um jogador entra e faltaria lote,
-- um rival "vende o terreno" e sai na hora.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local CustomerRules = require(ReplicatedStorage.Shared.CustomerRules)
local WorkshopLevels = require(ReplicatedStorage.Shared.WorkshopLevels)
local StationService = require(script.Parent.StationService)
local CustomerArrivalService = require(script.Parent.CustomerArrivalService)
local NpcKit = require(script.Parent.NpcKit)
local LotPath = require(script.Parent.LotPath)

local RivalService = {}

local OWNER_NAMES = {
	"Juninho_BR", "GuiMecanico", "LariTurbo", "Pedrao2011", "BiaMotors", "KauanRacing", "Thiaguinho_07", "MariGarage",
	"RafaZin", "Dudu_V8", "NatyCar", "BrunoTuning", "Leh_Oficina", "Matheus_RPM", "Carol_Pista", "Vitinho_Drift",
}

export type Rival = {
	Id: number,
	Name: string, -- nome do "dono"
	Plot: Instance,
	Reputation: number,
	TotalEarned: number,
	RatingSum: number,
	RatingCount: number,
	Price: number,
	SpecLevel: number,
	Busy: { [string]: boolean }, -- vagas ocupadas por carros de cliente
	Mechanic: Model?,
}

local rivals: { Rival } = {}
local nextId = 0
local nextJob = 0

local function plotsFolder(): Instance?
	return workspace:FindFirstChild("Plots")
end

local function usedNames(): { [string]: boolean }
	local used = {}
	for _, r in ipairs(rivals) do
		used[r.Name] = true
	end
	for _, p in ipairs(Players:GetPlayers()) do
		used[p.DisplayName] = true
	end
	return used
end

local function rating(r: Rival): number
	return CustomerRules.AverageRating(r.RatingSum, r.RatingCount)
end

local function tierColor(tier: number): Color3
	return tier >= 3 and Color3.fromRGB(255, 196, 70) or tier == 2 and Color3.fromRGB(70, 190, 255) or Color3.fromRGB(255, 196, 40)
end

local function refreshSign(r: Rival, rank: number?)
	local tier, tierName = Catalog.WorkshopTier(r.TotalEarned)
	StationService.SetSign(r.Plot, {
		Title = string.upper(tierName),
		Name = "OFICINA DE " .. string.upper(r.Name),
		Line1 = string.format("Nível %d  ·  ★ %.1f (%d avaliações)", Catalog.BusinessLevel(r.TotalEarned), rating(r), r.RatingCount),
		Line2 = string.format("Clientes atendidos: %d  ·  Rep. %d", r.RatingCount, r.Reputation),
		Line3 = rank and string.format("#%d no servidor", rank) or "Aberta 24 horas",
		Color = tierColor(tier),
	})
	-- mesmo critério dos jogadores: o nível do prédio acompanha o nível da oficina (faturamento)
	local business = Catalog.BusinessLevel(r.TotalEarned)
	local level = 0
	for candidate = 1, WorkshopLevels.MaxLevel do
		if business >= WorkshopLevels.Levels[candidate].MinBusinessLevel then
			level = candidate
		end
	end
	local _ = tier
	if StationService.LevelOf(r.Plot) ~= level and next(r.Busy) == nil then
		StationService.ApplyLevel(r.Plot, level, r.Name) -- prédio do rival cresce com o faturamento
	end
end

-- Mecânico do rival: fica em pé perto do portão; vai até o carro enquanto trabalha.
local function spawnMechanic(r: Rival)
	local root = StationService.FrameOf(r.Plot)
	if not root or r.Mechanic then
		return
	end
	local gender = math.random(1, 2) == 1 and "M" or "F"
	local npc = NpcKit.Clone(gender, r.Name .. "_mec", "Mecanico_Rival_" .. r.Id)
	if not npc then
		return
	end
	local feet = LotPath.Ground(root, 10, 2)
	npc.Parent = r.Plot
	NpcKit.Place(npc, feet, feet + root.LookVector * -5)
	NpcKit.ServerOwned(npc)
	NpcKit.Animate(npc).Idle()
	r.Mechanic = npc
end

local function occupy(plot: Instance)
	nextId += 1
	local used = usedNames()
	local free = {}
	for _, n in ipairs(OWNER_NAMES) do
		if not used[n] then
			table.insert(free, n)
		end
	end
	local name = #free > 0 and free[math.random(1, #free)] or ("Mecanico" .. nextId)
	local earned = math.random(4, 70) * 100
	local count = math.random(6, 60)
	local r: Rival = {
		Id = nextId,
		Name = name,
		Plot = plot,
		Reputation = math.random(5, 70),
		TotalEarned = earned,
		RatingSum = math.floor(count * (3.9 + math.random() * 1.0)),
		RatingCount = count,
		Price = 0.85 + math.random() * 0.35,
		SpecLevel = math.random(1, 4),
		Busy = {},
		Mechanic = nil,
	}
	plot:SetAttribute("OwnerUserId", -1)
	plot:SetAttribute("OwnerName", name)
	plot:SetAttribute("RivalId", r.Id)
	table.insert(rivals, r)
	refreshSign(r, nil)
	spawnMechanic(r)
end

local function evict(r: Rival)
	local index = table.find(rivals, r)
	if index then
		table.remove(rivals, index)
	end
	if r.Mechanic then
		r.Mechanic:Destroy()
		r.Mechanic = nil
	end
	local arrivals = workspace:FindFirstChild("Arrivals")
	for _, c in ipairs(arrivals and arrivals:GetChildren() or {}) do
		if c:GetAttribute("RivalId") == r.Id then
			c:Destroy()
		end
	end
	for i = 1, 6 do
		local bay = r.Plot:FindFirstChild("Bay" .. i)
		if bay and bay:IsA("BasePart") and StationService.IsBusy(bay) then
			task.spawn(StationService.Lift, bay, nil, false)
		end
	end
	StationService.ApplyLevel(r.Plot, 0)
	r.Plot:SetAttribute("RivalId", nil)
	r.Plot:SetAttribute("OwnerName", nil)
	r.Plot:SetAttribute("OwnerUserId", 0)
	StationService.SetSign(r.Plot, { Title = "LOTE LIVRE", Name = "Vire dono deste terreno!", Line1 = "", Line2 = "", Line3 = "" })
end

-- Quantos rivais cabem agora (sempre sobra lote para quem entra).
local function balance()
	local folder = plotsFolder()
	if not folder then
		return
	end
	local freePlots = {}
	local total = 0
	for _, plot in ipairs(folder:GetChildren()) do
		if plot:FindFirstChild("Base") then
			total += 1
			if plot:GetAttribute("OwnerUserId") == 0 then
				table.insert(freePlots, plot)
			end
		end
	end
	local allowed = math.min(Config.RivalMax, math.max(0, #freePlots + #rivals - Config.RivalKeepFreePlots))
	while #rivals > allowed do
		evict(rivals[#rivals])
	end
	while #rivals < allowed and #freePlots > 0 do
		local plot = table.remove(freePlots, math.random(1, #freePlots)) :: Instance
		occupy(plot)
	end
	local _ = total
end

-- Um cliente escolheu o rival: se houver vaga, o carro chega dirigindo e fica no box enquanto o mecânico trabalha.
function RivalService.Serve(rivalId: number)
	local r: Rival? = nil
	for _, candidate in ipairs(rivals) do
		if candidate.Id == rivalId then
			r = candidate
		end
	end
	if not r then
		return
	end
	local rival = r :: Rival
	-- estatísticas: cada cliente atendido rende e avalia
	local price = math.random(9, 40) * 10
	rival.TotalEarned += math.floor(price * rival.Price)
	rival.Reputation += math.random(1, 4)
	rival.RatingCount += 1
	rival.RatingSum += math.random(3, 5)
	local root = StationService.FrameOf(rival.Plot)
	local bay: BasePart? = nil
	for i = 1, 6 do
		local candidate = rival.Plot:FindFirstChild("Bay" .. i)
		if candidate and candidate:IsA("BasePart") and not rival.Busy[candidate.Name] then
			bay = candidate
			break
		end
	end
	if not root or not bay then
		return
	end
	local theBay = bay :: BasePart
	local frame = root :: CFrame
	rival.Busy[theBay.Name] = true
	nextJob += 1
	local gender, name = Catalog.PickCustomer()
	local job = {
		Id = "rival_" .. nextJob,
		OwnerUserId = -1,
		VehicleName = Catalog.VehicleNames[math.random(1, #Catalog.VehicleNames)],
		CustomerName = name,
		CustomerGender = gender,
		Vip = false,
	}
	local bayLocal = frame:PointToObjectSpace(theBay.Position)
	local path = LotPath.Enter(frame, nil, bayLocal.X, bayLocal.Z)
	local car, npc, animator = CustomerArrivalService.BuildCar(job, CFrame.lookAt(path[1], path[2]), "CarroRival_" .. job.Id)
	if not car then
		rival.Busy[theBay.Name] = nil
		return
	end
	local theCar = car :: Model
	theCar:SetAttribute("RivalId", rival.Id)
	task.spawn(function()
		LotPath.Drive(theCar.PrimaryPart :: BasePart, path, LotPath.YardSpeed)
		if not theCar.Parent then
			rival.Busy[theBay.Name] = nil
			return
		end
		if npc then
			npc.Parent = nil -- o cliente "entra na recepção" enquanto o carro é consertado
		end
		local specs = Catalog.Specializations
		theCar:SetAttribute("Sintoma", specs[math.random(1, #specs)])
		theCar:SetAttribute("Estacionado", true)
		local mech = rival.Mechanic
		local carRoot = theCar.PrimaryPart :: BasePart
		if mech and mech.Parent then
			local spot = carRoot.CFrame * Vector3.new(0, 0, -((tonumber(theCar:GetAttribute("Comprimento")) or 18) / 2 + 2))
			local l = frame:PointToObjectSpace(spot)
			local feet = LotPath.Ground(frame, l.X, l.Z)
			NpcKit.Place(mech, feet, carRoot.Position)
			NpcKit.ServerOwned(mech)
		end
		theCar:SetAttribute("Reparando", true)
		task.spawn(StationService.Lift, theBay, carRoot, true) -- carro sobe no elevador
		task.wait(math.random(45, 90))
		if not theCar.Parent then
			rival.Busy[theBay.Name] = nil
			return
		end
		theCar:SetAttribute("Reparando", false)
		StationService.Lift(theBay, carRoot, false)
		theCar:SetAttribute("Sintoma", "")
		if mech and mech.Parent then
			local feet = LotPath.Ground(frame, 10, 2)
			NpcKit.Place(mech, feet, feet + frame.LookVector * -5)
			NpcKit.ServerOwned(mech)
		end
		if npc then
			npc.Parent = theCar
			NpcKit.SeatIn(npc, theCar, animator)
		end
		task.wait(1)
		theCar:SetAttribute("Estacionado", false)
		local back, gateFromX = LotPath.BackOut(frame, bayLocal.X, bayLocal.Z)
		LotPath.Drive(carRoot, back, LotPath.YardSpeed * 0.7, true)
		rival.Busy[theBay.Name] = nil
		if theCar.Parent then
			LotPath.Drive(carRoot, LotPath.DriveOff(frame, gateFromX), LotPath.StreetSpeed)
		end
		theCar:Destroy()
	end)
end

-- Candidatos do mercado (mesmos campos que WorkshopService usa para jogadores) + o id do rival.
function RivalService.Candidates(): { any }
	local list = {}
	for _, r in ipairs(rivals) do
		local open = 0
		for _ in pairs(r.Busy) do
			open += 1
		end
		table.insert(list, {
			RivalId = r.Id,
			Price = r.Price,
			Reputation = r.Reputation,
			SpecLevel = r.SpecLevel,
			ServiceableCount = 3,
			Rating = rating(r),
			OpenJobs = open,
			Capacity = Config.MaxOpenJobsPerWorkshop,
			Distance = 150,
		})
	end
	return list
end

-- Linhas de ranking (mesmo formato do ranking de jogadores).
function RivalService.RankEntries(): { any }
	local list = {}
	for _, r in ipairs(rivals) do
		table.insert(list, {
			Name = "Oficina de " .. r.Name,
			Reputation = r.Reputation,
			TotalEarned = r.TotalEarned,
			Price = r.Price,
			Level = Catalog.BusinessLevel(r.TotalEarned),
			Rating = rating(r),
			RatingCount = r.RatingCount,
			IsMe = false,
		})
	end
	return list
end

-- Atualiza as placas dos rivais com a posição no ranking geral (chamado pelo WorkshopService).
function RivalService.RefreshSigns(rankOf: (string) -> number?)
	for _, r in ipairs(rivals) do
		refreshSign(r, rankOf("Oficina de " .. r.Name))
	end
end

-- Antes de dar lote a um jogador: se não sobrar lote livre, um rival sai.
function RivalService.MakeRoom()
	local folder = plotsFolder()
	if not folder or #rivals == 0 then
		return
	end
	local free = 0
	for _, plot in ipairs(folder:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == 0 then
			free += 1
		end
	end
	if free == 0 then
		evict(rivals[#rivals])
	end
end

function RivalService.Count(): number
	return #rivals
end

function RivalService.Start()
	balance()
	Players.PlayerAdded:Connect(function()
		balance()
	end)
	Players.PlayerRemoving:Connect(function()
		task.delay(5, balance)
	end)
	task.spawn(function()
		while true do
			task.wait(20)
			balance()
		end
	end)
end

return RivalService
