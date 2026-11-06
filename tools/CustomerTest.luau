-- Testes do mercado de clientes (CustomerRules + JobRules com especialização). Rodar no Edit via MCP.
local ServerStorage = game:GetService("ServerStorage")
local sharedClone = game.ReplicatedStorage.Shared:Clone()
sharedClone.Parent = ServerStorage
local CR = require(sharedClone.CustomerRules)
local JR = require(sharedClone.JobRules)
local Catalog = require(sharedClone.Catalog)

local results, failures = {}, 0
local function check(name, cond, detail)
	if not cond then failures += 1 end
	table.insert(results, (cond and "PASS " or "FAIL ") .. name .. (cond and "" or (" -> " .. tostring(detail))))
end

local function base()
	return { Price = 1, Reputation = 10, SpecLevel = 1, ServiceableCount = 3, OpenJobs = 0, Capacity = 3, Distance = 200 }
end
local function with(overrides)
	local c = base()
	for k, v in pairs(overrides) do c[k] = v end
	return c
end
-- Fatia da oficina `a` entre os clientes que fecharam com alguma das duas (ignora quem desistiu).
local function share(a, b, draws)
	local rng = Random.new(11)
	local wins, taken = 0, 0
	for _ = 1, draws do
		local pick = CR.Choose({ a, b }, function() return rng:NextNumber() end)
		if pick then
			taken += 1
			if pick == 1 then wins += 1 end
		end
	end
	return taken > 0 and wins / taken or 0
end

-- Probabilidade de um cliente fechar com uma oficina sozinha no bairro.
local function takeRate(c, draws)
	local rng = Random.new(21)
	local taken = 0
	for _ = 1, draws do
		if CR.Choose({ c }, function() return rng:NextNumber() end) then taken += 1 end
	end
	return taken / draws
end

-- ClampPrice
check("preço: 1.0 permanece", CR.ClampPrice(1) == 1)
check("preço: acima do máximo", CR.ClampPrice(9) == CR.MaxPrice, CR.ClampPrice(9))
check("preço: abaixo do mínimo", CR.ClampPrice(0.1) == CR.MinPrice, CR.ClampPrice(0.1))
check("preço: arredonda ao passo de 0.05", CR.ClampPrice(1.12) == 1.1, CR.ClampPrice(1.12))
check("preço: NaN vira 1", CR.ClampPrice(0 / 0) == 1)
check("preço: infinito vira 1", CR.ClampPrice(math.huge) == 1 and CR.ClampPrice(-math.huge) == 1)

-- Score / Choose
check("sem espaço: score zero", CR.Score(with({ OpenJobs = 3 })) == 0)
check("não atende a área: score mínimo", CR.Score(with({ ServiceableCount = 0 })) < 0.05)
check("oficina cheia nunca é escolhida", share(with({ OpenJobs = 3 }), with({}), 2000) == 0)
check("ninguém serve: nil", CR.Choose({ with({ OpenJobs = 3 }), with({ OpenJobs = 3 }) }, math.random) == nil)
check("lista vazia: nil", CR.Choose({}, math.random) == nil)
local cheap = share(with({ Price = 0.8 }), with({ Price = 1.2 }), 4000)
check("mais barato atrai a maioria (>65%)", cheap > 0.65, cheap)
check("preço absurdo fica com poucos (<22%)", share(with({ Price = 1.5 }), with({ Price = 0.7 }), 4000) < 0.22)
local rep = share(with({ Reputation = 60 }), with({ Reputation = 0 }), 4000)
check("reputação maior atrai mais (>60%)", rep > 0.6, rep)
local spec = share(with({ SpecLevel = 6 }), with({ SpecLevel = 1 }), 4000)
check("especialista atrai mais (>60%)", spec > 0.6, spec)
local near = share(with({ Distance = 50 }), with({ Distance = 500 }), 4000)
check("mais perto atrai mais (>55%)", near > 0.55, near)
local queue = share(with({ OpenJobs = 0 }), with({ OpenJobs = 2 }), 4000)
check("fila curta atrai mais (>55%)", queue > 0.55, queue)
local eq = share(with({}), with({}), 6000)
check("candidatos iguais dividem ~50%", math.abs(eq - 0.5) < 0.04, eq)
check("preço alto compensado por reputação", share(with({ Price = 1.3, Reputation = 200 }), with({ Price = 1.0, Reputation = 0 }), 4000) > 0.4)
-- Equilíbrio: preço de 0.7 não deve dominar absolutamente quando o outro tem reputação alta
local dump = share(with({ Price = 0.7, Reputation = 0 }), with({ Price = 1.0, Reputation = 200 }), 4000)
check("dumping não elimina a oficina de reputação (>15%)", dump < 0.85, dump)

