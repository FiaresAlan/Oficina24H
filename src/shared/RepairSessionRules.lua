--!strict
-- Estados da sessão de reparo, sem Players/Workspace para testes determinísticos.
local RepairSessionRules = {}

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function RepairSessionRules.IsActive(session: any?, now: number, maxSeconds: number): boolean
	if type(session) ~= "table" or not finite(session.StartedAt)
		or not finite(now) or not finite(maxSeconds) or maxSeconds < 0 then
		return false
	end
	local elapsed = now - session.StartedAt
	return elapsed >= 0 and elapsed <= maxSeconds
end

return RepairSessionRules
