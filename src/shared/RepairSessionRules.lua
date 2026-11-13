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

-- Finalização protegida em TODOS os tipos de reparo: não confiar no cliente
-- para concluir a sessão de outra OS (pacotes atrasados, replay de rede).
function RepairSessionRules.MatchesFinish(session: any?, jobId: any, payload: any): boolean
	return type(session) == "table" and session.JobId == jobId
		and type(session.Token) == "string" and #session.Token >= 16
		and type(payload) == "table" and payload.Token == session.Token
end

-- Cancelamento atrasado de qualquer painel (timing ou operações) nunca derruba sessão nova.
-- Um estado sem token é inválido; não criar exceções para reparos legacy.
function RepairSessionRules.CanCancel(session: any?, jobId: any, token: any): boolean
	if session == nil then return true end
	if type(session) ~= "table" then return false end
	if jobId ~= nil and jobId ~= session.JobId then return false end
	return type(session.Token) == "string" and type(token) == "string"
		and token == session.Token and jobId == session.JobId
end

return RepairSessionRules
