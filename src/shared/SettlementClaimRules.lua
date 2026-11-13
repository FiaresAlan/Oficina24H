--!strict
-- Reivindicações privadas do mecânico; nenhuma é autorizada a pagar sem
-- verificar o crédito do dono no DataStore persistente.
local Ledger = require(script.Parent.SettlementLedgerRules)
local OwnerProofs = require(script.Parent.OwnerSettlementProofRules)
local Claims = {}
Claims.MaxPending = 64
Claims.RecoveryGraceSeconds = 600 -- não recuperar enquanto o FinishRepair normal ainda pode estar em andamento

local function integer(x: any, low: number, high: number): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
		and x % 1 == 0 and x >= low and x <= high
end

function Claims.Valid(raw: any): boolean
	return type(raw) == "table"
		and integer(raw.OwnerUserId, -1e15, 1e15) and raw.OwnerUserId ~= 0
		and Ledger.ValidKey(raw.JobId, raw.Token)
		and integer(raw.OwnerPay, 0, 1e8) and integer(raw.WorkerPay, 0, 1e8)
		and integer(raw.XP, 0, 1e7) and integer(raw.Quality, 0, 100)
		and integer(raw.At, 1, 1e12)
		and type(raw.Service) == "string" and #raw.Service <= 64
		and type(raw.Vehicle) == "string" and #raw.Vehicle <= 60
		and type(raw.Spec) == "string" and #raw.Spec > 0 and #raw.Spec <= 64
end

function Claims.Make(ownerUserId: number, jobId: string, token: string,
	ownerPay: number, workerPay: number, xp: number, quality: number,
	service: string, vehicle: string, spec: string, at: number): any?
	local v: any = {
		OwnerUserId = ownerUserId, JobId = jobId, Token = token,
		OwnerPay = ownerPay, WorkerPay = workerPay, XP = xp, Quality = quality,
		Service = service, Vehicle = vehicle, Spec = spec, At = at,
	}
	return Claims.Valid(v) and v or nil
end

function Claims.Find(raw: any, jobId: any, token: any): any?
	if type(raw) ~= "table" or not Ledger.ValidKey(jobId, token) then return nil end
	for _, c in ipairs(raw) do
		if type(c) == "table" and c.JobId == jobId and c.Token == token then
			return c
		end
	end
	return nil
end

function Claims.Sanitize(raw: any): { any }
	local clean = {}
	if type(raw) ~= "table" then return clean end
	for _, c in ipairs(raw) do
		if Claims.Valid(c) and not Claims.Find(clean, c.JobId, c.Token) then
			table.insert(clean, Claims.Make(c.OwnerUserId, c.JobId, c.Token,
				c.OwnerPay, c.WorkerPay, c.XP, c.Quality, c.Service, c.Vehicle, c.Spec, c.At))
			while #clean > Claims.MaxPending do table.remove(clean, 1) end
		end
	end
	return clean
end

function Claims.Add(raw: any, claim: any): boolean
	if type(raw) ~= "table" or not Claims.Valid(claim)
		or #raw >= Claims.MaxPending or Claims.Find(raw, claim.JobId, claim.Token) then return false end
	table.insert(raw, Claims.Make(claim.OwnerUserId, claim.JobId, claim.Token,
		claim.OwnerPay, claim.WorkerPay, claim.XP, claim.Quality,
		claim.Service, claim.Vehicle, claim.Spec, claim.At))
	-- Nunca apagar silenciosamente uma reivindicação ainda não resolvida.
	return true
end

function Claims.Remove(raw: any, jobId: any, token: any): boolean
	if type(raw) ~= "table" then return false end
	for i = #raw, 1, -1 do
		if raw[i].JobId == jobId and raw[i].Token == token then
			table.remove(raw, i)
			return true
		end
	end
	return false
end

-- C25: o extrato do proprietário não identifica o mecânico beneficiário.
-- Uma linha de ledger legado sem prova vinculada nunca autoriza crédito
-- automático: a reivindicação continua aberta para auditoria.
function Claims.Recoverable(claim: any, now: any): boolean
	return Claims.Valid(claim) and type(now) == "number"
		and now == now and now - claim.At >= Claims.RecoveryGraceSeconds
end

-- Somente contagens agregadas podem seguir para a HUD; nunca incluir token/JobId.
function Claims.Summary(raw: any, now: number): any
	local summary = { Count = 0, Overdue = 0, OldestSeconds = 0 }
	if type(raw) ~= "table" or type(now) ~= "number" then return summary end
	for _, c in ipairs(raw) do
		if Claims.Valid(c) then
			local age = math.max(0, math.floor(now - c.At))
			summary.Count += 1
			if age >= 86400 then summary.Overdue += 1 end
			summary.OldestSeconds = math.max(summary.OldestSeconds, age)
		end
	end
	return summary
end

function Claims.EvidenceStatus(claim: any, ownerLedger: any, ownerProofs: any?,
	workerId: any?): string
	if not Claims.Valid(claim) or not integer(workerId, -1e15, 1e15)
		or workerId == 0 then return "Invalid" end
	local proof = OwnerProofs.Find(ownerProofs, claim.JobId, claim.Token)
	if proof then
		return OwnerProofs.Authorizes(proof, claim, workerId) and "Verified" or "Conflict"
	end
	local entry = Ledger.Find(ownerLedger, claim.JobId, claim.Token)
	if not entry then return "Missing" end
	if entry.Role ~= "Owner" or entry.Amount ~= claim.OwnerPay
		or entry.Service ~= claim.Service or entry.Vehicle ~= claim.Vehicle then
		return "Conflict"
	end
	-- Mesmo JobId/token/valor/serviço no extrato NÃO identifica beneficiário.
	return "LegacyUnverified"
end

function Claims.Authorized(claim: any, ownerLedger: any, ownerProofs: any?,
	workerId: any?): boolean
	return Claims.EvidenceStatus(claim, ownerLedger, ownerProofs, workerId) == "Verified"
end

return Claims
