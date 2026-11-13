--!strict
-- Provas compactas privadas do proprietário: persistidas junto de moedas/ledger no mesmo perfil.
-- Retenção ampliada, porém limitada; não é transação distribuída entre perfis.
local Ledger = require(script.Parent.SettlementLedgerRules)
local Proofs = {}
Proofs.MaxEntries = 1024

local function whole(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
		and v % 1 == 0 and v >= lo and v <= hi
end
function Proofs.Valid(v: any): boolean
	return type(v) == "table" and Ledger.ValidKey(v.JobId, v.Token)
		and whole(v.WorkerUserId, -1e15, 1e15) and v.WorkerUserId ~= 0
		and whole(v.OwnerPay, 0, 1e8) and whole(v.WorkerPay, 0, 1e8)
		and whole(v.At, 1, 1e12)
		and type(v.Service) == "string" and #v.Service <= 64
		and type(v.Vehicle) == "string" and #v.Vehicle <= 60
end
function Proofs.Make(jobId: string, token: string, workerId: number, ownerPay: number,
	workerPay: number, service: string, vehicle: string, at: number): any?
	local v = { JobId = jobId, Token = token, WorkerUserId = workerId,
		OwnerPay = ownerPay, WorkerPay = workerPay,
		Service = service, Vehicle = vehicle, At = at }
	return Proofs.Valid(v) and v or nil
end
function Proofs.Find(raw: any, jobId: any, token: any): any?
	if type(raw) ~= "table" or not Ledger.ValidKey(jobId, token) then return nil end
	for i = #raw, 1, -1 do
		local v = raw[i]
		if type(v) == "table" and v.JobId == jobId and v.Token == token then return v end
	end
	return nil
end
function Proofs.Add(raw: any, proof: any): boolean
	if type(raw) ~= "table" or not Proofs.Valid(proof) or Proofs.Find(raw, proof.JobId, proof.Token) then return false end
	table.insert(raw, Proofs.Make(proof.JobId, proof.Token, proof.WorkerUserId,
		proof.OwnerPay, proof.WorkerPay, proof.Service, proof.Vehicle, proof.At))
	while #raw > Proofs.MaxEntries do table.remove(raw, 1) end
	return true
end
function Proofs.Sanitize(raw: any): { any }
	local clean = {}
	if type(raw) ~= "table" then return clean end
	for _, v in ipairs(raw) do Proofs.Add(clean, v) end
	return clean
end
function Proofs.Authorizes(proof: any, claim: any, workerId: any): boolean
	return Proofs.Valid(proof) and type(claim) == "table"
		and proof.JobId == claim.JobId and proof.Token == claim.Token
		and proof.WorkerUserId == workerId and proof.OwnerPay == claim.OwnerPay
		and proof.WorkerPay == claim.WorkerPay
		and proof.Service == claim.Service and proof.Vehicle == claim.Vehicle
end
return Proofs
