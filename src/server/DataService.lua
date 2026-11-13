--!strict
-- DataService: perfil persistente do jogador (schema v2).
-- Garantias: retentativas com backoff, trava de sessão (um servidor por jogador), migração por reconcile,
-- histórico de transações limitado, salvamento só quando houve mudança (ou para renovar a trava),
-- liberação da trava ao sair, BindToClose paralelo. Em falha de leitura fora do Studio o jogador é expulso
-- (nunca cria perfil padrão que sobrescreveria dados existentes).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local CustomerRules = require(ReplicatedStorage.Shared.CustomerRules)
local SettlementLedgerRules = require(ReplicatedStorage.Shared.SettlementLedgerRules)
local SettlementClaimRules = require(ReplicatedStorage.Shared.SettlementClaimRules)
local SettlementClaimAuditRules = require(ReplicatedStorage.Shared.SettlementClaimAuditRules)
local OwnerSettlementProofRules = require(ReplicatedStorage.Shared.OwnerSettlementProofRules)
local OwnerProofSweepRules = require(ReplicatedStorage.Shared.OwnerProofSweepRules)
local WorkerSettlementProofRules = require(ReplicatedStorage.Shared.WorkerSettlementProofRules)
local WorkerPaidTombstoneRules = require(ReplicatedStorage.Shared.WorkerPaidTombstoneRules)
local WorkerProofArchiveRules = require(ReplicatedStorage.Shared.WorkerProofArchiveRules)
local EquipmentUpgradeRules = require(ReplicatedStorage.Shared.EquipmentUpgradeRules)
local V2SupplyRules = require(ReplicatedStorage.Shared.V2SupplyRules)
local V2StaffRules = require(ReplicatedStorage.Shared.V2StaffRules)

local DataService = {}

local SCHEMA_VERSION = 13 -- V2-05: escala, historico e folha de funcionarios; v11/v12 preservados
local MAX_ATTEMPTS = 4
local LOCK_TIMEOUT = 360 -- s; maior que 2 autosaves, para um servidor que caiu não prender o jogador para sempre
local LOCK_WAIT_STEP = 3
local LOCK_WAIT_MAX = 20 -- s esperando outro servidor liberar a trava (ajustável só em testes)
local MAX_TRANSACTIONS = 50
local MAX_ORDER_HISTORY = 30

local Profiles: { [number]: any } = {}
local Dirty: { [number]: boolean } = {}
local Saving: { [number]: boolean } = {}
local Removing: { [number]: boolean } = {} -- saída em andamento (grava e solta a trava); Load e BindToClose esperam
local Reconciling: { [number]: boolean } = {}
local ClaimCursor: { [number]: number } = {}
local LastClaimAlert: { [number]: number } = {}
local OwnerProofSweepRunning: { [number]: boolean } = {}
local OwnerProofSweepCursor: { [number]: number } = {}
local OwnerProofSweepLastAt: { [number]: number } = {}
local WorkerArchiveRunning: { [number]: boolean } = {}
local WorkerArchiveCursor: { [number]: number } = {}
local WorkerArchiveLastAt: { [number]: number } = {}
local Store: any = nil
local JobId: string = game.JobId ~= "" and game.JobId or "studio"
local MemoryMode = false

-- Inicialização do DataStore: falha em place não publicado. No Studio cai para modo memória (avisado).
local function initStore()
	local ok, result = pcall(function()
		-- No Studio (mesmo com API Services ligado) usa uma chave de TESTE: nunca toca os perfis de produção.
		return DataStoreService:GetDataStore(RunService:IsStudio() and (Config.DataStoreName .. "_STUDIO") or Config.DataStoreName)
	end)
	if ok then
		Store = result
		MemoryMode = false
	else
		Store = nil
		MemoryMode = RunService:IsStudio()
		warn("[DataService] DataStore indisponível:", result)
		if MemoryMode then
			warn("[DataService] MODO MEMÓRIA (Studio): progresso NÃO será salvo. Publique o place e habilite API Services.")
		end
	end
end
initStore()

local function deepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepClone(v)
	end
	return copy
end

local function makeDefaultData(): any
	local skills = {}
	for _, specialization in ipairs(Catalog.Specializations) do
		skills[specialization] = 0
	end
	return {
		SchemaVersion = SCHEMA_VERSION,
		Coins = Config.StartingCoins,
		Reputation = Config.StartingReputation,
		SkillXP = skills,
		Equipment = { BasicToolset = true },
		EquipmentLevels = { BasicToolset = 1 }, -- C16: upgrades permanentes de ferramentas e máquinas
		Parts = { TirePatch = 3, Battery = 1, Fuse = 2 }, -- estoque inicial para os primeiros serviços
		SupplyRequests = {}, -- V2-02: lista de peças a buscar na loja (NAO debita moedas)
        TelemetryV2 = { FirstUpgrade = false, FirstEmployee = false }, -- eventos anonimos de primeiro progresso
		Transactions = {},
		TotalEarned = 0,
		PriceMultiplier = 1, -- preço da oficina em relação à tabela (0.7 a 1.5)
		RatingCount = 0, -- avaliações recebidas dos clientes (1 a 5 estrelas)
		RatingSum = 0,
		RecentRatings = {}, -- últimas 10: { Stars, Service, At, CommentKey, Customer }
		OrderHistory = {}, -- últimos serviços concluídos: { At, Vehicle, Customer, Service, Price, Stars }
		RepairLedger = {}, -- C8: extrato limitado de crédito/recibo por JobId+token
		WorkerSettlementProofs = {}, -- C23: quitações detalhadas além do extrato de 64
		WorkerPaidTombstones = {}, -- C24: identificadores de pagamentos encerrados
		PendingClaims = {}, -- C12: reivindicações financeiras privadas do mecânico
		PendingClaimAudits = {}, -- C25: classificação privada de claims não confirmadas
		OwnerSettlementProofs = {}, -- C14: comprovantes compactos de repasse
		Onboarding = { Done = false }, -- guia do 1º atendimento (servidor decide; salvo por jogador)
		Bag = {}, -- peças na mochila do jogador (o resto fica na prateleira da oficina = Parts)
		Expansion = 0, -- (antigo: anexo; migrado para WorkshopLevel)
		WorkshopLevel = 0, -- nível do prédio (shared/WorkshopLevels: 0 = 1 box ... 3 = 6 boxes)
		Daily = { LastDay = -1, Streak = 0 }, -- recompensa diária (shared/ProgressRules)
		Missions = { Day = -1, List = {} }, -- missões do dia: { Id, Progress, Claimed }
		Codes = {}, -- códigos já usados
		Achievements = {}, -- conquistas ganhas
		Stats = { Repairs = 0, Earned = 0, Vip = 0, Perfect = 0, FirstTry = 0 }, -- contadores das conquistas
		Regulars = {}, -- fregueses: { Name, Gender, Vehicle, Visits } (até Config.RegularsMax)
		PendingVipReferral = false, -- um freguês indicou um VIP: o próximo cliente é VIP
		League = { Week = -1, Points = 0, Badge = "", BadgeWeek = -1 }, -- liga semanal (shared/ProgressRules)
		Employees = 0, -- mecânicos NPC contratados
        StaffSlots = V2StaffRules.Sanitize(nil), -- V2-05: escala de dois mecânicos
        StaffPayroll = { PaidCount=0, TotalPaid=0, LastDueAt=0 }, -- sem tokens privados novos
	}
end

