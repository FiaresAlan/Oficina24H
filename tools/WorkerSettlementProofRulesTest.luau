-- C23: pagamentos de contratado confirmados em marcador privado que não
-- gira junto do extrato de 64 lançamentos.
local Paid = require(game.ReplicatedStorage.Shared.WorkerSettlementProofRules)
local Ledger = require(game.ReplicatedStorage.Shared.SettlementLedgerRules)
local lines, errors = {}, 0
local function check(name: string, ok: boolean)
	if not ok then errors += 1 end
	table.insert(lines, (ok and "PASS " or "FAIL ") .. name)
end
local token = "c23aaaaa-1111-2222-3333-444444444444"
local p = Paid.Make("job_23", token, 185, 1790000000, "Freios", "Hatch")
local saved = {}
check("C23: marcador válido contém dados necessários", p ~= nil and Paid.Valid(p))
check("C23: registro único", Paid.Add(saved, p) and #saved == 1)
check("C23: duplicidade nunca é inserida", not Paid.Add(saved, p) and #saved == 1)
check("C23: consulta só pelo token correto", Paid.Find(saved, "job_23", token) ~= nil
	and Paid.Find(saved, "job_23", "invalid") == nil)
check("C23: token/pagamento inválido não cria prova",
	Paid.Make("x", "small", 185, 1790000000, "Freios", "Hatch") == nil
	and Paid.Make("x", token, -1, 1790000000, "Freios", "Hatch") == nil)
local owner = { JobId = "job_23", Token = token, WorkerPay = 185,
	Service = "Freios", Vehicle = "Hatch" }
check("C23: conferência exige ID, valor, serviço e carro exatos", Paid.Matches(owner, p))
check("C23: valor divergente bloqueia confirmação", not Paid.Matches({
	JobId = owner.JobId, Token = owner.Token, WorkerPay = 186,
	Service = owner.Service, Vehicle = owner.Vehicle }, p))
check("C23: serviço divergente bloqueia confirmação", not Paid.Matches({
	JobId = owner.JobId, Token = owner.Token, WorkerPay = 185,
	Service = "Motor", Vehicle = owner.Vehicle }, p))
local ledger = {}
Ledger.Record(ledger, "job_23", token, 185, "Worker", 1790000000, "Freios", "Hatch")
for i = 1, Ledger.MaxEntries + 5 do
	Ledger.Record(ledger, "other_" .. i,
		string.format("c23bbbbb-1111-2222-3333-%012d", i),
		3, "Worker", 1790000000, "Freios", "Hatch")
end
check("C23: extrato de 64 perdeu o pagamento antigo", Ledger.Find(ledger, "job_23", token) == nil)
check("C23: prova independente continua consultável", Paid.Find(saved, "job_23", token) ~= nil)
local migratedLedger = {}
Ledger.Record(migratedLedger, "v8_work", token, 77, "Worker", 1790000000, "Freios", "Hatch")
Ledger.Record(migratedLedger, "v8_owner",
	"c23ccccc-1111-2222-3333-dddddddddddd", 10, "Owner", 1790000000, "Freios", "Hatch")
local migrated = Paid.FromLedger(nil, migratedLedger)
check("C23: migração v8 adiciona apenas créditos Worker",
	#migrated == 1 and Paid.Find(migrated, "v8_work", token) ~= nil)
check("C23: migração repetida não duplica marcador",
	#Paid.FromLedger(migrated, migratedLedger) == 1)
check("C23: sanitize ignora valores corrompidos",
	#Paid.Sanitize({ p, p, { JobId = "job_bad", Token = token, Amount = math.huge } }) == 1)
local full = {}
for i = 1, Paid.MaxEntries do
	local tk = string.format("c23ddddd-1111-2222-3333-%012d", i)
	Paid.Add(full, Paid.Make("paid_" .. i, tk, 3, 1790000000, "Freios", "Hatch"))
end
local new = Paid.Make("new", "c23eeeee-1111-2222-3333-eeeeeeeeeeee",
	3, 1790000000, "Freios", "Hatch")
check("C23: arquivo cheio não expulsa comprovantes", #full == Paid.MaxEntries
	and not Paid.CanAdd(full, new) and not Paid.Add(full, new)
	and Paid.Find(full, "paid_1", "c23ddddd-1111-2222-3333-000000000001") ~= nil)
table.insert(lines, errors == 0 and "TODOS OS TESTES PASSARAM" or (errors .. " TESTE(S) FALHARAM"))
return table.concat(lines, "\n")
