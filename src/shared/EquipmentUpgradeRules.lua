--!strict
-- Progressão permanente das máquinas: cada compra exige posse do equipamento.
-- Preços e ganhos calculados no servidor; o pad de compra é somente apresentação.
local Catalog = require(script.Parent.Catalog)
local Rules = {}
Rules.MaxLevel = 3

function Rules.Level(raw: any, owned: any, equipmentId: any): number
	if type(equipmentId) ~= "string" or not Catalog.Equipment[equipmentId]
		or type(owned) ~= "table" or owned[equipmentId] ~= true then return 0 end
	local v = type(raw) == "table" and raw[equipmentId] or nil
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return 1 end
	return math.clamp(math.floor(v), 1, Rules.MaxLevel)
end

function Rules.NextCost(equipmentId: any, level: any): number?
	local entry = type(equipmentId) == "string" and Catalog.Equipment[equipmentId]
	if not entry or type(level) ~= "number" or level ~= math.floor(level)
		or level < 1 or level >= Rules.MaxLevel then return nil end
	local base = math.max(100, entry.Cost)
	if level == 1 then return math.max(180, math.floor(base * 0.7 + 0.5)) end
	return math.max(420, math.floor(base * 1.35 + 0.5))
end

function Rules.Sanitize(raw: any, owned: any): { [string]: number }
	local result = {}
	if type(owned) ~= "table" then return result end
	for id, isOwned in pairs(owned) do
		if isOwned == true and Catalog.Equipment[id] then
			result[id] = Rules.Level(raw, owned, id)
		end
	end
	return result
end

function Rules.Efficiency(id: string, level: number): number
	return math.clamp((Catalog.EquipmentEfficiency[id] or 0) + math.max(0, level - 1), 0, 4)
end

-- Ganho modesto, não um multiplicador que tornaria os reparos manuais obsoletos.
function Rules.RewardMultiplier(level: number): number
	return 1 + math.clamp(level - 1, 0, 2) * 0.03
end

function Rules.EmployeeQuality(base: number, level: number): number
	return math.clamp(base + math.max(0, level - 1) * 2, 0, 95)
end

function Rules.EmployeeSeconds(base: number, level: number): number
	return math.max(12, base * (1 - math.clamp(level - 1, 0, 2) * 0.08))
end

return Rules
