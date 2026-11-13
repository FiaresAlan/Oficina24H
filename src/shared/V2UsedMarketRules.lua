--!strict
-- V2-09: mercado de usados de baixa escala. Regras puras: o cliente nunca dita valores,
-- condições, identidade de oferta, preço de venda ou consumo de peças.
-- Carro de revenda NÃO ocupa as vagas das OS de clientes.
local Catalog = require(script.Parent.Catalog)

local Rules = {}
Rules.MaxOwned = 1
Rules.MinServiceCount = 3
Rules.CooldownSeconds = 600
Rules.MaxSales = 100000
Rules.StyleCost = 40
Rules.StyleBonus = 30 -- cosmético deliberadamente NÃO cria lucro automático

Rules.Order = { "Hatch", "Sedan", "Pickup" }
Rules.Offers = {
    Hatch = {
        Name = "Hatch de leilão", VehicleName = "Hatch amarelo", BuyPrice = 260,
        RepairFee = 35, Parts = { TirePatch = 1 }, SalePrice = 370,
        ScrapPrice = 180, RiskMax = 20,
    },
    Sedan = {
        Name = "Sedã sinistrado", VehicleName = "Sedã azul", BuyPrice = 500,
        RepairFee = 85, Parts = { Battery = 1, SparkPlug = 2 }, SalePrice = 730,
        ScrapPrice = 360, RiskMax = 40,
    },
    Pickup = {
        Name = "Picape de frota", VehicleName = "Picape antiga", BuyPrice = 800,
        RepairFee = 130, Parts = { BrakePad = 2, SuspensionKit = 1 }, SalePrice = 1090,
        ScrapPrice = 600, RiskMax = 70,
    },
}

local function finite(value: any): boolean
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end
local function integer(value: any, lower: number, upper: number): number
    return finite(value) and math.floor(math.clamp(value, lower, upper)) or lower
end
local function refCost(offer: any): number
    local cost = 0
    for partId, amount in pairs(offer.Parts) do
        cost += Catalog.Parts[partId].Cost * amount
    end
    return cost
end

function Rules.New(): any
    return { Owned = {}, NextBuyAt = 0, TotalSales = 0, TotalContribution = 0 }
end

-- Não aceitar carros, custos, id ou stage inventados em dados corrompidos.
-- Carro adicionado pelo servidor tem UID não reutilizável e uma oferta do catálogo.
function Rules.Sanitize(raw: any): any
    local state = Rules.New()
    if type(raw) ~= "table" then return state end
    state.NextBuyAt = integer(raw.NextBuyAt, 0, 4102444800)
    state.TotalSales = integer(raw.TotalSales, 0, Rules.MaxSales)
    state.TotalContribution = integer(raw.TotalContribution, -100000000, 100000000)
    local owned = type(raw.Owned) == "table" and raw.Owned or {}
    local seen = {}
    for _, item in ipairs(owned) do
        if #state.Owned >= Rules.MaxOwned then break end
        if type(item) == "table" and type(item.Uid) == "string"
            and #item.Uid >= 12 and #item.Uid <= 64 and not seen[item.Uid]
            and type(item.Variant) == "string" and Rules.Offers[item.Variant] then
            local offer = Rules.Offers[item.Variant]
            local stage = ({ Purchased = true, Inspected = true, Stripped = true, Restored = true })[item.Stage]
                and item.Stage or "Purchased"
            local style = (stage == "Restored" and
                (item.Style == "Blue" or item.Style == "Red")) and item.Style or "Factory"
            local risk = integer(item.RiskFee, 0, offer.RiskMax)
            table.insert(state.Owned, {
                Uid = item.Uid, Variant = item.Variant, Stage = stage,
                Style = style, RiskFee = risk,
                PurchasedAt = integer(item.PurchasedAt, 0, 4102444800),
            })
            seen[item.Uid] = true
        end
    end
    return state
end

