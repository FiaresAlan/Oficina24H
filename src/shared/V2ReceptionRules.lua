--!strict
-- V2-02: contratos de recepcao. Somente servidor pode alterar prioridade, desconto ou fila.
-- A estimativa ANTES do diagnostico nao consulta DefectId/ServiceId da ordem.
local Catalog = require(script.Parent.Catalog)
local Rules = {}

Rules.Priority = { Low = -1, Normal = 0, High = 1 }
Rules.Appointments = { [30] = true, [60] = true, [90] = true }
Rules.Discounts = { [0] = true, [5] = true, [10] = true }

local function number(value: any): number
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return 0
    end
    return value
end

function Rules.ValidPriority(value: any): boolean
    return type(value) == "number" and value % 1 == 0 and value >= -1 and value <= 1
end
function Rules.ValidAppointment(seconds: any): boolean
    return type(seconds) == "number" and Rules.Appointments[seconds] == true
end
function Rules.ValidDiscount(percent: any): boolean
    return type(percent) == "number" and Rules.Discounts[percent] == true
end
function Rules.PriceAfterDiscount(originalPrice: any, percent: any): number?
    if not Rules.ValidDiscount(percent) or type(originalPrice) ~= "number" or originalPrice < 1
        or originalPrice > 10000000 or originalPrice ~= originalPrice then
        return nil
    end
    return math.max(1, math.floor(originalPrice * (100 - percent) / 100 + 0.5))
end

-- Nao usar o defeito verdadeiro, catalogo ou preco interno de uma OS para inferir um unico defeito.
-- Uma faixa de referencial geral para todas as ordens e segura antes do diagnostico.
function Rules.GeneralPriceGuide(multiplier: any): (number, number)
    local low, high = math.huge, 0
    for _, service in pairs(Catalog.Services) do
        low = math.min(low, service.Reward)
        high = math.max(high, service.Reward)
    end
    local rate = math.clamp(number(multiplier), 0.7, 1.5)
    return math.floor(low * rate), math.ceil(high * rate * 2)
end

function Rules.MissingParts(parts: any, stock: any): { [string]: number }
    local missing: { [string]: number } = {}
    if type(parts) ~= "table" then return missing end
    local have = type(stock) == "table" and stock or {}
    for partId, amount in pairs(parts) do
        if type(partId) == "string" and Catalog.Parts[partId] ~= nil
            and type(amount) == "number" and amount % 1 == 0
            and amount > 0 and amount <= 100 then
            local owned = number(have[partId])
            local deficit = math.max(0, amount - math.max(0, owned))
            if deficit > 0 then missing[partId] = math.ceil(deficit) end
        end
    end
    return missing
end

-- Projecao atual das pecas, visivel SOMENTE apos o diagnostico.
-- Nao inclui mao-de-obra, salario, aluguel ou custo historico: nao e lucro liquido.
function Rules.EstimatedPartsCost(parts: any): number
    local total = 0
    if type(parts) ~= "table" then return total end
    for id, count in pairs(parts) do
        local known = Catalog.Parts[id]
        if known and type(count) == "number" and count == count and count > 0
            and count % 1 == 0 and count <= 1000 then
            total += known.Cost * count
        end
    end
    return total
end

-- Mapeamento de apresentacao: estados de persistencia da V1 nao sao renomeados nem adulterados.
function Rules.Stage(job: any, stock: any, now: number?): string
    if type(job) ~= "table" then return "Indisponível" end
    local moment = now or os.time()
    if job.Status == "Completed" then return "Entregue" end
    if job.Status == "Available" then
        if number(job.ScheduledUntil) > moment then return "Agendado" end
        return "Aguardando cliente"
    end
    if job.Status ~= "InProgress" then return "Indisponível" end
    if job.Diagnosed ~= true then return "Diagnóstico" end
    if next(Rules.MissingParts(job.Requirement and job.Requirement.Parts, stock)) ~= nil then
        return "Aguardando peça"
    end
    if job.CollaboratorUserId ~= nil then return "Com colaborador" end
    if job.Repairing == true then return "Em reparo" end
    return "Pronto para reparar"
end

function Rules.QueueLess(a: any, b: any): boolean
    local ap = math.clamp(number(a.Priority), -1, 1)
    local bp = math.clamp(number(b.Priority), -1, 1)
    if ap ~= bp then return ap > bp end
    local at = number(a.WaitSeconds)
    local bt = number(b.WaitSeconds)
    if at ~= bt then return at > bt end
    return tostring(a.Id) < tostring(b.Id)
end

function Rules.CanManage(ownerId: any, job: any, stage: string): boolean
    return type(ownerId) == "number" and type(job) == "table"
        and job.OwnerUserId == ownerId and job.Status == stage
end

function Rules.BuildVisible(job: any, profile: any, now: number?): any
    local stock = type(profile) == "table" and profile.Parts or {}
    local rate = type(profile) == "table" and profile.PriceMultiplier or 1
    local low, high = Rules.GeneralPriceGuide(rate)
    local diagnosed = job.Diagnosed == true
    local requirement = diagnosed and job.Requirement
    local estimatedParts = requirement and Rules.EstimatedPartsCost(requirement.Parts) or nil
    local price = requirement and number(requirement.Reward) or nil
    return {
        Stage = Rules.Stage(job, stock, now),
        Priority = Rules.ValidPriority(job.Priority) and job.Priority or 0,
        ScheduledUntil = number(job.ScheduledUntil),
        CanSchedule = job.Status == "Available" and job.ScheduleUsed ~= true,
        DiscountPercent = diagnosed and number(job.DiscountPercent) or 0,
        -- Descoberta do valor exato pertence ao diagnostico (Requirement.Reward V1).
        PriceGuideMin = low, PriceGuideMax = high,
        MissingParts = diagnosed and Rules.MissingParts(job.Requirement and job.Requirement.Parts, stock) or {},
        EstimatedPartsCost = estimatedParts,
        ContributionBeforeLabor = price and estimatedParts and (price - estimatedParts) or nil,
    }
end

return Rules
