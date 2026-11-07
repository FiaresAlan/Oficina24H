--!strict
-- ContractRules: regras puras dos CONTRATOS DE FROTA (sem estado; testável).
-- Uma empresa do bairro oferece um contrato: "Táxi Veloz: 3 reparos de pneu em 8 min". Enquanto o contrato vale,
-- parte dos clientes que chegam são carros da frota com defeito daquela área. Cumprir paga bem (moedas + reputação);
-- se o tempo acaba, um rival "pega" o contrato (só aviso, sem multa: o jogo motiva, não pune).
local ContractRules = {}

ContractRules.Companies = {
	{ Id = "taxi", Name = "Táxi Veloz", Spec = "Tires", Unit = "reparos de pneu" },
	{ Id = "delivery", Name = "Entregas Já", Spec = "Engine", Unit = "reparos de motor" },
	{ Id = "eletro", Name = "Frota Luz Elétrica", Spec = "Electrical", Unit = "reparos elétricos" },
	{ Id = "rent", Name = "Locadora do Bairro", Spec = "Bodywork", Unit = "reparos de funilaria" },
	{ Id = "serra", Name = "Transportes Serra", Spec = "Suspension", Unit = "reparos de suspensão" },
}

ContractRules.ById = {}
for _, c in ipairs(ContractRules.Companies) do
	ContractRules.ById[c.Id] = c
end

ContractRules.FleetChance = 0.6 -- parte das chegadas que vira carro da frota enquanto falta carro para o contrato

export type Offer = { Company: string, Name: string, Spec: string, Unit: string, Target: number, Seconds: number, Coins: number, Reputation: number }

-- Tamanho e prêmio pelo nível do prédio (0..3): mais boxes = contrato maior e mais valioso.
function ContractRules.Terms(level: number): (number, number, number, number)
	local l = math.clamp(math.floor(level), 0, 3)
	local target = 2 + l
	local seconds = 300 + target * 90 -- 2 carros = 8 min; 5 carros = 12,5 min
	local coins = target * (120 + 50 * l) -- 240 / 510 / 880 / 1350
	local reputation = 3 + 2 * l
	return target, seconds, coins, reputation
end

-- Oferta para uma oficina: `specs` = áreas que ela já atende (ver JobRules.ServiceableCountIn); `rand` = math.random.
function ContractRules.Offer(level: number, specs: { string }, rand: (number?, number?) -> number): Offer?
	local options = {}
	for _, c in ipairs(ContractRules.Companies) do
		if table.find(specs, c.Spec) then
			table.insert(options, c)
		end
	end
	if #options == 0 then
		return nil
	end
	local c = options[rand(1, #options)]
	local target, seconds, coins, reputation = ContractRules.Terms(level)
	return { Company = c.Id, Name = c.Name, Spec = c.Spec, Unit = c.Unit, Target = target, Seconds = seconds, Coins = coins, Reputation = reputation }
end

function ContractRules.Text(offer: { Name: string, Target: number, Unit: string, Seconds: number }): string
	return string.format("%s: %d %s em %d min", offer.Name, offer.Target, offer.Unit, math.ceil(offer.Seconds / 60))
end

-- Precisa de mais carros da frota? (feitos + em aberto ainda não bastam para a meta)
function ContractRules.NeedsFleet(done: number, inFlight: number, target: number): boolean
	return done + inFlight < target
end

return ContractRules
