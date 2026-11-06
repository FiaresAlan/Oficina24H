--!strict
-- Regras PURAS do minijogo de reparo "Apertar na hora certa" (sem Players/Workspace: testável no Edit).
-- O servidor sorteia o plano (semente), mede o tempo e RECALCULA tudo a partir dos instantes de toque enviados pelo
-- cliente; o cliente só desenha a barra e coleta os toques.
--
-- Qualidade final (0-100) considera 6 fatores (Product Owner, 2026-11-06):
--   Precisão     acerto de cada etapa (perfeito/bom) e rapidez total            -> execução base
--   Erros        etapa errada pede CORREÇÃO (até 2 por reparo); corrigido custa menos que ignorado
--   Habilidade   sobra de nível: zona maior e pontos extras (limitado)
--   Equipamento  eficiência do equipamento exigido: zona um pouco maior e pontos extras
--   Peça         confiabilidade da peça usada (remendo < peça nova < kit premium); faixas de peça ficam para depois
--   Diagnóstico  acertar de primeira dá pontos; cada palpite errado tira
-- Cada fator aparece no resumo do reparo (consequência legível).
local RepairRules = {}

RepairRules.MaxStepSeconds = 4 -- sem tocar por esse tempo = erro na etapa
RepairRules.MinStepSeconds = 0.25 -- toque mais rápido que isso é inválido (robô/lag impossível)
RepairRules.MaxSessionSeconds = 90 -- sessão expira
RepairRules.NetworkSlack = 0.6 -- folga (s) entre o tempo do cliente e o medido no servidor
RepairRules.PerfectQuality = 90 -- a partir daqui há gorjeta
RepairRules.PoorQuality = 40 -- abaixo disso o cliente paga menos
RepairRules.MaxCorrections = 2 -- correções permitidas por reparo

export type Plan = {
	Seed: number,
	Steps: number,
	Speed: number, -- ida e volta da barra: 2 / Speed segundos
	Width: number, -- largura da zona boa (0..1 da barra)
	Centers: { number }, -- centro da zona em cada etapa
	CorrectionCenters: { number }, -- centros das (até) 2 correções
	CorrectionWidth: number, -- zona de correção: um pouco maior (dá chance de consertar o erro)
	ParSeconds: number, -- tempo de referência (rapidez total)
}

export type Mods = {
	Margin: number, -- nível do mecânico menos o exigido (>= 0)
	EquipmentEfficiency: number, -- 0..4 do equipamento exigido
	PartReliability: number, -- média da confiabilidade das peças usadas (1 = neutra)
	DiagnosisAttempts: number, -- palpites até acertar (1 = de primeira)
}

-- Dificuldade: nível exigido pelo defeito. Sobra de nível e eficiência do equipamento alargam a zona; `assist`
-- (Reduzir movimento) deixa a barra mais lenta e a zona maior.
function RepairRules.BuildPlan(seed: number, requiredLevel: number, levelMargin: number, assist: boolean?, equipmentEfficiency: number?): Plan
	local level = math.max(1, math.floor(requiredLevel))
	local margin = math.max(0, math.floor(levelMargin))
	local efficiency = math.clamp(equipmentEfficiency or 0, 0, 4)
	local steps = 3 + (level >= 3 and 1 or 0) + (level >= 5 and 1 or 0)
	local speed = 0.8 + 0.1 * math.min(level, 6)
	local width = math.clamp(0.32 - 0.03 * (level - 1) + 0.02 * margin + 0.012 * efficiency, 0.14, 0.38)
	if assist then
		speed *= 0.7
		width = math.min(0.42, width + 0.05)
	end
	local rng = Random.new(seed)
	local centers = {}
	for i = 1, steps do
		centers[i] = 0.2 + rng:NextNumber() * 0.6
	end
	local correctionCenters = {}
	for i = 1, RepairRules.MaxCorrections do
		correctionCenters[i] = 0.2 + rng:NextNumber() * 0.6
	end
	return {
		Seed = seed, Steps = steps, Speed = speed, Width = width, Centers = centers,
		CorrectionCenters = correctionCenters, CorrectionWidth = math.min(0.46, width * 1.3), ParSeconds = steps * 3.0,
	}
end

-- Posição da barra (0..1) `t` segundos depois do início da etapa: onda triangular começando em 0.
function RepairRules.MarkerPosition(speed: number, t: number): number
	local x = (t * speed) % 2
	return x < 1 and x or 2 - x
end

-- "perfect" (centro da zona), "good" (dentro da zona) ou "miss".
local function judge(plan: Plan, center: number, width: number, t: number): string
	if t >= RepairRules.MaxStepSeconds then
		return "miss"
	end
	local distance = math.abs(RepairRules.MarkerPosition(plan.Speed, t) - center)
	if distance <= width * 0.25 then
		return "perfect"
	elseif distance <= width * 0.5 then
		return "good"
	end
	return "miss"
end

function RepairRules.Outcome(plan: Plan, step: number, t: number): string
	return judge(plan, plan.Centers[step], plan.Width, t)
end

function RepairRules.CorrectionOutcome(plan: Plan, correction: number, t: number): string
	return judge(plan, plan.CorrectionCenters[correction], plan.CorrectionWidth, t)
end

-- Pontos de cada fator (somados à execução base; limites pequenos: nenhum fator torna a execução irrelevante).
function RepairRules.SkillPoints(margin: number): number
	return math.min(6, 2 * math.max(0, math.floor(margin)))
