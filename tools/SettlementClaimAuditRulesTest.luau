-- C25: auditoria privada de reivindicações sem prova de beneficiário.
local Rules = require(game.ReplicatedStorage.Shared.SettlementClaimAuditRules)
local Claims = require(game.ReplicatedStorage.Shared.SettlementClaimRules)
local lines, errors = {}, 0
local function check(name: string, ok: boolean)
	if not ok then errors += 1 end
	table.insert(lines, (ok and "PASS " or "FAIL ") .. name)
end
local token = "c25aaaaa-1111-2222-3333-cccccccccccc"
local claim = Claims.Make(2501, "job_25", token, 85, 190,
	30, 90, "Freios", "Hatch", "Tires", 1790000000)
local audits = {}
check("C25: não aceita status desconhecido", not Rules.Mark(audits, claim, "Paid", 1790000000))
check("C25: adiciona dúvida legada sem apagar claim", Rules.Mark(audits,
	claim, "LegacyUnverified", 1790000000) and #audits == 1)
check("C25: mesmo status não duplica", not Rules.Mark(audits,
	claim, "LegacyUnverified", 1790000001) and #audits == 1)
check("C25: conflito substitui classificação sem apagar evidência",
	Rules.Mark(audits, claim, "Conflict", 1790000002)
	and Rules.Find(audits, "job_25", token).Status == "Conflict")
check("C25: resumo não expõe token/JobId/OwnerId", (function()
	local sum = Rules.Summary(audits)
	return sum.Count == 1 and sum.Conflict == 1
		and sum.Token == nil and sum.JobId == nil and sum.OwnerUserId == nil
end)())
check("C25: sanitização só preserva claims ainda pendentes",
	#Rules.Sanitize(audits, {}) == 0
	and #Rules.Sanitize(audits, { claim }) == 1)
local different = Claims.Make(2502, "job_25", token, 85, 190,
	30, 90, "Freios", "Hatch", "Tires", 1790000000)
check("C25: não atribui auditoria a outro dono",
	#Rules.Sanitize(audits, { different }) == 0)
check("C25: remove auditoria de claim encerrada",
	Rules.Remove(audits, "job_25", token) and #audits == 0
	and not Rules.Remove(audits, "job_25", token))
table.insert(lines, errors == 0 and "TODOS OS TESTES PASSARAM"
	or (errors .. " TESTE(S) FALHARAM"))
return table.concat(lines, "\n")
