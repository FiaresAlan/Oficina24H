-- Regressões de ciclo de vida e expiração das sessões de reparo.
local Rules = require(game.ReplicatedStorage.Shared.RepairSessionRules)
local results = {}
local function check(name, ok)
	table.insert(results, (ok and "PASS " or "FAIL ") .. name)
end
local session = { JobId = "job_1", StartedAt = 100, Plan = {} }
check("sessao ativa aos 10s", Rules.IsActive(session, 110, 90))
check("sessao ativa no limite", Rules.IsActive(session, 190, 90))
check("sessao expirada aos 91s", not Rules.IsActive(session, 191, 90))
check("sessao ausente invalida", not Rules.IsActive(nil, 110, 90))
check("sessao com inicio ausente invalida", not Rules.IsActive({}, 110, 90))
check("sessao futura invalida", not Rules.IsActive(session, 99, 90))
check("duracao NaN invalida", not Rules.IsActive(session, 110, 0 / 0))
check("inicio NaN invalido", not Rules.IsActive({ StartedAt = 0 / 0 }, 110, 90))
check("tempo do servidor infinito invalido", not Rules.IsActive(session, math.huge, 90))
check("duracao negativa invalida", not Rules.IsActive(session, 110, -1))
-- C6: um cancelamento tardio da janela antiga não pode encerrar outro serviço.
local secured = { JobId = "job_2", Token = "new-guid", StartedAt = 100 }
check("cancelamento do serviço atual permitido", Rules.CanCancel(secured, "job_2", "new-guid"))
check("token anterior não cancela a nova sessão", not Rules.CanCancel(secured, "job_2", "old-guid"))
check("outra OS não cancela a sessão", not Rules.CanCancel(secured, "job_1", "new-guid"))
check("omitir token não cancela sessão protegida", not Rules.CanCancel(secured, "job_2", nil))
check("omitir JobId não cancela sessão protegida", not Rules.CanCancel(secured, nil, "new-guid"))
check("sem sessão, cancelamento idempotente", Rules.CanCancel(nil, "job_2", "old-guid"))
check("sessão sem token não pode ser cancelada", not Rules.CanCancel(session, nil, nil))
check("timing protegido aceita apenas seu token", Rules.CanCancel({ JobId = "job_9", Token = "timing-token" }, "job_9", "timing-token"))
check("timing protegido recusa token ausente", not Rules.CanCancel({ JobId = "job_9", Token = "timing-token" }, "job_9", nil))
check("timing de outra OS é recusado", not Rules.CanCancel(session, "job_2", nil))
check("sessão inválida não autoriza cancelamento", not Rules.CanCancel("bad", nil, nil))
local signed = { JobId = "job_9", Token = "11111111-2222-3333-4444-555555555555", Plan = { Kind = "Timing" } }
check("timing: aceita seu token de finalização", Rules.MatchesFinish(signed, "job_9", {
	Token = signed.Token, 0.6, 1.7, 2.1,
}))
check("timing: não aceita sessão sem token", not Rules.MatchesFinish({ JobId = "job_9" }, "job_9", {}))
check("timing: não aceita token omitido", not Rules.MatchesFinish(signed, "job_9", { 0.6 }))
check("timing: não aceita token antigo", not Rules.MatchesFinish(signed, "job_9", { Token = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" }))
check("timing: não aceita outra OS", not Rules.MatchesFinish(signed, "job_10", { Token = signed.Token }))
check("timing: não aceita payload estranho", not Rules.MatchesFinish(signed, "job_9", "bad"))
local operationSession = { JobId = "job_10", Token = "eeeeeeee-1111-2222-3333-444444444444", Plan = { Kind = "Operations" } }
check("operação: mantém proteção equivalente", Rules.MatchesFinish(operationSession, "job_10", { Token = operationSession.Token }))
check("operação: rejeita pacote timing de outro token", not Rules.MatchesFinish(operationSession, "job_10", { Token = signed.Token }))
return table.concat(results, "\n")
