--!strict
-- Livro-razão por PERFIL: uma única gravação inclui saldo, marca de crédito e comprovante.
-- Não fornece atomicidade ENTRE dois jogadores; cada perfil é uma chave DataStore independente.
local SettlementLedgerRules = {}
SettlementLedgerRules.MaxEntries = 64

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end
local function str(x: any, max: number): string
	return type(x) == "string" and string.sub(x, 1, max) or ""
end
function SettlementLedgerRules.ValidKey(jobId: any, token: any): boolean
	return type(jobId) == "string" and #jobId > 0 and #jobId <= 128
		and type(token) == "string" and #token >= 16 and #token <= 128
end
local function number(x: any, lo: number, hi: number): number
	return finite(x) and math.clamp(math.floor(x), lo, hi) or lo
end
local function receiptCopy(payload: any): any?
	if type(payload) ~= "table" then return nil end
	local v: any = {
		JobId = str(payload.JobId, 128), Token = str(payload.Token, 128),
		Bonus = number(payload.Bonus, 0, 1e7),
		Quality = number(payload.Quality, 0, 100),
		Perfect = number(payload.Perfect, 0, 100),
		Good = number(payload.Good, 0, 100),
		Miss = number(payload.Miss, 0, 100),
		Corrected = number(payload.Corrected, 0, 100),
		Uncorrected = number(payload.Uncorrected, 0, 100),
		Tip = number(payload.Tip, 0, 1e8),
		Price = number(payload.Price, 0, 1e8),
		XP = number(payload.XP, 0, 1e7),
		Stars = number(payload.Stars, 0, 5),
		Combo = finite(payload.Combo) and math.clamp(payload.Combo, 0, 10) or 1,
		NextCombo = finite(payload.NextCombo) and math.clamp(payload.NextCombo, 0, 10) or 1,
	}
	local b = type(payload.Breakdown) == "table" and payload.Breakdown or {}
	v.Breakdown = {}
	for _, key in ipairs({ "Execution", "Errors", "Skill", "Equipment", "Part", "Diagnosis" }) do
		v.Breakdown[key] = number(b[key], -100, 100)
	end
	return v
end
function SettlementLedgerRules.Find(entries: any, jobId: any, token: any): any?
	if type(entries) ~= "table" or not SettlementLedgerRules.ValidKey(jobId, token) then return nil end
	for i = #entries, 1, -1 do
		local v = entries[i]
		if type(v) == "table" and v.JobId == jobId and v.Token == token then return v end
	end
	return nil
end
function SettlementLedgerRules.Record(entries: any, jobId: any, token: any, amount: any,
		role: any, at: any, service: any, vehicle: any): boolean
	if type(entries) ~= "table" or not SettlementLedgerRules.ValidKey(jobId, token)
		or not finite(amount) or amount < 0 or amount > 1e8
		or (role ~= "Owner" and role ~= "Worker") or not finite(at) then return false end
	if SettlementLedgerRules.Find(entries, jobId, token) then return false end
	table.insert(entries, {
		JobId = jobId, Token = token, Amount = math.floor(amount),
		Role = role, At = math.floor(at),
		Service = str(service, 64), Vehicle = str(vehicle, 60),
	})
	while #entries > SettlementLedgerRules.MaxEntries do table.remove(entries, 1) end
	return true
end
function SettlementLedgerRules.Attach(entries: any, jobId: any, token: any, payload: any): boolean
	local entry = SettlementLedgerRules.Find(entries, jobId, token)
	if not entry or entry.Receipt ~= nil or type(payload) ~= "table"
		or payload.JobId ~= jobId or payload.Token ~= token then return false end
	entry.Receipt = receiptCopy(payload)
	return true
end
function SettlementLedgerRules.Receipt(entries: any, jobId: any, token: any): any?
	local entry = SettlementLedgerRules.Find(entries, jobId, token)
	return entry and receiptCopy(entry.Receipt) or nil
end
function SettlementLedgerRules.Sanitize(raw: any): { any }
	local valid: { any } = {}
	if type(raw) ~= "table" then return valid end
	for _, v in ipairs(raw) do
		if type(v) == "table" and SettlementLedgerRules.ValidKey(v.JobId, v.Token)
			and finite(v.Amount) and v.Amount >= 0 and v.Amount <= 1e8
			and finite(v.At) and (v.Role == "Owner" or v.Role == "Worker")
			and not SettlementLedgerRules.Find(valid, v.JobId, v.Token) then
			local entry: any = {
				JobId = v.JobId, Token = v.Token, Amount = math.floor(v.Amount),
				Role = v.Role, At = math.floor(v.At),
				Service = str(v.Service, 64), Vehicle = str(v.Vehicle, 60),
			}
			if type(v.Receipt) == "table" and v.Receipt.JobId == v.JobId and v.Receipt.Token == v.Token then
				entry.Receipt = receiptCopy(v.Receipt)
			end
			table.insert(valid, entry)
			while #valid > SettlementLedgerRules.MaxEntries do table.remove(valid, 1) end
		end
	end
	return valid
end
function SettlementLedgerRules.Public(entries: any, limit: number?): { any }
	local visible: { any } = {}
	if type(entries) ~= "table" then return visible end
	local top = math.clamp(math.floor(limit or 8), 1, 20)
	for i = #entries, math.max(1, #entries - top + 1), -1 do
		local e = entries[i]
		if type(e) == "table" then
			table.insert(visible, {
				At = e.At, Service = e.Service, Vehicle = e.Vehicle, Amount = e.Amount,
				Role = e.Role,
				Quality = e.Receipt and e.Receipt.Quality or nil,
				Stars = e.Receipt and e.Receipt.Stars or nil,
			})
		end
	end
	return visible
end
return SettlementLedgerRules
