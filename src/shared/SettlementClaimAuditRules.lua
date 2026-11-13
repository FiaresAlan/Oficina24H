--!strict
-- C25: evidências insuficientes permanecem para auditoria privada.
-- NÃO confere saldo, não concede moedas e NÃO descarta reivindicações.
local Claims = require(script.Parent.SettlementClaimRules)
local Audit = {}
Audit.MaxEntries = Claims.MaxPending
Audit.Statuses = {
	LegacyUnverified = true, Conflict = true,
	Missing = true, ReadError = true,
}

local function valid(entry: any): boolean
	return type(entry) == "table"
		and type(entry.JobId) == "string" and type(entry.Token) == "string"
		and type(entry.OwnerUserId) == "number" and entry.OwnerUserId ~= 0
		and type(entry.Status) == "string" and Audit.Statuses[entry.Status] == true
		and type(entry.CheckedAt) == "number" and entry.CheckedAt == entry.CheckedAt
		and entry.CheckedAt % 1 == 0 and entry.CheckedAt >= 1 and entry.CheckedAt <= 1e12
end

function Audit.Find(raw: any, jobId: any, token: any): any?
	if type(raw) ~= "table" then return nil end
	for _, v in ipairs(raw) do
		if valid(v) and v.JobId == jobId and v.Token == token then return v end
	end
	return nil
end

function Audit.Remove(raw: any, jobId: any, token: any): boolean
	if type(raw) ~= "table" then return false end
	for i = #raw, 1, -1 do
		local v = raw[i]
		if valid(v) and v.JobId == jobId and v.Token == token then
			table.remove(raw, i)
			return true
		end
	end
	return false
end

function Audit.Mark(raw: any, claim: any, status: any, now: any): boolean
	if type(raw) ~= "table" or not Claims.Valid(claim)
		or Audit.Statuses[status] ~= true
		or type(now) ~= "number" or now ~= now or now % 1 ~= 0
		or now < 1 or now > 1e12 then return false end
	local prev = Audit.Find(raw, claim.JobId, claim.Token)
	if prev then
		if prev.Status == status then return false end
		prev.Status, prev.CheckedAt = status, now
		return true
	end
	if #raw >= Audit.MaxEntries then return false end
	table.insert(raw, { JobId = claim.JobId, Token = claim.Token,
		OwnerUserId = claim.OwnerUserId, Status = status, CheckedAt = now })
	return true
end

function Audit.Sanitize(raw: any, pending: any): { any }
	local clean = {}
	if type(raw) ~= "table" or type(pending) ~= "table" then return clean end
	for _, item in ipairs(raw) do
		if #clean >= Audit.MaxEntries then break end
		if valid(item) and not Audit.Find(clean, item.JobId, item.Token) then
			local claim = Claims.Find(pending, item.JobId, item.Token)
			if Claims.Valid(claim) and claim.OwnerUserId == item.OwnerUserId then
				table.insert(clean, { JobId = claim.JobId, Token = claim.Token,
					OwnerUserId = claim.OwnerUserId, Status = item.Status,
					CheckedAt = item.CheckedAt })
			end
		end
	end
	return clean
end

function Audit.Summary(raw: any): any
	local c = { Count = 0, LegacyUnverified = 0, Conflict = 0, Missing = 0, ReadError = 0 }
	if type(raw) ~= "table" then return c end
	for _, item in ipairs(raw) do
		if valid(item) then c.Count += 1; c[item.Status] += 1 end
	end
	return c
end
return Audit
