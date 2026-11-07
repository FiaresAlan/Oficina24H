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
	local store = { data = {}, failNext = 0, calls = 0 }
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

for _, c in ipairs(clones) do c:Destroy() end
table.insert(results, failures == 0 and "TODOS OS TESTES PASSARAM" or (failures .. " TESTE(S) FALHARAM"))
return table.concat(results, "\n")
