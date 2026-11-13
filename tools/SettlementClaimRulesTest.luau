-- C12/C13: a reivindicação só é resgatável com pagamento do dono persistido.
local Rules = require(game.ReplicatedStorage.Shared.SettlementClaimRules)
local Ledger = require(game.ReplicatedStorage.Shared.SettlementLedgerRules)
local lines, fail = {}, 0
local function check(name: string, ok: boolean)
	if not ok then fail += 1 end
	table.insert(lines, (ok and "PASS " or "FAIL ") .. name)
end
local token = "aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb"
local c = Rules.Make(902, "job_1", token, 80, 275, 45, 95, "Freios", "Hatch", "Freios", 1790000000)
check("cria reivindicação válida", c ~= nil)
check("rejeita jogador inválido", Rules.Make(0, "job_1", token, 80, 275, 45, 95, "Freios", "Hatch", "Freios", 1) == nil)
check("rejeita valor negativo", Rules.Make(902, "job_1", token, 80, -1, 45, 95, "Freios", "Hatch", "Freios", 1) == nil)
check("rejeita qualidade adulterada", Rules.Make(902, "job_1", token, 80, 275, 45, 999, "Freios", "Hatch", "Freios", 1) == nil)
local pending = {}
check("adiciona claim", Rules.Add(pending, c))
check("não duplica claim", not Rules.Add(pending, c) and #pending == 1)
check("busca claim", Rules.Find(pending, "job_1", token) ~= nil)
check("não vê token diferente", Rules.Find(pending, "job_1", "bbbbbbbb-1111-2222-3333-cccccccccccc") == nil)
local clean = Rules.Sanitize({ c, c, { OwnerPay = math.huge }, "evil" })
check("sanitização ignora duplicatas/corrupção", #clean == 1 and clean[1].OwnerUserId == 902)
local ownerLedger = {}
check("sem prova do dono não autoriza", not Rules.Authorized(c, ownerLedger))
check("registra parcela do dono", Ledger.Record(ownerLedger, "job_1", token, 80, "Owner", 1790000000, "Freios", "Hatch"))
check("prova do dono autoriza", Rules.Authorized(c, ownerLedger))
ownerLedger[1].Amount = 81
check("pagamento divergente não autoriza", not Rules.Authorized(c, ownerLedger))
ownerLedger[1].Amount, ownerLedger[1].Role = 80, "Worker"
check("papel divergente não autoriza", not Rules.Authorized(c, ownerLedger))
ownerLedger[1].Role, ownerLedger[1].Service = "Owner", "Motor"
check("serviço divergente não autoriza", not Rules.Authorized(c, ownerLedger))
check("remove após salvamento", Rules.Remove(pending, "job_1", token) and #pending == 0)
check("remoção idempotente", not Rules.Remove(pending, "job_1", token))
table.insert(lines, fail == 0 and "TODOS OS TESTES PASSARAM" or (fail .. " TESTE(S) FALHARAM"))
return table.concat(lines, "\n")
