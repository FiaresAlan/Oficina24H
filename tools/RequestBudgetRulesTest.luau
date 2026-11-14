-- Regressão da auditoria G5: teto por segundo de RepairAction/GetSnapshot e eco seguro do ACK.
local Rules = require(game.ReplicatedStorage.Shared.RequestBudgetRules)
local results = {}
local function check(label, ok)
	table.insert(results, (ok and "PASS " or "FAIL ") .. label)
end

local states = {}
local granted = 0
for _ = 1, 40 do
	if Rules.Take(states, 1, 100, 30) then granted += 1 end
end
check("janela de 1 s atende exatamente o limite", granted == 30)
check("mesmo instante acima do limite é recusado", not Rules.Take(states, 1, 100.5, 30))
check("nova janela libera de novo", Rules.Take(states, 1, 101, 30))
check("jogadores têm orçamentos independentes", Rules.Take(states, 2, 100.5, 30))
check("relógio que volta atrás reinicia a janela sem travar", Rules.Take(states, 1, 50, 30))
check("limite inválido nunca atende", not Rules.Take(states, 3, 100, 0) and not Rules.Take(states, 3, 100, 0 / 0))
check("relógio NaN nunca atende", not Rules.Take(states, 4, 0 / 0, 30))
check("janela personalizada", Rules.Take(states, 5, 0, 1, 0.25) and not Rules.Take(states, 5, 0.2, 1, 0.25)
	and Rules.Take(states, 5, 0.3, 1, 0.25))
Rules.Clear(states, 1)
check("limpeza ao sair remove o estado", states[1] == nil)

check("eco aceita GUID", Rules.EchoString("cccccccc-1111-2222-3333-dddddddddddd") ~= nil)
check("eco recusa string enorme", Rules.EchoString(string.rep("x", 5000)) == nil)
check("eco recusa tabela", Rules.EchoString({}) == nil)
check("eco numérico aceita inteiro", Rules.EchoNumber(7) == 7)
check("eco numérico recusa NaN/inf/string", Rules.EchoNumber(0 / 0) == nil and Rules.EchoNumber(math.huge) == nil
	and Rules.EchoNumber("3") == nil)

return table.concat(results, "\n")
