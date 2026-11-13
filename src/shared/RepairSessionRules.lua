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

-- Cancelamento atrasado de um painel antigo não deve derrubar um novo reparo.
-- Sessões de operações têm token obrigatório; o minijogo timing mantém compatibilidade.
function RepairSessionRules.CanCancel(session: any?, jobId: any, token: any): boolean
	if session == nil then return true end
	if type(session) ~= "table" then return false end
	if jobId ~= nil and jobId ~= session.JobId then return false end
	if session.Token ~= nil then
		return type(token) == "string" and token == session.Token and jobId == session.JobId
	end
	return true
end

return RepairSessionRules
