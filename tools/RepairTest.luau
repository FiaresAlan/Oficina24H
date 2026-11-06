-- Testes das regras PURAS do minijogo de reparo (shared/RepairRules), do diagnóstico (shared/DiagnosisRules) e do efeito
-- da qualidade na nota (CustomerRules). Rodar no Edit via MCP (clone + require, como as outras suítes).
local ServerStorage = game:GetService("ServerStorage")
local sharedClone = game.ReplicatedStorage.Shared:Clone()
sharedClone.Parent = ServerStorage
local R = require(sharedClone.RepairRules)
local CR = require(sharedClone.CustomerRules)
local DR = require(sharedClone.DiagnosisRules)
local Catalog = require(sharedClone.Catalog)

local results: { string } = {}
local failures = 0
local function check(name: string, cond: boolean, detail: any?)
	if not cond then failures += 1 end
	table.insert(results, (cond and "PASS " or "FAIL ") .. name .. (cond and "" or (" -> " .. tostring(detail))))
end

-- Plano: determinista, dentro das faixas, dificuldade cresce com o nível
local a, b = R.BuildPlan(1234, 2, 0), R.BuildPlan(1234, 2, 0)
local same = a.Steps == b.Steps and a.Speed == b.Speed and a.Width == b.Width
for i = 1, a.Steps do same = same and a.Centers[i] == b.Centers[i] end
for i = 1, R.MaxCorrections do same = same and a.CorrectionCenters[i] == b.CorrectionCenters[i] end
check("plano: mesma semente = mesmo plano", same)
check("plano: sementes diferentes mudam as zonas", R.BuildPlan(1, 2, 0).Centers[1] ~= R.BuildPlan(2, 2, 0).Centers[1])
local easy, hard = R.BuildPlan(7, 1, 0), R.BuildPlan(7, 6, 0)
check("plano: nível alto = mais etapas, mais rápido e zona menor", hard.Steps > easy.Steps and hard.Speed > easy.Speed and hard.Width < easy.Width, hard.Steps .. "/" .. easy.Steps)
check("plano: etapas entre 3 e 5", easy.Steps == 3 and hard.Steps == 5 and R.BuildPlan(7, 3, 0).Steps == 4)
check("plano: sobra de nível alarga a zona", R.BuildPlan(7, 4, 3).Width > R.BuildPlan(7, 4, 0).Width)
check("plano: equipamento melhor alarga a zona", R.BuildPlan(7, 4, 0, false, 4).Width > R.BuildPlan(7, 4, 0, false, 0).Width)
check("plano: zona nunca fora dos limites", R.BuildPlan(7, 99, 0).Width >= 0.14 and R.BuildPlan(7, 1, 99, false, 99).Width <= 0.38)
local assist = R.BuildPlan(7, 4, 0, true)
check("plano: assistência deixa mais lento e mais fácil", assist.Speed < R.BuildPlan(7, 4, 0).Speed and assist.Width > R.BuildPlan(7, 4, 0).Width)
check("plano: zona de correção é um pouco maior", easy.CorrectionWidth > easy.Width and easy.CorrectionWidth <= 0.46)
local centersOk = true
for _, p in ipairs({ easy, hard, assist }) do
	for i = 1, p.Steps do centersOk = centersOk and p.Centers[i] >= 0.2 and p.Centers[i] <= 0.8 end
	for i = 1, R.MaxCorrections do centersOk = centersOk and p.CorrectionCenters[i] >= 0.2 and p.CorrectionCenters[i] <= 0.8 end
end
check("plano: centros em [0.2, 0.8]", centersOk)

-- Barra: onda triangular em [0,1]
check("barra: começa em 0", R.MarkerPosition(1, 0) == 0)
check("barra: chega a 1 e volta", math.abs(R.MarkerPosition(1, 1) - 1) < 1e-9 and math.abs(R.MarkerPosition(1, 2)) < 1e-9)
local inRange = true
for i = 0, 400 do
	local p = R.MarkerPosition(1.3, i * 0.037)
	inRange = inRange and p >= 0 and p <= 1
end
check("barra: sempre em [0,1]", inRange)
check("barra: periódica", math.abs(R.MarkerPosition(1.3, 0.4) - R.MarkerPosition(1.3, 0.4 + 2 / 1.3)) < 1e-9)

