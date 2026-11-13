--!strict
-- C29: cenas de chegada/saída assíncronas não sobrevivem ao dono ausente.
local Rules = {}
function Rules.IsCurrentArrival(states: any, jobId: any, state: any): boolean
	return type(states) == "table" and type(jobId) == "string"
		and type(state) == "table" and states[jobId] == state
end
function Rules.IsOwnedBy(record: any, ownerUserId: any): boolean
	return type(record) == "table" and type(ownerUserId) == "number"
		and ownerUserId == ownerUserId and ownerUserId > 0
		and record.OwnerUserId == ownerUserId
end
return Rules
