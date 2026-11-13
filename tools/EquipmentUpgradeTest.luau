-- C16: novas ferramentas aumentam qualidade e renda sem saltos descontrolados.
local Rules = require(game.ReplicatedStorage.Shared.EquipmentUpgradeRules)
local Catalog = require(game.ReplicatedStorage.Shared.Catalog)
local lines, failures = {}, 0
local function check(name: string, ok: boolean)
	if not ok then failures += 1 end
	table.insert(lines, (ok and "PASS " or "FAIL ") .. name)
end
local owned = { BasicToolset = true, Jack = true }
check("kit inicial nível 1", Rules.Level(nil, owned, "BasicToolset") == 1)
check("não inventa item não comprado", Rules.Level({ Scanner = 3 }, owned, "Scanner") == 0)
check("ignora nível adulterado", Rules.Level({ Jack = math.huge }, owned, "Jack") == 1)
check("limita nível máximo", Rules.Level({ Jack = 999 }, owned, "Jack") == Rules.MaxLevel)
check("sanitiza upgrades e mantém posse", Rules.Sanitize({ Jack = 2, Scanner = 3 }, owned).Jack == 2
	and Rules.Sanitize({ Jack = 2, Scanner = 3 }, owned).Scanner == nil)
for id in pairs(Catalog.Equipment) do
	local l2, l3 = Rules.NextCost(id, 1), Rules.NextCost(id, 2)
	check(id .. " custo crescente", l2 ~= nil and l3 ~= nil and l2 > 0 and l3 > l2)
	check(id .. " sem upgrade após nível 3", Rules.NextCost(id, 3) == nil)
	check(id .. " bônus qualidade limitado", Rules.Efficiency(id, 3) <= 4)
end
check("nível 3 rende mais moedas", Rules.RewardMultiplier(3) > Rules.RewardMultiplier(1)
	and Rules.RewardMultiplier(3) <= 1.06)
check("funcionário mais rápido com equipamento melhor", Rules.EmployeeSeconds(60, 3) < 60)
check("qualidade do NPC cresce sem 100 automático", Rules.EmployeeQuality(72, 3) == 76)
table.insert(lines, failures == 0 and "TODOS OS TESTES PASSARAM" or (failures .. " TESTE(S) FALHARAM"))
return table.concat(lines, "\n")
