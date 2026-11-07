--!strict
-- ContractService: CONTRATOS DE FROTA (regras puras em shared/ContractRules).
-- A cada Config.ContractEverySeconds uma empresa do bairro oferece um contrato à oficina do jogador (depois do guia).
-- Enquanto vale, parte dos clientes que chegam são carros da frota (WorkshopService.createJob pergunta WantsFleet).
-- Cada carro da frota concluído (por qualquer caminho: jogador, colaborador, funcionário) conta 1. Bateu a meta: paga
-- moedas + reputação e o servidor inteiro fica sabendo. O tempo acabou: um rival "pega" o contrato (sem multa).
-- Estado só da sessão (não vai para o DataStore): sair e voltar começa o relógio de novo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ContractRules = require(ReplicatedStorage.Shared.ContractRules)

local ProgressService = require(script.Parent.ProgressService)
local ProgressRules = require(ReplicatedStorage.Shared.ProgressRules)

local ContractService = {}

type Contract = {
	Token: number,
	Offer: ContractRules.Offer,
	Done: number,
	EndsAt: number,
}

local DataService: any = nil
local notify: ((Player, string, boolean) -> ())? = nil
local broadcast: ((string, any) -> ())? = nil
local rivalName: (() -> string?)? = nil
local offerFor: ((Player) -> ContractRules.Offer?)? = nil -- WorkshopService monta a oferta (nível e áreas atendidas)

local contracts: { [number]: Contract } = {}
local nextAt: { [number]: number } = {}
local lastResult: { [number]: { Text: string, Success: boolean, At: number } } = {}
local tokens = 0

function ContractService.Init(dataService: any, notifier: (Player, string, boolean) -> (), broadcaster: (string, any) -> (), rivalNameFn: () -> string?)
	DataService = dataService
	notify = notifier
	broadcast = broadcaster
	rivalName = rivalNameFn
end

function ContractService.SetOfferBuilder(fn: (Player) -> ContractRules.Offer?)
	offerFor = fn
end

function ContractService.Active(userId: number): Contract?
	local c = contracts[userId]
	if c and os.time() < c.EndsAt and c.Done < c.Offer.Target then
		return c
	end
	return nil
end

-- O próximo cliente desta oficina deve ser um carro da frota? `inFlight` = carros da frota deste contrato ainda abertos.
-- Retorna o contrato (token + área) ou nil.
function ContractService.WantsFleet(userId: number, inFlight: number, roll: number): Contract?
	local c = ContractService.Active(userId)
	if c and ContractRules.NeedsFleet(c.Done, inFlight, c.Offer.Target) and roll < ContractRules.FleetChance then
		return c
	end
	return nil
end

local function finish(player: Player, c: Contract)
	contracts[player.UserId] = nil
	nextAt[player.UserId] = os.time() + Config.ContractEverySeconds
	DataService.AddCoins(player, c.Offer.Coins, "Contrato de frota: " .. c.Offer.Name)
	DataService.AddReputation(player, c.Offer.Reputation)
	ProgressService.AddLeague(player, ProgressRules.LeagueContractPoints)
	DataService.MarkDirty(player)
	local text = string.format("📋 Contrato cumprido: %s! +%d moedas e +%d de reputação.", c.Offer.Name, c.Offer.Coins, c.Offer.Reputation)
	lastResult[player.UserId] = { Text = text, Success = true, At = os.time() }
	if notify then
		notify(player, text, true)
	end
	if broadcast then
		broadcast("Notice", { Message = string.format("🏁 A oficina de %s cumpriu o contrato da %s!", player.DisplayName, c.Offer.Name), Success = true })
	end
end

local function fail(player: Player, c: Contract)
	contracts[player.UserId] = nil
	nextAt[player.UserId] = os.time() + Config.ContractEverySeconds
	local rival = rivalName and rivalName() or nil
	local text = string.format("⌛ O contrato da %s acabou (%d/%d).%s Próximo em %d min.", c.Offer.Name, c.Done, c.Offer.Target,
		rival and (" A " .. rival .. " ficou com ele.") or "", math.floor(Config.ContractEverySeconds / 60))
	lastResult[player.UserId] = { Text = text, Success = false, At = os.time() }
	if notify then
		notify(player, text, false)
	end
end

-- Um carro da frota foi concluído na oficina de `owner` (chamado pelo WorkshopService ao avaliar o serviço).
function ContractService.FleetDone(owner: Player, token: any)
	local c = contracts[owner.UserId]
	if not c or c.Token ~= token or os.time() >= c.EndsAt then
		return
	end
	c.Done += 1
	if c.Done >= c.Offer.Target then
		finish(owner, c)
	elseif notify then
		notify(owner, string.format("📋 %s: %d/%d carros da frota prontos.", c.Offer.Name, c.Done, c.Offer.Target), true)
	end
end

function ContractService.Offer(player: Player): boolean
	if contracts[player.UserId] or not offerFor then
		return false
	end
	local offer = offerFor(player)
	if not offer then
		nextAt[player.UserId] = os.time() + 60 -- ainda não atende nenhuma área: tenta de novo daqui a pouco
		return false
	end
	tokens += 1
	contracts[player.UserId] = { Token = tokens, Offer = offer, Done = 0, EndsAt = os.time() + offer.Seconds }
	if notify then
		notify(player, string.format("📋 NOVO CONTRATO — %s. Prêmio: %d moedas + %d de reputação. Os carros da frota já estão vindo!",
			ContractRules.Text(offer), offer.Coins, offer.Reputation), true)
	end
	return true
end

-- Para a interface (vai no snapshot do jogador).
function ContractService.Snapshot(userId: number): any
	local now = os.time()
	local c = ContractService.Active(userId)
	local result = lastResult[userId]
	if result and now - result.At > 20 then
		result = nil
	end
	if c then
		return {
			Active = true, Name = c.Offer.Name, Text = ContractRules.Text(c.Offer), Spec = c.Offer.Spec, Unit = c.Offer.Unit,
			Done = c.Done, Target = c.Offer.Target, EndsIn = math.max(0, c.EndsAt - now), Coins = c.Offer.Coins, Reputation = c.Offer.Reputation,
		}
	end
	return { Active = false, NextIn = nextAt[userId] and math.max(0, nextAt[userId] - now) or nil, Result = result }
end

-- Só para QA no Studio: traz o próximo contrato para agora.
function ContractService.QaOfferNow(player: Player): boolean
	contracts[player.UserId] = nil
	return ContractService.Offer(player)
end

function ContractService.Start()
	Players.PlayerRemoving:Connect(function(player)
		contracts[player.UserId] = nil
		nextAt[player.UserId] = nil
		lastResult[player.UserId] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for _, player in ipairs(Players:GetPlayers()) do
				local id = player.UserId
				local profile = DataService and DataService.Get(player)
				if not profile then
					continue
				end
				local c = contracts[id]
				if c then
					if now >= c.EndsAt and c.Done < c.Offer.Target then
						fail(player, c)
					end
				elseif profile.Onboarding and profile.Onboarding.Done then
					if not nextAt[id] then
						nextAt[id] = now + Config.ContractFirstDelaySeconds
					elseif now >= nextAt[id] then
						ContractService.Offer(player)
					end
				end
			end
		end
	end)
end

return ContractService
