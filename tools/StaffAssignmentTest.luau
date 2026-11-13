-- C17: não roubar a primeira ordem enquanto o jogador começa o serviço.
local Rules = require(game.ReplicatedStorage.Shared.StaffAssignmentRules)
local lines, errors = {}, 0
local function check(name: string, ok: boolean)
	if not ok then errors += 1 end
	table.insert(lines, (ok and "PASS " or "FAIL ") .. name)
end
check("nenhum carro: funcionário espera", not Rules.ShouldDispatch(0, 200))
check("um carro recente: jogador tem preferência", not Rules.ShouldDispatch(1, 24))
check("um carro esquecido: NPC trabalha", Rules.ShouldDispatch(1, 25))
check("dois carros: NPC ajuda imediatamente", Rules.ShouldDispatch(2, 0))
check("carro novo não é escolhido se só havia um", not Rules.EligibleJob(1, 1))
check("com dois carros, o mais novo também pode ser atendido", Rules.EligibleJob(2, 1))
table.insert(lines, errors == 0 and "TODOS OS TESTES PASSARAM" or (errors .. " TESTE(S) FALHARAM"))
return table.concat(lines, "\n")
