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
Ledger.Record(recent, "job_1", token, 80, "Owner", 1790000000, "Freios", "Hatch")
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
check("C21: arquivo limitado sem apagar prova pendente", #proofs == Proof.MaxEntries)
check("C21: prova antiga não é descartada sob pressão", Proof.Find(proofs, "job_1", token) ~= nil)
local overflow = Proof.Make("overflow", "33333333-2222-4444-5555-666666666666", 902, 12, 25, "Freios", "Hatch", 1790000000)
check("C21: arquivo cheio recusa nova prova", not Proof.CanAdd(proofs, overflow) and not Proof.Add(proofs, overflow))
check("C21: remoção exige contratado correto", not Proof.Remove(proofs, "job_1", token, 903)
	and Proof.Find(proofs, "job_1", token) ~= nil)
check("C21: confirmação libera apenas a prova correta", Proof.Remove(proofs, "job_1", token, 902)
	and not Proof.Remove(proofs, "job_1", token, 902) and #proofs == Proof.MaxEntries - 1)
check("C21: a vaga liberada permite novo repasse", Proof.CanAdd(proofs, overflow)
	and Proof.Add(proofs, overflow) and #proofs == Proof.MaxEntries)
check("C21: sanitização preserva as últimas provas válidas",
	#Proof.Sanitize(proofs) == Proof.MaxEntries and Proof.Find(Proof.Sanitize(proofs), "overflow", overflow.Token) ~= nil)
table.insert(output, errors == 0 and "TODOS OS TESTES PASSARAM" or (errors .. " TESTE(S) FALHARAM"))
return table.concat(output, "\n")
