--!strict
-- Regras puras do mercado: como um cliente NPC escolhe oficina. Sem acesso ao jogo, portanto testável sem jogadores.
-- Fatores: preço, reputação, especialização (nível na área que o cliente precisa), distância, fila e disponibilidade.
local CustomerRules = {}

CustomerRules.MinPrice = 0.7
CustomerRules.MaxPrice = 1.5
CustomerRules.PriceStep = 0.05

export type Candidate = {
	Price: number, -- multiplicador do dono (1.0 = preço de tabela)
	Reputation: number,
	SpecLevel: number, -- nível do dono na especialização que o cliente procura
	ServiceableCount: number, -- quantos defeitos dessa área a oficina consegue atender agora
	OpenJobs: number, -- ordens abertas
	Capacity: number, -- máximo de ordens abertas
	Distance: number, -- studs entre o ponto de chegada e a entrada do lote
	Rating: number?, -- nota média (bayesiana) da oficina; ausente = neutra
}

-- ===== Avaliações =====
CustomerRules.RatingPriorMean = 3.5 -- oficina sem avaliações começa neutra
CustomerRules.RatingPriorWeight = 5 -- "avaliações fictícias" que seguram a média no começo

-- Média bayesiana: poucas avaliações pesam pouco (uma nota 5 sozinha não faz a oficina parecer perfeita).
function CustomerRules.AverageRating(sum: number, count: number): number
	local w = CustomerRules.RatingPriorWeight
	return (sum + CustomerRules.RatingPriorMean * w) / (count + w)
end

-- Multiplicador de atratividade pela nota média (1.0 em 3.5).
function CustomerRules.RatingFactor(average: number): number
	return math.clamp(1 + (average - 3.5) * 0.25, 0.5, 1.5)
end

export type ServiceContext = {
	PriceMultiplier: number, -- preço cobrado em relação à tabela
	WaitSeconds: number, -- do chegada do cliente até a conclusão
	PatienceSeconds: number, -- paciência do cliente
	LevelMargin: number, -- nível de quem executou menos o exigido (>= 0)
	ByNpc: boolean, -- feito por mecânico NPC
	Quality: number?, -- qualidade do minijogo de reparo (0-100); nil = sem minijogo (NPC/colaborador)
}

-- Nota de 1 a 5 que o cliente dá ao serviço. rand() em [0,1) acrescenta uma variação de ±0,5.
function CustomerRules.RateService(ctx: ServiceContext, rand: () -> number): number
	local score = 4.0
	-- preço justo agrada; caro desagrada
	local p = ctx.PriceMultiplier
	if p <= 0.9 then
		score += 0.5
	elseif p > 1.3 then
		score -= 1.0
	elseif p > 1.1 then
		score -= 0.5
	end
	-- espera
	local f = ctx.PatienceSeconds > 0 and ctx.WaitSeconds / ctx.PatienceSeconds or 0
	if f < 0.25 then
		score += 0.5
	elseif f >= 0.9 then
		score -= 1.0
	elseif f >= 0.6 then
		score -= 0.5
	end
	-- qualidade: quem sobra em nível entrega melhor acabamento
	if ctx.LevelMargin >= 2 then
		score += 0.5
	elseif ctx.LevelMargin >= 1 then
		score += 0.25
	end
	-- mecânico NPC é menos cuidadoso
	if ctx.ByNpc then
		score -= 0.5
	end
	-- qualidade do reparo (minijogo): quem capricha ganha nota; serviço mal feito perde
	local q = ctx.Quality
	if q then
		if q >= 90 then
			score += 0.75
		elseif q >= 70 then
			score += 0.25
		elseif q < 20 then
			score -= 1.25
		elseif q < 40 then
			score -= 0.75
		end
	end
	score += (rand() - 0.5) -- variação de humor do cliente
	return math.clamp(math.floor(score + 0.5), 1, 5)
end

