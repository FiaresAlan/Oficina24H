--!strict
-- Três procedimentos curtos e distintos, avaliados pelo servidor.
-- São alternativas ao minijogo de timing; mantém RepairRules para outros serviços.
local RepairRules = require(script.Parent.RepairRules)
local RepairOperations = {}

local SPOTS = { "Inner", "Center", "Outer" }
local HINTS = {
	Inner = "Bolhas no ombro INTERNO do pneu.",
	Center = "Bolhas no CENTRO da banda de rodagem.",
	Outer = "Bolhas no ombro EXTERNO do pneu.",
}
local BATTERY_SEQUENCE = { "OffNegative", "OffPositive", "OnPositive", "OnNegative" }
-- Duração mínima para uma operação humana plausível; não prova cada clique, mas impede conclusão instantânea.
local MIN_DURATION = { Tire = 2, Battery = 3.5, Cooling = 3 }

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

-- nil = outro defeito, usar minijogo de timing legado.
function RepairOperations.BuildPlan(defectId: string, seed: number): any?
	if defectId == "FlatTire" then
		local spot = SPOTS[(math.floor(seed) % #SPOTS) + 1]
		return { Kind = "Operations", Mode = "Tire", LeakSpot = spot, Hint = HINTS[spot], TargetPressure = 32 }
	elseif defectId == "WeakBattery" then
		return { Kind = "Operations", Mode = "Battery", Sequence = BATTERY_SEQUENCE }
	elseif defectId == "Overheating" then
		return { Kind = "Operations", Mode = "Cooling", TargetFluid = 2, TargetBleed = 2 }
	end
	return nil
end

-- Não revelar campos de correção do servidor no payload.
function RepairOperations.PublicPlan(plan: any): any
	if plan.Mode == "Tire" then
		return { Kind = plan.Kind, Mode = plan.Mode, Hint = plan.Hint, PressureTarget = plan.TargetPressure, MinSeconds = MIN_DURATION.Tire }
	elseif plan.Mode == "Battery" then
		return { Kind = plan.Kind, Mode = plan.Mode, Hint = "Desconecte negativo, depois positivo; conecte positivo, depois negativo.", MinSeconds = MIN_DURATION.Battery }
	end
	return { Kind = plan.Kind, Mode = plan.Mode, Hint = "Complete 2 litros, faça 2 ciclos de sangria e verifique a ventoinha.", MinSeconds = MIN_DURATION.Cooling }
end

local function invalid(reason: string): any
	return {
		Valid = false, Reason = reason, Quality = 0, Perfect = 0, Good = 0, Miss = 0,
		Corrected = 0, Uncorrected = 0,
		Breakdown = { Execution = 0, Errors = 0, Skill = 0, Equipment = 0, Part = 0, Diagnosis = 0 },
	}
end

-- Avalia um formulário de operação com o mesmo contrato de resultado de RepairRules.
-- As entradas são decisões do jogador; não alteram as tabelas de preços ou o estoque.
function RepairOperations.Evaluate(plan: any, input: any, elapsed: number, mods: RepairRules.Mods): any
	if type(plan) ~= "table" or plan.Kind ~= "Operations" or type(input) ~= "table" then
		return invalid("procedimento inválido")
	end
	local minDuration = MIN_DURATION[plan.Mode]
	if not minDuration or not finite(elapsed) or elapsed < minDuration or elapsed > RepairRules.MaxSessionSeconds then
		return invalid("duração do procedimento inválida")
	end
	local execution, successes, errors = 0, 0, 0
	if plan.Mode == "Tire" then
		if type(input.Spot) ~= "string" or not table.find(SPOTS, input.Spot) or not finite(input.Pressure)
			or input.Pressure < 0 or input.Pressure > 45 then
			return invalid("remendo ou pressão inválidos")
		end
		local patchOk = input.Spot == plan.LeakSpot
		local offset = math.abs(input.Pressure - plan.TargetPressure)
		execution = (patchOk and 60 or 10) + math.max(0, 40 - offset * 8)
		successes = (patchOk and 1 or 0) + (offset <= 1 and 1 or 0)
		errors = 2 - successes
	elseif plan.Mode == "Battery" then
		if type(input.Steps) ~= "table" or #input.Steps ~= #plan.Sequence then
			return invalid("ordem de terminais incompleta")
		end
		local used = {}
		for index, action in ipairs(input.Steps) do
			if type(action) ~= "string" or not table.find(BATTERY_SEQUENCE, action) or used[action] then
				return invalid("ordem de terminais inválida")
			end
			used[action] = true
			if action == plan.Sequence[index] then
				successes += 1
			end
		end
		execution = successes * 25
		errors = 4 - successes
	elseif plan.Mode == "Cooling" then
		if not finite(input.Fluid) or input.Fluid < 0 or input.Fluid > 3
			or not finite(input.BleedCycles) or input.BleedCycles % 1 ~= 0
			or input.BleedCycles < 0 or input.BleedCycles > 5
			or type(input.FanChecked) ~= "boolean" then
			return invalid("calibração de arrefecimento inválida")
		end
		local deltaFluid = math.abs(input.Fluid - plan.TargetFluid)
		execution = math.max(0, 45 - deltaFluid * 30)
			+ math.max(0, 30 - math.abs(input.BleedCycles - plan.TargetBleed) * 15)
			+ (input.FanChecked and 25 or 0)
		successes = (deltaFluid <= 0.25 and 1 or 0)
			+ (input.BleedCycles == plan.TargetBleed and 1 or 0)
			+ (input.FanChecked and 1 or 0)
		errors = 3 - successes
	else
		return invalid("tipo de procedimento desconhecido")
	end

	local breakdown = {
		Execution = math.floor(math.clamp(execution, 0, 100) + 0.5),
		Errors = 0, -- desvios já descontados na execução para não penalizar duas vezes
		Skill = RepairRules.SkillPoints(mods.Margin),
		Equipment = math.clamp(math.floor(mods.EquipmentEfficiency + 0.5), 0, 4),
		Part = RepairRules.PartPoints(mods.PartReliability),
		Diagnosis = RepairRules.DiagnosisPoints(mods.DiagnosisAttempts),
	}
	local quality = math.clamp(
		breakdown.Execution + breakdown.Errors + breakdown.Skill + breakdown.Equipment + breakdown.Part + breakdown.Diagnosis,
		0, 100
	)
	return {
		Valid = true, Reason = nil, Quality = math.floor(quality + 0.5),
		Perfect = successes, Good = 0, Miss = errors, Corrected = 0, Uncorrected = errors, Breakdown = breakdown,
	}
end

return RepairOperations
