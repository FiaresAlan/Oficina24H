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

-- Contratos de frota (shared/ContractRules)
local ContractRules = require(game:GetService("ReplicatedStorage").Shared.ContractRules)
local t0, s0, c0, r0 = ContractRules.Terms(0)
local t3, s3, c3, r3 = ContractRules.Terms(3)
check("contrato: nível 0 pede 2 carros", t0 == 2, t0)
check("contrato: nível 3 maior, mais tempo e mais prêmio", t3 > t0 and s3 > s0 and c3 > c0 and r3 > r0, c3)
check("contrato: nível fora da faixa é limitado", (ContractRules.Terms(9)) == t3 and (ContractRules.Terms(-2)) == t0)
check("contrato: tempo razoável por carro (>= 2,5 min cada)", s0 / t0 >= 150 and s3 / t3 >= 150, s3 / t3)
local offer = ContractRules.Offer(1, { "Tires" }, math.random)
check("contrato: só oferece área que a oficina atende", offer ~= nil and offer.Spec == "Tires", offer and offer.Spec)
check("contrato: sem área atendida não oferece", ContractRules.Offer(1, {}, math.random) == nil)
check("contrato: texto legível", offer ~= nil and ContractRules.Text(offer):find("Táxi Veloz") ~= nil, offer and ContractRules.Text(offer))
check("contrato: precisa de frota até cobrir a meta", ContractRules.NeedsFleet(1, 1, 3) and not ContractRules.NeedsFleet(2, 1, 3))
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local specsOk = true
for _, c in ipairs(ContractRules.Companies) do
	if not table.find(Catalog.Specializations, c.Spec) then specsOk = false end
end
check("contrato: toda empresa usa uma especialização do catálogo", specsOk)

-- Liga semanal
local monday = 1793588400 -- 2026-11-02 03:00 UTC = segunda 00:00 em Brasília
check("liga: semana vira na segunda 00:00 de Brasília", ProgressRules.Week(monday) == ProgressRules.Week(monday - 1) + 1)
check("liga: mesma semana até domingo", ProgressRules.Week(monday) == ProgressRules.Week(monday + 6 * 86400 + 86399))
check("liga: fim da semana em até 7 dias", ProgressRules.WeekEndsIn(monday) == 604800 and ProgressRules.WeekEndsIn(monday + 100) == 604700)
local tier, nextTier = ProgressRules.LeagueTier(0)
check("liga: 0 pontos sem faixa, próxima Bronze", tier == nil and nextTier and nextTier.Id == "Bronze")
tier, nextTier = ProgressRules.LeagueTier(150)
check("liga: 150 pontos = Prata, próxima Ouro", tier and tier.Id == "Prata" and nextTier and nextTier.Id == "Ouro", tier and tier.Id)
tier, nextTier = ProgressRules.LeagueTier(99999)
check("liga: topo = Ouro sem próxima", tier and tier.Id == "Ouro" and nextTier == nil)
check("liga: prêmios crescentes", ProgressRules.LeagueTiers[1].Coins < ProgressRules.LeagueTiers[2].Coins and ProgressRules.LeagueTiers[2].Coins < ProgressRules.LeagueTiers[3].Coins)
check("liga: pontos de um 5 estrelas perfeito VIP = 9", ProgressRules.LeaguePoints(5, 95, true) == 9)
check("liga: pontos limitados e sem NaN", ProgressRules.LeaguePoints(99, nil, false) == 5 and ProgressRules.LeaguePoints(0 / 0, 0 / 0, false) == 0)

-- Movimento dos carros (shared/RouteMotion): mesma conta no servidor e no cliente
local RouteMotion = require(game:GetService("ReplicatedStorage").Shared.RouteMotion)
local route = RouteMotion.Build({ Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), Vector3.new(20, 0, 20) }, 12, false)
check("rota: monta com 3 pontos", route ~= nil)
if route then
	check("rota: comprimento total 40", math.abs(route.Total - 40) < 1e-6, route.Total)
	check("rota: começa parado no início", RouteMotion.DistanceAt(route, 0) == 0)
	check("rota: termina exatamente no fim", RouteMotion.DistanceAt(route, route.Duration + 1) == route.Total)
	local mono = true
	local last = -1
	for i = 0, 60 do
		local d = RouteMotion.DistanceAt(route, route.Duration * i / 60)
		if d < last then mono = false end
		last = d
	end
	check("rota: distância nunca volta", mono)
	check("rota: duração coerente com a velocidade", route.Duration > 40 / 12 and route.Duration < 40 / 12 + 4, route.Duration)
	local endPose = RouteMotion.Pose(route, route.Total)
	check("rota: pose final no último ponto", (endPose.Position - Vector3.new(20, 0, 20)).Magnitude < 1e-3)
	check("rota: de frente para onde vai (+Z no fim)", endPose.LookVector:Dot(Vector3.new(0, 0, 1)) > 0.9, endPose.LookVector)
	local back = RouteMotion.Build({ Vector3.new(0, 0, 0), Vector3.new(0, 0, 10) }, 8, true)
	check("rota: ré aponta a frente para trás", back ~= nil and RouteMotion.Pose(back, 5).LookVector:Dot(Vector3.new(0, 0, -1)) > 0.9)
end
check("rota: recusa rota de 1 ponto", RouteMotion.Build({ Vector3.zero }, 10) == nil)

table.insert(results, failures == 0 and "TODOS OS TESTES PASSARAM" or (failures .. " TESTE(S) FALHARAM"))
return table.concat(results, "\n")