end

function RepairRules.PartPoints(reliability: number): number
	return math.clamp(math.floor((reliability - 1) * 60 + 0.5), -8, 4)
end

function RepairRules.DiagnosisPoints(attempts: number): number
	if attempts <= 1 then
		return 6
	elseif attempts == 2 then
		return 0
	end
	return -6
end

export type Breakdown = {
	Execution: number, -- precisão + rapidez (0-100)
	Errors: number, -- negativo
	Skill: number,
	Equipment: number,
	Part: number,
	Diagnosis: number,
}

export type Result = {
	Valid: boolean,
	Reason: string?,
	Quality: number,
	Perfect: number,
	Good: number,
	Miss: number, -- etapas erradas na primeira tentativa
	Corrected: number, -- dessas, quantas foram consertadas
	Uncorrected: number,
	Breakdown: Breakdown,
}

local function invalid(reason: string): Result
	return {
		Valid = false, Reason = reason, Quality = 0, Perfect = 0, Good = 0, Miss = 0, Corrected = 0, Uncorrected = 0,
		Breakdown = { Execution = 0, Errors = 0, Skill = 0, Equipment = 0, Part = 0, Diagnosis = 0 },
	}
end

-- Valida a sequência de toques e calcula o resultado. A sequência é DETERMINADA pelos próprios resultados: depois de
-- uma etapa errada (se ainda houver correção disponível) o toque seguinte é a correção. `elapsed` é o tempo REAL medido
-- pelo servidor; a soma dos toques nunca pode passar dele (senão o cliente poderia pular a espera).
function RepairRules.Evaluate(plan: Plan, presses: any, elapsed: number, mods: Mods): Result
	if type(presses) ~= "table" then
		return invalid("toques inválidos")
	end
	local maxPresses = plan.Steps + RepairRules.MaxCorrections
	local count = #presses
	if count < plan.Steps or count > maxPresses then
		return invalid("quantidade de toques inválida")
	end
	local total = 0
	for i = 1, count do
		local t = presses[i]
		if type(t) ~= "number" or t ~= t or t == math.huge or t == -math.huge or t < RepairRules.MinStepSeconds or t > RepairRules.MaxStepSeconds then
			return invalid("toque fora do intervalo")
		end
		total += t
	end
	if elapsed < count * RepairRules.MinStepSeconds or elapsed + RepairRules.NetworkSlack < total then
		return invalid("tempo incompatível")
	end

	local perfect, good, miss, corrected, corrections = 0, 0, 0, 0, 0
	local index = 1
	for step = 1, plan.Steps do
		if index > count then
			return invalid("faltou o toque da etapa")
		end
		local outcome = RepairRules.Outcome(plan, step, presses[index])
		index += 1
		if outcome == "perfect" then
			perfect += 1
		elseif outcome == "good" then
			good += 1
		else
			miss += 1
			if corrections < RepairRules.MaxCorrections then
				corrections += 1
				if index > count then
					return invalid("faltou o toque da correção")
				end
				local fix = RepairRules.CorrectionOutcome(plan, corrections, presses[index])
				index += 1
				if fix ~= "miss" then
					corrected += 1
				end
			end
		end
	end
	if index - 1 ~= count then
		return invalid("toques sobrando")
	end

	local precision = (perfect + good * 0.6) / plan.Steps
	local speed = elapsed <= plan.ParSeconds and 1 or math.clamp(1 - (elapsed - plan.ParSeconds) / (plan.ParSeconds * 1.5), 0, 1)
	local uncorrected = miss - corrected
	local breakdown: Breakdown = {
		Execution = math.floor(100 * (0.8 * precision + 0.2 * speed) + 0.5),
		Errors = 0 - (corrected * 6 + uncorrected * 14), -- (0 - x evita o "-0")
		Skill = RepairRules.SkillPoints(mods.Margin),
		Equipment = math.clamp(math.floor(mods.EquipmentEfficiency + 0.5), 0, 4),
		Part = RepairRules.PartPoints(mods.PartReliability),
		Diagnosis = RepairRules.DiagnosisPoints(mods.DiagnosisAttempts),
	}
	local quality = breakdown.Execution + breakdown.Errors + breakdown.Skill + breakdown.Equipment + breakdown.Part + breakdown.Diagnosis
	return {
		Valid = true, Reason = nil, Quality = math.clamp(quality, 0, 100), Perfect = perfect, Good = good, Miss = miss,
		Corrected = corrected, Uncorrected = uncorrected, Breakdown = breakdown,
	}
end

-- Pagamento: serviço mal feito paga menos (85%).
function RepairRules.PayMultiplier(quality: number): number
	return quality < RepairRules.PoorQuality and 0.85 or 1
end

-- Gorjeta variável: 0 abaixo de 90; de 5% a 20% do preço conforme a qualidade (90 -> 5%, 100 -> 20%).
function RepairRules.Tip(price: number, quality: number): number
	if quality < RepairRules.PerfectQuality then
		return 0
	end
	local fraction = 0.05 + 0.15 * (quality - RepairRules.PerfectQuality) / (100 - RepairRules.PerfectQuality)
	return math.floor(price * fraction + 0.5)
end

-- Bônus de XP: +20% em serviço perfeito.
function RepairRules.XPBonus(xp: number, quality: number): number
	return quality >= RepairRules.PerfectQuality and math.floor(xp * 1.2 + 0.5) or xp
end

return RepairRules
