-- C26: toda ordem de uma oficina encerrada some da memória; colaborador
-- desconectado devolve a ordem ao dono, sem encerrar por engano.
local Rules = require(game.ReplicatedStorage.Shared.JobExitRules)
local lines, errors = {}, 0
local function check(name, ok)
	if not ok then errors += 1 end
	table.insert(lines, (ok and "PASS " or "FAIL ") .. name)
end
for _, status in ipairs({ "Available", "InProgress", "Completed" }) do
	check("C26: dono saiu; remover OS " .. status,
		Rules.Action({ OwnerUserId = 2601, Status = status }, 2601) == "RemoveOwner")
	check("C26: dono saiu com colaborador; remover " .. status,
		Rules.Action({ OwnerUserId = 2601, CollaboratorUserId = 2602,
			Status = status }, 2601) == "RemoveOwner")
end
check("C26: colaborador saiu; devolver OS em progresso",
	Rules.Action({ OwnerUserId = 2601, CollaboratorUserId = 2602,
		Status = "InProgress" }, 2602) == "ReturnToOwner")
check("C26: colaborador não devolve OS concluída",
	Rules.Action({ OwnerUserId = 2601, CollaboratorUserId = 2602,
		Status = "Completed" }, 2602) == "None")
check("C26: outro jogador não altera OS",
	Rules.Action({ OwnerUserId = 2601, CollaboratorUserId = 2602,
		Status = "InProgress" }, 2603) == "None")
check("C26: nil ou id inválido não remove jobs",
	Rules.Action(nil, 2601) == "None" and Rules.Action({}, "2601") == "None")
table.insert(lines, errors == 0 and "TODOS OS TESTES PASSARAM" or (errors .. " TESTE(S) FALHARAM"))
return table.concat(lines, "\n")
