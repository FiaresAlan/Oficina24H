-- Testes de proximidade de estabelecimentos; requer execução no Edit do Roblox Studio.
local Rules = require(game.ReplicatedStorage.Shared.LocationRules)
local results = {}
local function check(label, condition)
	table.insert(results, (condition and "PASS " or "FAIL ") .. label)
end

local cf = CFrame.new(100, 0, 30) * CFrame.Angles(0, math.rad(90), 0)
local size = Vector3.new(20, 10, 12)
check("loja centro", Rules.IsNearBlock(cf, size, cf.Position, 0))
check("loja borda", Rules.IsNearBlock(cf, size, cf:PointToWorldSpace(Vector3.new(10, 0, 6)), 0))
check("loja dentro da tolerancia", Rules.IsNearBlock(cf, size, cf:PointToWorldSpace(Vector3.new(12, 0, 6)), 2))
check("loja fora da tolerancia", not Rules.IsNearBlock(cf, size, cf:PointToWorldSpace(Vector3.new(12.1, 0, 6)), 2))
check("loja longe", not Rules.IsNearBlock(cf, size, Vector3.new(999, 0, 999), 40))
check("bloco ausente", not Rules.IsNearBlock(nil, size, Vector3.new(), 40))
check("sem personagem", not Rules.IsNearBlock(cf, size, nil, 40))
check("distancia negativa", not Rules.IsNearBlock(cf, size, cf.Position, -1))
check("distancia NaN", not Rules.IsNearBlock(cf, size, cf.Position, 0 / 0))
check("publicado: sem bloco e negado", not Rules.MissingBlockAllowed(false))
check("Studio: ausencia explicitamente tolerada", Rules.MissingBlockAllowed(true))

return table.concat(results, "\n")
