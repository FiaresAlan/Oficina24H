--!strict
-- C28: nenhuma liquidação depois que uma OS muda durante Save(worker).
-- Regra pura para testar as janelas de saída do dono/colaborador e
-- transferência de responsável; não concede crédito, peças ou XP.
local CollaborationRules = require(script.Parent.CollaborationRules)

local Guard = {}

function Guard.CanSettle(expectedJob: any, currentJob: any,
	ownerUserId: number, actorUserId: number, delegated: boolean,
	ownerConnected: boolean, actorConnected: boolean, expectedSplit: number?): boolean
	if type(expectedJob) ~= "table" or currentJob ~= expectedJob
		or type(ownerUserId) ~= "number" or type(actorUserId) ~= "number"
		or ownerConnected ~= true or actorConnected ~= true
		or expectedJob.OwnerUserId ~= ownerUserId then
		return false
	end
	if not CollaborationRules.IsAuthorized(currentJob, actorUserId) then
		return false
	end
	-- Não permitir que o beneficiário ou a porcentagem do acordo
	-- sejam trocados enquanto a claim é salva (valores calculados antes do yield).
	if CollaborationRules.IsWorker(currentJob, actorUserId) ~= delegated then
		return false
	end
	return not delegated or currentJob.CollaborationSplitPercent == expectedSplit
end

return Guard
