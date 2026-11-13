-- C29: duas contas, cancelamento de chegada e limpeza de saída não
-- podem manter carros fantasmas nem afetar carros de outro proprietário.
local Rules = require(game.ReplicatedStorage.Shared.VehicleSceneRules)
local results, errors = {}, 0
local function check(label: string, ok: boolean)
	if not ok then errors += 1 end
	table.insert(results, (ok and "PASS " or "FAIL ") .. label)
end

local a = { JobId = "job_29", OwnerUserId = 2901 }
local b = { JobId = "job_30", OwnerUserId = 2902 }
local states = { job_29 = a, job_30 = b }
check("C29: chegada ativa permanece válida", Rules.IsCurrentArrival(states, "job_29", a))
states.job_29 = nil
check("C29: cancelar antes da coroutine não deve criar carro",
	not Rules.IsCurrentArrival(states, "job_29", a))
states.job_29 = { JobId = "job_29", OwnerUserId = 2901 }
check("C29: reabrir mesma ID não revalida coroutine antiga",
	not Rules.IsCurrentArrival(states, "job_29", a))
check("C29: chegada de B permanece ativa enquanto A sai",
	Rules.IsCurrentArrival(states, "job_30", b))
check("C29: estado inválido não pode criar cena",
	not Rules.IsCurrentArrival(nil, "job_29", a)
	and not Rules.IsCurrentArrival(states, nil, a)
	and not Rules.IsCurrentArrival(states, "job_29", nil))
local curb = { OwnerUserId = 2901 }
local departing = { OwnerUserId = 2902 }
check("C29: ao sair A, limpar carro em despedida de A",
	Rules.IsOwnedBy(curb, 2901))
check("C29: ao sair A, carro de B não pode ser destruído",
	not Rules.IsOwnedBy(departing, 2901))
check("C29: ao sair B, apenas seu carro é elegível",
	Rules.IsOwnedBy(departing, 2902) and not Rules.IsOwnedBy(curb, 2902))
check("C29: registros inconsistentes não autorizam limpar terceiros",
	not Rules.IsOwnedBy({}, 2901) and not Rules.IsOwnedBy(nil, 2901)
	and not Rules.IsOwnedBy(curb, 0) and not Rules.IsOwnedBy(curb, "2901"))
table.insert(results, errors == 0 and "TODOS OS TESTES PASSARAM"
	or (errors .. " TESTE(S) FALHARAM"))
return table.concat(results, "\n")
