-- Testes do DataService com um DataStore simulado (não toca o DataStore real).
-- Rodar no Edit via MCP: clonar o módulo e dar require no clone (evita cache de execuções anteriores).
-- Cada "servidor" é uma cópia independente do DataService com seu próprio JobId.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local source = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("DataService")

local results: { string } = {}
local failures = 0
local function check(name: string, cond: boolean, detail: any?)
	if not cond then
		failures += 1
	end
	table.insert(results, (cond and "PASS " or "FAIL ") .. name .. (cond and "" or (" -> " .. tostring(detail))))
end

local function deepCopy(v: any): any
	if type(v) ~= "table" then return v end
	local c = {}
	for k, x in pairs(v) do c[k] = deepCopy(x) end
	return c
end

local function newStore()
	local store = { data = {}, failNext = 0, failGetNext = 0, calls = 0 }
	function store:GetAsync(key: string)
		if self.failGetNext > 0 then
			self.failGetNext -= 1
			error("simulated GetAsync failure")
		end
		return deepCopy(self.data[key])
	end
	function store:UpdateAsync(key: string, fn: (any) -> any)
		self.calls += 1
		if self.failNext > 0 then
			self.failNext -= 1
			error("simulated datastore failure")
		end
		local out = fn(deepCopy(self.data[key]))
		if out ~= nil then
			self.data[key] = deepCopy(out)
		end
		return out
	end
	return store
end

local function newServer(store: any, jobId: string, lockWait: number?)
	local clone = source:Clone()
	clone.Parent = ServerStorage
	local svc = require(clone)
	svc._setStoreForTesting(store, jobId, lockWait or 2)
	return svc, clone
end

local function fakePlayer(userId: number)
	local kicked: string? = nil
	local p = { UserId = userId, Parent = Players, DisplayName = "T" .. userId }
	function p:Kick(msg: string) kicked = msg end
	return p, function() return kicked end
end

local clones = {}
local function server(store, jobId, lockWait)
	local svc, clone = newServer(store, jobId, lockWait)
	table.insert(clones, clone)
	return svc
end

-- 1. Jogador novo
do
	local store = newStore()
	local A = server(store, "A")
	local p = fakePlayer(1)
	A.Load(p)
	local prof = A.Get(p)
	check("novo: perfil criado com moedas iniciais", prof and prof.Coins == 250, prof and prof.Coins)
	check("novo: kit básico presente", prof and prof.Equipment.BasicToolset == true)
	check("C16: kit inicia no nível 1", A.GetEquipmentLevel(p, "BasicToolset") == 1)
	check("C16: perfil novo já nasce no schema v8", prof.SchemaVersion == 8)
	check("novo: trava de sessão gravada", store.data["u_1"] and store.data["u_1"].Session and store.data["u_1"].Session.JobId == "A")
end

