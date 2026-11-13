--!strict
-- V2-02: leitura de snapshot V1. Historico de receita = BRUTO, nao margem ou lucro.
local Levels = require(script.Parent.WorkshopLevels)
local Supply = require(script.Parent.V2SupplyRules)
local Rules = {}
local function nonnegative(x: any): number
    if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge or x < 0 then
        return 0
    end
    return math.floor(math.min(x, 1e9))
end
function Rules.Build(snapshot: any): any
    local s = type(snapshot) == "table" and snapshot or {}
    local profile = type(s.Profile) == "table" and s.Profile or {}
    local jobs = type(s.Jobs) == "table" and s.Jobs or {}
    local bays = #(Levels.Levels[math.clamp(nonnegative(profile.WorkshopLevel), 0, 3)].Bays)
    local waiting, busy, urgent, estimated = 0, 0, 0, 0
    for _, job in ipairs(jobs) do
        if type(job) == "table" then
            if job.Status == "Available" then
                waiting += 1
                local limit = nonnegative(job.PatienceSeconds)
                if limit > 0 and nonnegative(job.WaitSeconds) >= limit * 0.75 then urgent += 1 end
            elseif job.Status == "InProgress" then
                busy += 1
                if job.Diagnosed == true and type(job.Requirement) == "table" then
                    estimated += nonnegative(job.Requirement.Reward)
                end
            end
        end
    end
    local gross, count = 0, 0
    if type(profile.OrderHistory) == "table" then
        for i, job in ipairs(profile.OrderHistory) do
            if i > 30 then break end
            if type(job) == "table" then
                gross += nonnegative(job.Price)
                count += 1
            end
        end
    end
    local action = "Acompanhe as ordens de serviço"
    if not s.HasWorkshop then action = "Registre a oficina para começar"
    elseif urgent > 0 then action = "Clientes aguardando há muito tempo"
    elseif waiting > 0 then action = "Atenda o próximo cliente"
    elseif busy > 0 then action = "Conclua um reparo em andamento"
    else action = "Aguarde clientes ou divulgue a oficina" end
    local pending = Supply.Sanitize(profile.SupplyRequests)
    local kinds, stockUnits = 0, 0
    for _ in pairs(pending) do kinds += 1 end
    if type(profile.Parts) == "table" then
        for _, n in pairs(profile.Parts) do stockUnits += nonnegative(n) end
    end
    return {
        Bays = bays, FreeBays = math.max(0, bays - busy), Waiting = waiting, Working = busy,
        Urgent = urgent, Employees = nonnegative(profile.Employees), Coins = nonnegative(profile.Coins),
        RecentGross = gross, RecentCount = count, DiagnosedEstimateGross = estimated,
        SupplyRequestKinds = kinds, SupplyEstimatedCost = Supply.TotalEstimatedCost(pending),
        StockUnits = stockUnits,
        NextAction = action, NetProfitAvailable = false,
    }
end
return Rules
