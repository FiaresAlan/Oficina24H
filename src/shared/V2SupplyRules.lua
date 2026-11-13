--!strict
-- V2-02: lista de compras persistida, sem pagamento automatico nem reserva ficticia.
local Catalog = require(script.Parent.Catalog)
local Rules = {}
Rules.MaxKinds = 12
Rules.MaxQuantity = 20
function Rules.Sanitize(raw: any): { [string]: number }
    local safe: { [string]: number } = {}
    if type(raw) ~= "table" then return safe end
    local keys = {}
    for partId in pairs(raw) do
        if type(partId) == "string" and Catalog.Parts[partId] ~= nil then
            table.insert(keys, partId)
        end
    end
    table.sort(keys)
    for i, partId in ipairs(keys) do
        if i > Rules.MaxKinds then break end
        local amount = raw[partId]
        if type(amount) == "number" and amount == amount
            and amount ~= math.huge and amount ~= -math.huge and amount >= 1 then
            safe[partId] = math.clamp(math.floor(amount), 1, Rules.MaxQuantity)
        end
    end
    return safe
end

function Rules.MergeMissing(current: any, missing: any): ({ [string]: number }, number)
    local nextList = Rules.Sanitize(current)
    if type(missing) ~= "table" then return nextList, 0 end
    local added = 0
    for partId, count in pairs(missing) do
        if Catalog.Parts[partId] and type(count) == "number" and count == count
            and count ~= math.huge and count ~= -math.huge and count > 0
            and count % 1 == 0 and count <= Rules.MaxQuantity then
            if nextList[partId] == nil then
                local kinds = 0
                for _ in pairs(nextList) do kinds += 1 end
                if kinds >= Rules.MaxKinds then break end
            end
            local before = nextList[partId] or 0
            nextList[partId] = math.min(Rules.MaxQuantity, math.max(before, count))
            if nextList[partId] > before then added += 1 end
        end
    end
    return nextList, added
end

-- Depois de comprar a peça na LOJA FISICA (V1), a pendencia e reduzida.
function Rules.OnPurchase(current: any, partId: any, quantity: any): { [string]: number }
    local nextList = Rules.Sanitize(current)
    if type(partId) ~= "string" or type(quantity) ~= "number"
        or quantity % 1 ~= 0 or quantity <= 0 or nextList[partId] == nil then
        return nextList
    end
    local left = nextList[partId] - quantity
    if left > 0 then nextList[partId] = left else nextList[partId] = nil end
    return nextList
end

function Rules.TotalEstimatedCost(current: any): number
    local total = 0
    for partId, count in pairs(Rules.Sanitize(current)) do
        total += count * Catalog.Parts[partId].Cost
    end
    return total
end
return Rules
