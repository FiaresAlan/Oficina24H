--!strict
-- Estado puro da confirmação de entrega. Uma OS só aparece como entregue
-- quando o salvamento de TODOS os beneficiários exigidos foi confirmado.
-- Não cria atomicidade entre chaves DataStore distintas.
local SettlementDeliveryRules = {}

function SettlementDeliveryRules.New(jobId: any, token: any, ownerUserId: any, workerUserId: any): any?
	if type(jobId) ~= "string" or jobId == "" or type(token) ~= "string" or #token < 16
		or type(ownerUserId) ~= "number" or type(workerUserId) ~= "number"
		or ownerUserId < 1 or workerUserId < 1 then return nil end
	return {
		JobId = jobId, Token = token,
		OwnerUserId = ownerUserId, WorkerUserId = workerUserId,
		OwnerSaved = false, WorkerSaved = false,
	}
end

function SettlementDeliveryRules.Matches(state: any, jobId: any, token: any): boolean
	return type(state) == "table" and state.JobId == jobId and state.Token == token
end

function SettlementDeliveryRules.MarkSaved(state: any, role: any, succeeded: any): boolean
	if type(state) ~= "table" or succeeded ~= true then return false end
	if role == "Owner" then
		state.OwnerSaved = true
	elseif role == "Worker" and state.OwnerSaved == true then
		state.WorkerSaved = true
	else
		return false
	end
	return true
end

function SettlementDeliveryRules.Ready(state: any): boolean
	return type(state) == "table" and state.OwnerSaved == true and state.WorkerSaved == true
end

return SettlementDeliveryRules
