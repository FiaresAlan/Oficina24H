--!strict
-- V2-09: mercado de usados de baixa escala. Regras puras: o cliente nunca dita valores,
-- condições, identidade de oferta, preço de venda ou consumo de peças.
-- Carro de revenda NÃO ocupa as vagas das OS de clientes.
local Catalog = require(script.Parent.Catalog)
local Appearance = require(script.Parent.V2ShowroomRules)

local Rules = {}
Rules.MaxOwned = 1
Rules.MaxShowroom = Appearance.MaxShowroom
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
    return { Owned = {}, Showroom = {}, ShowroomSeen = {},
        NextBuyAt = 0, TotalSales = 0, TotalContribution = 0 }
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
                Finish = item.Finish, Wheels = item.Wheels,
                PurchasedAt = integer(item.PurchasedAt, 0, 4102444800),
            })
            Appearance.NormalizeCar(state.Owned[#state.Owned])
            seen[item.Uid] = true
        end
    end
    -- V2-10: somente carros RESTAURADOS podem permanecer expostos.
    -- A mesma identidade nunca pode existir no estoque e no showroom.
    local showroom = type(raw.Showroom) == "table" and raw.Showroom or {}
    for _, item in ipairs(showroom) do
        if #state.Showroom >= Rules.MaxShowroom then break end
        if type(item) == "table" and type(item.Uid) == "string"
            and #item.Uid >= 12 and #item.Uid <= 64 and not seen[item.Uid]
            and item.Stage == "Restored" and Rules.Offers[item.Variant] then
            local offer = Rules.Offers[item.Variant]
            local copy = {
                Uid = item.Uid, Variant = item.Variant, Stage = "Restored",
                Style = item.Style, Finish = item.Finish, Wheels = item.Wheels,
                RiskFee = integer(item.RiskFee,0,offer.RiskMax),
                PurchasedAt = integer(item.PurchasedAt,0,4102444800),
            }
            Appearance.NormalizeCar(copy)
            table.insert(state.Showroom,copy)
            seen[item.Uid] = true
        end
    end
    if type(raw.ShowroomSeen) == "table" then
        for variant in pairs(Rules.Offers) do
            if raw.ShowroomSeen[variant] == true then state.ShowroomSeen[variant] = true end
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
    local showroomPublic = {}
    local function visibleCar(car: any): any
        local offer = Rules.Offers[car.Variant]
        return {
            Uid = car.Uid, Variant = car.Variant, Stage = car.Stage,
            Style = car.Style, Finish = car.Finish, Wheels = car.Wheels,
            Name = offer.Name, VehicleName = offer.VehicleName,
            VehicleModel = Catalog.VehicleModels[offer.VehicleName],
            RepairFee = offer.RepairFee + car.RiskFee,
            RiskFee = car.RiskFee, Parts = table.clone(offer.Parts),
            PartsReferenceCost = refCost(offer),
            CosmeticSpend = Appearance.Spent(car),
            SellPrice = car.Stage == "Restored" and
                (offer.SalePrice + Appearance.SaleBonus(car))
                or offer.ScrapPrice,
        }
    end
    for _, car in ipairs(state.Owned) do table.insert(owned,visibleCar(car)) end
    for _, car in ipairs(state.Showroom) do table.insert(showroomPublic,visibleCar(car)) end
    local recognized = 0
    for _ in pairs(state.ShowroomSeen) do recognized += 1 end
    return {
        CanBuy = allowed, BlockedReason = why,
        NextBuyAt = state.NextBuyAt, TotalSales = state.TotalSales,
        TotalContribution = state.TotalContribution, Capacity = Rules.MaxOwned,
        MinServices = Rules.MinServiceCount, StyleCost = Rules.StyleCost,
        Offers = offers, Owned = owned, Showroom = showroomPublic,
        ShowroomCapacity = Rules.MaxShowroom, ShowroomReputationEarned = recognized,
        Customizations = Appearance.Public(),
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
    local function result(delta: number, reason: string, parts: any?,
        message: string, reputation: number?): any
        return { Market = market, Delta = delta, Reason = reason,
            Parts = parts, Message = message, ReputationAward = reputation or 0 }
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
        for _, exhibit in ipairs(market.Showroom) do
            if exhibit.Uid == freshUid then return nil, "Identificador já utilizado." end
        end
        table.insert(market.Owned, {
            Uid = freshUid, Variant = input, Stage = "Purchased",
            Style = "Factory", Finish = "Standard", Wheels = "Stock",
            RiskFee = chosenRisk, PurchasedAt = now,
        })
        return result(-offer.BuyPrice, "Usados: compra de " .. offer.Name,
            nil, "Carro comprado. Avalie, desmonte e restaure antes da venda.")
    end
    local car = market.Owned[1]
    if (operation == "Recall" or operation == "SellExhibit") then
        local index: number? = nil
        for i, exhibit in ipairs(market.Showroom) do
            if exhibit.Uid == input then index = i break end
        end
        if not index then return nil, "Veículo não encontrado no showroom." end
        local exhibit = market.Showroom[index]
        if operation == "Recall" then
            if #market.Owned > 0 then
                return nil, "Finalize o veículo em restauração antes de retirar o carro da vitrine."
            end
            table.insert(market.Owned, exhibit)
            table.remove(market.Showroom,index)
            return result(0, "", nil,"Veículo devolvido à área de preparação para personalização.")
        end
        local showroomOffer = Rules.Offers[exhibit.Variant]
        local sale = showroomOffer.SalePrice + Appearance.SaleBonus(exhibit)
        if profile.Coins + sale > 1000000000000 then return nil, "Saldo acima do limite." end
        local contribution = sale - showroomOffer.BuyPrice - showroomOffer.RepairFee
            - exhibit.RiskFee - refCost(showroomOffer) - Appearance.Spent(exhibit)
        market.TotalSales += 1
        market.TotalContribution = math.clamp(market.TotalContribution + contribution,
            -100000000, 100000000)
        table.remove(market.Showroom,index)
        market.NextBuyAt = now + Rules.CooldownSeconds
        return result(sale, "Usados: venda showroom de " .. showroomOffer.Name,
            nil, string.format("Vendido por %d; contribuição estimada %+d.",sale,contribution))
    end
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
    elseif operation == "Customize" and car.Stage == "Restored" then
        local category, choice = Appearance.Parse(chosenRisk)
        local quote, errorMessage = Appearance.Quote(category, choice, car)
        if not quote then return nil, errorMessage end
        if profile.Coins < quote.Cost then return nil, "Saldo insuficiente para esta personalização." end
        if category == "Paint" then car.Style = choice
        elseif category == "Finish" then car.Finish = choice
        else car.Wheels = choice end
        return result(-quote.Cost, "Usados: personalizado " .. quote.Name,
            nil, quote.Name .. " aplicado. Bônus de revenda menor que o gasto.")
    elseif operation == "Showcase" and car.Stage == "Restored" then
        if #market.Showroom >= Rules.MaxShowroom then
            return nil, "As duas vagas de exposição já estão ocupadas."
        end
        local reputation = market.ShowroomSeen[car.Variant] and 0 or 1
        market.ShowroomSeen[car.Variant] = true
        table.insert(market.Showroom, car)
        market.Owned = {}
        return result(0, "", nil,
            reputation > 0 and "Veículo exibido. Reputação +1 pela primeira exposição desta variante."
                or "Veículo exibido. Esta variante já concedeu reputação anteriormente.",
            reputation)
    elseif operation == "Paint" and car.Stage == "Restored" and car.Style == "Factory" then
        if chosenRisk ~= "Blue" and chosenRisk ~= "Red" then
            return nil, "Escolha uma pintura disponível."
        end
        if profile.Coins < Rules.StyleCost then return nil, "Saldo insuficiente." end
        car.Style = chosenRisk
        return result(-Rules.StyleCost, "Usados: pintura",
            nil, "Pintura aplicada. Personalização não garante lucro.")
    elseif operation == "Sell" and car.Stage == "Restored" then
        local sale = offer.SalePrice + Appearance.SaleBonus(car)
        if profile.Coins + sale > 1000000000000 then return nil, "Saldo acima do limite." end
        local contribution = sale - offer.BuyPrice - offer.RepairFee - car.RiskFee
            - refCost(offer) - Appearance.Spent(car)
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
