-- Verifica o portão de entrega sem exigir DataStore ou jogadores reais.
local Rules = require(game.ReplicatedStorage.Shared.SettlementDeliveryRules)
local results, failures = {}, 0
local function check(name: string, passed: boolean)
	if not passed then failures += 1 end
	table.insert(results, (passed and "PASS " or "FAIL ") .. name)
end
local token = "aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb"
check("token curto rejeitado", Rules.New("job_1", "x", 10, 11) == nil)
check("identidade de beneficiário obrigatória", Rules.New("job_1", token, -1, 11) == nil)
local s = Rules.New("job_1", token, 10, 11)
check("entrega nasce pendente", s ~= nil and not Rules.Ready(s))
check("sessão correta reconhecida", Rules.Matches(s, "job_1", token))
check("token diferente não reconhecido", not Rules.Matches(s, "job_1", "cccccccc-1111-2222-3333-dddddddddddd"))
check("não conclui com o primeiro salvamento falho", not Rules.MarkSaved(s, "Owner", false) and not Rules.Ready(s))
check("contratado não confirma antes do dono", not Rules.MarkSaved(s, "Worker", true))
check("salvamento do dono confirmado", Rules.MarkSaved(s, "Owner", true) and s.OwnerSaved)
check("salvamento falho do contratado preserva pendência", not Rules.MarkSaved(s, "Worker", false) and not Rules.Ready(s))
check("salvamento do contratado conclui", Rules.MarkSaved(s, "Worker", true) and Rules.Ready(s))
check("papel desconhecido rejeitado", not Rules.MarkSaved(s, "Other", true))
check("estado corrompido não confirma", not Rules.Ready({ OwnerSaved = true }))
local own = Rules.New("job_2", token, 10, 10)
check("serviço individual ainda exige gravação", own ~= nil and not Rules.Ready(own))
check("serviço individual entrega após gravação", Rules.MarkSaved(own, "Owner", true)
	and Rules.MarkSaved(own, "Worker", true) and Rules.Ready(own))
table.insert(results, failures == 0 and "TODOS OS TESTES PASSARAM" or (failures .. " TESTE(S) FALHARAM"))
return table.concat(results, "\n")