function Rules.CanBuy(profile: any, now: number): (boolean, string)
    if type(profile) ~= "table" then return false, "Perfil indisponível." end
    local market = Rules.Sanitize(profile.UsedMarket)
    if integer(profile.WorkshopLevel, 0, 3) < 1 then
        return false, "Amplie a oficina para o nível 1 antes de negociar usados."
    end
    if #(type(profile.OrderHistory) == "table" and profile.OrderHistory or {}) < Rules.MinServiceCount then
        return false, "Conclua 3 ordens de clientes antes de acessar o mercado."
    end
    if #market.Owned >= Rules.MaxOwned then
        return false, "Você já tem um carro para restaurar; ele não ocupa um box de cliente."
    end
    if now < market.NextBuyAt then
        return false, "Mercado em intervalo: aguarde a próxima oportunidade."
    end
    if market.TotalSales >= Rules.MaxSales then return false, "Limite de operações atingido." end
    return true, ""
end

function Rules.Public(profile: any, now: number): any
    local state = Rules.Sanitize(profile and profile.UsedMarket)
    local allowed, why = Rules.CanBuy(profile, now)
    local offers = {}
    for _, id in ipairs(Rules.Order) do
        local offer = Rules.Offers[id]
        local partsCost = refCost(offer)
        table.insert(offers, {
            Id = id, Name = offer.Name,
            VehicleName = offer.VehicleName,
            VehicleModel = Catalog.VehicleModels[offer.VehicleName],
            BuyPrice = offer.BuyPrice, RepairFee = offer.RepairFee,
            Parts = table.clone(offer.Parts), PartsReferenceCost = partsCost,
            RiskMax = offer.RiskMax, SalePrice = offer.SalePrice,
            EstimatedContributionMin = offer.SalePrice - offer.BuyPrice
                - offer.RepairFee - offer.RiskMax - partsCost,
            EstimatedContributionMax = offer.SalePrice - offer.BuyPrice
                - offer.RepairFee - partsCost,
        })
    end
    local owned = {}
    for _, car in ipairs(state.Owned) do
        local offer = Rules.Offers[car.Variant]
        table.insert(owned, {
            Uid = car.Uid, Variant = car.Variant, Stage = car.Stage,
            Style = car.Style, Name = offer.Name, VehicleName = offer.VehicleName,
            VehicleModel = Catalog.VehicleModels[offer.VehicleName],
            RepairFee = offer.RepairFee + car.RiskFee,
            RiskFee = car.RiskFee, Parts = table.clone(offer.Parts),
            PartsReferenceCost = refCost(offer),
            SellPrice = car.Stage == "Restored" and
                (offer.SalePrice + (car.Style ~= "Factory" and Rules.StyleBonus or 0))
                or offer.ScrapPrice,
        })
    end
    return {
        CanBuy = allowed, BlockedReason = why,
        NextBuyAt = state.NextBuyAt, TotalSales = state.TotalSales,
        TotalContribution = state.TotalContribution, Capacity = Rules.MaxOwned,
        MinServices = Rules.MinServiceCount, StyleCost = Rules.StyleCost,
        Offers = offers, Owned = owned,
    }
end

