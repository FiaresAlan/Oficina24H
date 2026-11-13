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
-- Nunca descartar a prova antiga para abrir espaço: pode corresponder a
-- uma claim ainda pendente e um crédito perdido após queda de servidor.
function Proofs.CanAdd(raw: any, proof: any): boolean
	return type(raw) == "table" and #raw < Proofs.MaxEntries
		and Proofs.Valid(proof) and not Proofs.Find(raw, proof.JobId, proof.Token)
end
function Proofs.Add(raw: any, proof: any): boolean
	if not Proofs.CanAdd(raw, proof) then return false end
	table.insert(raw, Proofs.Make(proof.JobId, proof.Token, proof.WorkerUserId,
		proof.OwnerPay, proof.WorkerPay, proof.Service, proof.Vehicle, proof.At))
	return true
end
-- Só remover após confirmação de que a claim do contratado foi removida
-- do perfil DELE e a gravação com o crédito já retornou sucesso.
function Proofs.Remove(raw: any, jobId: any, token: any, workerUserId: any): boolean
	if type(raw) ~= "table" or not Ledger.ValidKey(jobId, token)
		or not whole(workerUserId, -1e15, 1e15) then return false end
	for i = #raw, 1, -1 do
		local entry = raw[i]
		if type(entry) == "table" and entry.JobId == jobId
			and entry.Token == token and entry.WorkerUserId == workerUserId then
			table.remove(raw, i)
			return true
		end
	end
	return false
end
function Proofs.Sanitize(raw: any): { any }
	local clean = {}
	if type(raw) ~= "table" then return clean end
	-- Compatibilidade defensiva com dados antigos acima do teto: conservar
	-- os registros mais recentes no mesmo formato; nunca criar duplicata.
	local seen = {}
	for i = #raw, 1, -1 do
		if #clean >= Proofs.MaxEntries then break end
		local v = raw[i]
		if Proofs.Valid(v) then
			local key = v.JobId .. ":" .. v.Token
			if not seen[key] then
				seen[key] = true
				table.insert(clean, 1, Proofs.Make(v.JobId, v.Token, v.WorkerUserId,
					v.OwnerPay, v.WorkerPay, v.Service, v.Vehicle, v.At))
			end
		end
	end
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
