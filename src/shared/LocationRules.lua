--!strict
-- Regras geométricas puras para validar presença em estabelecimentos públicos.
-- É permitido testar sem o prédio SOMENTE se o chamador estiver no Studio.
local LocationRules = {}

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
	local dx = math.max(math.abs(localPos.X) - size.X / 2, 0)
	local dz = math.max(math.abs(localPos.Z) - size.Z / 2, 0)
	return dx * dx + dz * dz <= distance * distance
end

function LocationRules.MissingBlockAllowed(isStudio: boolean): boolean
	return isStudio == true
end

return LocationRules