-- Planeja a transação inteira sem mutar perfil. Aplicação no DataService
-- é síncrona/no-yield, com crédito/débito e estado no MESMO perfil persistido.
-- input: oferta em Buy, UID nas ações do carro, style apenas Blue/Red.
function Rules.Plan(profile: any, operation: any, input: any, now: number,
    freshUid: any?, chosenRisk: any?): (any?, string)
    if type(profile) ~= "table" or not finite(profile.Coins) or profile.Coins < 0 then
        return nil, "Perfil inválido."
    end
    if type(operation) ~= "string" or type(input) ~= "string" then
        return nil, "Ação inválida."
    end
    local market = Rules.Sanitize(profile.UsedMarket)
    local function result(delta: number, reason: string, parts: any?, message: string): any
        return { Market = market, Delta = delta, Reason = reason,
            Parts = parts, Message = message }
    end
    if operation == "Buy" then
        local permitted, why = Rules.CanBuy(profile, now)
        if not permitted then return nil, why end
        local offer = Rules.Offers[input]
        if not offer then return nil, "Veículo indisponível." end
        if profile.Coins < offer.BuyPrice then return nil, "Saldo insuficiente." end
        if type(freshUid) ~= "string" or #freshUid < 12 or #freshUid > 64
            or not finite(chosenRisk) or chosenRisk % 1 ~= 0
            or chosenRisk < 0 or chosenRisk > offer.RiskMax then
            return nil, "Proposta inválida."
        end
        table.insert(market.Owned, {
            Uid = freshUid, Variant = input, Stage = "Purchased",
            Style = "Factory", RiskFee = chosenRisk, PurchasedAt = now,
        })
        return result(-offer.BuyPrice, "Usados: compra de " .. offer.Name,
            nil, "Carro comprado. Avalie, desmonte e restaure antes da venda.")
    end
    local car = market.Owned[1]
    if not car or car.Uid ~= input then return nil, "Esse veículo não está na sua coleção." end
    local offer = Rules.Offers[car.Variant]
    if operation == "Inspect" and car.Stage == "Purchased" then
        car.Stage = "Inspected"
        return result(0, "", nil, "Inspeção concluída. Prepare a desmontagem.")
    elseif operation == "Strip" and car.Stage == "Inspected" then
        car.Stage = "Stripped"
        return result(0, "", nil, "Peça avariada removida. Substitua com estoque e serviço.")
    elseif operation == "Restore" and car.Stage == "Stripped" then
        local due = offer.RepairFee + car.RiskFee
        if profile.Coins < due then return nil, "Saldo insuficiente para a restauração." end
        local stock = type(profile.Parts) == "table" and profile.Parts or {}
        for partId, qty in pairs(offer.Parts) do
            if not finite(stock[partId]) or stock[partId] < qty then
                return nil, "Peças insuficientes. Reponha na loja física."
            end
        end
        car.Stage = "Restored"
        return result(-due, "Usados: restauração de " .. offer.Name,
            table.clone(offer.Parts), "Restauração concluída; revisão visual disponível.")
    elseif operation == "Paint" and car.Stage == "Restored" and car.Style == "Factory" then
        if chosenRisk ~= "Blue" and chosenRisk ~= "Red" then
            return nil, "Escolha uma pintura disponível."
        end
        if profile.Coins < Rules.StyleCost then return nil, "Saldo insuficiente." end
        car.Style = chosenRisk
        return result(-Rules.StyleCost, "Usados: pintura",
            nil, "Pintura aplicada. Personalização não garante lucro.")
    elseif operation == "Sell" and car.Stage == "Restored" then
        local sale = offer.SalePrice + (car.Style ~= "Factory" and Rules.StyleBonus or 0)
        if profile.Coins + sale > 1000000000000 then return nil, "Saldo acima do limite." end
        local contribution = sale - offer.BuyPrice - offer.RepairFee - car.RiskFee
            - refCost(offer) - (car.Style ~= "Factory" and Rules.StyleCost or 0)
        market.TotalSales += 1
        market.TotalContribution = math.clamp(market.TotalContribution + contribution,
            -100000000, 100000000)
        market.Owned = {}
        market.NextBuyAt = now + Rules.CooldownSeconds
        return result(sale, "Usados: venda de " .. offer.Name, nil,
            string.format("Vendido por %d. Contribuição estimada %+d (peças pelo valor de tabela).",
                sale, contribution))
    elseif operation == "Scrap" and car.Stage ~= "Restored" then
        local sale = offer.ScrapPrice
        if profile.Coins + sale > 1000000000000 then return nil, "Saldo acima do limite." end
        market.TotalSales += 1
        market.TotalContribution = math.clamp(
            market.TotalContribution + sale - offer.BuyPrice, -100000000, 100000000)
        market.Owned = {}
        market.NextBuyAt = now + Rules.CooldownSeconds
        return result(sale, "Usados: descarte de " .. offer.Name, nil,
            "Veículo vendido como sucata com prejuízo, sem XP ou bônus de OS.")
    end
    return nil, "Etapa inválida ou já executada."
end

return Rules