-- Resultado de cada toque
local plan = R.BuildPlan(99, 2, 0)
local speed, center = plan.Speed, plan.Centers[1]
check("toque: no centro = perfect", R.Outcome(plan, 1, center / speed) == "perfect")
local tGood = (center + plan.Width * 0.4) / speed
check("toque: dentro da zona = good", R.Outcome(plan, 1, tGood) == "good", R.Outcome(plan, 1, tGood))
local tMiss = (center + plan.Width * 0.9) / speed
check("toque: fora da zona = miss", R.Outcome(plan, 1, tMiss) == "miss" and R.Outcome(plan, 1, R.MaxStepSeconds) == "miss")
check("correção: no centro = perfect, tempo esgotado = miss", R.CorrectionOutcome(plan, 1, plan.CorrectionCenters[1] / speed) == "perfect" and R.CorrectionOutcome(plan, 1, R.MaxStepSeconds) == "miss")

-- Ajudantes
local MISS = R.MaxStepSeconds
local function perfectAt(i: number): number return plan.Centers[i] / plan.Speed end
local function sum(t: { number }): number local s = 0 for _, v in ipairs(t) do s += v end return s end
local neutral = { Margin = 0, EquipmentEfficiency = 0, PartReliability = 1, DiagnosisAttempts = 2 }
local function play(seq: any, mods: any?)
	local elapsed = type(seq) == "table" and math.max(sum(seq), #seq * R.MinStepSeconds) or 5
	return R.Evaluate(plan, seq, elapsed, mods or neutral)
end
local allPerfect = {}
for i = 1, plan.Steps do allPerfect[i] = perfectAt(i) end

-- Validação dos toques
check("toques: válidos aceitos", play(allPerfect).Valid)
check("toques: quantidade errada ou tipo errado recusados", not play({ 1, 1 }).Valid and not R.Evaluate(plan, "x", 5, neutral).Valid and not R.Evaluate(plan, nil, 5, neutral).Valid)
local function with(i: number, v: any): { any } local c = table.clone(allPerfect) c[i] = v return c end
check("toques: NaN/infinito/negativo/zero/enorme/texto recusados",
	not play(with(1, 0 / 0)).Valid and not play(with(1, math.huge)).Valid and not play(with(1, -1)).Valid
		and not play(with(1, 0)).Valid and not play(with(1, 99)).Valid and not play(with(1, "1")).Valid)
check("tempo: soma maior que o tempo real recusada", not R.Evaluate(plan, { 3, 3, 3 }, 1, neutral).Valid)
check("tempo: rápido demais para a quantidade de toques recusado", not R.Evaluate(plan, allPerfect, 0.1, neutral).Valid)
check("tempo: folga de rede definida", R.NetworkSlack > 0 and R.NetworkSlack < 2)
check("toque extra sem erro recusado", not play({ allPerfect[1], allPerfect[2], allPerfect[3], 1 }).Valid)
check("erro sem o toque de correção recusado", not play({ MISS, perfectAt(2), perfectAt(3) }).Valid)
check("mais de Etapas+2 toques recusado", not play({ MISS, MISS, MISS, MISS, MISS, MISS }).Valid)

-- Qualidade
local best = play(allPerfect)
check("qualidade: tudo perfeito e neutro = 100", best.Valid and best.Quality == 100 and best.Perfect == plan.Steps and best.Miss == 0, best.Quality)
local worst = play({ MISS, MISS, MISS, MISS, MISS })
check("qualidade: tudo errado = 0", worst.Valid and worst.Quality == 0 and worst.Miss == plan.Steps, worst.Reason)

-- Erro + correção (no máximo 2 por reparo)
local function withCorrection(fixPerfect: boolean): { number }
	local t = { MISS, fixPerfect and (plan.CorrectionCenters[1] / plan.Speed) or MISS }
	for i = 2, plan.Steps do table.insert(t, perfectAt(i)) end
	return t
end
local fixed, unfixed = play(withCorrection(true)), play(withCorrection(false))
check("correção: erro consertado conta", fixed.Valid and fixed.Miss == 1 and fixed.Corrected == 1 and fixed.Uncorrected == 0 and fixed.Breakdown.Errors == -6, fixed.Reason)
check("correção: erro não consertado custa mais", unfixed.Valid and unfixed.Uncorrected == 1 and unfixed.Breakdown.Errors == -14 and unfixed.Quality < fixed.Quality)
check("correção: consertado ainda vale menos que perfeito", fixed.Quality < best.Quality)
check("correção: só 2 por reparo (3 erros = 5 toques)", R.MaxCorrections == 2 and worst.Miss == 3 and worst.Corrected + worst.Uncorrected == 3)

-- Seis fatores
local base = play(withCorrection(false))
local function delta(m: any): number return play(withCorrection(false), m).Quality - base.Quality end
check("fator habilidade: sobra de nível soma pontos (limite 6)", delta({ Margin = 3, EquipmentEfficiency = 0, PartReliability = 1, DiagnosisAttempts = 2 }) == 6 and R.SkillPoints(1) == 2 and R.SkillPoints(9) == 6)
check("fator equipamento: eficiência soma 0-4 pontos", delta({ Margin = 0, EquipmentEfficiency = 4, PartReliability = 1, DiagnosisAttempts = 2 }) == 4
	and R.Evaluate(plan, withCorrection(false), 30, { Margin = 0, EquipmentEfficiency = 99, PartReliability = 1, DiagnosisAttempts = 2 }).Breakdown.Equipment == 4)
check("fator peça: pontos por confiabilidade", R.PartPoints(0.90) == -6 and R.PartPoints(1) == 0 and R.PartPoints(1.05) == 3 and R.PartPoints(0.5) == -8 and R.PartPoints(2) == 4)
check("fator peça: entra no resultado", delta({ Margin = 0, EquipmentEfficiency = 0, PartReliability = 0.9, DiagnosisAttempts = 2 }) == -6)
check("fator diagnóstico: pontos por tentativa", R.DiagnosisPoints(1) == 6 and R.DiagnosisPoints(2) == 0 and R.DiagnosisPoints(3) == -6 and R.DiagnosisPoints(9) == -6)
check("fator diagnóstico: entra no resultado", delta({ Margin = 0, EquipmentEfficiency = 0, PartReliability = 1, DiagnosisAttempts = 1 }) == 6 and delta({ Margin = 0, EquipmentEfficiency = 0, PartReliability = 1, DiagnosisAttempts = 3 }) == -6)
local br = base.Breakdown
check("detalhamento soma a qualidade (sem teto)", br.Execution + br.Errors + br.Skill + br.Equipment + br.Part + br.Diagnosis == base.Quality)
check("qualidade nunca passa de 100 nem fica abaixo de 0", play(allPerfect, { Margin = 9, EquipmentEfficiency = 4, PartReliability = 2, DiagnosisAttempts = 1 }).Quality == 100 and worst.Quality >= 0)

-- Rapidez
local slowRun = R.Evaluate(plan, allPerfect, plan.ParSeconds * 2, neutral)
check("rapidez: lento perde só a parte da rapidez", slowRun.Valid and slowRun.Quality < 100 and slowRun.Quality >= 75, slowRun.Quality)

-- Pagamento, gorjeta e XP
check("pagamento: serviço ruim paga 85%", R.PayMultiplier(39) == 0.85 and R.PayMultiplier(40) == 1 and R.PayMultiplier(100) == 1)
check("gorjeta: nenhuma abaixo de 90", R.Tip(100, 89) == 0 and R.Tip(100, 0) == 0)
check("gorjeta: 90 = 5% e 100 = 20%", R.Tip(100, 90) == 5 and R.Tip(100, 100) == 20, R.Tip(100, 90) .. "/" .. R.Tip(100, 100))
local tipGrows = true
for q = 90, 99 do tipGrows = tipGrows and R.Tip(400, q + 1) >= R.Tip(400, q) end
check("gorjeta: cresce com a qualidade", tipGrows)
check("XP: +20% só em serviço perfeito", R.XPBonus(50, 90) == 60 and R.XPBonus(50, 89) == 50)

-- Diagnóstico por escolha
local rnd = Random.new(11)
local function rand(): number return rnd:NextNumber() end
local optionsOk = true
for realId in pairs(Catalog.Defects) do
	local opts = DR.BuildOptions(Catalog.Defects, realId, nil, rand)
	local seen, hasReal = {}, false
	for _, id in ipairs(opts) do
		optionsOk = optionsOk and not seen[id] and Catalog.Defects[id] ~= nil
		seen[id] = true
		hasReal = hasReal or id == realId
	end
	optionsOk = optionsOk and #opts == DR.OptionCount and hasReal
end
check("diagnóstico: 3 opções distintas, sempre com o defeito real", optionsOk)
local realId, hintId
for id in pairs(Catalog.Defects) do
	if not realId then realId = id elseif not hintId then hintId = id end
end
check("diagnóstico: o defeito sugerido pela reclamação entra nas opções", table.find(DR.BuildOptions(Catalog.Defects, realId, hintId, rand), hintId) ~= nil)
local opts = DR.BuildOptions(Catalog.Defects, realId, nil, rand)
local wrongId, outside
for _, id in ipairs(opts) do if id ~= realId then wrongId = id break end end
for id in pairs(Catalog.Defects) do if not table.find(opts, id) then outside = id break end end
check("diagnóstico: escolha certa", DR.Judge(opts, {}, realId, realId) == "correct")
check("diagnóstico: escolha errada", DR.Judge(opts, {}, realId, wrongId) == "wrong")
check("diagnóstico: palpite repetido é inválido", DR.Judge(opts, { [wrongId] = true }, realId, wrongId) == "invalid")
check("diagnóstico: fora das opções, nulo e tipo errado inválidos",
	DR.Judge(opts, {}, realId, outside) == "invalid" and DR.Judge(opts, {}, realId, nil) == "invalid" and DR.Judge(opts, {}, realId, 5) == "invalid" and DR.Judge(opts, {}, realId, {}) == "invalid")

-- Catálogo: eficiência e confiabilidade
local effOk = true
for id in pairs(Catalog.Equipment) do
	effOk = effOk and type(Catalog.EquipmentEfficiency[id]) == "number" and Catalog.EquipmentEfficiency[id] >= 0 and Catalog.EquipmentEfficiency[id] <= 4
end
check("catálogo: todo equipamento tem eficiência 0-4", effOk)
local relOk = true
for id, value in pairs(Catalog.PartReliability) do
	relOk = relOk and Catalog.Parts[id] ~= nil and value >= 0.8 and value <= 1.1
end
check("catálogo: confiabilidade só para peças existentes e em faixa razoável", relOk)
check("catálogo: peça sem valor conta como neutra (1)", Catalog.AveragePartReliability({ Tire = 1 }) == 1 and Catalog.AveragePartReliability(nil) == 1
	and math.abs(Catalog.AveragePartReliability({ TirePatch = 1, Tire = 1 }) - 0.95) < 1e-9)

-- Nota do cliente com qualidade
local ctx = { PriceMultiplier = 1, WaitSeconds = 100, PatienceSeconds = 300, LevelMargin = 0, ByNpc = false }
local function avg(q: number?): number
	local c = table.clone(ctx) c.Quality = q
	local total, n = 0, 400
	local seed = Random.new(5)
	for _ = 1, n do total += CR.RateService(c, function() return seed:NextNumber() end) end
	return total / n
end
check("nota: qualidade perfeita > sem minijogo > ruim", avg(100) > avg(nil) and avg(nil) > avg(10), avg(100) .. "/" .. avg(nil) .. "/" .. avg(10))
check("comentário: qualidade ruim", CR.CommentKey({ PriceMultiplier = 1, WaitSeconds = 10, PatienceSeconds = 300, LevelMargin = 0, ByNpc = false, Quality = 20 }, 2) == "rating_comment_sloppy")
check("comentário: qualidade perfeita", CR.CommentKey({ PriceMultiplier = 1, WaitSeconds = 100, PatienceSeconds = 300, LevelMargin = 0, ByNpc = false, Quality = 95 }, 5) == "rating_comment_perfect")
local Locale = require(sharedClone.Locale)
local keys = { "rp_perfect", "rp_fix", "rp_fixed", "rp_factors", "rp_f_precision", "rp_f_errors", "rp_f_skill", "rp_f_equipment", "rp_f_part", "rp_f_diagnosis", "dg_title", "dg_hint", "rating_comment_perfect", "rating_comment_sloppy" }
local missing = {}
for _, k in ipairs(keys) do if Locale.t(k) == k then table.insert(missing, k) end end
check("textos do minijogo e do diagnóstico existem", #missing == 0, table.concat(missing, ","))

sharedClone:Destroy()
table.insert(results, failures == 0 and "TODOS OS TESTES PASSARAM" or (failures .. " TESTE(S) FALHARAM"))
return table.concat(results, "\n")