-- Receita esperada por cliente (preço x probabilidade): preço 1.0 vs 1.5 contra um rival a 1.0
local function revenue(price)
	local p = share(with({ Price = price }), with({ Price = 1.0 }), 4000)
	return p * price
end
check("subir muito o preço reduz a receita esperada", revenue(1.5) < revenue(1.0), revenue(1.5) .. " vs " .. revenue(1.0))

-- Oficina sozinha: preço mexe na demanda (clientes desistem) e o teto não é a melhor estratégia
local solo = {}
for _, p in ipairs({ 0.7, 1.0, 1.5 }) do solo[p] = takeRate(with({ Price = p, Reputation = 0 }), 6000) end
check("solo: demanda cai com o preço", solo[0.7] > solo[1.0] and solo[1.0] > solo[1.5], string.format("%.2f %.2f %.2f", solo[0.7], solo[1.0], solo[1.5]))
check("solo: cobrar o teto rende menos que a tabela", solo[1.5] * 1.5 < solo[1.0] * 1.0, string.format("%.3f vs %.3f", solo[1.5] * 1.5, solo[1.0]))
check("solo: dumping (0.7) rende menos que a tabela", solo[0.7] * 0.7 < solo[1.0] * 1.0, string.format("%.3f vs %.3f", solo[0.7] * 0.7, solo[1.0]))
check("solo: reputação alta aumenta a demanda", takeRate(with({ Reputation = 100 }), 6000) > takeRate(with({ Reputation = 0 }), 6000))
check("solo: sempre chega algum cliente (>25%) no preço de tabela", solo[1.0] > 0.25, solo[1.0])

-- Avaliações
check("média bayesiana: sem notas = neutra", math.abs(CR.AverageRating(0, 0) - 3.5) < 1e-9)
check("média bayesiana: uma nota 5 não vira 5", CR.AverageRating(5, 1) < 4, CR.AverageRating(5, 1))
check("média bayesiana: converge com muitas notas", math.abs(CR.AverageRating(500, 100) - 5) < 0.2, CR.AverageRating(500, 100))
check("fator de nota: 3.5 é neutro", math.abs(CR.RatingFactor(3.5) - 1) < 1e-9)
check("fator de nota: monotônico", CR.RatingFactor(5) > CR.RatingFactor(4) and CR.RatingFactor(4) > CR.RatingFactor(2))
check("fator de nota: limitado", CR.RatingFactor(100) <= 1.5 and CR.RatingFactor(-100) >= 0.5)
local function mean(ctx, n)
	local rng = Random.new(31)
	local sum, minS, maxS, allInt = 0, 9, 0, true
	for _ = 1, n do
		local s = CR.RateService(ctx, function() return rng:NextNumber() end)
		sum += s
		minS, maxS = math.min(minS, s), math.max(maxS, s)
		if s ~= math.floor(s) then allInt = false end
	end
	return sum / n, minS, maxS, allInt
end
local good = mean({ PriceMultiplier = 0.9, WaitSeconds = 20, PatienceSeconds = 300, LevelMargin = 2, ByNpc = false }, 4000)
local bad, bmin, bmax, bint = mean({ PriceMultiplier = 1.5, WaitSeconds = 290, PatienceSeconds = 300, LevelMargin = 0, ByNpc = true }, 4000)
local mid = mean({ PriceMultiplier = 1.0, WaitSeconds = 100, PatienceSeconds = 300, LevelMargin = 0, ByNpc = false }, 4000)
check("serviço ótimo: média >= 4.6", good >= 4.6, good)
check("serviço péssimo: média <= 2.3", bad <= 2.3, bad)
check("serviço comum: média entre 3.5 e 4.5", mid >= 3.5 and mid <= 4.5, mid)
check("notas sempre inteiras entre 1 e 5", bint and bmin >= 1 and bmax <= 5, bmin .. "," .. bmax)
check("preço alto piora a nota", mean({ PriceMultiplier = 1.4, WaitSeconds = 50, PatienceSeconds = 300, LevelMargin = 0, ByNpc = false }, 3000) < mid)
check("espera longa piora a nota", mean({ PriceMultiplier = 1.0, WaitSeconds = 280, PatienceSeconds = 300, LevelMargin = 0, ByNpc = false }, 3000) < mid)
check("mecânico NPC piora a nota", mean({ PriceMultiplier = 1.0, WaitSeconds = 100, PatienceSeconds = 300, LevelMargin = 0, ByNpc = true }, 3000) < mid)
check("sobra de nível melhora a nota", mean({ PriceMultiplier = 1.0, WaitSeconds = 100, PatienceSeconds = 300, LevelMargin = 3, ByNpc = false }, 3000) > mid)
check("paciência zero não quebra", CR.RateService({ PriceMultiplier = 1, WaitSeconds = 5, PatienceSeconds = 0, LevelMargin = 0, ByNpc = false }, function() return 0.5 end) >= 1)
check("reputação por nota: 5 -> +2, 1 -> -2", CR.ReputationDelta(5) == 2 and CR.ReputationDelta(1) == -2 and CR.ReputationDelta(3) == 0)
check("estrelas em texto", CR.StarsText(4) == "★★★★☆" and CR.StarsText(0) == "☆☆☆☆☆" and CR.StarsText(5) == "★★★★★")