-- Completa campos ausentes, corrige tipos e migra versões antigas. Nunca descarta dados válidos.
local function reconcile(data: any): any
	local defaults = makeDefaultData()
	if type(data) ~= "table" then
		return defaults
	end
	if data.Onboarding == nil and ((type(data.RatingCount) == "number" and data.RatingCount > 0) or (type(data.TotalEarned) == "number" and data.TotalEarned > 0)) then
		data.Onboarding = { Done = true } -- perfil antigo que já atendeu clientes não precisa do guia
	end
	-- perfil de antes dos níveis do prédio: quem já atendia clientes tinha 2 boxes (nível 1)
	if data.WorkshopLevel == nil then
		data.WorkshopLevel = (type(data.TotalEarned) == "number" and data.TotalEarned > 0) and 1 or 0
	end
	for key, value in pairs(defaults) do
		if data[key] == nil then
			data[key] = value
		end
	end
	if type(data.Coins) ~= "number" or data.Coins ~= data.Coins or data.Coins == math.huge or data.Coins == -math.huge then
		data.Coins = defaults.Coins
	end
	data.Coins = math.max(0, math.floor(data.Coins))
	if type(data.NextPayAt) ~= "number" or data.NextPayAt ~= data.NextPayAt then
		data.NextPayAt = 0
	end
	if type(data.Reputation) ~= "number" or data.Reputation ~= data.Reputation or data.Reputation == math.huge or data.Reputation == -math.huge then
		data.Reputation = defaults.Reputation
	end
	if type(data.TotalEarned) ~= "number" or data.TotalEarned ~= data.TotalEarned or data.TotalEarned < 0 or data.TotalEarned == math.huge then
		data.TotalEarned = 0
	end
	if type(data.SkillXP) ~= "table" then
		data.SkillXP = defaults.SkillXP
	end
	for _, specialization in ipairs(Catalog.Specializations) do
		local xp = data.SkillXP[specialization]
		if type(xp) ~= "number" or xp ~= xp or xp == math.huge or xp < 0 then
			data.SkillXP[specialization] = 0
		end
	end
	if type(data.Equipment) ~= "table" then
		data.Equipment = defaults.Equipment
	end
	data.Equipment.BasicToolset = true
	for equipmentId in pairs(data.Equipment) do
		if Catalog.Equipment[equipmentId] == nil then
			data.Equipment[equipmentId] = nil -- item removido do catálogo
		end
	end
	data.EquipmentLevels = EquipmentUpgradeRules.Sanitize(data.EquipmentLevels, data.Equipment)
	data.PriceMultiplier = type(data.PriceMultiplier) == "number" and CustomerRules.ClampPrice(data.PriceMultiplier) or 1
	-- Avaliações: contadores coerentes (soma entre count e 5*count) e lista recente limpa
	local rc = type(data.RatingCount) == "number" and data.RatingCount == data.RatingCount and math.max(0, math.floor(data.RatingCount)) or 0
	local rs = type(data.RatingSum) == "number" and data.RatingSum == data.RatingSum and math.floor(data.RatingSum) or 0
	data.RatingCount = rc
	data.RatingSum = math.clamp(rs, rc, rc * 5)
	if type(data.RecentRatings) ~= "table" then
		data.RecentRatings = {}
	end
	local cleanRecent = {}
	for _, entry in ipairs(data.RecentRatings) do
		if type(entry) == "table" and type(entry.Stars) == "number" and entry.Stars >= 1 and entry.Stars <= 5 then
			table.insert(cleanRecent, {
				Stars = math.floor(entry.Stars),
				Service = type(entry.Service) == "string" and string.sub(entry.Service, 1, 60) or "",
				At = type(entry.At) == "number" and entry.At or 0,
				CommentKey = type(entry.CommentKey) == "string" and string.sub(entry.CommentKey, 1, 40) or "",
				Customer = type(entry.Customer) == "string" and string.sub(entry.Customer, 1, 30) or "",
			})
		end
	end
	while #cleanRecent > 10 do
		table.remove(cleanRecent, 1)
	end
	data.RecentRatings = cleanRecent
	if type(data.OrderHistory) ~= "table" then
		data.OrderHistory = {}
	end
	local cleanHistory = {}
	for _, entry in ipairs(data.OrderHistory) do
		if type(entry) == "table" and type(entry.Price) == "number" and entry.Price == entry.Price then
			table.insert(cleanHistory, {
				At = type(entry.At) == "number" and entry.At or 0,
				Vehicle = type(entry.Vehicle) == "string" and string.sub(entry.Vehicle, 1, 40) or "",
				Customer = type(entry.Customer) == "string" and string.sub(entry.Customer, 1, 30) or "",
				Service = type(entry.Service) == "string" and string.sub(entry.Service, 1, 60) or "",
				Price = math.max(0, math.floor(entry.Price)),
				Stars = type(entry.Stars) == "number" and math.clamp(math.floor(entry.Stars), 1, 5) or 0,
			})
		end
	end
	while #cleanHistory > MAX_ORDER_HISTORY do
		table.remove(cleanHistory, 1)
	end
	data.OrderHistory = cleanHistory
	data.RepairLedger = SettlementLedgerRules.Sanitize(data.RepairLedger)
	data.WorkerPaidTombstones = WorkerPaidTombstoneRules.Sanitize(data.WorkerPaidTombstones)
	data.WorkerSettlementProofs = WorkerSettlementProofRules.FromLedger(
		data.WorkerSettlementProofs, data.RepairLedger, data.WorkerPaidTombstones)
	data.PendingClaims = SettlementClaimRules.Sanitize(data.PendingClaims)
	data.PendingClaimAudits = SettlementClaimAuditRules.Sanitize(
		data.PendingClaimAudits, data.PendingClaims)
	data.OwnerSettlementProofs = OwnerSettlementProofRules.Sanitize(data.OwnerSettlementProofs)
	if type(data.Parts) ~= "table" then
		data.Parts = {}
	end
	for partId, count in pairs(data.Parts) do
		if Catalog.Parts[partId] == nil or type(count) ~= "number" or count ~= count or count <= 0 then
			data.Parts[partId] = nil -- peça removida do catálogo, ou valor inválido
		else
			data.Parts[partId] = math.floor(count)
		end
	end
	-- V2-02: migracao aditiva v11 -> v12; whitelist, limite e nenhuma retirada de moedas.
	data.SupplyRequests = V2SupplyRules.Sanitize(data.SupplyRequests)
	if type(data.Bag) ~= "table" then
		data.Bag = {}
	end
	local bagTotal = 0
	for partId, count in pairs(data.Bag) do
		if Catalog.Parts[partId] == nil or type(count) ~= "number" or count ~= count or count <= 0 then
			data.Bag[partId] = nil
		else
			data.Bag[partId] = math.floor(count)
			bagTotal += data.Bag[partId]
		end
	end
	if bagTotal > Config.BagCapacity then
		-- mochila acima do limite (limite mudou): o excesso volta para a prateleira, nada se perde
		for partId, count in pairs(data.Bag) do
			local excess = math.min(count, bagTotal - Config.BagCapacity)
			if excess > 0 then
				data.Bag[partId] = count - excess > 0 and count - excess or nil
				data.Parts[partId] = (data.Parts[partId] or 0) + excess
				bagTotal -= excess
			end
		end
	end
	-- Retenção (ProgressService): tabelas válidas, números finitos
	local function num(v: any): number
		return (type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge) and v or 0
	end
	if type(data.Daily) ~= "table" then
		data.Daily = { LastDay = -1, Streak = 0 }
	end
	data.Daily = { LastDay = math.floor(num(data.Daily.LastDay)), Streak = math.clamp(math.floor(num(data.Daily.Streak)), 0, 100000) }
	if type(data.Missions) ~= "table" or type(data.Missions.List) ~= "table" then
		data.Missions = { Day = -1, List = {} }
	end
	for _, key in ipairs({ "Codes", "Achievements" }) do
		if type(data[key]) ~= "table" then
			data[key] = {}
		end
	end
	if type(data.Stats) ~= "table" then
		data.Stats = {}
	end
	local cleanRegulars = {}
	for _, r in ipairs(type(data.Regulars) == "table" and data.Regulars or {}) do
		if type(r) == "table" and type(r.Name) == "string" and (r.Gender == "M" or r.Gender == "F") and type(r.Vehicle) == "string"
			and Catalog.VehicleModels[r.Vehicle] and #cleanRegulars < Config.RegularsMax then
			table.insert(cleanRegulars, { Name = string.sub(r.Name, 1, 30), Gender = r.Gender, Vehicle = r.Vehicle, Visits = math.max(1, math.floor(num(r.Visits))) })
		end
	end
	data.Regulars = cleanRegulars
	data.PendingVipReferral = data.PendingVipReferral == true
	local league = type(data.League) == "table" and data.League or {}
	data.League = {
		Week = math.floor(num(league.Week ~= nil and league.Week or -1)),
		Points = math.clamp(math.floor(num(league.Points)), 0, 1e7),
		Badge = (league.Badge == "Bronze" or league.Badge == "Prata" or league.Badge == "Ouro") and league.Badge or "",
		BadgeWeek = math.floor(num(league.BadgeWeek ~= nil and league.BadgeWeek or -1)),
	}
	for _, key in ipairs({ "Repairs", "Earned", "Vip", "Perfect", "FirstTry" }) do
		data.Stats[key] = math.max(0, math.floor(num(data.Stats[key])))
	end
	local function intIn(v: any, lo: number, hi: number): number
		return type(v) == "number" and v == v and math.clamp(math.floor(v), lo, hi) or lo
	end
	-- Nível do prédio. Perfis antigos (já tinham 2 boxes) começam no nível 1; quem comprou o anexo antigo recebe o
	-- dinheiro de volta (o anexo deixou de existir).
	data.WorkshopLevel = intIn(data.WorkshopLevel, 0, 3)
	local oldExpansion = intIn(data.Expansion, 0, #Config.ExpansionCosts)
	if oldExpansion > 0 then
		for i = 1, oldExpansion do
			data.Coins += Config.ExpansionCosts[i] or 0
		end
	end
	data.Expansion = 0
	data.Employees = intIn(data.Employees, 0, Config.MaxEmployees)
    data.StaffSlots = V2StaffRules.Sanitize(data.StaffSlots)
    local payroll = type(data.StaffPayroll)=="table" and data.StaffPayroll or {}
    data.StaffPayroll = {
        PaidCount = intIn(payroll.PaidCount,0,100000000),
        TotalPaid = intIn(payroll.TotalPaid,0,1000000000),
        LastDueAt = intIn(payroll.LastDueAt,0,4102444800),
    }
	if type(data.Transactions) ~= "table" then
		data.Transactions = {}
	end
	if type(data.Onboarding) ~= "table" then
		data.Onboarding = { Done = false }
	end
	data.Onboarding = { Done = data.Onboarding.Done == true }
    local metrics = type(data.TelemetryV2) == "table" and data.TelemetryV2 or {}
    data.TelemetryV2 = {
        FirstUpgrade = metrics.FirstUpgrade == true,
        FirstEmployee = metrics.FirstEmployee == true,
    }
	data.SchemaVersion = SCHEMA_VERSION
	return data
end

local function keyFor(userId: number): string
	return "u_" .. tostring(userId)
end

local function lockedByOther(old: any): boolean
	local s = old and old.Session
	return type(s) == "table" and s.JobId ~= JobId and (os.time() - (s.At or 0)) < LOCK_TIMEOUT
end

-- Adquire a trava de sessão e devolve os dados armazenados. Retorna (ok, dados | motivo).
local function acquire(userId: number): (boolean, any)
	local key = keyFor(userId)
	local waited = 0
	local attempt = 0
	while true do
		local result: any = nil
		local locked = false
		local ok, err = pcall(function()
			Store:UpdateAsync(key, function(old: any)
				result, locked = nil, false
				if lockedByOther(old) then
					locked = true
					return nil -- cancela a gravação
				end
				local data = old
				if type(data) ~= "table" then
					data = nil
				end
				result = data -- dados brutos (nil = jogador novo)
				local out = data or {}
				out.Session = { JobId = JobId, At = os.time() }
				if data == nil then
					out.NewPlayer = true
					result = out
				end
				return out
			end)
		end)
		if ok and locked then
			if waited >= LOCK_WAIT_MAX then
				return false, "sessão ativa em outro servidor"
			end
			task.wait(LOCK_WAIT_STEP)
			waited += LOCK_WAIT_STEP
		elseif ok then
			return true, result
		else
			attempt += 1
			if attempt >= MAX_ATTEMPTS then
				return false, tostring(err)
			end
			task.wait(2 ^ attempt * 0.5)
		end
	end
end

-- Retorna (gravou, trava perdida). `lost` = outro servidor assumiu a sessão (o jogador não deve continuar jogando aqui).
local function writeProfile(userId: number, release: boolean): (boolean, boolean)
	local profile = Profiles[userId]
	if not profile or not Store then
		return false, false -- ausência de store/perfil jamais confirma persistência
	end
	local key = keyFor(userId)
	for attempt = 1, MAX_ATTEMPTS do
		local lost = false
		local ok, err = pcall(function()
			Store:UpdateAsync(key, function(old: any)
				lost = false
				if type(old) == "table" and old.Session and old.Session.JobId ~= JobId and lockedByOther(old) then
					lost = true
					return nil -- outro servidor assumiu: não sobrescrever
				end
				local data = deepClone(profile)
				data.Session = if release then nil else { JobId = JobId, At = os.time() }
				data.UpdatedAt = os.time()
				return data
			end)
		end)
		if ok and lost then
			warn("[DataService] Trava de sessão perdida para", userId, "- gravação cancelada.")
			return false, true
		elseif ok then
			Dirty[userId] = nil
			return true, false
		end
		warn("[DataService] Falha ao salvar", userId, "tentativa", attempt, err)
		if attempt < MAX_ATTEMPTS then
			task.wait(2 ^ attempt * 0.5)
		end
	end
	return false, false
end

-- ===== API pública =====

function DataService.Get(player: Player): any
	return Profiles[player.UserId]
end

function DataService.GetSkillLevel(player: Player, specialization: string): number
	local profile = Profiles[player.UserId]
	if not profile then
		return 0
	end
	local xp = profile.SkillXP[specialization] or 0
	return math.floor(xp / Catalog.SkillXPPerLevel) + 1
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function DataService.AddSkillXP(player: Player, specialization: string, amount: number)
	local profile = Profiles[player.UserId]
	if not profile or profile.SkillXP[specialization] == nil or not finite(amount) then
		return
	end
	profile.SkillXP[specialization] += math.max(0, math.floor(amount))
	Dirty[player.UserId] = true
end

function DataService.AddCoins(player: Player, amount: number, reason: string?)
	local profile = Profiles[player.UserId]
	if not profile or not finite(amount) then
		return
	end
	local delta = math.floor(amount)
	local before = profile.Coins
	profile.Coins = math.max(0, before + delta)
	local applied = profile.Coins - before
	if applied > 0 then
		profile.TotalEarned += applied
	end
	if applied ~= 0 then
		table.insert(profile.Transactions, {
			At = os.time(),
			Amount = applied,
			Balance = profile.Coins,
			Reason = reason or (applied > 0 and "Receita" or "Despesa"),
		})
		while #profile.Transactions > MAX_TRANSACTIONS do
			table.remove(profile.Transactions, 1)
		end
	end
	Dirty[player.UserId] = true
end

-- Registro idempotente: saldo e chave de crédito mudam no MESMO perfil sem yield.
-- Não resolve pagamento multi-conta de modo transacional (cada usuário tem uma chave DataStore).
function DataService.CreditRepairOnce(player: Player, jobId: string, token: string,
	amount: number, role: string, serviceName: string, vehicleName: string,
	workerUserId: number?, workerPay: number?): boolean
	local profile = Profiles[player.UserId]
	if not profile then return false end
	profile.RepairLedger = profile.RepairLedger or {}
	profile.OwnerSettlementProofs = profile.OwnerSettlementProofs or {}
	profile.WorkerSettlementProofs = profile.WorkerSettlementProofs or {}
	profile.WorkerPaidTombstones = profile.WorkerPaidTombstones or {}
	local workerProof = nil
	if role == "Worker" then
		-- Mesmo um crédito antigo já compactado é imutável: não pagar
		-- novamente quando o extrato de 64 e o marcador detalhado sumirem.
		if WorkerPaidTombstoneRules.Find(profile.WorkerPaidTombstones, jobId, token) then return false end
		local claim = SettlementClaimRules.Find(profile.PendingClaims, jobId, token)
		workerProof = WorkerSettlementProofRules.Make(jobId, token, amount, os.time(),
			serviceName, vehicleName, claim and claim.OwnerUserId or nil)
		if not workerProof or not WorkerSettlementProofRules.CanAdd(
			profile.WorkerSettlementProofs, workerProof) then
			return false -- marcador ausente ou arquivo cheio: NÃO conceder moedas
		end
	end
	local proof = nil
	if workerUserId ~= nil or workerPay ~= nil then
		if role ~= "Owner" or type(workerUserId) ~= "number"
			or type(workerPay) ~= "number" then return false end
		proof = OwnerSettlementProofRules.Make(jobId, token, workerUserId, amount,
			workerPay, serviceName, vehicleName, os.time())
		if not proof or not OwnerSettlementProofRules.CanAdd(profile.OwnerSettlementProofs, proof) then
			return false -- sem espaço, não altera moedas ou ledger
		end
	end
	if not SettlementLedgerRules.Record(profile.RepairLedger, jobId, token, amount, role,
		os.time(), serviceName, vehicleName) then return false end
	if proof then
		-- Mesmo perfil DataStore: arquivo de prova, ledger e moedas entram no mesmo Save.
		OwnerSettlementProofRules.Add(profile.OwnerSettlementProofs, proof)
	end
	if workerProof then
		-- Crédito e marcador do trabalhador são escritos no MESMO perfil e Save.
		-- Não há yield entre a checagem de capacidade e a inclusão.
		WorkerSettlementProofRules.Add(profile.WorkerSettlementProofs, workerProof)
	end
	DataService.AddCoins(player, amount, "Liquidação de OS: " .. serviceName)
	Dirty[player.UserId] = true
	return true
end

-- Controle de capacidade antes de consumir peças do dono na OS colaborativa.
function DataService.HasOwnerProofCapacity(player: Player): boolean
	local profile = Profiles[player.UserId]
	return profile ~= nil and type(profile.OwnerSettlementProofs) == "table"
		and #profile.OwnerSettlementProofs < OwnerSettlementProofRules.MaxEntries
end

-- O dono só descarta sua prova quando o contratado já recebeu e a remoção
-- da claim foi persistida no perfil do contratado. Nunca expor via remoto.
function DataService.DiscardConfirmedOwnerProof(owner: Player, jobId: any, token: any,
	workerUserId: number): boolean
	local profile = Profiles[owner.UserId]
	if not profile or not OwnerSettlementProofRules.Remove(profile.OwnerSettlementProofs,
		jobId, token, workerUserId) then return false end
	Dirty[owner.UserId] = true
	return true
end

function DataService.HasRepairCredit(player: Player, jobId: any, token: any): boolean
	local profile = Profiles[player.UserId]
	return profile ~= nil and (
		SettlementLedgerRules.Find(profile.RepairLedger, jobId, token) ~= nil
		or WorkerSettlementProofRules.Find(profile.WorkerSettlementProofs, jobId, token) ~= nil
		or WorkerPaidTombstoneRules.Find(profile.WorkerPaidTombstones, jobId, token) ~= nil)
end

function DataService.HasWorkerProofCapacity(player: Player): boolean
	local profile = Profiles[player.UserId]
	return profile ~= nil and type(profile.WorkerSettlementProofs) == "table"
		and #profile.WorkerSettlementProofs < WorkerSettlementProofRules.MaxEntries
end

function DataService.AttachRepairReceipt(player: Player, jobId: string, token: string,
	payload: any): boolean
	local profile = Profiles[player.UserId]
	if not profile then return false end
	if not SettlementLedgerRules.Attach(profile.RepairLedger, jobId, token, payload) then return false end
	Dirty[player.UserId] = true
	return true
end

function DataService.GetRepairReceipt(player: Player, jobId: any, token: any): any?
	local profile = Profiles[player.UserId]
	return profile and SettlementLedgerRules.Receipt(profile.RepairLedger, jobId, token) or nil
end

function DataService.RecentRepairSettlements(player: Player, limit: number?): { any }
	local profile = Profiles[player.UserId]
	return profile and SettlementLedgerRules.Public(profile.RepairLedger, limit) or {}
end

-- C12: registra no perfil do MECÂNICO, antes de gastar peças ou pagar, a
-- reivindicação verificável no ledger persistido do proprietário.
-- Cada claim é salva antes de qualquer efeito econômico em FinishRepair.
function DataService.StageWorkerClaim(worker: Player, ownerUserId: number, jobId: string, token: string,
	ownerPay: number, workerPay: number, xp: number, quality: number,
	service: string, vehicle: string, spec: string): boolean
	local profile = Profiles[worker.UserId]
	if not profile or ownerUserId == worker.UserId or not profile.SkillXP[spec] then return false end
	profile.PendingClaims = profile.PendingClaims or {}
	local existing = SettlementClaimRules.Find(profile.PendingClaims, jobId, token)
	if existing then
		return existing.OwnerUserId == ownerUserId and existing.OwnerPay == ownerPay
			and existing.WorkerPay == workerPay and existing.XP == xp
			and existing.Quality == quality and existing.Service == service
			and existing.Vehicle == vehicle and existing.Spec == spec
	end
	if #profile.PendingClaims >= SettlementClaimRules.MaxPending
		or DataService.HasRepairCredit(worker, jobId, token) then return false end
	local claim = SettlementClaimRules.Make(ownerUserId, jobId, token, ownerPay, workerPay,
		xp, quality, service, vehicle, spec, os.time())
	if not claim or not SettlementClaimRules.Add(profile.PendingClaims, claim) then return false end
	Dirty[worker.UserId] = true
	return true
end

function DataService.PendingClaimSummary(player: Player): any
	local profile = Profiles[player.UserId]
	local summary = SettlementClaimRules.Summary(profile and profile.PendingClaims, os.time())
	local audit = SettlementClaimAuditRules.Summary(profile and profile.PendingClaimAudits)
	-- Apenas contagens na HUD, nunca JobId/token ou identidade do proprietário.
	summary.NeedsReview = audit.Count
	summary.LegacyUnverified = audit.LegacyUnverified
	summary.Conflicts = audit.Conflict
	return summary
end

function DataService.DiscardWorkerClaim(worker: Player, jobId: any, token: any): boolean
	local profile = Profiles[worker.UserId]
	if not profile or not SettlementClaimRules.Remove(profile.PendingClaims, jobId, token) then return false end
	SettlementClaimAuditRules.Remove(profile.PendingClaimAudits, jobId, token)
	Dirty[worker.UserId] = true
	return true
end

-- C13: somente a gravação do dono (não uma promessa do executor) autoriza
-- restaurar a parcela perdida. Nunca altera um perfil de outro jogador.
function DataService.ReconcileWorkerClaims(worker: Player): number
	local userId = worker.UserId
	local profile = Profiles[userId]
	if not profile or Reconciling[userId] or MemoryMode or not Store then return 0 end
	if type(Store.GetAsync) ~= "function" then return 0 end
	Reconciling[userId] = true
	local recovered = 0
	local pending = profile.PendingClaims
	local total = #pending
	local start = ClaimCursor[userId] or 1
	local visited = 0
	for offset = 0, total - 1 do
		if visited >= 8 or Profiles[userId] ~= profile or worker.Parent ~= Players then break end
		local index = ((start + offset - 1) % total) + 1
		local claim = pending[index]
		if claim and SettlementClaimRules.Valid(claim) then
			visited += 1
			-- A reivindicação é escrita antes do reparo terminar. Nunca deixar
			-- a rotina de resgate competir com o crédito normal do mesmo token.
			if not SettlementClaimRules.Recoverable(claim, os.time()) then continue end
			local already = DataService.HasRepairCredit(worker, claim.JobId, claim.Token)
			local verified = already
			local evidenceStatus = "Missing"
			if not already then
				local ok, ownerRaw = pcall(function()
					return Store:GetAsync(keyFor(claim.OwnerUserId))
				end)
				if ok and type(ownerRaw) == "table" then
					evidenceStatus = SettlementClaimRules.EvidenceStatus(claim,
						ownerRaw.RepairLedger, ownerRaw.OwnerSettlementProofs, userId)
					verified = evidenceStatus == "Verified"
				elseif not ok then
					evidenceStatus = "ReadError"
				end
				if not verified and Profiles[userId] == profile then
					if SettlementClaimAuditRules.Mark(profile.PendingClaimAudits,
						claim, evidenceStatus, os.time()) then
						Dirty[userId] = true
					end
				end
			end
			if Profiles[userId] ~= profile or worker.Parent ~= Players then break end
			if verified then
				if not already and DataService.CreditRepairOnce(worker, claim.JobId, claim.Token,
					claim.WorkerPay, "Worker", claim.Service, claim.Vehicle) then
					DataService.AddSkillXP(worker, claim.Spec, claim.XP)
					DataService.AttachRepairReceipt(worker, claim.JobId, claim.Token, {
						JobId = claim.JobId, Token = claim.Token, Price = claim.WorkerPay,
						Quality = claim.Quality, XP = claim.XP,
					})
					recovered += 1
					warn("[DataService] Pagamento de contratado restaurado da prova do proprietário:", userId, claim.JobId)
				end
				-- C23: nunca remover a claim se o crédito falhou (ex.: arquivo
				-- cheio). O marcador durável também protege após giro do ledger.
				if DataService.HasRepairCredit(worker, claim.JobId, claim.Token)
					and DataService.Save(worker) then
					SettlementClaimRules.Remove(profile.PendingClaims, claim.JobId, claim.Token)
					SettlementClaimAuditRules.Remove(profile.PendingClaimAudits, claim.JobId, claim.Token)
					Dirty[userId] = true
				end
			end
		end
	end
	ClaimCursor[userId] = total > 0 and ((start + visited - 1) % total) + 1 or 1
	local summary = SettlementClaimRules.Summary(profile.PendingClaims, os.time())
	local alerted = LastClaimAlert[userId] or 0
	if summary.Overdue > 0 and os.time() - alerted >= 86400 then
		LastClaimAlert[userId] = os.time()
		local audit = SettlementClaimAuditRules.Summary(profile.PendingClaimAudits)
		warn("[DataService] Reivindicações antigas não resolvidas:", userId,
			"quantidade", summary.Overdue, "idade máxima (h)", math.floor(summary.OldestSeconds / 3600),
			"legacy_sem_vinculo", audit.LegacyUnverified,
			"provas_conflitantes", audit.Conflict)
	end
	Reconciling[userId] = nil
	return recovered
end

-- C22: sweep CONSERVADOR de comprovantes de antigos contratados (inclusive
-- offline). Nunca ler o perfil do trabalhador em memória: só o GetAsync do
-- DataStore pode comprovar que o crédito já foi gravado e a claim removida.
-- O número de consultas é limitado, rodando com intervalo mínimo por dono.
function DataService.ReconcileOwnerProofs(owner: Player): number
	local userId = owner.UserId
	local profile = Profiles[userId]
	if not profile or #profile.OwnerSettlementProofs == 0
		or OwnerProofSweepRunning[userId] or MemoryMode or not Store
		or type(Store.GetAsync) ~= "function" or Removing[userId] then return 0 end
	local now = os.time()
	if now - (OwnerProofSweepLastAt[userId] or 0) < OwnerProofSweepRules.MinIntervalSeconds then
		return 0
	end
	OwnerProofSweepLastAt[userId] = now
	OwnerProofSweepRunning[userId] = true
	local proofs = profile.OwnerSettlementProofs
	local candidates, nextCursor = OwnerProofSweepRules.Batch(
		proofs, OwnerProofSweepCursor[userId] or 1, now)
	OwnerProofSweepCursor[userId] = nextCursor
	local removed = 0
	for _, proof in ipairs(candidates) do
		if Profiles[userId] ~= profile or Removing[userId] or owner.Parent ~= Players then break end
		local ok, workerRaw = pcall(function()
			return Store:GetAsync(keyFor(proof.WorkerUserId))
		end)
		if ok and OwnerProofSweepRules.CanRelease(proof, workerRaw, proof.WorkerUserId)
			and Profiles[userId] == profile and owner.Parent == Players and not Removing[userId] then
			-- GetAsync pode ceder a execução; conferir que a prova ainda é
			-- a mesma e não foi modificada durante a espera.
			local current = OwnerSettlementProofRules.Find(proofs, proof.JobId, proof.Token)
			if current and current.WorkerUserId == proof.WorkerUserId
				and current.At == proof.At and current.OwnerPay == proof.OwnerPay
				and current.WorkerPay == proof.WorkerPay
				and current.Service == proof.Service and current.Vehicle == proof.Vehicle
				and OwnerSettlementProofRules.Remove(proofs, proof.JobId, proof.Token, proof.WorkerUserId) then
				Dirty[userId] = true
				removed += 1
			end
		elseif not ok then
			warn("[DataService] C22: leitura da conta do contratado falhou; prova preservada:", userId)
		end
	end
	-- Se a gravação falhar, a prova ainda existe no perfil persistido. No
	-- próximo login/salvamento a limpeza poderá ser retomada sem perda.
	local persisted = true
	if removed > 0 and Profiles[userId] == profile and not Removing[userId] then
		persisted = DataService.Save(owner)
		if not persisted then
			warn("[DataService] C22: limpeza de provas ainda não persistida:", userId)
		end
	end
	OwnerProofSweepRunning[userId] = nil
	return persisted and removed or 0
end

-- C24: compactar somente quitações verificadas, sem apagar a proteção
-- contra replay. Marcador e tombstone mudam na MESMA chave DataStore.
-- Não compactar créditos v9 sem OwnerUserId (histórico incompleto).
function DataService.ReconcileWorkerProofs(worker: Player): number
	local userId = worker.UserId
	local profile = Profiles[userId]
	if not profile or #profile.WorkerSettlementProofs == 0
		or WorkerArchiveRunning[userId] or MemoryMode or not Store
		or type(Store.GetAsync) ~= "function" or Removing[userId] then return 0 end
	if #profile.WorkerPaidTombstones >= WorkerPaidTombstoneRules.MaxEntries then return 0 end
	local now = os.time()
	if now - (WorkerArchiveLastAt[userId] or 0) < WorkerProofArchiveRules.MinIntervalSeconds then
		return 0
	end
	WorkerArchiveLastAt[userId] = now
	WorkerArchiveRunning[userId] = true
	local proofs = profile.WorkerSettlementProofs
	local candidates, nextCursor = WorkerProofArchiveRules.Batch(proofs,
		WorkerArchiveCursor[userId] or 1, now)
	WorkerArchiveCursor[userId] = nextCursor
	-- Garantir que saldo, marcador e remoção da claim foram gravados ANTES
	-- de consultar a liberação do proprietário.
	if #candidates == 0 or not DataService.Save(worker) then
		WorkerArchiveRunning[userId] = nil
		return 0
	end
	local compacted = 0
	for _, marker in ipairs(candidates) do
		if Profiles[userId] ~= profile or Removing[userId] or worker.Parent ~= Players then break end
		if #profile.WorkerPaidTombstones >= WorkerPaidTombstoneRules.MaxEntries then break end
		local ok, ownerRaw = pcall(function()
			return Store:GetAsync(keyFor(marker.OwnerUserId))
		end)
		if ok and WorkerProofArchiveRules.CanCompact(marker, ownerRaw,
			profile.PendingClaims, marker.OwnerUserId)
			and Profiles[userId] == profile and worker.Parent == Players and not Removing[userId] then
			local current = WorkerSettlementProofRules.Find(proofs, marker.JobId, marker.Token)
			if current and current.OwnerUserId == marker.OwnerUserId
				and current.Amount == marker.Amount and current.At == marker.At
				and current.Service == marker.Service and current.Vehicle == marker.Vehicle
				and WorkerProofArchiveRules.CanCompact(current, ownerRaw,
					profile.PendingClaims, marker.OwnerUserId)
				and WorkerPaidTombstoneRules.Compact(proofs, profile.WorkerPaidTombstones,
					marker.JobId, marker.Token) then
				Dirty[userId] = true
				compacted += 1
			end
		elseif not ok then
			warn("[DataService] C24: falha ao verificar quitação com proprietário; prova preservada:", userId)
		end
	end
	if compacted > 0 then
		if Profiles[userId] ~= profile or Removing[userId] or not DataService.Save(worker) then
			warn("[DataService] C24: compactação ainda não confirmada no DataStore:", userId)
			WorkerArchiveRunning[userId] = nil
			return 0
		end
	end
	WorkerArchiveRunning[userId] = nil
	return compacted
end

-- Encerra o guia do 1º atendimento. Com `bonus` (serviço concluído de verdade) paga uma única vez; pular não paga.
-- Retorna as moedas pagas (0 se já estava encerrado).
function DataService.CompleteOnboarding(player: Player, bonus: number): number
	local profile = Profiles[player.UserId]
	if not profile or profile.Onboarding.Done then
		return 0
	end
	profile.Onboarding.Done = true
	Dirty[player.UserId] = true
	if bonus > 0 then
		DataService.AddCoins(player, bonus, "Bônus do primeiro serviço")
	end
	return bonus
end

function DataService.AddReputation(player: Player, amount: number)
	local profile = Profiles[player.UserId]
	if not profile or not finite(amount) then
		return
	end
	profile.Reputation = math.max(0, profile.Reputation + math.floor(amount))
	Dirty[player.UserId] = true
end

function DataService.GrantEquipment(player: Player, equipmentId: string): boolean
	local profile = Profiles[player.UserId]
	if not profile or Catalog.Equipment[equipmentId] == nil then
		return false
	end
	profile.Equipment[equipmentId] = true
	profile.EquipmentLevels = profile.EquipmentLevels or {}
	profile.EquipmentLevels[equipmentId] = 1
	Dirty[player.UserId] = true
	return true
end

function DataService.GetEquipmentLevel(player: Player, equipmentId: string): number
	local profile = Profiles[player.UserId]
	return profile and EquipmentUpgradeRules.Level(profile.EquipmentLevels, profile.Equipment, equipmentId) or 0
end

-- C16: troca dinheiro por um upgrade da própria máquina, sem yield entre
-- checagem de nível/saldo e débito. Não há RemoteEvent de compra do pad.
function DataService.UpgradeOwnedEquipment(player: Player, equipmentId: string): (boolean, string)
	local profile = Profiles[player.UserId]
	if not profile or not Catalog.Equipment[equipmentId] then return false, "Equipamento inválido." end
	local current = EquipmentUpgradeRules.Level(profile.EquipmentLevels, profile.Equipment, equipmentId)
	if current == 0 then return false, "Você precisa comprar e instalar este equipamento primeiro." end
	local cost = EquipmentUpgradeRules.NextCost(equipmentId, current)
	if not cost then return false, "Equipamento já está no nível máximo." end
	if profile.Coins < cost then return false, "Moedas insuficientes para esta melhoria." end
	DataService.AddCoins(player, -cost, "Melhoria: " .. Catalog.Equipment[equipmentId].DisplayName .. " N" .. (current + 1))
	profile.EquipmentLevels[equipmentId] = current + 1
	Dirty[player.UserId] = true
	return true, string.format("%s melhorado para nível %d! (-%d moedas)",
		Catalog.Equipment[equipmentId].DisplayName, current + 1, cost)
end

-- Registra a avaliação de um cliente (1 a 5). Devolve (quantidade, soma) ou nil se inválida/sem perfil.
function DataService.AddRating(player: Player, stars: number, serviceName: string, extra: { CommentKey: string?, Customer: string? }?): (number?, number?)
	local profile = Profiles[player.UserId]
	if not profile or type(stars) ~= "number" or stars ~= stars or stars < 1 or stars > 5 then
		return nil, nil
	end
	local s = math.floor(stars)
	profile.RatingCount += 1
	profile.RatingSum += s
	table.insert(profile.RecentRatings, {
		Stars = s,
		Service = string.sub(serviceName, 1, 60),
		At = os.time(),
		CommentKey = extra and extra.CommentKey and string.sub(extra.CommentKey, 1, 40) or "",
		Customer = extra and extra.Customer and string.sub(extra.Customer, 1, 30) or "",
	})
	while #profile.RecentRatings > 10 do
		table.remove(profile.RecentRatings, 1)
	end
	Dirty[player.UserId] = true
	return profile.RatingCount, profile.RatingSum
end

-- Histórico dos serviços concluídos (últimos MAX_ORDER_HISTORY), mostrado na aba Concluídas e no Perfil.
function DataService.AddOrderHistory(player: Player, entry: { Vehicle: string, Customer: string, Service: string, Price: number, Stars: number })
	local profile = Profiles[player.UserId]
	if not profile or type(entry.Price) ~= "number" or entry.Price ~= entry.Price then
		return
	end
	table.insert(profile.OrderHistory, {
		At = os.time(),
		Vehicle = string.sub(entry.Vehicle, 1, 40),
		Customer = string.sub(entry.Customer, 1, 30),
		Service = string.sub(entry.Service, 1, 60),
		Price = math.max(0, math.floor(entry.Price)),
		Stars = math.clamp(math.floor(entry.Stars), 1, 5),
	})
	while #profile.OrderHistory > MAX_ORDER_HISTORY do
		table.remove(profile.OrderHistory, 1)
	end
	Dirty[player.UserId] = true
end

-- Preço da oficina: sempre normalizado por CustomerRules.ClampPrice (faixa e passo); devolve o valor aplicado.
function DataService.SetPriceMultiplier(player: Player, value: number): number?
	local profile = Profiles[player.UserId]
	if not profile then
		return nil
	end
	profile.PriceMultiplier = CustomerRules.ClampPrice(value)
	Dirty[player.UserId] = true
	return profile.PriceMultiplier
end

-- Estoque de peças ---------------------------------------------------------------------------------------
function DataService.GetPartCount(player: Player, partId: string): number
	local profile = Profiles[player.UserId]
	return profile and profile.Parts[partId] or 0
end

function DataService.AddParts(player: Player, partId: string, amount: number): boolean
	local profile = Profiles[player.UserId]
	local n = math.floor(amount)
	if not profile or Catalog.Parts[partId] == nil or n <= 0 then
		return false
	end
		profile.Parts[partId] = (profile.Parts[partId] or 0) + n
	Dirty[player.UserId] = true
	return true
end

-- Apenas compra confirmada na loja reduz a lista de requisicoes.
-- AddParts generico serve tambem para rollback e recompensas; nao deve diminuir pedidos.
function DataService.FulfillSupplyRequest(player: Player, partId: string, count: number): boolean
    local profile = Profiles[player.UserId]
    if not profile or Catalog.Parts[partId] == nil or type(count) ~= "number"
        or count ~= count or count % 1 ~= 0 or count <= 0 or count > Catalog.MaxPartPurchase then
        return false
    end
    profile.SupplyRequests = V2SupplyRules.OnPurchase(profile.SupplyRequests, partId, count)
    Dirty[player.UserId] = true
    return true
end

-- V2-02: pedido de compra SEM transacao financeira; a compra real continua na loja V1.
-- Recebe somente deficit calculado no servidor por WorkshopService.
function DataService.RequestSupply(player: Player, needed: any): (boolean, string)
    local profile = Profiles[player.UserId]
    if not profile then return false, "Perfil indisponível." end
    local nextList, added = V2SupplyRules.MergeMissing(profile.SupplyRequests, needed)
    if added == 0 then return false, "Nenhuma peça nova para adicionar à lista." end
    profile.SupplyRequests = nextList
    Dirty[player.UserId] = true
    return true, "Lista atualizada. Compre as peças na Loja de Autopeças."
end

-- Descarte explicito de wishlist: nenhuma transacao financeira nem estoque muda.
function DataService.ClearSupplyRequests(player: Player): (boolean, string)
    local profile = Profiles[player.UserId]
    if not profile then return false, "Perfil indisponível." end
    if next(profile.SupplyRequests) == nil then return false, "Lista já está vazia." end
    profile.SupplyRequests = {}
    Dirty[player.UserId] = true
    return true, "Lista de compras descartada sem alterar estoque ou saldo."
end

-- Devolve true se o estoque cobre TODAS as peças pedidas ({ [partId] = quantidade }).
function DataService.HasParts(player: Player, needed: { [string]: number }?): boolean
	local profile = Profiles[player.UserId]
	if not profile then
		return false
	end
	for partId, count in pairs(needed or {}) do
		if (profile.Parts[partId] or 0) < count then
			return false
		end
	end
	return true
end

-- Tudo-ou-nada: só desconta se houver estoque para todas as peças (nunca fica meio pago).
function DataService.TakeParts(player: Player, needed: { [string]: number }?): boolean
	if not DataService.HasParts(player, needed) then
		return false
	end
	local profile = Profiles[player.UserId]
	for partId, count in pairs(needed or {}) do
		local left = profile.Parts[partId] - count
		profile.Parts[partId] = left > 0 and left or nil
	end
	Dirty[player.UserId] = true
	return true
end

-- C20: liquida um reparo de NPC com peças + crédito idempotente no MESMO
-- perfil (sem yield). A gravação subsequente do perfil é atômica por usuário.
-- A confirmação de salvamento e as retentativas são feitas pelo WorkshopService.
function DataService.SettleNpcRepairOnce(player: Player, jobId: string, token: string,
	amount: number, needed: { [string]: number }?, service: string, vehicle: string): boolean
	if not Profiles[player.UserId] or not SettlementLedgerRules.ValidKey(jobId, token)
		or not finite(amount) or amount % 1 ~= 0 or amount < 0 or amount > 1e8
		or (needed ~= nil and type(needed) ~= "table")
		or type(service) ~= "string" or type(vehicle) ~= "string" then return false end
	for partId, count in pairs(needed or {}) do
		if Catalog.Parts[partId] == nil or not finite(count)
			or count % 1 ~= 0 or count < 1 or count > 10000 then return false end
	end
	if DataService.HasRepairCredit(player, jobId, token)
		or not DataService.HasParts(player, needed) then return false end
	if not DataService.TakeParts(player, needed) then return false end
	if not DataService.CreditRepairOnce(player, jobId, token, amount, "Owner", service, vehicle) then
		for partId, count in pairs(needed or {}) do
			DataService.AddParts(player, partId, count) -- rollback sem yield
		end
		return false
	end
	return true
end

-- C21 (revisão de concorrência): as peças e a PARCELA DO DONO são
-- preparadas no mesmo perfil sem yield. Mesmo que outro reparo tenha
-- ocupado a última prova durante o Save da claim do trabalhador, o dono
-- não perde estoque nem paga parcialmente quando a prova falha.
function DataService.SettleRepairOwnerOnce(owner: Player, jobId: string, token: string,
	amount: number, needed: { [string]: number }?, service: string, vehicle: string,
	workerUserId: number?, workerPay: number?): boolean
	if not Profiles[owner.UserId] or not SettlementLedgerRules.ValidKey(jobId, token)
		or not finite(amount) or amount % 1 ~= 0 or amount < 0 or amount > 1e8
		or (needed ~= nil and type(needed) ~= "table")
		or type(service) ~= "string" or type(vehicle) ~= "string" then return false end
	for partId, count in pairs(needed or {}) do
		if Catalog.Parts[partId] == nil or not finite(count)
			or count % 1 ~= 0 or count < 1 or count > 10000 then return false end
	end
	if DataService.HasRepairCredit(owner, jobId, token)
		or not DataService.HasParts(owner, needed) then return false end
	if not DataService.TakeParts(owner, needed) then return false end
	if not DataService.CreditRepairOnce(owner, jobId, token, amount,
		"Owner", service, vehicle, workerUserId, workerPay) then
		for partId, count in pairs(needed or {}) do
			DataService.AddParts(owner, partId, count)
		end
		return false
	end
	return true
end

-- Mochila: move `amount` peças entre a prateleira (Parts) e a mochila (Bag). `toBag` = pegar da prateleira.
-- Retorna (ok, mensagem). Respeita o limite Config.BagCapacity.
function DataService.MoveBag(player: Player, partId: string, amount: number, toBag: boolean): (boolean, string)
	local profile = DataService.Get(player)
	-- inteiro finito entre 1 e a capacidade (NaN/inf/fração vindos do cliente são recusados)
	if type(amount) ~= "number" or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > Config.BagCapacity then
		return false, "Pedido inválido."
	end
	local n = amount
	if not profile or Catalog.Parts[partId] == nil then
		return false, "Pedido inválido."
	end
	local from = toBag and profile.Parts or profile.Bag
	local to = toBag and profile.Bag or profile.Parts
	if (from[partId] or 0) < n then
		return false, toBag and "Não há peças suficientes na prateleira." or "Não há peças suficientes na mochila."
	end
	if toBag then
		local total = 0
		for _, c in pairs(profile.Bag) do
			total += c
		end
		if total + n > Config.BagCapacity then
			return false, string.format("A mochila leva no máximo %d peças.", Config.BagCapacity)
		end
	end
	from[partId] = from[partId] - n > 0 and from[partId] - n or nil
	to[partId] = (to[partId] or 0) + n
	DataService.MarkDirty(player)
	return true, string.format("%dx %s %s.", n, Catalog.Parts[partId].DisplayName, toBag and "na mochila" or "na prateleira")
end

-- Expansão e funcionários (valores validados por quem chama; aqui só grava com limites).
function DataService.SetExpansion(player: Player, level: number)
	local profile = DataService.Get(player)
	if profile then
		profile.Expansion = math.clamp(math.floor(level), 0, #Config.ExpansionCosts)
		DataService.MarkDirty(player)
	end
end

function DataService.SetWorkshopLevel(player: Player, level: number)
	local profile = DataService.Get(player)
	if profile then
		profile.WorkshopLevel = math.clamp(math.floor(level), 0, 3)
		DataService.MarkDirty(player)
	end
end

function DataService.SetEmployees(player: Player, count: number)
	local profile = DataService.Get(player)
	if profile then
		profile.Employees = math.clamp(math.floor(count), 0, Config.MaxEmployees)
		DataService.MarkDirty(player)
	end
end

-- V2-05: quadro de funcionários salvo no mesmo perfil com limites rígidos.
function DataService.UpdateStaffPolicy(player: Player,index: any,key: any,value: any): (boolean,string)
    local profile=Profiles[player.UserId]
    if not profile or type(index)~="number" or index%1~=0 or index<1
        or index>(profile.Employees or 0) then return false,"Mecânico não contratado." end
    local ok,message=V2StaffRules.Update(profile.StaffSlots,index,key,value)
    if ok then Dirty[player.UserId]=true end
    return ok,message
end

function DataService.RecordStaffJob(player: Player,index: number,jobId: string,
    service: string,amount: number,quality: number,seconds: number): boolean
    local profile=Profiles[player.UserId]
    if not profile then return false end
    -- O caller chama somente após SettleNpcRepairOnce confirmar crédito e consumo no mesmo perfil.
    local ok=V2StaffRules.Record(profile.StaffSlots,index,jobId,service,amount,
        quality,seconds,os.time())
    if ok then Dirty[player.UserId]=true end
    return ok
end

-- Debita salário no mesmo perfil em que se avança a data de vencimento,
-- sem yield. Chamadas repetidas com a mesma data são recusadas.
function DataService.ChargeStaffPayrollOnce(player: Player,dueAt: any,count: any): (boolean,string)
    local profile=Profiles[player.UserId]
    if not profile or type(dueAt)~="number" or dueAt%1~=0 or dueAt<=0
        or type(count)~="number" or count%1~=0 or count<1
        or count>Config.MaxEmployees or profile.Employees~=count
        or profile.NextPayAt~=dueAt or os.time()<dueAt then
        return false,"Folha já executada ou prazo inválido."
    end
    local due=count*Config.EmployeeSalary
    if profile.Coins<due then return false,"Saldo insuficiente para salários." end
    profile.NextPayAt=os.time()+Config.PaydaySeconds
    profile.StaffPayroll.PaidCount+=1
    profile.StaffPayroll.TotalPaid+=due
    profile.StaffPayroll.LastDueAt=dueAt
    DataService.AddCoins(player,-due,"Salário dos funcionários")
    return true,"Salários registrados no perfil."
end

-- Concedido uma unica vez por perfil; permite registrar funis sem identificadores pessoais.
function DataService.ClaimTelemetryMilestone(player: Player, kind: string): boolean
    if kind ~= "FirstUpgrade" and kind ~= "FirstEmployee" then return false end
    local profile = Profiles[player.UserId]
    if not profile then return false end
    profile.TelemetryV2 = profile.TelemetryV2 or {}
    if profile.TelemetryV2[kind] then return false end
    profile.TelemetryV2[kind] = true
    Dirty[player.UserId] = true
    return true
end

function DataService.MarkDirty(player: Player)
	Dirty[player.UserId] = true
end

function DataService.IsMemoryMode(): boolean
	return MemoryMode
end

function DataService.Load(player: Player)
	local userId = player.UserId
	if MemoryMode then
		Profiles[userId] = reconcile(nil)
		return
	end
	if not Store then
		player:Kick("Serviço de dados indisponível. Tente novamente em instantes.")
		return
	end

	while Removing[userId] or Saving[userId] do
		task.wait(0.1) -- reentrada rápida: espera o salvamento anterior terminar (evita ler dado antigo)
	end
	local ok, result = acquire(userId)
	if not ok then
		warn("[DataService] Falha ao carregar dados de", userId, result)
		player:Kick("Não foi possível carregar seus dados (" .. tostring(result) .. "). Tente entrar novamente.")
		return
	end

	-- O jogador pode ter saído durante a espera: libera a trava e descarta.
	if player.Parent ~= Players then
		Profiles[userId] = reconcile(result)
		writeProfile(userId, true)
		Profiles[userId] = nil
		return
	end

	local profile = reconcile(result)
	profile.Session = nil
	profile.NewPlayer = nil
	Profiles[userId] = profile
	Dirty[userId] = true -- grava a migração/perfil novo no primeiro autosave
	if #profile.PendingClaims > 0 then
		task.spawn(DataService.ReconcileWorkerClaims, player)
	end
	if #profile.WorkerSettlementProofs > 0 then
		task.delay(20, function()
			if Profiles[userId] == profile and player.Parent == Players then
				DataService.ReconcileWorkerProofs(player)
			end
		end)
	end
	if #profile.OwnerSettlementProofs > 0 then
		-- Tempo para o join/estado inicial estabilizar; não esperar sweep para jogar.
		task.delay(15, function()
			if Profiles[userId] == profile and player.Parent == Players then
				DataService.ReconcileOwnerProofs(player)
			end
		end)
	end
end

function DataService.Save(player: Player): boolean
	local userId = player.UserId
	if not Profiles[userId] then
		-- Perfil descarregado NÃO significa que o crédito foi persistido.
		return false
	end
	if MemoryMode then
		return true -- ambiente Studio sem DataStore: confirmação só em memória
	end
	while Saving[userId] do
		task.wait(0.1)
	end
	Saving[userId] = true
	local ok, lost = writeProfile(userId, false)
	Saving[userId] = nil
	if lost then
		-- outro servidor assumiu esta conta: continuar aqui perderia todo ganho em silêncio
		player:Kick("Sua conta foi aberta em outro servidor. Entre novamente.")
	end
	return ok
end

function DataService.Remove(player: Player)
	local userId = player.UserId
	local profile = Profiles[userId]
	Removing[userId] = true
	if profile and not MemoryMode then
		while Saving[userId] do
			task.wait(0.1)
		end
		Saving[userId] = true
		writeProfile(userId, true)
		Saving[userId] = nil
	end
	if Profiles[userId] == profile then -- não apaga um perfil novo carregado depois
		Profiles[userId] = nil
		Dirty[userId] = nil
		ClaimCursor[userId] = nil
		LastClaimAlert[userId] = nil
		OwnerProofSweepCursor[userId] = nil
		OwnerProofSweepLastAt[userId] = nil
		WorkerArchiveCursor[userId] = nil
		WorkerArchiveLastAt[userId] = nil
	end
	Removing[userId] = nil
end

function DataService.Start()
	Players.PlayerAdded:Connect(DataService.Load)
	Players.PlayerRemoving:Connect(DataService.Remove)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(DataService.Load, player)
	end

	task.spawn(function()
		while true do
			task.wait(Config.AutoSaveSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(DataService.Save, player) -- sempre grava: renova a trava de sessão
				task.spawn(DataService.ReconcileWorkerClaims, player) -- recuperação C13 sob trava da própria conta
				task.spawn(DataService.ReconcileOwnerProofs, player) -- C22: comprovantes de ex-colaboradores
				task.spawn(DataService.ReconcileWorkerProofs, player) -- C24: compactar quitações confirmadas
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				DataService.Remove(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while (pending > 0 or next(Removing) ~= nil) and os.clock() - started < 25 do -- inclui saídas já em andamento (último jogador)
			task.wait(0.2)
		end
	end)
end

-- ===== Somente testes (tools/PersistenceTest.luau) =====
function DataService._setStoreForTesting(store: any, jobId: string, lockWaitMax: number?)
	Store = store
	MemoryMode = false
	JobId = jobId
	if lockWaitMax then
		LOCK_WAIT_MAX = lockWaitMax
	end
end

-- Apenas para a suíte de persistência: simular passagem do intervalo entre sweeps.
function DataService._resetProofSweepForTesting(userId: number)
	OwnerProofSweepLastAt[userId] = nil
	OwnerProofSweepCursor[userId] = nil
end

function DataService._resetWorkerArchiveForTesting(userId: number)
	WorkerArchiveLastAt[userId] = nil
	WorkerArchiveCursor[userId] = nil
end

function DataService._peekProfile(userId: number): any
	return Profiles[userId]
end

return DataService
