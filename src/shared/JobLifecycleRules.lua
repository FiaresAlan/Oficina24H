--!strict
-- Regras puras de ciclo de vida: sem ordens fantasmas após desconexão
-- e sem cliente com carro cujo modelo 3D não pode ser carregado.
local JobLifecycleRules = {}

function JobLifecycleRules.SelectVehicle(
	candidates: { string }, preferred: string?, exists: (string) -> boolean, rand: () -> number
): string?
	if type(preferred) == "string" and preferred ~= "" and exists(preferred) then
		return preferred
	end
	local available: { string } = {}
	for _, name in ipairs(candidates) do
		if type(name) == "string" and exists(name) then
			table.insert(available, name)
		end
	end
	if #available == 0 then return nil end
	local roll = rand()
	if type(roll) ~= "number" or roll ~= roll or roll < 0 or roll >= 1 then
		return available[1]
	end
	return available[math.floor(roll * #available) + 1]
end

function JobLifecycleRules.ShouldRemoveForOwnerExit(jobOwnerId: any, leavingUserId: any): boolean
	return type(jobOwnerId) == "number" and type(leavingUserId) == "number"
		and jobOwnerId == leavingUserId
end

return JobLifecycleRules
