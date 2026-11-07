--!strict
-- ProgressRules: regras PURAS de retenção (sem serviços do Roblox, testáveis no Edit):
--   * recompensa diária com sequência de 7 dias (perdeu um dia, volta ao dia 1);
--   * 3 missões diárias sorteadas por jogador e por dia (mesmo sorteio no mesmo dia, mesmo após sair e voltar);
--   * conquistas permanentes por marcos (clientes atendidos, faturamento, VIP, reparos perfeitos, prédio);
--   * códigos promocionais (uma vez por jogador, com validade).
-- O servidor (ProgressService) guarda o estado no perfil e decide tudo; o cliente só mostra.
local ProgressRules = {}

-- Dia UTC (número inteiro) de um instante os.time().
function ProgressRules.Day(now: number): number
	return math.floor(now / 86400)
end

-- Recompensa diária ---------------------------------------------------------------------------------------------
ProgressRules.DailyRewards = {
	{ Coins = 100 },
	{ Coins = 150 },
	{ Coins = 200, Parts = { TirePatch = 2 } },
	{ Coins = 250 },
	{ Coins = 300, Parts = { Battery = 1, Fuse = 2 } },
	{ Coins = 400 },
	{ Coins = 700, Parts = { SparkPlug = 2, Coolant = 2, BrakePad = 1 }, Big = true }, -- 7º dia: o grande
} :: { { Coins: number, Parts: { [string]: number }?, Big: boolean? } }

-- Próximo dia da sequência dado o último resgate. Retorna (pode resgatar hoje, dia da sequência 1..7).
function ProgressRules.DailyState(lastDay: number?, streak: number?, today: number): (boolean, number)
	local s = math.max(0, streak or 0)
	local n = #ProgressRules.DailyRewards
	if lastDay == today then
		return false, ((math.max(1, s) - 1) % n) + 1
	end
	if lastDay == today - 1 then
		return true, (s % n) + 1 -- continua a sequência (depois do 7º volta ao 1º, sem perder a contagem)
	end
	return true, 1 -- primeira vez ou sequência quebrada
end

-- Missões diárias -----------------------------------------------------------------------------------------------
-- Kind = evento que conta; Target = meta; Reward = moedas (+ reputação).
export type MissionDef = { Id: string, Kind: string, Target: number, Coins: number, Reputation: number, Text: string, Param: string? }

ProgressRules.MissionPool = {
	{ Id = "repair3", Kind = "Repair", Target = 3, Coins = 150, Reputation = 2, Text = "Conserte 3 carros" },
	{ Id = "repair6", Kind = "Repair", Target = 6, Coins = 320, Reputation = 4, Text = "Conserte 6 carros" },
	{ Id = "earn800", Kind = "Earn", Target = 800, Coins = 200, Reputation = 2, Text = "Fature 800 moedas em serviços" },
	{ Id = "earn2000", Kind = "Earn", Target = 2000, Coins = 450, Reputation = 4, Text = "Fature 2.000 moedas em serviços" },
	{ Id = "stars2", Kind = "FiveStars", Target = 2, Coins = 220, Reputation = 3, Text = "Receba 2 avaliações 5 estrelas" },
	{ Id = "perfect2", Kind = "Perfect", Target = 2, Coins = 240, Reputation = 3, Text = "Faça 2 reparos com qualidade 90% ou mais" },
	{ Id = "firsttry3", Kind = "FirstTry", Target = 3, Coins = 200, Reputation = 2, Text = "Acerte 3 diagnósticos de primeira" },
	{ Id = "vip1", Kind = "Vip", Target = 1, Coins = 300, Reputation = 3, Text = "Atenda 1 cliente VIP" },
	{ Id = "tires2", Kind = "Spec", Param = "Tires", Target = 2, Coins = 180, Reputation = 2, Text = "Conserte 2 problemas de pneu" },
	{ Id = "engine2", Kind = "Spec", Param = "Engine", Target = 2, Coins = 220, Reputation = 2, Text = "Conserte 2 problemas de motor" },
	{ Id = "electric2", Kind = "Spec", Param = "Electrical", Target = 2, Coins = 220, Reputation = 2, Text = "Conserte 2 problemas elétricos" },
	{ Id = "body2", Kind = "Spec", Param = "Bodywork", Target = 2, Coins = 200, Reputation = 2, Text = "Conserte 2 problemas de funilaria" },
	{ Id = "susp2", Kind = "Spec", Param = "Suspension", Target = 2, Coins = 200, Reputation = 2, Text = "Conserte 2 problemas de suspensão" },
	{ Id = "rush2", Kind = "Rush", Target = 2, Coins = 260, Reputation = 3, Text = "Conserte 2 carros na Hora do Rush" },
} :: { MissionDef }