-- Comentário do cliente: sempre derivado dos fatores reais do serviço (chaves existentes em Locale)
do
	local Locale = require(sharedClone.Locale)
	local base = { PriceMultiplier = 1, WaitSeconds = 10, PatienceSeconds = 300, LevelMargin = 0, ByNpc = false }
	local function ctx(over) local c = table.clone(base) for k, v in pairs(over) do c[k] = v end return c end
	check("comentário: espera longa", CR.CommentKey(ctx({ WaitSeconds = 200 }), 3) == "rating_comment_slow")
	check("comentário: preço alto", CR.CommentKey(ctx({ PriceMultiplier = 1.3 }), 3) == "rating_comment_expensive")
	check("comentário: NPC com nota baixa", CR.CommentKey(ctx({ ByNpc = true, WaitSeconds = 100 }), 3) == "rating_comment_npc")
	check("comentário: nível sobrando", CR.CommentKey(ctx({ LevelMargin = 2, WaitSeconds = 100 }), 5) == "rating_comment_skilled")
	check("comentário: rápido", CR.CommentKey(ctx({}), 5) == "rating_comment_fast")
	check("comentário: barato", CR.CommentKey(ctx({ PriceMultiplier = 0.8, WaitSeconds = 100 }), 5) == "rating_comment_cheap")
	check("comentário: nota 1 sem fator", CR.CommentKey(ctx({ WaitSeconds = 100 }), 1) == "rating_comment_bad")
	local allKeysExist = true
	for _, key in ipairs({ "slow", "expensive", "npc", "skilled", "fast", "cheap", "good", "ok", "bad" }) do
		if Locale.t("rating_comment_" .. key) == "rating_comment_" .. key then allKeysExist = false end
	end
	check("comentários têm texto no Locale", allKeysExist)
end
local rated = share(with({ Rating = 4.6 }), with({ Rating = 2.5 }), 4000)
check("nota alta atrai mais clientes (>60%)", rated > 0.6, rated)
check("nota ausente = neutra", math.abs(CR.Score(with({})) - CR.Score(with({ Rating = 3.5 }))) < 1e-9)

-- Ranking
local ranked = CR.Rank({
	{ Name = "B", Reputation = 5, TotalEarned = 100 },
	{ Name = "A", Reputation = 5, TotalEarned = 100 },
	{ Name = "C", Reputation = 9, TotalEarned = 1 },
	{ Name = "D", Reputation = 5, TotalEarned = 900 },
})
check("ranking: maior reputação primeiro", ranked[1].Name == "C")
check("ranking: desempate por total ganho", ranked[2].Name == "D")
check("ranking: desempate final por nome", ranked[3].Name == "A" and ranked[4].Name == "B")

-- JobRules com filtro de especialização
local lv, eqp = {}, { BasicToolset = true }
for _, s in ipairs(Catalog.Specializations) do lv[s] = 1 end
local rng = Random.new(5)
local wrong = 0
for _ = 1, 600 do
	local id = JR.PickDefectId(lv, eqp, function() return rng:NextNumber() end, "Bodywork")
	if Catalog.Defects[id].Specialization ~= "Bodywork" then wrong += 1 end
end
check("defeito respeita a especialização pedida", wrong == 0, wrong)
local counts = JR.ServiceableCountIn("Bodywork", lv, eqp)
check("contagem atendível em Funilaria (novato) >= 1", counts >= 1, counts)
check("contagem atendível cresce com equipamento", JR.ServiceableCountIn("Bodywork", lv, { BasicToolset = true, BodyworkKit = true, Compressor = true }) >= counts)

sharedClone:Destroy()
table.insert(results, failures == 0 and "TODOS OS TESTES PASSARAM" or (failures .. " TESTE(S) FALHARAM"))
return table.concat(results, "\n")
