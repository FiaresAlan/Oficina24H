--!strict
-- C23: marcador de quitação privado do CONTRATADO, persistido junto do saldo
-- e independente do extrato de 64 reparos. Nunca descartar prova por idade.
-- Limite conservador: arquivo cheio recusa novos créditos, sem duplo pagamento.
local Ledger = require(script.Parent.SettlementLedgerRules)
local Tombstones = require(script.Parent.WorkerPaidTombstoneRules)
local Paid = {}
Paid.MaxEntries = 2048

local function whole(value: any, lo: number, hi: number): boolean
	return type(value) == "number" and value == value and value ~= math.huge
		and value ~= -math.huge and value % 1 == 0 and value >= lo and value <= hi
end

function Paid.Valid(v: any): boolean
	return type(v) == "table" and Ledger.ValidKey(v.JobId, v.Token)
		and whole(v.Amount, 0, 1e8) and whole(v.At, 1, 1e12)
		and type(v.Service) == "string" and #v.Service <= 64
		and type(v.Vehicle) == "string" and #v.Vehicle <= 60
		and (v.OwnerUserId == nil
			-- Mesmo intervalo de SettlementClaimRules/OwnerSettlementProofRules (negativos existem nos
			-- jogadores de teste do Studio). Antes só aceitava >= 1: a reivindicação passava, a quitação do
			-- contratado era recusada e o pagamento dele nunca saía (achado no teste com 2 jogadores).
			or (whole(v.OwnerUserId, -1e15, 1e15) and v.OwnerUserId ~= 0))
end

function Paid.Make(jobId: string, token: string, amount: number, at: number,
	service: string, vehicle: string, ownerUserId: number?): any?
	local v = { JobId = jobId, Token = token, Amount = amount, At = at,
		Service = service, Vehicle = vehicle, OwnerUserId = ownerUserId }
	return Paid.Valid(v) and v or nil
end

function Paid.Find(raw: any, jobId: any, token: any): any?
	if type(raw) ~= "table" or not Ledger.ValidKey(jobId, token) then return nil end
	for i = #raw, 1, -1 do
		local v = raw[i]
		if type(v) == "table" and v.JobId == jobId and v.Token == token then return v end
	end
	return nil
end

function Paid.CanAdd(raw: any, proof: any): boolean
	return type(raw) == "table" and #raw < Paid.MaxEntries
		and Paid.Valid(proof) and not Paid.Find(raw, proof.JobId, proof.Token)
end

function Paid.Add(raw: any, proof: any): boolean
	if not Paid.CanAdd(raw, proof) then return false end
	table.insert(raw, Paid.Make(proof.JobId, proof.Token, proof.Amount,
		proof.At, proof.Service, proof.Vehicle, proof.OwnerUserId))
	return true
end

-- Perfis v8: só é legítimo recuperar os registros de Worker ainda presentes
-- no ledger. Recebimentos que já giraram ANTES da migração são desconhecidos.
function Paid.FromLedger(raw: any, ledger: any, tombstones: any?): { any }
	local clean = Paid.Sanitize(raw)
	if type(ledger) == "table" then
		for _, entry in ipairs(ledger) do
			if type(entry) == "table" and entry.Role == "Worker"
				and not Tombstones.Find(tombstones, entry.JobId, entry.Token) then
				local marker = Paid.Make(entry.JobId, entry.Token, entry.Amount, entry.At,
					entry.Service, entry.Vehicle)
				if marker then Paid.Add(clean, marker) end
			end
		end
	end
	return clean
end

function Paid.Sanitize(raw: any): { any }
	local clean = {}
	if type(raw) ~= "table" then return clean end
	-- Não há expiração silenciosa. Em conteúdo antigo acima do limite,
	-- conservar até o teto; é necessária auditoria para o restante.
	for _, entry in ipairs(raw) do
		if #clean >= Paid.MaxEntries then break end
		if Paid.Valid(entry) and not Paid.Find(clean, entry.JobId, entry.Token) then
			table.insert(clean, Paid.Make(entry.JobId, entry.Token, entry.Amount,
				entry.At, entry.Service, entry.Vehicle, entry.OwnerUserId))
		end
	end
	return clean
end

function Paid.Matches(proof: any, payment: any): boolean
	return Paid.Valid(payment) and type(proof) == "table"
		and payment.JobId == proof.JobId and payment.Token == proof.Token
		and payment.Amount == proof.WorkerPay
		and payment.Service == proof.Service and payment.Vehicle == proof.Vehicle
end

return Paid
