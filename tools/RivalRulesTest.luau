-- Testa invariantes de faturamento e capacidade dos concorrentes NPC.
local Rules = require(game.ReplicatedStorage.Shared.RivalRules)
local results = {}
local function check(label, condition)
	table.insert(results, (condition and "PASS " or "FAIL ") .. label)
end

local base = { Active = true, BayReserved = true, VehiclePresent = true, Completed = true, Credited = false }
local function with(change)
	local c = table.clone(base)
	for k, v in pairs(change) do c[k] = v end
	return c
end
check("servico concluido e valido pode creditar", Rules.CanSettle(base))
check("rival removido nao fatura", not Rules.CanSettle(with({ Active = false })))
check("vaga nao reservada nao fatura", not Rules.CanSettle(with({ BayReserved = false })))
check("carro nao criado nao fatura", not Rules.CanSettle(with({ VehiclePresent = false })))
check("trabalho incompleto nao fatura", not Rules.CanSettle(with({ Completed = false })))
check("repeticao nao fatura duas vezes", not Rules.CanSettle(with({ Credited = true })))
check("zero vaga nao compete", Rules.BayCapacity(0, 3) == 0)
check("uma vaga limita demanda", Rules.BayCapacity(1, 3) == 1)
check("limite do mercado e respeitado", Rules.BayCapacity(6, 3) == 3)
check("contagens negativas nao viram capacidade", Rules.BayCapacity(-2, 3) == 0)

return table.concat(results, "\n")