-- 2. Salvar, sair e recarregar em outro servidor
do
	local store = newStore()
	local A = server(store, "A")
	local p = fakePlayer(2)
	A.Load(p)
	A.AddCoins(p, 500, "Teste")
	A.AddSkillXP(p, "Engine", 130)
	A.GrantEquipment(p, "Jack")
	A.AddReputation(p, 7)
	A.Remove(p)
	check("sair: trava liberada", store.data["u_2"].Session == nil)
	local B = server(store, "B")
	B.Load(p)
	local prof = B.Get(p)
	check("recarga: moedas", prof and prof.Coins == 750, prof and prof.Coins)
	check("recarga: XP e nível", B.GetSkillLevel(p, "Engine") == 2, B.GetSkillLevel(p, "Engine"))
	check("recarga: equipamento persistido", prof and prof.Equipment.Jack == true)
	check("C16: equipamento existente migra para nível 1", B.GetEquipmentLevel(p, "Jack") == 1)
	check("recarga: reputação", prof and prof.Reputation == 7)
	check("recarga: histórico de transações", prof and #prof.Transactions == 1 and prof.Transactions[1].Reason == "Teste")
end

-- 3. Trava de sessão: B espera A liberar
do
	local store = newStore()
	local A = server(store, "A")
	local B = server(store, "B", 12)
	local p = fakePlayer(3)
	A.Load(p)
	A.AddCoins(p, 100, "A ganhou")
	task.delay(3.5, function() A.Remove(p) end)
	local t0 = os.clock()
	B.Load(p)
	local prof = B.Get(p)
	check("trava: B aguardou e carregou dados de A", prof and prof.Coins == 350, prof and prof.Coins)
	check("trava: B esperou pela liberação", os.clock() - t0 >= 3, os.clock() - t0)
end

-- 4. Trava presa: B recusa (kick) sem sobrescrever; trava expirada é tomada
do
	local store = newStore()
	local A = server(store, "A")
	local p = fakePlayer(4)
	A.Load(p)
	A.AddCoins(p, 1000, "dinheiro de A")
	A.Save(p)
	local before = deepCopy(store.data["u_4"])
	local B = server(store, "B", 1)
	local pB, kicked = fakePlayer(4)
	B.Load(pB)
	check("trava ativa: B expulsa o jogador", kicked() ~= nil, kicked())
	check("trava ativa: B não criou perfil", B.Get(pB) == nil)
	check("trava ativa: dados do DataStore intactos", store.data["u_4"].Coins == before.Coins)
	store.data["u_4"].Session.At = os.time() - 100000 -- servidor A "caiu"
	local C = server(store, "C", 1)
	C.Load(pB)
	check("trava expirada: C assume com dados preservados", C.Get(pB) and C.Get(pB).Coins == 1250, C.Get(pB) and C.Get(pB).Coins)
end

-- 5. Perda de trava no salvamento não sobrescreve
do
	local store = newStore()
	local A = server(store, "A")
	local p, kicked5 = fakePlayer(5)
	A.Load(p)
	store.data["u_5"].Session = { JobId = "OUTRO", At = os.time() }
	store.data["u_5"].Coins = 99999
	A.AddCoins(p, 1, "x")
	local ok = A.Save(p)
	check("trava perdida: save recusado", ok == false)
	check("trava perdida: dado do outro servidor preservado", store.data["u_5"].Coins == 99999, store.data["u_5"].Coins)
	check("trava perdida: jogador é expulso (não joga sem salvar)", kicked5() ~= nil, kicked5())
	-- falha temporária do DataStore NÃO expulsa: só tenta de novo no próximo autosave
	local q, kickedQ2 = fakePlayer(36)
	A.Load(q)
	store.failNext = 99
	A.AddCoins(q, 5, "y")
	check("falha temporária: save falha mas não expulsa", A.Save(q) == false and kickedQ2() == nil)
	store.failNext = 0
	check("falha temporária: o próximo save grava", A.Save(q) == true and store.data["u_36"].Coins == A.Get(q).Coins)
end

-- 6. Retentativas
do
	local store = newStore()
	local A = server(store, "A")
	store.failNext = 2
	local p, kicked = fakePlayer(6)
	A.Load(p)
	check("retry: carrega após 2 falhas", A.Get(p) ~= nil and kicked() == nil)
	store.failNext = 99
	local q, kickedQ = fakePlayer(7)
	A.Load(q)
	check("falha total: jogador expulso", kickedQ() ~= nil)
	check("falha total: sem perfil padrão (não sobrescreve)", A.Get(q) == nil)
	store.failNext = 0
end

-- 7. Migração v1 -> v2
do
	local store = newStore()
	store.data["u_8"] = { SchemaVersion = 1, Coins = 999, Reputation = 12, SkillXP = { Tires = 150 } }
	local A = server(store, "A")
	local p = fakePlayer(8)
	A.Load(p)
	local prof = A.Get(p)
	check("migração: dados antigos preservados", prof and prof.Coins == 999 and prof.SkillXP.Tires == 150)
	check("migração: campos novos criados", prof and prof.Equipment.BasicToolset and type(prof.Transactions) == "table" and prof.SchemaVersion == 4 and type(prof.Daily) == "table" and type(prof.League) == "table" and prof.League.Points == 0 and prof.WorkshopLevel ~= nil)
	check("migração: outras habilidades zeradas", prof and prof.SkillXP.Engine == 0)
end

-- 8. Economia: limite do histórico e saldo nunca negativo
do
	local store = newStore()
	local A = server(store, "A")
	local p = fakePlayer(9)
	A.Load(p)
	for i = 1, 70 do A.AddCoins(p, 1, "t" .. i) end
	local prof = A.Get(p)
	check("histórico limitado a 50", #prof.Transactions == 50, #prof.Transactions)
	check("histórico mantém os mais recentes", prof.Transactions[50].Reason == "t70")
	A.AddCoins(p, -999999, "gasto absurdo")
	check("saldo não fica negativo", prof.Coins == 0, prof.Coins)
	check("receita total só soma ganhos", prof.TotalEarned == 70, prof.TotalEarned)
end

-- 8b. Guia do 1º atendimento (onboarding)
do
	local store = newStore()
	store.data["u_30"] = { SchemaVersion = 2, Coins = 10, RatingCount = 3, RatingSum = 12 } -- perfil antigo que já atendeu
	store.data["u_31"] = { SchemaVersion = 2, Coins = 10, Onboarding = "lixo" } -- valor corrompido
	local A = server(store, "A")
	local fresh, old, bad = fakePlayer(29), fakePlayer(30), fakePlayer(31)
	A.Load(fresh) A.Load(old) A.Load(bad)
	check("guia: jogador novo começa sem concluir", A.Get(fresh).Onboarding.Done == false)
	check("guia: perfil antigo com clientes atendidos não repete o guia", A.Get(old).Onboarding.Done == true)
	check("guia: valor corrompido volta ao padrão", type(A.Get(bad).Onboarding) == "table" and A.Get(bad).Onboarding.Done == false)
	local coins = A.Get(fresh).Coins
	check("guia: bônus do 1º serviço paga uma vez", A.CompleteOnboarding(fresh, 40) == 40 and A.Get(fresh).Coins == coins + 40)
	check("guia: segunda conclusão não paga de novo", A.CompleteOnboarding(fresh, 40) == 0 and A.Get(fresh).Coins == coins + 40)
	local before = A.Get(bad).Coins
	check("guia: pular não paga bônus", A.CompleteOnboarding(bad, 0) == 0 and A.Get(bad).Coins == before and A.Get(bad).Onboarding.Done == true)
	check("guia: depois de pular, o bônus não é mais pago", A.CompleteOnboarding(bad, 40) == 0 and A.Get(bad).Coins == before)
	A.Remove(fresh)
	local B = server(store, "B")
	B.Load(fresh)
	check("guia: estado persiste após sair", B.Get(fresh).Onboarding.Done == true)
end

-- 8c. Valores não finitos nunca entram no perfil; perfil antigo com ganhos não repete o guia
do
	local store = newStore()
	store.data["u_32"] = { SchemaVersion = 2, Coins = 10, TotalEarned = 500 } -- sem avaliações, mas já ganhou dinheiro
	store.data["u_33"] = { SchemaVersion = 2, Coins = 10, Reputation = 0 / 0, TotalEarned = "x" }
	local A = server(store, "A")
	local old, bad, p = fakePlayer(32), fakePlayer(33), fakePlayer(34)
	A.Load(old) A.Load(bad) A.Load(p)
	check("guia: perfil com ganhos prévios não repete o guia", A.Get(old).Onboarding.Done == true)
	check("saneamento: reputação NaN e total ganho inválido voltam ao padrão", A.Get(bad).Reputation == A.Get(p).Reputation and A.Get(bad).TotalEarned == 0)
	local coins, rep, xp = A.Get(p).Coins, A.Get(p).Reputation, A.Get(p).SkillXP.Tires
	A.AddCoins(p, 0 / 0, "x") A.AddCoins(p, math.huge, "x") A.AddCoins(p, -math.huge, "x")
	A.AddReputation(p, 0 / 0) A.AddReputation(p, math.huge)
	A.AddSkillXP(p, "Tires", 0 / 0) A.AddSkillXP(p, "Tires", math.huge)
	check("NaN/infinito não alteram moedas, reputação nem XP", A.Get(p).Coins == coins and A.Get(p).Reputation == rep and A.Get(p).SkillXP.Tires == xp)
end

-- 8d. Reentrada rápida: Load espera o Remove anterior e não apaga o perfil novo
do
	local store = newStore()
	local A = server(store, "A")
	local p = fakePlayer(35)
	A.Load(p)
	A.AddCoins(p, 100, "antes de sair")
	local removed = false
	task.spawn(function() A.Remove(p) removed = true end)
	A.Load(p) -- reentra enquanto a saída pode estar gravando
	check("reentrada: recebe os dados gravados na saída", A.Get(p) ~= nil and A.Get(p).Coins == 350, A.Get(p) and A.Get(p).Coins)
	check("reentrada: a saída terminou antes do novo perfil", removed)
end

-- 9. Estoque de peças
do
	local store = newStore()
	local A = server(store, "A")
	local p = fakePlayer(10)
	A.Load(p)
	local prof = A.Get(p)
	check("peças: estoque inicial", prof.Parts.TirePatch == 3, prof.Parts.TirePatch)
	check("peças: AddParts soma", A.AddParts(p, "Tire", 4) and A.GetPartCount(p, "Tire") == 4)
	check("peças: AddParts inválido recusado", A.AddParts(p, "Foo", 1) == false and A.AddParts(p, "Tire", -3) == false and A.AddParts(p, "Tire", 0) == false)
	check("peças: TakeParts é tudo-ou-nada", A.TakeParts(p, { Tire = 2, EngineKit = 1 }) == false and A.GetPartCount(p, "Tire") == 4)
	check("peças: TakeParts desconta", A.TakeParts(p, { Tire = 2 }) and A.GetPartCount(p, "Tire") == 2)
	check("peças: esgotar remove a chave", A.TakeParts(p, { TirePatch = 3 }) and A.Get(p).Parts.TirePatch == nil)
	A.Remove(p)
	local B = server(store, "B")
	B.Load(p)
	check("peças: persistem após sair", B.GetPartCount(p, "Tire") == 2 and B.GetPartCount(p, "TirePatch") == 0)
	store.data["u_11"] = { SchemaVersion = 2, Coins = 5, Parts = { Tire = -5, Ghost = 3, Battery = 2.7, Fuse = "x" } }
	local C = server(store, "C")
	local q = fakePlayer(11)
	C.Load(q)
	local pp = C.Get(q).Parts
	check("peças: reconcile limpa lixo e arredonda", pp.Tire == nil and pp.Ghost == nil and pp.Fuse == nil and pp.Battery == 2, pp.Battery)
end

-- 10. Preço da oficina
do
	local store = newStore()
	local A = server(store, "A")
	local p = fakePlayer(12)
	A.Load(p)
	check("preço: padrão 1.0", A.Get(p).PriceMultiplier == 1)
	check("preço: define e normaliza (1.12 -> 1.1)", A.SetPriceMultiplier(p, 1.12) == 1.1)
	check("preço: limita ao teto", A.SetPriceMultiplier(p, 50) == 1.5)
	check("preço: limita ao piso", A.SetPriceMultiplier(p, -3) == 0.7)
	check("preço: NaN vira 1.0", A.SetPriceMultiplier(p, 0 / 0) == 1)
	A.SetPriceMultiplier(p, 1.25)
	A.Remove(p)
	local B = server(store, "B")
	B.Load(p)
	check("preço: persiste", B.Get(p).PriceMultiplier == 1.25, B.Get(p).PriceMultiplier)
	store.data["u_13"] = { SchemaVersion = 2, Coins = 5, PriceMultiplier = 99 }
	local C = server(store, "C")
	local q = fakePlayer(13)
	C.Load(q)
	check("preço: valor corrompido é corrigido", C.Get(q).PriceMultiplier == 1.5, C.Get(q).PriceMultiplier)
end

-- 11. Avaliações
do
	local store = newStore()
	local A = server(store, "A")
	local p = fakePlayer(14)
	A.Load(p)
	check("avaliações: começa zerado", A.Get(p).RatingCount == 0 and A.Get(p).RatingSum == 0)
	check("avaliações: registra notas válidas", A.AddRating(p, 5, "Pneu") == 1 and A.AddRating(p, 3, "Freio") == 2 and A.Get(p).RatingSum == 8)
	check("avaliações: inválidas recusadas", A.AddRating(p, 0, "x") == nil and A.AddRating(p, 6, "x") == nil and A.AddRating(p, 0 / 0, "x") == nil and A.Get(p).RatingCount == 2)
	for i = 1, 14 do A.AddRating(p, 4, "S" .. i) end
	check("avaliações: lista recente limitada a 10", #A.Get(p).RecentRatings == 10, #A.Get(p).RecentRatings)
	check("avaliações: lista mantém as mais novas", A.Get(p).RecentRatings[10].Service == "S14")
	-- comentário e cliente ficam guardados com a avaliação; histórico de serviços concluídos (limite 30, limpo na carga)
	A.AddRating(p, 5, "Motor", { CommentKey = "rating_comment_fast", Customer = "Ana" })
	local lastRating = A.Get(p).RecentRatings[10]
	check("avaliações: guarda comentário e cliente", lastRating.CommentKey == "rating_comment_fast" and lastRating.Customer == "Ana")
	for i = 1, 35 do A.AddOrderHistory(p, { Vehicle = "Hatch compacto", Customer = "C" .. i, Service = "S", Price = 10 + i, Stars = 4 }) end
	local hist = A.Get(p).OrderHistory
	check("histórico: limitado a 30 e mantém os mais novos", #hist == 30 and hist[30].Customer == "C35" and hist[1].Customer == "C6", #hist)
	A.AddOrderHistory(p, { Vehicle = "x", Customer = "y", Service = "z", Price = 0 / 0, Stars = 3 })
	check("histórico: preço inválido recusado", #A.Get(p).OrderHistory == 30)
	A.Remove(p)
	local B = server(store, "B")
	B.Load(p)
	check("avaliações: persistem", B.Get(p).RatingCount == 17 and B.Get(p).RatingSum == 8 + 14 * 4 + 5, B.Get(p).RatingCount)
	store.data["u_15"] = { SchemaVersion = 2, Coins = 1, RatingCount = 3, RatingSum = 99, RecentRatings = { { Stars = 9 }, { Stars = 4, Service = 7 }, "lixo", { Stars = 2, Service = "Ok", At = 5 } } }
	local C = server(store, "C")
	local q = fakePlayer(15)
	C.Load(q)
	local cp = C.Get(q)
	check("avaliações: soma corrompida limitada a 5x", cp.RatingSum == 15, cp.RatingSum)
	check("avaliações: lista corrompida é limpa", #cp.RecentRatings == 2 and cp.RecentRatings[1].Stars == 4 and cp.RecentRatings[1].Service == "" and cp.RecentRatings[2].Service == "Ok")
end

-- C8. Crédito e recibo persistem juntos no perfil após saída/reconexão.
do
	local store = newStore()
	local A = server(store, "settlementA")
	local p = fakePlayer(901)
	local owner = fakePlayer(902)
	A.Load(p)
	A.Load(owner)
	local token = "aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb"
	local start = A.Get(p).Coins
	check("ledger inicia vazio", type(A.Get(p).RepairLedger) == "table" and #A.Get(p).RepairLedger == 0)
	check("primeira liquidação credita", A.CreditRepairOnce(p, "job_1", token, 275, "Worker", "Freios", "Hatch"))
	check("saldo do executor atualizado", A.Get(p).Coins == start + 275)
	check("replay não credita pela segunda vez",
		not A.CreditRepairOnce(p, "job_1", token, 275, "Worker", "Freios", "Hatch"))
	check("saldo sem segunda cobrança", A.Get(p).Coins == start + 275)
	check("outra conta pode receber sua parte",
		A.CreditRepairOnce(owner, "job_1", token, 80, "Owner", "Freios", "Hatch"))
	check("partes das duas contas isoladas", A.Get(owner).Coins == 330 and A.Get(p).Coins == start + 275)
	check("marcador de crédito presente", A.HasRepairCredit(p, "job_1", token))
	check("sem crédito de token errado", not A.HasRepairCredit(p, "job_1", "cccccccc-1111-2222-3333-dddddddddddd"))
	local receipt = { JobId = "job_1", Token = token, Price = 275, Quality = 95,
		Tip = 0, XP = 45, Stars = 5, Breakdown = { Execution = 90 } }
	check("comprovante anexado", A.AttachRepairReceipt(p, "job_1", token, receipt))
	check("comprovante não duplica", not A.AttachRepairReceipt(p, "job_1", token, receipt))
	check("comprovante recuperado no perfil", A.GetRepairReceipt(p, "job_1", token).Price == 275)
	check("outro beneficiário não vê recibo do executor", A.GetRepairReceipt(owner, "job_1", token) == nil)
	local ownerReceipt = { JobId = "job_1", Token = token, Price = 80, Quality = 95, Stars = 5 }
	check("dono anexa seu recibo", A.AttachRepairReceipt(owner, "job_1", token, ownerReceipt))
	check("salvamento do dono aprovado", A.Save(owner))
	-- Falha somente na conta do executor após a primeira conta já ter sido gravada.
	store.failNext = 4
	check("falha persistente não retorna sucesso falso", A.Save(p) == false)
	check("crédito continua único em memória", A.HasRepairCredit(p, "job_1", token)
		and not A.CreditRepairOnce(p, "job_1", token, 275, "Worker", "Freios", "Hatch"))
	check("salvamento posterior do executor recupera", A.Save(p))
	A.Remove(p) A.Remove(owner)
	local B = server(store, "settlementB")
	B.Load(p) B.Load(owner)
	check("recarga mantém saldo executor", B.Get(p).Coins == start + 275)
	check("recarga mantém crédito proprietário", B.Get(owner).Coins == 330)
	check("recarga mantém chave de idempotência", B.HasRepairCredit(p, "job_1", token))
	check("recarga nega crédito duplicado", not B.CreditRepairOnce(p, "job_1", token, 275, "Worker", "Freios", "Hatch"))
	check("recarga mantém recibo", B.GetRepairReceipt(p, "job_1", token).Quality == 95)
	check("dono vê somente o seu comprovante", B.GetRepairReceipt(owner, "job_1", token).Price == 80)
	check("lista do executor omite token", B.RecentRepairSettlements(p, 3)[1].Token == nil)
	check("lista de operações mostra valor e papel", B.RecentRepairSettlements(p, 3)[1].Amount == 275 and B.RecentRepairSettlements(p, 3)[1].Role == "Worker")
end

-- C12/C13: crash entre salvamento do dono e do contratado.
-- A reivindicação é salva ANTES de qualquer pagamento; o dono é prova de autorização.
do
	local token = "cccccccc-1111-2222-3333-dddddddddddd"
	local store = newStore()
	local A = server(store, "claimA")
	local worker = fakePlayer(1101)
	local owner = fakePlayer(1102)
	A.Load(worker) A.Load(owner)
	local workerInitial = A.Get(worker).Coins
	check("C12: reivindicação pode ser preparada",
		A.StageWorkerClaim(worker, 1102, "job_77", token, 120, 280, 44, 92,
			"Freios", "Hatch", "Freios"))
	check("C12: salva a reivindicação antes de creditar", A.Save(worker))
	check("C12: claim foi persistida sem saldo", #store.data["u_1101"].PendingClaims == 1
		and store.data["u_1101"].Coins == workerInitial)
	check("C12: dono recebe crédito uma vez", A.CreditRepairOnce(owner, "job_77",
		token, 120, "Owner", "Freios", "Hatch", worker.UserId, 280))
	check("C14: dono guarda prova vinculada ao mecânico",
		#A.Get(owner).OwnerSettlementProofs == 1)
	-- O histórico comum gira, mas a prova de repasse C14 permanece no arquivo.
	for i = 1, 70 do
		local tk = string.format("11111111-3333-4444-5555-%012d", i)
		A.CreditRepairOnce(owner, "other_" .. i, tk, 10, "Owner", "Freios", "Hatch")
	end
	check("C14: histórico comum não tem mais OS original",
		not A.HasRepairCredit(owner, "job_77", token))
	check("C14: arquivo retém prova da OS",
		#A.Get(owner).OwnerSettlementProofs == 1
		and A.Get(owner).OwnerSettlementProofs[1].WorkerUserId == worker.UserId)
	check("C12: dono salva antes do executor", A.Save(owner))
	A.Remove(worker) A.Remove(owner)
	-- Simula passagem do tempo após crash: recuperação nunca concorre com uma
	-- liquidação normal que ainda está em execução no servidor de origem.
	store.data["u_1101"].PendingClaims[1].At -= 900 -- simula novo servidor sem aplicar parcela do contratado
	local B = server(store, "claimB")
	B.Load(worker)
	check("C16: migração do schema v8", B.Get(worker).SchemaVersion == 8)
	local recovered = B.ReconcileWorkerClaims(worker)
	check("C13: parcela ausente recuperada", recovered == 1
		or B.HasRepairCredit(worker, "job_77", token))
	check("C13: saldo exato recuperado uma vez", B.Get(worker).Coins == workerInitial + 280)
	check("C13: XP pago após crash", B.Get(worker).SkillXP.Freios == 44)
	check("C13: recibo mínimo disponível", B.GetRepairReceipt(worker, "job_77", token).Price == 280)
	B.ReconcileWorkerClaims(worker)
	check("C13: repetição nunca gera segundo crédito/XP",
		B.Get(worker).Coins == workerInitial + 280 and B.Get(worker).SkillXP.Freios == 44)
	check("C13: comprovante permanece após segunda reconexão", B.Save(worker))
	B.Remove(worker)
	local C = server(store, "claimC")
	C.Load(worker)
	check("C13: reentrada mantém crédito único", C.Get(worker).Coins == workerInitial + 280
		and C.HasRepairCredit(worker, "job_77", token))
end

-- Não pagar uma claim se a parcela do dono não foi gravada ou está divergente.
do
	local store = newStore()
	local A = server(store, "claimNoOwnerA")
	local worker, owner = fakePlayer(1201), fakePlayer(1202)
	local token = "eeeeeeee-1111-2222-3333-ffffffffffff"
	A.Load(worker) A.Load(owner)
	check("C13: reivindicação isolada salva",
		A.StageWorkerClaim(worker, 1202, "job_88", token, 80, 220, 32, 88,
			"Freios", "Hatch", "Freios") and A.Save(worker))
	A.Remove(worker)
	store.data["u_1201"].PendingClaims[1].At -= 900
	local B = server(store, "claimNoOwnerB")
	B.Load(worker)
	B.ReconcileWorkerClaims(worker)
	check("C13: sem crédito do dono não paga", B.Get(worker).Coins == 250
		and not B.HasRepairCredit(worker, "job_88", token))
	check("C13: reivindicação não desaparece sem prova", #B.Get(worker).PendingClaims == 1)
	A.CreditRepairOnce(owner, "job_88", token, 81, "Owner", "Freios", "Hatch")
	A.Save(owner)
	B.ReconcileWorkerClaims(worker)
	check("C13: valor divergente não autoriza", B.Get(worker).Coins == 250)
	-- O ledger persistido demonstra agora o pagamento correto em um novo serviço.
	local token2 = "11111111-2222-3333-4444-555555555555"
	check("C13: nova reivindicação preparada",
		B.StageWorkerClaim(worker, 1202, "job_89", token2, 80, 220, 32, 88,
			"Freios", "Hatch", "Freios") and B.Save(worker))
	B.Get(worker).PendingClaims[2].At -= 900
	check("C13: dono paga próxima OS", A.CreditRepairOnce(owner, "job_89", token2,
		80, "Owner", "Freios", "Hatch") and A.Save(owner))
	store.failGetNext = 2 -- duas claims pendentes; ambas precisam falhar neste ciclo
	B.ReconcileWorkerClaims(worker)
	check("C13: falha de leitura não inventa receita", not B.HasRepairCredit(worker, "job_89", token2))
	B.ReconcileWorkerClaims(worker)
	check("C13: leitura recuperada paga", B.HasRepairCredit(worker, "job_89", token2)
		and B.Get(worker).Coins == 470)
	check("C15: apenas contagem pública de reivindicações", B.PendingClaimSummary(worker).Count == 1
		and B.PendingClaimSummary(worker).Token == nil)
end

-- C21: a prova do proprietário só pode desaparecer quando a claim do
-- executor já tiver sido removida com sucesso do DataStore dele.
do
	local store = newStore()
	local A = server(store, "proofC21-A")
	local worker, owner = fakePlayer(2101), fakePlayer(2102)
	local token = "cccccccc-aaaa-4444-bbbb-dddddddddddd"
	A.Load(worker) A.Load(owner)
	local startWorker = A.Get(worker).Coins
	check("C21: permite registrar claim e persistir antes da OS",
		A.StageWorkerClaim(worker, owner.UserId, "job_2101", token,
			120, 230, 44, 92, "Freios", "Hatch", "Freios") and A.Save(worker))
	check("C21: dono registra sua parcela e prova do contratado",
		A.CreditRepairOnce(owner, "job_2101", token, 120, "Owner",
			"Freios", "Hatch", worker.UserId, 230) and A.Save(owner))
	check("C21: prova do proprietário fica disponível após o 1º save",
		#store.data["u_2102"].OwnerSettlementProofs == 1)
	check("C21: crédito do executor salvo de forma idempotente",
		A.CreditRepairOnce(worker, "job_2101", token, 230, "Worker", "Freios", "Hatch")
			and A.Save(worker))
	check("C21: claim persistente ainda pede limpeza",
		#store.data["u_2101"].PendingClaims == 1)
	check("C21: limpeza da claim inicia em memória", A.DiscardWorkerClaim(worker, "job_2101", token))
	store.failNext = 4
	check("C21: save falhou, claim ainda está no disco",
		not A.Save(worker) and #store.data["u_2101"].PendingClaims == 1)
	check("C21: erro NÃO libera prova do dono",
		#store.data["u_2102"].OwnerSettlementProofs == 1
			and #A.Get(owner).OwnerSettlementProofs == 1)
	check("C21: retentativa salva remoção da claim", A.Save(worker)
		and #store.data["u_2101"].PendingClaims == 0)
	check("C21: prova fica vinculada ao trabalhador correto",
		not A.DiscardConfirmedOwnerProof(owner, "job_2101", token, 2103)
			and #A.Get(owner).OwnerSettlementProofs == 1)
	check("C21: após save do trabalhador, dono pode liberar prova",
		A.DiscardConfirmedOwnerProof(owner, "job_2101", token, worker.UserId)
			and A.Save(owner) and #store.data["u_2102"].OwnerSettlementProofs == 0)
	A.Remove(worker) A.Remove(owner)
	local B = server(store, "proofC21-B")
	B.Load(worker) B.Load(owner)
	check("C21: após reconexão saldo do trabalhador é exato",
		B.Get(worker).Coins == startWorker + 230
			and B.HasRepairCredit(worker, "job_2101", token))
	check("C21: claims finalizadas não ressurgem após reconexão",
		#B.Get(worker).PendingClaims == 0
			and #B.Get(owner).OwnerSettlementProofs == 0)
	check("C21: replay não gera segundo pagamento",
		not B.CreditRepairOnce(worker, "job_2101", token, 230, "Worker", "Freios", "Hatch")
			and B.Get(worker).Coins == startWorker + 230)
end

-- C21: arquivo cheio não pode apagar créditos antigos e não pode conceder
-- parcela do proprietário sem registrar prova do contratado.
do
	local Proofs = require(game.ReplicatedStorage.Shared.OwnerSettlementProofRules)
	local store = newStore()
	local A = server(store, "proofFull")
	local owner = fakePlayer(2120)
	A.Load(owner)
	for i = 1, Proofs.MaxEntries do
		local token = string.format("21212121-3333-4444-5555-%012d", i)
		Proofs.Add(A.Get(owner).OwnerSettlementProofs,
			Proofs.Make("old_" .. i, token, 2101, 20, 40, "Freios", "Hatch", 1790000000))
	end
	local coins = A.Get(owner).Coins
	local token = "21212121-4444-5555-6666-777777777777"
	check("C21: capacidade do dono detecta arquivo completo", not A.HasOwnerProofCapacity(owner))
	check("C21: owner não credita sem conseguir registrar prova nova",
		not A.CreditRepairOnce(owner, "job_new", token, 60, "Owner",
			"Freios", "Hatch", 2101, 100)
		and A.Get(owner).Coins == coins
		and not A.HasRepairCredit(owner, "job_new", token))
	check("C21: entrada antiga continua para recuperação",
		Proofs.Find(A.Get(owner).OwnerSettlementProofs, "old_1",
			"21212121-3333-4444-5555-000000000001") ~= nil)
	check("C21: remover uma prova confirmada reabre capacidade",
		A.DiscardConfirmedOwnerProof(owner, "old_1",
			"21212121-3333-4444-5555-000000000001", 2101)
		and A.HasOwnerProofCapacity(owner))
end

-- C21 revisão: a prova pode ficar cheia durante o Save da claim do
-- contratado. A transação do dono deve devolver peças se não puder pagar.
do
	local Proofs = require(game.ReplicatedStorage.Shared.OwnerSettlementProofRules)
	local store = newStore()
	local A = server(store, "settleOwnerAtomic")
	local owner = fakePlayer(2130)
	A.Load(owner)
	local token = "21302130-aaaa-bbbb-cccc-000000000001"
	local start = A.Get(owner).Coins
	local pieces = A.GetPartCount(owner, "TirePatch")
	check("C21: reserva do dono debita peças e paga na mesma operação",
		A.SettleRepairOwnerOnce(owner, "job_1", token, 80, { TirePatch = 2 },
			"Freios", "Hatch", 2101, 120)
		and A.GetPartCount(owner, "TirePatch") == pieces - 2
		and A.Get(owner).Coins == start + 80
		and #A.Get(owner).OwnerSettlementProofs == 1)
	check("C21: repetir mesma liquidação não consome peça nem paga novamente",
		not A.SettleRepairOwnerOnce(owner, "job_1", token, 80, { TirePatch = 2 },
			"Freios", "Hatch", 2101, 120)
		and A.GetPartCount(owner, "TirePatch") == pieces - 2
		and A.Get(owner).Coins == start + 80)
	check("C21: validar números de partes antes de mutar perfil",
		not A.SettleRepairOwnerOnce(owner, "job_invalid", "21302130-aaaa-bbbb-cccc-000000000002",
			80, { TirePatch = -1 }, "Freios", "Hatch", 2101, 120))
	-- Deixe o arquivo lotado, mas ainda existe estoque de uma peça.
	for i = 2, Proofs.MaxEntries do
		local tk = string.format("21302130-eeee-ffff-0000-%012d", i)
		Proofs.Add(A.Get(owner).OwnerSettlementProofs,
			Proofs.Make("old_" .. i, tk, 2101, 20, 40, "Freios", "Hatch", 1790000000))
	end
	local before = A.Get(owner).Coins
	local beforeParts = A.GetPartCount(owner, "TirePatch")
	check("C21: falta de capacidade faz rollback de peças sem crédito",
		not A.SettleRepairOwnerOnce(owner, "job_next",
			"21302130-aaaa-bbbb-cccc-000000000003", 90, { TirePatch = 1 },
			"Freios", "Hatch", 2101, 140)
		and A.Get(owner).Coins == before
		and A.GetPartCount(owner, "TirePatch") == beforeParts
		and not A.HasRepairCredit(owner, "job_next", "21302130-aaaa-bbbb-cccc-000000000003"))
end

-- C13: dados corrompidos de reivindicação são descartados na migração.
do
	local store = newStore()
	store.data["u_1301"] = {
		SchemaVersion = 5, Coins = 300,
		PendingClaims = { { WorkerPay = math.huge }, "corrompida" },
	}
	local A = server(store, "claimCorruptA")
	local p = fakePlayer(1301)
	A.Load(p)
	check("C16: schema atualizado ao carregar v5", A.Get(p).SchemaVersion == 8)
	check("C13: sanitize de reivindicações corrompidas", #A.Get(p).PendingClaims == 0)
	check("C13: mantém saldo antigo", A.Get(p).Coins == 300)
end

-- C16: upgrade persistente, débito único, limites e recarga.
do
	local store = newStore()
	local A = server(store, "upgradeA")
	local p = fakePlayer(1601)
	A.Load(p)
	check("C16: equipamento não comprado não pode melhorar",
		not select(1, A.UpgradeOwnedEquipment(p, "Scanner")))
	check("C16: kit nível 2 custa 180", select(1, A.UpgradeOwnedEquipment(p, "BasicToolset"))
		and A.Get(p).Coins == 70 and A.GetEquipmentLevel(p, "BasicToolset") == 2)
	check("C16: saldo insuficiente não muda nível", not select(1, A.UpgradeOwnedEquipment(p, "BasicToolset"))
		and A.GetEquipmentLevel(p, "BasicToolset") == 2 and A.Get(p).Coins == 70)
	A.AddCoins(p, 420, "Teste de melhoria")
	check("C16: nível 3 custa 420", select(1, A.UpgradeOwnedEquipment(p, "BasicToolset"))
		and A.GetEquipmentLevel(p, "BasicToolset") == 3 and A.Get(p).Coins == 70)
	check("C16: nível máximo não cobra novamente", not select(1, A.UpgradeOwnedEquipment(p, "BasicToolset"))
		and A.Get(p).Coins == 70)
	A.Remove(p)
	local B = server(store, "upgradeB")
	B.Load(p)
	check("C16: upgrade persiste ao reconectar", B.GetEquipmentLevel(p, "BasicToolset") == 3
		and B.Get(p).Coins == 70)
end

-- C20: serviço NPC consome estoque e credita UMA VEZ no mesmo perfil.
do
	local store = newStore()
	local A = server(store, "npc20-A")
	local p = fakePlayer(2001)
	A.Load(p)
	A.AddParts(p, "Tire", 2)
	local token = "55555555-2222-3333-4444-555555555555"
	local initial = A.Get(p).Coins
	check("C20: não aceita quantidade de peça inválida", not A.SettleNpcRepairOnce(p, "job_1", token,
		150, { Tire = -2 }, "Troca", "Hatch"))
	check("C20: sem estoque não concede crédito", not A.SettleNpcRepairOnce(p, "job_1", token,
		150, { BrakePad = 100 }, "Troca", "Hatch"))
	check("C20: valor negativo não concede crédito", not A.SettleNpcRepairOnce(p, "job_1", token,
		-150, { Tire = 1 }, "Troca", "Hatch"))
	check("C20: nenhuma falha consome peças ou dinheiro",
		A.GetPartCount(p, "Tire") == 2 and A.Get(p).Coins == initial)
	check("C20: reparo NPC liquida com peças e ledger", A.SettleNpcRepairOnce(p, "job_1", token,
		150, { Tire = 1 }, "Troca", "Hatch")
		and A.GetPartCount(p, "Tire") == 1 and A.Get(p).Coins == initial + 150
		and A.HasRepairCredit(p, "job_1", token))
	check("C20: replay do mesmo token é recusado sem novo débito", not A.SettleNpcRepairOnce(p, "job_1", token,
		150, { Tire = 1 }, "Troca", "Hatch")
		and A.GetPartCount(p, "Tire") == 1 and A.Get(p).Coins == initial + 150)
	-- Falha de quatro tentativas não deve declarar recebimento confirmado;
	-- a mesma intenção é gravada novamente SEM conceder dinheiro ou peça extra.
	store.failNext = 4
	check("C20: falha total do DataStore não declara pagamento salvo", not A.Save(p)
		and store.data["u_2001"].Coins == initial)
	check("C20: falha não remove ledger em memória e não permite replay",
		A.HasRepairCredit(p, "job_1", token) and A.Get(p).Coins == initial + 150
		and A.GetPartCount(p, "Tire") == 1
		and not A.SettleNpcRepairOnce(p, "job_1", token, 150, { Tire = 1 }, "Troca", "Hatch"))
	check("C20: retentativa grava crédito e estoque juntos", A.Save(p)
		and store.data["u_2001"].Coins == initial + 150
		and store.data["u_2001"].Parts.Tire == 1)
	A.Remove(p)
	local B = server(store, "npc20-B")
	B.Load(p)
	check("C20: reconexão conserva saldo, ledger e estoque",
		B.Get(p).Coins == initial + 150 and B.GetPartCount(p, "Tire") == 1
		and B.HasRepairCredit(p, "job_1", token))
end

for _, c in ipairs(clones) do c:Destroy() end
table.insert(results, failures == 0 and "TODOS OS TESTES PASSARAM" or (failures .. " TESTE(S) FALHARAM"))
return table.concat(results, "\n")