-- Chave do comentário do cliente (texto em Locale), escolhida pelo fator que mais pesou na nota do próprio serviço.
-- Não há texto livre: o comentário é sempre derivado dos mesmos dados usados em RateService.
function CustomerRules.CommentKey(ctx: ServiceContext, stars: number): string
	local f = ctx.PatienceSeconds > 0 and ctx.WaitSeconds / ctx.PatienceSeconds or 0
	local q = ctx.Quality
	if q and q < 40 then
		return "rating_comment_sloppy"
	elseif q and q >= 90 and stars >= 4 then
		return "rating_comment_perfect"
	elseif f >= 0.6 then
		return "rating_comment_slow"
	elseif ctx.PriceMultiplier > 1.1 then
		return "rating_comment_expensive"
	elseif ctx.ByNpc and stars <= 3 then
		return "rating_comment_npc"
	elseif stars >= 4 and ctx.LevelMargin >= 1 then
		return "rating_comment_skilled"
	elseif stars >= 4 and f < 0.25 then
		return "rating_comment_fast"
	elseif stars >= 4 and ctx.PriceMultiplier <= 0.9 then
		return "rating_comment_cheap"
	elseif stars >= 4 then
		return "rating_comment_good"
	elseif stars == 3 then
		return "rating_comment_ok"
	end
	return "rating_comment_bad"
end

-- Ajuste de reputação pela nota (somado ao ganho padrão do serviço).
function CustomerRules.ReputationDelta(stars: number): number
	local table_ = { [1] = -2, [2] = -1, [3] = 0, [4] = 1, [5] = 2 }
	return table_[math.clamp(math.floor(stars), 1, 5)] or 0
end

function CustomerRules.StarsText(stars: number): string
	local n = math.clamp(math.floor(stars + 0.5), 0, 5)
	return string.rep("★", n) .. string.rep("☆", 5 - n)
end

-- Mantém o preço em [MinPrice, MaxPrice] e em múltiplos de PriceStep. NaN/inf viram 1.0.
function CustomerRules.ClampPrice(value: number): number
	if value ~= value or value == math.huge or value == -math.huge then
		return 1
	end
	local stepped = math.floor(value / CustomerRules.PriceStep + 0.5) * CustomerRules.PriceStep
	stepped = math.clamp(stepped, CustomerRules.MinPrice, CustomerRules.MaxPrice)
	return math.floor(stepped * 100 + 0.5) / 100
end

-- Atratividade (>= 0). Zero = o cliente nem considera esta oficina.
function CustomerRules.Score(c: Candidate): number
	if c.OpenJobs >= c.Capacity then
		return 0 -- sem espaço: não atende
	end
	if c.ServiceableCount <= 0 then
		return 0.02 -- não sabe/não pode fazer: só aparece por engano
	end
	local price = math.max(c.Price, 0.01)
	-- Elasticidade 2: contra um rival igual, o preço de tabela (1.0) maximiza a receita esperada; subir ou baixar demais perde.
	local priceFactor = (1 / price) ^ 2
	local repFactor = 1 + math.log(1 + math.max(c.Reputation, 0)) * 0.6
	local specFactor = 1 + (math.max(c.SpecLevel, 1) - 1) * 0.25
	local distFactor = 1 / (1 + math.max(c.Distance, 0) / 250)
	local queueFactor = 1 / (1 + c.OpenJobs * 0.35)
	local ratingFactor = CustomerRules.RatingFactor(c.Rating or CustomerRules.RatingPriorMean)
	return priceFactor * repFactor * specFactor * distFactor * queueFactor * ratingFactor
end

-- Opção "ir embora": atratividade fixa que concorre com as oficinas. Sem ela, um jogador sozinho poderia cobrar o teto
-- sem perder nenhum cliente. Com muitos clientes bons por perto o peso dela some.
CustomerRules.WalkAwayScore = 0.35

-- Sorteio proporcional à atratividade. Devolve o índice escolhido, ou nil se ninguém serve ou o cliente desiste.
function CustomerRules.Choose(candidates: { Candidate }, rand: () -> number): number?
	local total = 0
	local scores = {}
	for i, candidate in ipairs(candidates) do
		scores[i] = CustomerRules.Score(candidate)
		total += scores[i]
	end
	if total <= 0 then
		return nil
	end
	local roll = rand() * (total + CustomerRules.WalkAwayScore)
	if roll >= total then
		return nil -- desistiu
	end
	for i, s in ipairs(scores) do
		roll -= s
		if roll < 0 then
			return i
		end
	end
	return #candidates
end

-- Ranking das oficinas: reputação, depois total ganho, depois nome (ordem estável).
export type RankEntry = { Name: string, Reputation: number, TotalEarned: number, [string]: any }

function CustomerRules.Rank(entries: { RankEntry }): { RankEntry }
	local sorted = table.clone(entries)
	table.sort(sorted, function(a, b)
		if a.Reputation ~= b.Reputation then
			return a.Reputation > b.Reputation
		end
		if a.TotalEarned ~= b.TotalEarned then
			return a.TotalEarned > b.TotalEarned
		end
		return a.Name < b.Name
	end)
	return sorted
end

return CustomerRules
