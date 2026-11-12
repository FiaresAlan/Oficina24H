-- Regressões contra OS fantasmas e carros sem asset.
local R = require(game.ReplicatedStorage.Shared.JobLifecycleRules)
local out = {}
local function check(name, ok)
	table.insert(out, (ok and "PASS " or "FAIL ") .. name)
end
local available = { B = true, C = true }
local function exists(name) return available[name] == true end
local names = { "A", "B", "C" }
check("prefere carro regular válido", R.SelectVehicle(names, "C", exists, function() return 0 end) == "C")
check("regular inválido tem fallback", R.SelectVehicle(names, "Z", exists, function() return 0 end) == "B")
check("carros indisponíveis são ignorados", R.SelectVehicle(names, nil, exists, function() return 0 end) == "B")
check("sorteio seleciona último disponível", R.SelectVehicle(names, nil, exists, function() return 0.999 end) == "C")
check("sorteio inválido não causa índice fora dos limites", R.SelectVehicle(names, nil, exists, function() return 0/0 end) == "B")
check("sem nenhum carro não cria OS", R.SelectVehicle(names, nil, function() return false end, function() return 0 end) == nil)
check("regular tem prioridade mesmo fora dos nomes comuns", R.SelectVehicle(names, "Raro", function(x) return x == "Raro" end, function() return 0 end) == "Raro")
check("dono saiu remove OS ativa", R.ShouldRemoveForOwnerExit(10, 10))
check("dono saiu remove OS aguardando", R.ShouldRemoveForOwnerExit(20, 20))
check("saída de contratado mantém OS do dono", not R.ShouldRemoveForOwnerExit(10, 20))
check("ids inválidos não apagam OS", not R.ShouldRemoveForOwnerExit(nil, 10))
return table.concat(out, "\n")
