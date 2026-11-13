--!strict
-- Comprovantes de conclusão privados por token, com limite de memória e tempo.
local Rules = require(game.ReplicatedStorage.Shared.RepairReceiptRules)
local output = {}
local function check(name: string, condition: any)
	table.insert(output, (condition and "PASS " or "FAIL ") .. name)
end
local token = "11111111-2222-3333-4444-555555555555"
local other = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
local now = 1000
local receipts = {}

check("identificador completo válido", Rules.ValidRequest("job_17", token))
check("ID sem token é inválido", not Rules.ValidRequest("job_17", nil))
check("token curto é inválido", not Rules.ValidRequest("job_17", "abc"))
check("JobId inexistente é inválido", not Rules.ValidRequest(nil, token))
check("JobId longo é inválido", not Rules.ValidRequest(string.rep("z", 129), token))
check("comprovante inexistente é nil", Rules.Lookup(receipts, "job_17", token, now) == nil)
check("não aceita comprovante sem resultado", not Rules.Remember(receipts, "job_17", token, nil, now))
check("não aceita tempo infinito", not Rules.Remember(receipts, "job_17", token, {}, math.huge))
local payload = { JobId = "job_17", Token = token, Quality = 91, Price = 250, XP = 50,
	Breakdown = { Execution = 87, Skill = 2 } }
check("registrar somente após liquidação", Rules.Remember(receipts, "job_17", token, payload, now))
check("um único comprovante na lista", #receipts == 1)
payload.Price = 99999
payload.Breakdown.Execution = 0
local found = Rules.Lookup(receipts, "job_17", token, now + 2)
check("recibo não compartilha referência externa", found.Price == 250 and found.Breakdown.Execution == 87)
found.Price = -100
found.Breakdown.Execution = -1
local again = Rules.Lookup(receipts, "job_17", token, now + 3)
check("consulta retorna cópia isolada", again.Price == 250 and again.Breakdown.Execution == 87)
check("repetição não sobrescreve recibo", not Rules.Remember(receipts, "job_17", token, { Price = 9999 }, now + 5))
check("repetição preserva valor pago", Rules.Lookup(receipts, "job_17", token, now + 7).Price == 250)
check("outra sessão não acessa resultado", Rules.Lookup(receipts, "job_17", other, now) == nil)
check("outra OS não acessa resultado", Rules.Lookup(receipts, "job_18", token, now) == nil)
check("tempo negativo nega consulta", Rules.Lookup(receipts, "job_17", token, -1) == nil)
check("comprovante disponível no limite TTL",
	Rules.Lookup(receipts, "job_17", token, now + Rules.TtlSeconds) ~= nil)
check("comprovante expira após TTL",
	Rules.Lookup(receipts, "job_17", token, now + Rules.TtlSeconds + 0.1) == nil)
check("comprovante expirado é removido", #receipts == 0)

local many = {}
for i = 1, Rules.MaxPerPlayer + 4 do
	local key = string.format("receipt-token-%08d", i)
	check("registra recibo " .. i, Rules.Remember(many, "job_" .. i, key, { Price = i }, i + 1000))
end
check("lista respeita limite por jogador", #many == Rules.MaxPerPlayer)
check("registro mais antigo é descartado", Rules.Lookup(many, "job_1", "receipt-token-00000001", 1013) == nil)
check("último registro permanece", Rules.Lookup(many, "job_12", "receipt-token-00000012", 1013) ~= nil)
check("limpeza inválida não destrói a lista", Rules.Prune(many, 0 / 0) == 0)
check("limpeza futura remove expirados", Rules.Prune(many, 9999) == Rules.MaxPerPlayer)
check("lista vazia após limpeza", #many == 0)

return table.concat(output, "\n")
