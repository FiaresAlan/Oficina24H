--!strict
-- ProgressService: recompensa diária, missões do dia, conquistas, códigos e a HORA DO RUSH (evento do servidor).
-- Regras puras em shared/ProgressRules; aqui só estado do perfil, validação e recompensas. Tudo decidido no servidor.
--   * Hora do Rush: a cada Config.RushEverySeconds, por Config.RushSeconds, chegam clientes em dobro e todo serviço
--     paga +50%. Avisa todo mundo antes e durante (motivo para voltar e ficar).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ProgressRules = require(ReplicatedStorage.Shared.ProgressRules)
local PromoCodes = require(script.Parent.PromoCodes)

local ProgressService = {}

local DataService: any = nil
local notify: ((Player, string, boolean) -> ())? = nil
local broadcast: ((string, any) -> ())? = nil

function ProgressService.Init(dataService: any, notifier: (Player, string, boolean) -> (), broadcaster: (string, any) -> ())
	DataService = dataService
	notify = notifier
	broadcast = broadcaster
end

local function give(player: Player, coins: number, parts: { [string]: number }?, reason: string)
	if coins > 0 then
		DataService.AddCoins(player, coins, reason)
	end
	for partId, n in pairs(parts or {}) do
		if Catalog.Parts[partId] then
			DataService.AddParts(player, partId, n)
		end
	end
end

-- Missões do dia: garante a lista de hoje no perfil.
local function ensureMissions(player: Player, profile: any): any
	local today = ProgressRules.Day(os.time())
	if profile.Missions.Day ~= today then
		local list = {}
		for _, id in ipairs(ProgressRules.DailyMissions(player.UserId, today)) do
			table.insert(list, { Id = id, Progress = 0, Claimed = false })
		end
		profile.Missions = { Day = today, List = list }
		DataService.MarkDirty(player)
	end
	return profile.Missions
end

local function stats(profile: any): { [string]: number }
	return {
		Repairs = math.max(profile.Stats.Repairs or 0, profile.RatingCount or 0),
		Earned = profile.TotalEarned or 0,
		Vip = profile.Stats.Vip or 0,
		Perfect = profile.Stats.Perfect or 0,
		FirstTry = profile.Stats.FirstTry or 0,
		Level = profile.WorkshopLevel or 0,
		Streak = profile.Daily.Streak or 0,
	}
end

-- Confere conquistas novas e paga na hora (com aviso).
local function checkAchievements(player: Player, profile: any)
	for _, a in ipairs(ProgressRules.NewAchievements(stats(profile), profile.Achievements)) do
		profile.Achievements[a.Id] = true
		give(player, a.Coins, nil, "Conquista: " .. a.Title)
		if notify then
			notify(player, string.format("🏆 Conquista: %s! +%d moedas", a.Title, a.Coins), true)
		end
	end
	DataService.MarkDirty(player)
end

-- Evento de jogo (chamado pelo WorkshopService ao concluir um reparo do próprio jogador).
-- event = { Kind = "RepairDone", Amount, Spec, Quality, Stars, Vip, FirstTry, Rush }
function ProgressService.Record(player: Player, event: { [string]: any })
	local profile = DataService and DataService.Get(player)
	if not profile then
		return
	end
	if event.Kind == "RepairDone" then
		profile.Stats.Repairs += 1
		if event.Vip then
			profile.Stats.Vip += 1
		end
		if (tonumber(event.Quality) or 0) >= 90 then
			profile.Stats.Perfect += 1
		end
		if event.FirstTry then
			profile.Stats.FirstTry += 1
		end
	end
	local missions = ensureMissions(player, profile)
	for _, m in ipairs(missions.List) do
		local def = ProgressRules.MissionById[m.Id]
		if def and not m.Claimed and m.Progress < def.Target then
			local add = ProgressRules.Contribution(def, event)
			if add > 0 then
				m.Progress = math.min(def.Target, m.Progress + add)
				if m.Progress >= def.Target and notify then
					notify(player, "✅ Missão completa: " .. def.Text .. " — resgate em Metas!", true)
				end
			end
		end
	end
	DataService.MarkDirty(player)
	checkAchievements(player, profile)
end

function ProgressService.ClaimDaily(player: Player): (boolean, string)
	local profile = DataService.Get(player)
	if not profile then
		return false, "Seus dados ainda estão carregando."
	end
	local today = ProgressRules.Day(os.time())
	local can, day = ProgressRules.DailyState(profile.Daily.LastDay, profile.Daily.Streak, today)
	if not can then
		return false, "Você já pegou a recompensa de hoje. Volte amanhã!"
	end
	local reward = ProgressRules.DailyRewards[day]
	local continuing = profile.Daily.LastDay == today - 1
	profile.Daily = { LastDay = today, Streak = continuing and (profile.Daily.Streak + 1) or 1 }
	give(player, reward.Coins, reward.Parts, "Recompensa diária (dia " .. day .. ")")
	checkAchievements(player, profile)
	return true, string.format("Recompensa do dia %d: +%d moedas%s", day, reward.Coins, reward.Parts and " e peças" or "")
