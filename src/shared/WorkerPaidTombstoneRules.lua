--!strict
-- C24: identificadores compactos de quitacoes JA verificadas no perfil do
-- mecânico. Nunca expiram automaticamente: mesmo após perder o extrato
-- de 64, o mesmo JobId+Token não pode pagar outra vez.
local Ledger = require(script.Parent.SettlementLedgerRules)
local Tombstones = {}
Tombstones.MaxEntries = 8192

function Tombstones.Valid(value: any): boolean
	return type(value) == "table" and Ledger.ValidKey(value.JobId, value.Token)
end

function Tombstones.Find(raw: any, jobId: any, token: any): any?
	if type(raw) ~= "table" or not Ledger.ValidKey(jobId, token) then return nil end
	for i = #raw, 1, -1 do
		local t = raw[i]
		if Tombstones.Valid(t) and t.JobId == jobId and t.Token == token then return t end
	end
	return nil
end

function Tombstones.CanAdd(raw: any, jobId: any, token: any): boolean
	return type(raw) == "table" and #raw < Tombstones.MaxEntries
		and Ledger.ValidKey(jobId, token) and Tombstones.Find(raw, jobId, token) == nil
end

function Tombstones.Sanitize(raw: any): { any }
	local clean, seen = {}, {}
	if type(raw) ~= "table" then return clean end
	for _, entry in ipairs(raw) do
		if #clean >= Tombstones.MaxEntries then break end
		if Tombstones.Valid(entry) then
			local key = entry.JobId .. ":" .. entry.Token
			if not seen[key] then
				seen[key] = true
				table.insert(clean, { JobId = entry.JobId, Token = entry.Token })
			end
		end
	end
	return clean
end

-- Mesma mutação do perfil, SEM yield: escreve tombstone ANTES de retirar o
-- marcador detalhado. Se não houver capacidade, mantém a prova original.
function Tombstones.Compact(proofs: any, raw: any, jobId: any, token: any): boolean
	if type(proofs) ~= "table" or not Tombstones.CanAdd(raw, jobId, token) then return false end
	for i = #proofs, 1, -1 do
		local marker = proofs[i]
		if type(marker) == "table" and marker.JobId == jobId and marker.Token == token then
			table.insert(raw, { JobId = jobId, Token = token })
			table.remove(proofs, i)
			return true
		end
	end
	return false
end

return Tombstones