local function byId(): { [string]: MissionDef }
	local map = {}
	for _, m in ipairs(ProgressRules.MissionPool) do
		map[m.Id] = m
	end
	return map
end
ProgressRules.MissionById = byId()

-- Sorteio estável: 3 missões diferentes para (jogador, dia), nunca duas do mesmo tipo de evento.
function ProgressRules.DailyMissions(userId: number, day: number): { string }
	local rng = Random.new((userId % 1000003) * 7919 + day * 104729)
	local pool = table.clone(ProgressRules.MissionPool)
	local chosen, kinds = {}, {}
	while #chosen < 3 and #pool > 0 do
		local i = rng:NextInteger(1, #pool)
		local m = table.remove(pool, i)
		if not kinds[m.Kind] then
			kinds[m.Kind] = true
			table.insert(chosen, m.Id)
		end
	end
	return chosen
end

-- Quanto um evento soma numa missão. event: { Kind, Amount?, Spec?, Quality?, Stars?, Vip?, FirstTry?, Rush? }
function ProgressRules.Contribution(def: MissionDef, event: { [string]: any }): number
	if event.Kind ~= "RepairDone" then
		return 0
	end
	if def.Kind == "Repair" then
		return 1
	elseif def.Kind == "Earn" then
		return math.max(0, math.floor(tonumber(event.Amount) or 0))
	elseif def.Kind == "FiveStars" then
		return event.Stars == 5 and 1 or 0
	elseif def.Kind == "Perfect" then
		return (tonumber(event.Quality) or 0) >= 90 and 1 or 0
	elseif def.Kind == "FirstTry" then
		return event.FirstTry == true and 1 or 0
	elseif def.Kind == "Vip" then
		return event.Vip == true and 1 or 0
	elseif def.Kind == "Spec" then
		return event.Spec == def.Param and 1 or 0
	elseif def.Kind == "Rush" then
		return event.Rush == true and 1 or 0
	end
	return 0
end

-- Conquistas ----------------------------------------------------------------------------------------------------
export type AchievementDef = { Id: string, Stat: string, Target: number, Coins: number, Title: string }

ProgressRules.Achievements = {
	{ Id = "cli1", Stat = "Repairs", Target = 1, Coins = 50, Title = "Primeiro cliente" },
	{ Id = "cli10", Stat = "Repairs", Target = 10, Coins = 200, Title = "Mecânico do bairro" },
	{ Id = "cli50", Stat = "Repairs", Target = 50, Coins = 800, Title = "Mão na graxa" },
	{ Id = "cli200", Stat = "Repairs", Target = 200, Coins = 3000, Title = "Lenda da oficina" },
	{ Id = "earn5k", Stat = "Earned", Target = 5000, Coins = 300, Title = "Primeiros 5 mil" },
	{ Id = "earn50k", Stat = "Earned", Target = 50000, Coins = 2500, Title = "Empresário" },
	{ Id = "vip1", Stat = "Vip", Target = 1, Coins = 150, Title = "Atendimento VIP" },
	{ Id = "vip15", Stat = "Vip", Target = 15, Coins = 1200, Title = "Oficina dos famosos" },
	{ Id = "perf10", Stat = "Perfect", Target = 10, Coins = 600, Title = "Perfeccionista" },
	{ Id = "first20", Stat = "FirstTry", Target = 20, Coins = 600, Title = "Olho clínico" },
	{ Id = "lvl1", Stat = "Level", Target = 1, Coins = 300, Title = "Oficina de verdade" },
	{ Id = "lvl2", Stat = "Level", Target = 2, Coins = 1000, Title = "Centro automotivo" },
	{ Id = "lvl3", Stat = "Level", Target = 3, Coins = 4000, Title = "Rei do bairro" },
	{ Id = "streak7", Stat = "Streak", Target = 7, Coins = 500, Title = "Uma semana seguida" },
} :: { AchievementDef }

-- Conquistas recém-alcançadas (stats atuais, já ganhas).
function ProgressRules.NewAchievements(stats: { [string]: number }, owned: { [string]: boolean }): { AchievementDef }
	local list = {}
	for _, a in ipairs(ProgressRules.Achievements) do
		if not owned[a.Id] and (stats[a.Stat] or 0) >= a.Target then
			table.insert(list, a)
		end
	end
	return list
end

-- Códigos promocionais: a LISTA fica só no servidor (src/server/PromoCodes.lua), para ninguém ler antes do anúncio.
function ProgressRules.NormalizeCode(text: any): string?
	if type(text) ~= "string" or #text > 24 then
		return nil
	end
	local clean = string.upper((string.gsub(text, "%s", "")))
	if not string.match(clean, "^[%w_]+$") then
		return nil
	end
	return clean
end

return ProgressRules
