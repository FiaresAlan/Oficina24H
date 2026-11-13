--!strict
-- C22: verificar OFFLINE se um pagamento colaborativo foi realmente salvo
-- no perfil do trabalhador, antes de dispensar uma prova no perfil do dono.
-- Regra puramente defensiva: falta/erro de dados = manter a prova.
local Proofs = require(script.Parent.OwnerSettlementProofRules)
local Ledger = require(script.Parent.SettlementLedgerRules)
local Claims = require(script.Parent.SettlementClaimRules)
local WorkerProofs = require(script.Parent.WorkerSettlementProofRules)

local Sweep = {}
Sweep.MaxReadsPerPass = 4
Sweep.MinIntervalSeconds = 300
Sweep.GraceSeconds = 900

function Sweep.Batch(proofs: any, cursor: any, now: any): ({ any }, number)
	local out = {}
	if type(proofs) ~= "table" or #proofs == 0
		or type(now) ~= "number" or now ~= now then return out, 1 end
	local count = #proofs
	local start = type(cursor) == "number" and cursor == cursor
		and math.clamp(math.floor(cursor), 1, count) or 1
	local nextCursor = start
	-- A busca na memória pode percorrer a lista; apenas até 4 leituras
	-- remotas serão realizadas na rotina que consome estes candidatos.
	for offset = 0, count - 1 do
		local index = ((start + offset - 1) % count) + 1
		nextCursor = (index % count) + 1
		local proof = proofs[index]
		if Proofs.Valid(proof) and now - proof.At >= Sweep.GraceSeconds then
			table.insert(out, proof)
			if #out >= Sweep.MaxReadsPerPass then break end
		end
	end
	return out, nextCursor
end

function Sweep.CanRelease(proof: any, workerRaw: any, queriedUserId: any): boolean
	if not Proofs.Valid(proof) or queriedUserId ~= proof.WorkerUserId
		or type(workerRaw) ~= "table"
		or type(workerRaw.PendingClaims) ~= "table"
		or type(workerRaw.RepairLedger) ~= "table" then return false end
	-- Claim ainda presente => pode ser resgate em andamento; jamais retirar.
	if Claims.Find(workerRaw.PendingClaims, proof.JobId, proof.Token) then return false end
	local credit = Ledger.Find(workerRaw.RepairLedger, proof.JobId, proof.Token)
	if type(credit) == "table" and credit.Role == "Worker"
		and credit.Amount == proof.WorkerPay and credit.Service == proof.Service
		and credit.Vehicle == proof.Vehicle then return true end
	-- C23: confirmação independente do extrato comum limitado a 64.
	-- A prova só entra nesse arquivo junto com o crédito no mesmo Save.
	local marker = WorkerProofs.Find(workerRaw.WorkerSettlementProofs, proof.JobId, proof.Token)
	return WorkerProofs.Matches(proof, marker)
end

return Sweep
