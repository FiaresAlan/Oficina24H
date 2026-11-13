--!strict
-- V2-10: catálogo canônico de personalização de revenda/showroom.
-- Valores de peças, pintura, bônus e limites vivem no servidor.
-- Toda opção tem bônus de revenda MENOR que o custo; não gera arbitragem.
local Rules = {}
Rules.Order = { "Paint", "Finish", "Wheels" }
Rules.Defaults = { Paint = "Factory", Finish = "Standard", Wheels = "Stock" }
Rules.Catalog = {
    Paint = {
        Blue = { Name = "Azul metálico", Cost = 40, ResaleBonus = 30,
            Color = Color3.fromRGB(26, 100, 190) },
        Red = { Name = "Vermelho rubi", Cost = 40, ResaleBonus = 30,
            Color = Color3.fromRGB(175, 38, 43) },
        Graphite = { Name = "Grafite", Cost = 50, ResaleBonus = 35,
            Color = Color3.fromRGB(58, 63, 75) },
    },
    Finish = {
        Gloss = { Name = "Acabamento brilhante", Cost = 45, ResaleBonus = 25 },
        Matte = { Name = "Acabamento fosco", Cost = 55, ResaleBonus = 30 },
    },
    Wheels = {
        Sport = { Name = "Rodas esportivas", Cost = 75, ResaleBonus = 40,
            Color = Color3.fromRGB(200, 210, 222) },
        Classic = { Name = "Rodas clássicas", Cost = 60, ResaleBonus = 30,
            Color = Color3.fromRGB(154, 151, 143) },
    },
}
Rules.MaxShowroom = 2
Rules.MaxUniqueReputation = 3

function Rules.ValidOption(category: any, choice: any): boolean
    return type(category) == "string" and type(choice) == "string"
        and Rules.Catalog[category] ~= nil
        and Rules.Catalog[category][choice] ~= nil
end

function Rules.Parse(spec: any): (string?, string?)
    if type(spec) ~= "string" or #spec > 32 then return nil, nil end
    local category, choice = string.match(spec, "^([A-Za-z]+):([A-Za-z]+)$")
    if not Rules.ValidOption(category, choice) then return nil, nil end
    return category, choice
end

function Rules.Appearance(raw: any): any
    local x = type(raw) == "table" and raw or {}
    local result = {}
    for _, category in ipairs(Rules.Order) do
        local field = category == "Paint" and "Style" or category
        local candidate = x[field]
        result[category] = Rules.ValidOption(category, candidate)
            and candidate or Rules.Defaults[category]
    end
    return result
end

function Rules.NormalizeCar(car: any): any
    local a = Rules.Appearance(car)
    car.Style = a.Paint -- mantém compatibilidade com o Paint V2-09
    car.Finish = a.Finish
    car.Wheels = a.Wheels
    return car
end

function Rules.Quote(category: any, choice: any, car: any): (any?, string)
    if not Rules.ValidOption(category, choice) then
        return nil, "Personalização indisponível."
    end
    if type(car) ~= "table" or car.Stage ~= "Restored" then
        return nil, "Restaure o carro antes de personalizar."
    end
    local appearance = Rules.Appearance(car)
    if appearance[category] ~= Rules.Defaults[category] then
        return nil, "Esta categoria já recebeu uma personalização. Não há nova cobrança."
    end
    local item = Rules.Catalog[category][choice]
    return { Category = category, Choice = choice, Name = item.Name,
        Cost = item.Cost, ResaleBonus = item.ResaleBonus }, ""
end

function Rules.SaleBonus(car: any): number
    local a = Rules.Appearance(car)
    local bonus = 0
    for _, category in ipairs(Rules.Order) do
        local item = Rules.Catalog[category][a[category]]
        if item then bonus += item.ResaleBonus end
    end
    return bonus
end

function Rules.Spent(car: any): number
    local a = Rules.Appearance(car)
    local paid = 0
    for _, category in ipairs(Rules.Order) do
        local item = Rules.Catalog[category][a[category]]
        if item then paid += item.Cost end
    end
    return paid
end

function Rules.Public(): any
    local categories = {}
    for _, category in ipairs(Rules.Order) do
        local options = {}
        local names = {}
        for choice in pairs(Rules.Catalog[category]) do table.insert(names, choice) end
        table.sort(names)
        for _, choice in ipairs(names) do
            local option = Rules.Catalog[category][choice]
            table.insert(options,{
                Id = choice, Name = option.Name,
                Cost = option.Cost, ResaleBonus = option.ResaleBonus,
            })
        end
        table.insert(categories,{ Id = category,
            Name = category == "Paint" and "Pintura"
                or category == "Finish" and "Acabamento" or "Rodas",
            Options = options })
    end
    return categories
end

return Rules
