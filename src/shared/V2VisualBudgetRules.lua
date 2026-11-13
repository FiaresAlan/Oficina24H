--!strict
-- V2-01: LOD exclusivamente de DETALHES OPCIONAIS, nunca do casco, luzes ou interacoes.
local Rules = {}
Rules.DetailLevels = { High = true, Medium = true, Always = true }
Rules.NearDistance = { Touch = 78, Desktop = 135 }
Rules.MediumDistance = { Touch = 150, Desktop = 250 }
Rules.MaxDecorativeParts = 24 -- referencias para assets/Blender (nao sao limite do casco V1)
Rules.MaxActiveEffects = 4
local function safeDistance(distance: any): number
    if type(distance) ~= "number" or distance ~= distance or distance == math.huge
        or distance == -math.huge or distance < 0 then return math.huge end
    return distance
end
function Rules.Show(level: any, distance: any, touch: boolean): boolean
    if level == "Always" or not Rules.DetailLevels[level] then return true end
    local profile = touch and "Touch" or "Desktop"
    local d = safeDistance(distance)
    if level == "High" then return d <= Rules.NearDistance[profile] end
    if level == "Medium" then return d <= Rules.MediumDistance[profile] end
    return true
end
return Rules
