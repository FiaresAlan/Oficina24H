--!strict
-- Pontos padronizados de inspeção ao redor de qualquer carro, sem depender de malhas 3D específicas.
-- Todos são criados para todo carro: não revelam ao cliente o defeito que o servidor escolheu.
local InspectionPointRules = {}

InspectionPointRules.Exams = {
	{ Id = "TirePressure", Name = "Pneu", Action = "Medir pressão" },
	{ Id = "BatteryVoltage", Name = "Bateria", Action = "Testar tensão" },
	{ Id = "CoolingTemperature", Name = "Arrefecimento", Action = "Medir temperatura" },
}
InspectionPointRules.MaxDistance = 11

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function InspectionPointRules.Offsets(width: number, length: number, height: number): { [string]: Vector3 }
	local w = math.clamp(finite(width) and width or 8, 4, 14)
	local l = math.clamp(finite(length) and length or 18, 8, 32)
	local h = math.clamp(finite(height) and height or 5, 2, 9)
	-- Roblox: frente do carro é -Z na PrimaryPart. Pontos são aproximados e não exigem peças nomeadas.
	return {
		TirePressure = Vector3.new(-w / 2 - 0.35, math.max(1.25, h * 0.33), -l * 0.28),
		BatteryVoltage = Vector3.new(-w * 0.22, math.max(1.8, h * 0.7), -l * 0.36),
		CoolingTemperature = Vector3.new(w * 0.22, math.max(1.8, h * 0.7), -l * 0.36),
	}
end

function InspectionPointRules.ExamFromKind(kind: any): string?
	if type(kind) ~= "string" or string.sub(kind, 1, 8) ~= "Inspect_" then
		return nil
	end
	local id = string.sub(kind, 9)
	for _, exam in ipairs(InspectionPointRules.Exams) do
		if exam.Id == id then
			return id
		end
	end
	return nil
end

function InspectionPointRules.IsNear(point: Vector3?, position: Vector3?, maxDistance: number): boolean
	if typeof(point) ~= "Vector3" or typeof(position) ~= "Vector3"
		or not finite(maxDistance) or maxDistance < 0 then
		return false
	end
	return (point - position).Magnitude <= maxDistance
end

return InspectionPointRules
