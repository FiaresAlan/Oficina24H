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
return table.concat(results, "\n")