end

function ProgressService.ClaimMission(player: Player, missionId: string): (boolean, string)
	local profile = DataService.Get(player)
	if not profile or type(missionId) ~= "string" then
		return false, "Missão inválida."
	end
	local missions = ensureMissions(player, profile)
	for _, m in ipairs(missions.List) do
		if m.Id == missionId then
			local def = ProgressRules.MissionById[m.Id]
			if m.Claimed then
				return false, "Recompensa já resgatada."
			end
			if not def or m.Progress < def.Target then
				return false, "Missão ainda não concluída."
			end
			m.Claimed = true
			give(player, def.Coins, nil, "Missão: " .. def.Text)
			DataService.AddReputation(player, def.Reputation)
			DataService.MarkDirty(player)
			return true, string.format("Missão concluída: +%d moedas e +%d de reputação", def.Coins, def.Reputation)
		end
	end
	return false, "Missão inválida."
end

function ProgressService.RedeemCode(player: Player, text: any): (boolean, string)
	local profile = DataService.Get(player)
	local code = ProgressRules.NormalizeCode(text)
	if not profile or not code then
		return false, "Código inválido."
	end
	local def = PromoCodes[code]
	if not def or (def.Expires and os.time() > def.Expires) or (def.StartsAt and os.time() < def.StartsAt) then
		return false, "Código inválido ou expirado."
	end
	if profile.Codes[code] then
		return false, "Você já usou este código."
	end
	profile.Codes[code] = true
	give(player, def.Coins, def.Parts, "Código " .. code)
	DataService.MarkDirty(player)
	return true, def.Text .. string.format(" +%d moedas", def.Coins)
end

-- Hora do Rush ---------------------------------------------------------------------------------------------------
local rushUntil = 0
local nextRushAt = os.time() + Config.RushFirstDelaySeconds

function ProgressService.IsRush(): boolean
	return os.time() < rushUntil
end

function ProgressService.RushInfo(): { Active: boolean, EndsIn: number, StartsIn: number }
	local now = os.time()
	return { Active = now < rushUntil, EndsIn = math.max(0, rushUntil - now), StartsIn = math.max(0, nextRushAt - now) }
end

-- Estado para a interface (vai no snapshot).
function ProgressService.Snapshot(player: Player, profile: any): any
	local missions = ensureMissions(player, profile)
	local can, day = ProgressRules.DailyState(profile.Daily.LastDay, profile.Daily.Streak, ProgressRules.Day(os.time()))
	local list = {}
	for _, m in ipairs(missions.List) do
		local def = ProgressRules.MissionById[m.Id]
		if def then
			table.insert(list, { Id = m.Id, Text = def.Text, Progress = m.Progress, Target = def.Target, Coins = def.Coins, Reputation = def.Reputation, Claimed = m.Claimed })
		end
	end
	local owned = 0
	for _ in pairs(profile.Achievements) do
		owned += 1
	end
	local nextAch: any = nil
	local st = stats(profile)
	for _, a in ipairs(ProgressRules.Achievements) do
		if not profile.Achievements[a.Id] then
			nextAch = { Title = a.Title, Have = math.min(st[a.Stat] or 0, a.Target), Need = a.Target, Coins = a.Coins }
			break
		end
	end
	return {
		Daily = { CanClaim = can, Day = day, Streak = profile.Daily.Streak, Rewards = ProgressRules.DailyRewards },
		Missions = list,
		Achievements = { Owned = owned, Total = #ProgressRules.Achievements, Next = nextAch },
		Rush = ProgressService.RushInfo(),
	}
end

function ProgressService.Start()
	-- conquistas que o jogador já merece ao entrar (perfis antigos)
	Players.PlayerAdded:Connect(function(player)
		task.delay(8, function()
			local profile = DataService.Get(player)
			if profile and player.Parent then
				ensureMissions(player, profile)
				checkAchievements(player, profile)
			end
		end)
	end)
	task.spawn(function()
		local warned = false
		while true do
			task.wait(1)
			local now = os.time()
			if not warned and now >= nextRushAt - 30 and now < nextRushAt then
				warned = true
				if broadcast then
					broadcast("Notice", { Message = "⏰ A HORA DO RUSH começa em 30 segundos! Clientes em dobro e pagando +50%.", Success = true })
				end
			end
			if now >= nextRushAt then
				rushUntil = now + Config.RushSeconds
				nextRushAt = now + Config.RushEverySeconds
				warned = false
				if broadcast then
					broadcast("Rush", { Active = true, EndsIn = Config.RushSeconds })
					broadcast("Notice", { Message = "🔥 HORA DO RUSH! Por 3 minutos: clientes em dobro e serviços pagando +50%!", Success = true })
				end
			end
		end
	end)
end

return ProgressService
