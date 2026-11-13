-- C22: prova do proprietário só pode ser removida com pagamento do trabalhador
-- confirmado NO DATASTORE e claim já ausente. A idade sozinha não autoriza.
local Sweep = require(game.ReplicatedStorage.Shared.OwnerProofSweepRules)
local Proof = require(game.ReplicatedStorage.Shared.OwnerSettlementProofRules)
local Claim = require(game.ReplicatedStorage.Shared.SettlementClaimRules)
local Ledger = require(game.ReplicatedStorage.Shared.SettlementLedgerRules)
local lines, fail = {}, 0
local function check(name: string, value: boolean)
	if not value then fail += 1 end
	table.insert(lines, (value and "PASS " or "FAIL ") .. name)
end
local at = 1790000000
local token = "aabbccdd-1111-2222-3333-eeeeeeeeeeee"
local proof = Proof.Make("job_22", token, 2202, 100, 250, "Freios", "Hatch", at)
local account = { PendingClaims = {}, RepairLedger = {} }
check("C22: sem crédito persistido não libera", not Sweep.CanRelease(proof, account, 2202))
check("C22: usuário consultado diferente é proibido", not Sweep.CanRelease(proof, account, 2201))
check("C22: conta indisponível não libera", not Sweep.CanRelease(proof, nil, 2202))
check("C22: conta sem lista de claims não libera", not Sweep.CanRelease(proof,
	{ RepairLedger = {} }, 2202))
check("C22: crédito do trabalhador registrado", Ledger.Record(account.RepairLedger,
	"job_22", token, 250, "Worker", at, "Freios", "Hatch"))
local c = Claim.Make(2201, "job_22", token, 100, 250, 40, 95, "Freios", "Hatch", "Freios", at)
Claim.Add(account.PendingClaims, c)
check("C22: crédito salvo mas claim ainda aberta não libera", not Sweep.CanRelease(proof, account, 2202))
Claim.Remove(account.PendingClaims, "job_22", token)
check("C22: crédito salvo e claim ausente libera", Sweep.CanRelease(proof, account, 2202))
account.RepairLedger[1].Amount = 251
check("C22: valor divergente não libera", not Sweep.CanRelease(proof, account, 2202))
account.RepairLedger[1].Amount, account.RepairLedger[1].Service = 250, "Motor"
check("C22: serviço divergente não libera", not Sweep.CanRelease(proof, account, 2202))
account.RepairLedger[1].Service, account.RepairLedger[1].Role = "Freios", "Owner"
check("C22: crédito do próprio dono não libera", not Sweep.CanRelease(proof, account, 2202))
account.RepairLedger[1].Role = "Worker"
check("C22: restaura verificação após corrigir ledger", Sweep.CanRelease(proof, account, 2202))
account.RepairLedger = {} -- simula giro do extrato de 64 reparos
check("C22: ledger rotacionado mantém prova", not Sweep.CanRelease(proof, account, 2202))
local all = {}
for i = 1, 11 do
	local tk = string.format("aabbccdd-1111-2222-3333-%012d", i)
	Proof.Add(all, Proof.Make("job_" .. i, tk, 2202, 10, 20, "Freios", "Hatch", at))
end
local first, cursor = Sweep.Batch(all, 1, at + Sweep.GraceSeconds)
check("C22: limita consultas a quatro por ciclo", #first == Sweep.MaxReadsPerPass and cursor == 5)
local second, nextCursor = Sweep.Batch(all, cursor, at + Sweep.GraceSeconds)
check("C22: avança cursor para não repetir apenas primeiras", #second == 4
	and second[1].JobId == "job_5" and nextCursor == 9)
local young = Proof.Make("recent", "bbbbbbbb-1111-2222-3333-cccccccccccc",
	2202, 10, 20, "Freios", "Hatch", at + 500)
local mixed = { young, all[1], all[2], all[3], all[4] }
local chosen, after = Sweep.Batch(mixed, 1, at + Sweep.GraceSeconds)
check("C22: ignora prova nova e varre antigas", #chosen == 4 and chosen[1].JobId == "job_1"
	and after == 1)
local none = Sweep.Batch({ young }, 1, at + Sweep.GraceSeconds)
check("C22: não remove comprovante somente pela idade insuficiente", #none == 0)
table.insert(lines, fail == 0 and "TODOS OS TESTES PASSARAM" or (fail .. " TESTE(S) FALHARAM"))
return table.concat(lines, "\n")
