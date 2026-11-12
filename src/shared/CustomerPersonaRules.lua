--!strict
-- Arquétipos de clientes com decisões de mercado e avaliação próprias.
-- Um perfil muda o tempo disponível e o que é considerado bom atendimento.
-- Não contém identificadores pessoais nem dados persistentes.
local CustomerPersonaRules = {}

local personas = {
	Standard = {
		Label = "Cliente comum", Hint = "Quer um conserto confiável.",
		Weight = 30, Patience = 1.0, PriceSensitivity = 2.0, Pay = 1.0,
	},
	Urgent = {
		Label = "Com pressa", Hint = "Precisa sair logo: a demora custa avaliação.",
		Weight = 20, Patience = 0.7, PriceSensitivity = 1.35, Pay = 1.12,
	},
	Budget = {
		Label = "Econômico", Hint = "Compara preços e prefere uma solução justa.",
		Weight = 20, Patience = 1.2, PriceSensitivity = 2.9, Pay = 0.96,
	},
	Demanding = {
		Label = "Exigente", Hint = "Valoriza diagnóstico e acabamento muito bem feitos.",
		Weight = 20, Patience = 1.05, PriceSensitivity = 1.45, Pay = 1.08,
	},
	Friendly = {
		Label = "Freguês tranquilo", Hint = "Aceita esperar mais por um bom atendimento.",
		Weight = 10, Patience = 1.4, PriceSensitivity = 1.9, Pay = 1.0,
	},
}
CustomerPersonaRules.Catalog = personas
local ordered = { "Standard", "Urgent", "Budget", "Demanding", "Friendly" }
CustomerPersonaRules.Order = ordered

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function CustomerPersonaRules.Get(id: any): any
	return type(id) == "string" and personas[id] or personas.Standard
end

function CustomerPersonaRules.Pick(rand: () -> number): string
	local roll = rand()
	if not finite(roll) then roll = 0 end
	roll = math.clamp(roll, 0, 0.999999)
	local total = 0
	for _, id in ipairs(ordered) do
		total += personas[id].Weight
	end
	local ticket = roll * total
	for _, id in ipairs(ordered) do
		ticket -= personas[id].Weight
		if ticket < 0 then return id end
	end
	return "Standard"
end

function CustomerPersonaRules.Patience(base: number, id: any): number
	if not finite(base) or base <= 0 then return 0 end
	return math.max(1, math.floor(base * CustomerPersonaRules.Get(id).Patience + 0.5))
end

function CustomerPersonaRules.PayMultiplier(id: any): number
	return CustomerPersonaRules.Get(id).Pay
end

function CustomerPersonaRules.PriceSensitivity(id: any): number
	return CustomerPersonaRules.Get(id).PriceSensitivity
end

function CustomerPersonaRules.RatingAdjustment(id: any, ctx: any): number
	if type(ctx) ~= "table" then return 0 end
	local wait = finite(ctx.WaitSeconds) and math.max(0, ctx.WaitSeconds) or 0
	local patience = finite(ctx.PatienceSeconds) and math.max(1, ctx.PatienceSeconds) or 300
	local fraction = wait / patience
	local price = finite(ctx.PriceMultiplier) and ctx.PriceMultiplier or 1
	local quality = finite(ctx.Quality) and ctx.Quality or nil
	if id == "Urgent" then
		return fraction >= 0.6 and -0.75 or (fraction < 0.2 and 0.3 or 0)
	elseif id == "Budget" then
		return price > 1.2 and -0.5 or (price <= 0.9 and 0.3 or 0)
	elseif id == "Demanding" then
		if quality then
			return quality >= 90 and 0.4 or (quality < 70 and -0.8 or 0)
		end
		return 0 -- sem minijogo real (funcionário): não aplicar punição invisível
	elseif id == "Friendly" then
		return quality and quality >= 70 and 0.15 or 0
	end
	return 0
end

return CustomerPersonaRules
