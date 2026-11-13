--!strict
local Ledger = require(game.ReplicatedStorage.Shared.SettlementLedgerRules)
local lines = {}
local function check(name: string, success: any)
	table.insert(lines, (success and "PASS " or "FAIL ") .. name)
end
local token = "aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb"
local other = "aaaaaaaa-1111-2222-3333-cccccccccccc"
local entries = {}
check("chave de sessão válida", Ledger.ValidKey("job_1", token))
check("token curto rejeitado", not Ledger.ValidKey("job_1", "x"))
check("registro com chave e papel", Ledger.Record(entries, "job_1", token, 380, "Owner", 1000, "Freios", "Sedã"))
check("registro contém valor", Ledger.Find(entries, "job_1", token).Amount == 380)
check("não grava crédito duplicado", not Ledger.Record(entries, "job_1", token, 380, "Owner", 1001, "Freios", "Sedã"))
check("nenhum segundo crédito", #entries == 1)
check("outra sessão não tem crédito", Ledger.Find(entries, "job_1", other) == nil)
check("rejeita crédito negativo", not Ledger.Record(entries, "job_2", other, -2, "Owner", 1001, "Motor", "Hatch"))
check("rejeita crédito infinito", not Ledger.Record(entries, "job_2", other, math.huge, "Owner", 1001, "Motor", "Hatch"))
check("rejeita papel desconhecido", not Ledger.Record(entries, "job_2", other, 5, "Spy", 1001, "Motor", "Hatch"))
check("não aceita recibo de outro token", not Ledger.Attach(entries, "job_1", token, { JobId = "job_1", Token = other }))
local receipt = { JobId = "job_1", Token = token, Price = 350, Tip = 30, XP = 20,
	Quality = 92, Stars = 5, Breakdown = { Execution = 84, Skill = 3 } }
check("anexa recibo ao crédito existente", Ledger.Attach(entries, "job_1", token, receipt))
check("não sobrescreve recibo", not Ledger.Attach(entries, "job_1", token, { JobId = "job_1", Token = token, Price = 999 }))
receipt.Price = 999
receipt.Breakdown.Execution = 0
local result = Ledger.Receipt(entries, "job_1", token)
check("recibo não compartilha referências", result.Price == 350 and result.Breakdown.Execution == 84)
result.Price = -5
check("consulta retorna cópia", Ledger.Receipt(entries, "job_1", token).Price == 350)
check("consulta de outro token é negada", Ledger.Receipt(entries, "job_1", other) == nil)
local clean = Ledger.Sanitize(entries)
check("livro sanitizado conserva recibo", #clean == 1 and Ledger.Receipt(clean, "job_1", token).Price == 350)
check("lista pública omite token e JobId", Ledger.Public(clean, 5)[1].Token == nil and Ledger.Public(clean, 5)[1].JobId == nil)
check("lista pública mostra valor real", Ledger.Public(clean, 5)[1].Amount == 380)
check("lista pública mostra qualidade", Ledger.Public(clean, 5)[1].Quality == 92)
local malformed = { { JobId = "bad", Token = "x", Amount = 9, Role = "Owner", At = 1 },
	{ JobId = "job_1", Token = token, Amount = -100, Role = "Owner", At = 5 } }
check("livro corrompido descartado", #Ledger.Sanitize(malformed) == 0)
local more = {}
for i = 1, Ledger.MaxEntries + 4 do
	local key = string.format("00000000-0000-0000-0000-%012d", i)
	check("grava lançamento " .. i, Ledger.Record(more, "job_" .. i, key, i, "Worker", i, "Servico", "Carro"))
end
check("livro limitado a 64", #more == Ledger.MaxEntries)
check("mais antigo saiu", Ledger.Find(more, "job_1", "00000000-0000-0000-0000-000000000001") == nil)
check("último lançamento preservado", Ledger.Find(more, "job_68", "00000000-0000-0000-0000-000000000068") ~= nil)
return table.concat(lines, "\n")
