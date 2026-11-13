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

local DataService = {}

local SCHEMA_VERSION = 6 -- 6: reivindicação de remuneração colaborativa para recuperação pós-crash
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
		Parts = { TirePatch = 3, Battery = 1, Fuse = 2 }, -- estoque inicial para os primeiros serviços
		Transactions = {},
		TotalEarned = 0,
		PriceMultiplier = 1, -- preço da oficina em relação à tabela (0.7 a 1.5)
		RatingCount = 0, -- avaliações recebidas dos clientes (1 a 5 estrelas)
		RatingSum = 0,
		RecentRatings = {}, -- últimas 10: { Stars, Service, At, CommentKey, Customer }
		OrderHistory = {}, -- últimos serviços concluídos: { At, Vehicle, Customer, Service, Price, Stars }
		RepairLedger = {}, -- C8: crédito e comprovante por JobId+token, no mesmo perfil persistido
		PendingClaims = {}, -- C12: provas pendentes do mecânico, privadas, nunca replicadas
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
	data.PendingClaims = SettlementClaimRules.Sanitize(data.PendingClaims)
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
	if type(data.Transactions) ~= "table" then
		data.Transactions = {}
	end
	if type(data.Onboarding) ~= "table" then
		data.Onboarding = { Done = false }
	end
	data.Onboarding = { Done = data.Onboarding.Done == true }
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
	amount: number, role: string, serviceName: string, vehicleName: string): boolean
	local profile = Profiles[player.UserId]
	if not profile then return false end
	profile.RepairLedger = profile.RepairLedger or {}
	if not SettlementLedgerRules.Record(profile.RepairLedger, jobId, token, amount, role,
		os.time(), serviceName, vehicleName) then return false end
	DataService.AddCoins(player, amount, "Liquidação de OS: " .. serviceName)
	Dirty[player.UserId] = true
	return true
end

function DataService.HasRepairCredit(player: Player, jobId: any, token: any): boolean
	local profile = Profiles[player.UserId]
	return profile ~= nil and SettlementLedgerRules.Find(profile.RepairLedger, jobId, token) ~= nil
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

function DataService.DiscardWorkerClaim(worker: Player, jobId: any, token: any): boolean
	local profile = Profiles[worker.UserId]
	if not profile or not SettlementClaimRules.Remove(profile.PendingClaims, jobId, token) then return false end
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
			local already = DataService.HasRepairCredit(worker, claim.JobId, claim.Token)
			local verified = already
			if not already then
				local ok, ownerRaw = pcall(function()
					return Store:GetAsync(keyFor(claim.OwnerUserId))
				end)
				if ok and type(ownerRaw) == "table" then
					verified = SettlementClaimRules.Authorized(claim, ownerRaw.RepairLedger)
				elseif not ok then
					warn("[DataService] Falha ao consultar prova de pagamento:", userId, claim.JobId)
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
				-- Salva saldo+ledger ANTES de descartar a prova. Em erro, claim
				-- continua disponível e o ledger impede duplo crédito no retry.
				if DataService.Save(worker) then
					SettlementClaimRules.Remove(profile.PendingClaims, claim.JobId, claim.Token)
					Dirty[userId] = true
				end
			end
		end
	end
	ClaimCursor[userId] = total > 0 and ((start + visited - 1) % total) + 1 or 1
	Reconciling[userId] = nil
	return recovered
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
	Dirty[player.UserId] = true
	return true
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

function DataService._peekProfile(userId: number): any
	return Profiles[userId]
end

return DataService
