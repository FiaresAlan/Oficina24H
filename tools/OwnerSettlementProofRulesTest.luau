-- Testa retenção de prova independente das 64 linhas do extrato.
local Proof = require(game.ReplicatedStorage.Shared.OwnerSettlementProofRules)
local Claim = require(game.ReplicatedStorage.Shared.SettlementClaimRules)
local Ledger = require(game.ReplicatedStorage.Shared.SettlementLedgerRules)
local output, errors = {}, 0
local function check(name: string, ok: boolean)
	if not ok then errors += 1 end
	table.insert(output, (ok and "PASS " or "FAIL ") .. name)
end
local token = "aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb"
local c = Claim.Make(901, "job_1", token, 80, 275, 45, 92, "Freios", "Hatch", "Freios", 1790000000)
local v = Proof.Make("job_1", token, 902, 80, 275, "Freios", "Hatch", 1790000000)
local proofs = {}
check("C14: gera prova válida", v ~= nil)
check("C14: insere prova", Proof.Add(proofs, v))
check("C14: recusa duplicata", not Proof.Add(proofs, v) and #proofs == 1)
check("C14: autoriza mecânico correto", Claim.Authorized(c, {}, proofs, 902))
check("C14: impede mecânico diferente", not Claim.Authorized(c, {}, proofs, 903))
check("C14: recusa valor fraudado apesar do ledger legado", not Claim.Authorized(c, {
	{ JobId = "job_1", Token = token, Amount = 80, Role = "Owner", Service = "Freios", Vehicle = "Hatch" }
}, { Proof.Make("job_1", token, 902, 81, 275, "Freios", "Hatch", 1790000000) }, 902))
check("C14: sanitize remove corrupção", #Proof.Sanitize({ v, v, { WorkerPay = math.huge } }) == 1)
local recent = {}
for i = 1, Ledger.MaxEntries + 4 do
	local tk = string.format("11111111-2222-3333-4444-%012d", i)
	Ledger.Record(recent, "job_" .. i, tk, 10, "Owner", 1790000000, "Freios", "Hatch")
end
check("C14: o extrato comum gira", Ledger.Find(recent, "job_1", token) == nil)
check("C14: prova continua válida depois de girar extrato", Claim.Authorized(c, recent, proofs, 902))
for i = 1, Proof.MaxEntries + 2 do
	local tk = string.format("22222222-3333-4444-5555-%012d", i)
	Proof.Add(proofs, Proof.Make("fill_" .. i, tk, 902, 10, 10, "Freios", "Hatch", 1790000000))
end
check("C14: arquivo limitado", #proofs == Proof.MaxEntries)
check("C14: registros antigos eventualmente giram", Proof.Find(proofs, "job_1", token) == nil)
table.insert(output, errors == 0 and "TODOS OS TESTES PASSARAM" or (errors .. " TESTE(S) FALHARAM"))
return table.concat(output, "\n")
