--!strict
-- Procedimentos curtos de preparação feitos NO CARRO antes do minijogo.
-- Apenas três receitas piloto exigem preparo; outros defeitos mantêm fluxo legado.
-- Todos os sockets são instanciados em todos os carros, evitando revelar defeitos antes do diagnóstico.
local RepairPrepRules = {}

RepairPrepRules.MaxDistance = 7.5
RepairPrepRules.Steps = {
	WheelBolts = { Id = "WheelBolts", Name = "Soltar porcas da roda", Action = "Soltar porcas", Hold = 0.8 },
	JackSupport = { Id = "JackSupport", Name = "Posicionar apoio do elevador", Action = "Apoiar veículo", Hold = 0.8 },
	HoodRelease = { Id = "HoodRelease", Name = "Abrir capô", Action = "Abrir capô", Hold = 0.7 },
	BatteryBracket = { Id = "BatteryBracket", Name = "Liberar presilha da bateria", Action = "Liberar suporte", Hold = 0.8 },
	DrainPan = { Id = "DrainPan", Name = "Preparar bandeja de fluido", Action = "Posicionar bandeja", Hold = 0.8 },
}
RepairPrepRules.Order = { "WheelBolts", "JackSupport", "HoodRelease", "BatteryBracket", "DrainPan" }

local recipes = {
	FlatTire = { "WheelBolts", "JackSupport" },
	WeakBattery = { "HoodRelease", "BatteryBracket" },
	Overheating = { "HoodRelease", "DrainPan" },
}

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function RepairPrepRules.Requires(defectId: any): boolean
	return type(defectId) == "string" and recipes[defectId] ~= nil
end

function RepairPrepRules.Current(defectId: any, stepIndex: any): string?
	local steps = recipes[defectId]
	if not steps or not finite(stepIndex) or stepIndex % 1 ~= 0 or stepIndex < 1 then
		return nil
	end
	return steps[stepIndex]
end

function RepairPrepRules.Ready(defectId: any, stepIndex: any): boolean
	local steps = recipes[defectId]
	if not steps then return true end
	return finite(stepIndex) and stepIndex % 1 == 0 and stepIndex > #steps
end

-- Não permite completar etapa posterior por adivinhação ou repetir uma já executada.
function RepairPrepRules.Advance(defectId: any, stepIndex: any, suppliedStep: any): number?
	if type(suppliedStep) ~= "string" or RepairPrepRules.Current(defectId, stepIndex) ~= suppliedStep then
		return nil
	end
	return stepIndex + 1
end

function RepairPrepRules.FromPrompt(kind: any): string?
	if type(kind) ~= "string" or string.sub(kind, 1, 5) ~= "Prep_" then
		return nil
	end
	local stepId = string.sub(kind, 6)
	return RepairPrepRules.Steps[stepId] and stepId or nil
end

function RepairPrepRules.Offsets(width: any, length: any, height: any): { [string]: Vector3 }
	local w = math.clamp(finite(width) and width or 8, 4, 14)
	local l = math.clamp(finite(length) and length or 18, 8, 32)
	local h = math.clamp(finite(height) and height or 5, 2, 9)
	return {
		WheelBolts = Vector3.new(-w / 2 - 0.45, math.max(1.1, h * 0.35), -l * 0.27),
		JackSupport = Vector3.new(-w * 0.4, math.max(1, h * 0.20), -l * 0.08),
		HoodRelease = Vector3.new(0, math.max(1.8, h * 0.7), -l / 2 - 0.55),
		BatteryBracket = Vector3.new(-w * 0.25, math.max(1.8, h * 0.72), -l * 0.37),
		DrainPan = Vector3.new(w * 0.25, math.max(1.0, h * 0.25), -l * 0.42),
	}
end

function RepairPrepRules.IsNear(point: Vector3?, position: Vector3?, maxDistance: number): boolean
	if typeof(point) ~= "Vector3" or typeof(position) ~= "Vector3"
		or not finite(maxDistance) or maxDistance < 0 then
		return false
	end
	return (point - position).Magnitude <= maxDistance
end

return RepairPrepRules
