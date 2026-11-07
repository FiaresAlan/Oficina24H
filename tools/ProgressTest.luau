-- Testes das regras de retenção (shared/ProgressRules): diária, missões, conquistas e códigos. Rodar no Edit via MCP.
local ProgressRules = require(game:GetService("ReplicatedStorage").Shared.ProgressRules)

local results, failures = {}, 0
local function check(name: string, cond: boolean, detail: any?)
	if not cond then failures += 1 end
	table.insert(results, (cond and "PASS " or "FAIL ") .. name .. (cond and "" or (" -> " .. tostring(detail))))
end

-- Diária
local today = 20000
local can, day = ProgressRules.DailyState(nil, 0, today)
check("diária: primeira vez pode, dia 1", can and day == 1, day)
can, day = ProgressRules.DailyState(today, 1, today)
check("diária: já pegou hoje não pode", not can)
can, day = ProgressRules.DailyState(today - 1, 3, today)
check("diária: dia seguinte continua (dia 4)", can and day == 4, day)
can, day = ProgressRules.DailyState(today - 1, 7, today)
check("diária: depois do 7º volta ao dia 1 sem quebrar", can and day == 1, day)
can, day = ProgressRules.DailyState(today - 3, 5, today)
check("diária: pulou dia recomeça no 1", can and day == 1, day)
check("diária: 7 recompensas crescentes até o grande dia", #ProgressRules.DailyRewards == 7 and ProgressRules.DailyRewards[7].Coins > ProgressRules.DailyRewards[1].Coins)

-- Missões
local a = ProgressRules.DailyMissions(123, today)
local b = ProgressRules.DailyMissions(123, today)
check("missões: 3 por dia", #a == 3, #a)
check("missões: mesmo sorteio no mesmo dia", a[1] == b[1] and a[2] == b[2] and a[3] == b[3])
local kinds = {}
for _, id in ipairs(a) do
	local def = ProgressRules.MissionById[id]
	check("missão " .. id .. " existe", def ~= nil)
	if def then
		check("missão " .. id .. " sem tipo repetido", kinds[def.Kind] == nil)
		kinds[def.Kind] = true
	end
end
local differs = false
for d = 1, 10 do
	local other = ProgressRules.DailyMissions(123, today + d)
	if other[1] ~= a[1] or other[2] ~= a[2] then differs = true end
end
check("missões: mudam com o dia", differs)
local repair = ProgressRules.MissionById.repair3
check("contribuição: reparo conta 1", ProgressRules.Contribution(repair, { Kind = "RepairDone" }) == 1)
check("contribuição: outro evento não conta", ProgressRules.Contribution(repair, { Kind = "Outro" }) == 0)
check("contribuição: faturamento soma o valor", ProgressRules.Contribution(ProgressRules.MissionById.earn800, { Kind = "RepairDone", Amount = 250 }) == 250)
check("contribuição: especialização certa", ProgressRules.Contribution(ProgressRules.MissionById.tires2, { Kind = "RepairDone", Spec = "Tires" }) == 1
	and ProgressRules.Contribution(ProgressRules.MissionById.tires2, { Kind = "RepairDone", Spec = "Engine" }) == 0)
check("contribuição: NaN no valor não soma", ProgressRules.Contribution(ProgressRules.MissionById.earn800, { Kind = "RepairDone", Amount = 0 / 0 }) == 0)

-- Conquistas
local new = ProgressRules.NewAchievements({ Repairs = 10, Earned = 0 }, { cli1 = true })
local ids = {}
for _, x in ipairs(new) do ids[x.Id] = true end
check("conquistas: alcança cli10 e não repete cli1", ids.cli10 == true and ids.cli1 == nil)
check("conquistas: nada sem stats", #ProgressRules.NewAchievements({}, {}) == 0)

-- Códigos
check("código: normaliza minúsculas e espaços", ProgressRules.NormalizeCode(" oficina24h ") == "OFICINA24H")
check("código: recusa símbolos", ProgressRules.NormalizeCode("a;drop") == nil)
check("código: recusa texto longo", ProgressRules.NormalizeCode(string.rep("A", 40)) == nil)
check("código: recusa não-texto", ProgressRules.NormalizeCode(5) == nil)
check("lista de códigos não vai para o cliente", ProgressRules.Codes == nil)
local PromoCodes = require(game:GetService("ServerScriptService").Server.PromoCodes)
check("código OFICINA24H existe no servidor", PromoCodes.OFICINA24H ~= nil)

table.insert(results, failures == 0 and "TODOS OS TESTES PASSARAM" or (failures .. " TESTE(S) FALHARAM"))
return table.concat(results, "\n")
