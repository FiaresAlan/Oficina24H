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
check("dono mexeu agora: OS é dele", Rules.OwnerIsWorking(100, 110))
check("dono parado há 25 s: NPC pode ajudar", not Rules.OwnerIsWorking(100, 125))
check("OS nunca tocada não bloqueia o NPC", not Rules.OwnerIsWorking(nil, 125))
check("toque inválido (NaN) não bloqueia", not Rules.OwnerIsWorking(0 / 0, 125))
local busy = {}
check("ordem sem reserva pode ser ocupada", Rules.TryReserve(busy, "job_1"))
check("reserva existente é reconhecida", Rules.IsReserved(busy, "job_1"))
check("ordem reservada não pode ter segundo executor", not Rules.TryReserve(busy, "job_1"))
check("outra ordem pode ser reservada", Rules.TryReserve(busy, "job_2"))
check("reserva não aceita IDs inválidos", not Rules.TryReserve(busy, "") and not Rules.TryReserve(busy, nil))
check("liberação de ordem é idempotente", Rules.Release(busy, "job_1") and not Rules.Release(busy, "job_1"))
check("ordem liberada pode ser retomada", Rules.TryReserve(busy, "job_1"))
check("liberação não remove trabalho da outra OS", Rules.IsReserved(busy, "job_2"))
table.insert(lines, errors == 0 and "TODOS OS TESTES PASSARAM" or (errors .. " TESTE(S) FALHARAM"))
return table.concat(lines, "\n")
