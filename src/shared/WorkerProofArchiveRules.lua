--!strict
-- C24: a compressão de comprovantes só acontece DEPOIS que o proprietário
-- salvou a baixa da sua prova. Ausência de dados/claim aberta => preservar.
local Paid = require(script.Parent.WorkerSettlementProofRules)
local OwnerProofs = require(script.Parent.OwnerSettlementProofRules)
local Claims = require(script.Parent.SettlementClaimRules)

local Archive = {}
Archive.MaxReadsPerPass = 4
Archive.MinIntervalSeconds = 300
Archive.GraceSeconds = 900

function Archive.Batch(raw: any, cursor: any, now: any): ({ any }, number)
	local batch = {}
	if type(raw) ~= "table" or #raw == 0 or type(now) ~= "number"
		or now ~= now then return batch, 1 end
	local count = #raw
	local start = type(cursor) == "number" and cursor == cursor
		and math.clamp(math.floor(cursor), 1, count) or 1
	local nextCursor = start
	for offset = 0, count - 1 do
		local index = ((start + offset - 1) % count) + 1
		nextCursor = (index % count) + 1
		local marker = raw[index]
		if Paid.Valid(marker) and type(marker.OwnerUserId) == "number"
			and now - marker.At >= Archive.GraceSeconds then
			table.insert(batch, marker)
			if #batch >= Archive.MaxReadsPerPass then break end
		end
	end
	return batch, nextCursor
end

function Archive.CanCompact(marker: any, ownerRaw: any, workerPending: any,
	queriedOwnerId: any): boolean
	if not Paid.Valid(marker) or type(marker.OwnerUserId) ~= "number"
		or marker.OwnerUserId ~= queriedOwnerId
		or type(ownerRaw) ~= "table"
		or type(ownerRaw.OwnerSettlementProofs) ~= "table"
		or type(workerPending) ~= "table" then return false end
	-- Mesmo que o worker RECEBEU, uma claim aberta ainda pode precisar
	-- de reconciliação. Não eliminar o único recibo detalhado.
	if Claims.Find(workerPending, marker.JobId, marker.Token) then return false end
	-- Prova ainda presente no dono => ele ainda não confirmou a baixa.
	return OwnerProofs.Find(ownerRaw.OwnerSettlementProofs, marker.JobId, marker.Token) == nil
end

return Archive
