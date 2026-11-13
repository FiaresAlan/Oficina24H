--!strict
-- C28: nenhuma liquidação depois que uma OS muda durante Save(worker).
-- Regra pura para testar as janelas de saída do dono/colaborador e
-- transferência de responsável; não concede crédito, peças ou XP.
local CollaborationRules = require(script.Parent.CollaborationRules)

local Guard = {}

function Guard.CanSettle(expectedJob: any, currentJob: any,
	ownerUserId: number, actorUserId: number, delegated: boolean,
	ownerConnected: boolean, actorConnected: boolean): boolean
	if type(expectedJob) ~= "table" or currentJob ~= expectedJob
		or type(ownerUserId) ~= "number" or type(actorUserId) ~= "number"
		or ownerConnected ~= true or actorConnected ~= true
		or expectedJob.OwnerUserId ~= ownerUserId then
		return false
	end
	if not CollaborationRules.IsAuthorized(currentJob, actorUserId) then
		return false
	end
	-- Não permitir que a divisão mude enquanto a claim é salva.
	return CollaborationRules.IsWorker(currentJob, actorUserId) == delegated
end

return Guard
