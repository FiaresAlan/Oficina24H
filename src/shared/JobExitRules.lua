--!strict
-- C26: desligamento nunca deixa ordem sem proprietário no servidor.
-- Regra pura para testar todos os estados; não produz crédito nem XP.
local JobExitRules = {}

function JobExitRules.Action(job: any, leavingUserId: any): string
	if type(job) ~= "table" or type(leavingUserId) ~= "number"
		or leavingUserId ~= leavingUserId or leavingUserId == 0 then
		return "None"
	end
	-- Qualquer status (inclusive InProgress/Completed): oficina saiu.
	-- O carro e NPCs associados serão destruídos no mesmo PlayerLeft.
	if job.OwnerUserId == leavingUserId then return "RemoveOwner" end
	if job.Status == "InProgress" and job.CollaboratorUserId == leavingUserId then
		return "ReturnToOwner"
	end
	return "None"
end

return JobExitRules
