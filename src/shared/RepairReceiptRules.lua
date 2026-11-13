--!strict
-- Comprovantes efêmeros e privados por jogador/sessão.
-- O resultado é guardado APÓS a liquidação. Consultar nunca paga, consome peças ou altera XP.
local RepairReceiptRules = {}

RepairReceiptRules.TtlSeconds = 900
RepairReceiptRules.MaxPerPlayer = 8

local function validKey(value: any): boolean
	return type(value) == "string" and #value >= 1 and #value <= 128
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function RepairReceiptRules.ValidRequest(jobId: any, token: any): boolean
	return validKey(jobId) and type(token) == "string" and #token >= 16 and #token <= 128
end

-- Faz cópia superficial dos campos públicos do resultado. Não armazena instâncias/Models.
local function clonePayload(payload: any): any
	local result = {}
	for key, value in pairs(payload) do
		if type(value) == "table" then
			result[key] = table.clone(value)
		else
			result[key] = value
		end
	end
	return result
end

function RepairReceiptRules.Prune(receipts: any, now: number): number
	if type(receipts) ~= "table" or not finite(now) then return 0 end
	local removed = 0
	for i = #receipts, 1, -1 do
		local entry = receipts[i]
		if type(entry) ~= "table" or not finite(entry.At)
			or now - entry.At > RepairReceiptRules.TtlSeconds then
			table.remove(receipts, i)
			removed += 1
		end
	end
	while #receipts > RepairReceiptRules.MaxPerPlayer do
		table.remove(receipts, 1)
		removed += 1
	end
	return removed
end

function RepairReceiptRules.Remember(receipts: any, jobId: any, token: any, payload: any, now: number): boolean
	if type(receipts) ~= "table" or not RepairReceiptRules.ValidRequest(jobId, token)
		or type(payload) ~= "table" or not finite(now) then return false end
	RepairReceiptRules.Prune(receipts, now)
	-- Nunca substituir comprovante de uma sessão por outro valor.
	for _, entry in ipairs(receipts) do
		if entry.JobId == jobId and entry.Token == token then return false end
	end
	table.insert(receipts, { JobId = jobId, Token = token, Payload = clonePayload(payload), At = now })
	RepairReceiptRules.Prune(receipts, now)
	return true
end

function RepairReceiptRules.Lookup(receipts: any, jobId: any, token: any, now: number): any?
	if not RepairReceiptRules.ValidRequest(jobId, token) or type(receipts) ~= "table"
		or not finite(now) then return nil end
	RepairReceiptRules.Prune(receipts, now)
	for i = #receipts, 1, -1 do
		local entry = receipts[i]
		if entry.JobId == jobId and entry.Token == token and now >= entry.At then
			return clonePayload(entry.Payload)
		end
	end
	return nil
end

return RepairReceiptRules
