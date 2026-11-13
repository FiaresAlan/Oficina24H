--!strict
-- V2-05: regras puras de escala e seleção de funcionário. Sem dados pessoais.
local Catalog = require(script.Parent.Catalog)
local Rules = {}

Rules.MaxEmployees = 2
Rules.MaxHistory = 12
Rules.Modes = { Auto = true, Manual = true, Paused = true }
Rules.Focuses = { Any = true }
for _, spec in ipairs(Catalog.Specializations) do
    Rules.Focuses[spec] = true
end

local function signedPriority(value: any): number
    if type(value)~="number" or value~=value
        or value==math.huge or value==-math.huge then return 0 end
    return math.floor(math.clamp(value,-1,1))
end

local function bounded(value: any, max: number): number
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return 0
    end
    return math.floor(math.clamp(value, 0, max))
end

function Rules.DefaultSlot(): any
    return { Mode = "Auto", Focus = "Any", Completed = 0, Gross = 0,
        TotalSeconds = 0, QualitySum = 0, Recent = {} }
end

function Rules.Sanitize(value: any): { any }
    local old = type(value) == "table" and value or {}
    local slots = {}
    for i = 1, Rules.MaxEmployees do
        local prior = type(old[i]) == "table" and old[i] or {}
        local recent = {}
        if type(prior.Recent) == "table" then
            for _, log in ipairs(prior.Recent) do
                if #recent >= Rules.MaxHistory then break end
                if type(log) == "table" and type(log.Service) == "string"
                    and #log.Service <= 80 and #log.Service > 0 then
                    table.insert(recent, {
                        JobId = type(log.JobId)=="string" and string.sub(log.JobId,1,80) or "",
                        Service = log.Service, Gross = bounded(log.Gross, 100000000),
                        Quality = bounded(log.Quality, 100),
                        Seconds = bounded(log.Seconds, 3600),
                        At = bounded(log.At, 4102444800),
                    })
                end
            end
        end
        slots[i] = {
            Mode = Rules.Modes[prior.Mode] and prior.Mode or "Auto",
            Focus = Rules.Focuses[prior.Focus] and prior.Focus or "Any",
            Completed = bounded(prior.Completed, 100000000),
            Gross = bounded(prior.Gross, 1000000000),
            TotalSeconds = bounded(prior.TotalSeconds, 1000000000),
            QualitySum = bounded(prior.QualitySum, 10000000000),
            Recent = recent,
        }
    end
    return slots
end

function Rules.Update(slots: any, index: any, key: any, value: any): (boolean, string)
    if type(slots) ~= "table" or type(index) ~= "number"
        or index % 1 ~= 0 or index < 1 or index > Rules.MaxEmployees
        or type(slots[index]) ~= "table" then
        return false, "Funcionário inválido."
    end
    if key == "Mode" and not Rules.Modes[value] then
        return false, "Modo inválido."
    elseif key == "Focus" and not Rules.Focuses[value] then
        return false, "Especialização inválida."
    elseif key ~= "Mode" and key ~= "Focus" then
        return false, "Configuração inválida."
    end
    if slots[index][key] == value then return false, "Configuração já aplicada." end
    slots[index][key] = value
    return true, "Escala de mecânico atualizada."
end

function Rules.Record(slots: any, slot: any, jobId: any, service: any,
    gross: any, quality: any, seconds: any, at: any): boolean
    if type(slots) ~= "table" or type(slot) ~= "number" or slot % 1 ~= 0
        or slot < 1 or slot > Rules.MaxEmployees or type(slots[slot]) ~= "table"
        or type(jobId) ~= "string" or #jobId < 1 or #jobId > 80
        or type(service) ~= "string" or #service < 1 or #service > 80
        or type(gross) ~= "number" or gross < 0
        or type(quality) ~= "number" or quality < 0 or quality > 100
        or type(seconds) ~= "number" or seconds < 0 then return false end
    local s = slots[slot]
    for _, entry in ipairs(s.Recent) do
        if entry.JobId == jobId then return false end -- replay de recibo não contabiliza duas vezes
    end
    s.Completed = bounded(s.Completed + 1, 100000000)
    s.Gross = bounded(s.Gross + gross, 1000000000)
    s.QualitySum = bounded(s.QualitySum + quality, 10000000000)
    s.TotalSeconds = bounded(s.TotalSeconds + seconds, 1000000000)
    table.insert(s.Recent, 1, {
        JobId = jobId, Service = service, Gross = bounded(gross, 100000000),
        Quality = bounded(quality, 100), Seconds = bounded(seconds, 3600),
        At = bounded(at, 4102444800),
    })
    while #s.Recent > Rules.MaxHistory do table.remove(s.Recent) end
    return true
end

function Rules.CanHandle(slot: any, specialization: any): boolean
    return type(slot) == "table" and Rules.Modes[slot.Mode] == true
        and slot.Mode ~= "Paused" and (slot.Focus == "Any" or slot.Focus == specialization)
end

-- Determinístico: atribuição manual tem precedência, depois prioridade de OS,
-- urgência por tempo aguardando, idade e ID. Não revela defeito ao cliente.
function Rules.Order(jobs: any, slot: any, now: number): { any }
    local candidates = {}
    if type(jobs) ~= "table" or type(slot) ~= "table" then return candidates end
    for _, j in ipairs(jobs) do
        if type(j) == "table" and type(j.Id) == "string"
            and j.Ready == true and Rules.CanHandle(slot, j.Specialization)
            and (slot.Mode ~= "Manual" or j.Manual == true)
            and (slot.Mode ~= "Auto" or j.Manual ~= false) then
            table.insert(candidates, j)
        end
    end
    table.sort(candidates, function(a, b)
        if (a.Manual == true) ~= (b.Manual == true) then return a.Manual == true end
        local p1, p2 = signedPriority(a.Priority), signedPriority(b.Priority)
        if p1 ~= p2 then return p1 > p2 end
        local t1, t2 = bounded(a.AcceptedAt, 4102444800), bounded(b.AcceptedAt, 4102444800)
        if t1 ~= t2 then return t1 < t2 end
        return a.Id < b.Id
    end)
    return candidates
end

function Rules.CanAssign(slot: any, specialization: any): boolean
    return Rules.CanHandle(slot, specialization)
end

return Rules
