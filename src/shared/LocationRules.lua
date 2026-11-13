--!strict
-- Regras geométricas puras para validar presença em estabelecimentos públicos.
-- É permitido testar sem o prédio SOMENTE se o chamador estiver no Studio.
local LocationRules = {}

local EPSILON = 1e-3

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function LocationRules.IsNearBlock(cf: CFrame?, size: Vector3?, position: Vector3?, distance: number): boolean
	if typeof(cf) ~= "CFrame" or typeof(size) ~= "Vector3" or typeof(position) ~= "Vector3" then
		return false
	end
	if type(distance) ~= "number" or not finite(distance) or distance < 0 then
		return false
	end
	local localPos = cf:PointToObjectSpace(position)
	-- EPSILON absorve o erro de float32 do CFrame (ida e volta world/object): um jogador exatamente
	-- na borda/limite não pode ser recusado por 0,0000001 stud.
	local dx = math.max(math.abs(localPos.X) - size.X / 2 - EPSILON, 0)
	local dz = math.max(math.abs(localPos.Z) - size.Z / 2 - EPSILON, 0)
	return dx * dx + dz * dz <= distance * distance
end

function LocationRules.MissingBlockAllowed(isStudio: boolean): boolean
	return isStudio == true
end

return LocationRules
