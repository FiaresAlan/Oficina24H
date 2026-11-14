--!strict
-- V2-01: LOD exclusivamente de DETALHES OPCIONAIS, nunca do casco, luzes ou interacoes.
local Rules = {}
Rules.DetailLevels = { High = true, Medium = true, Always = true }
Rules.NearDistance = { Touch = 78, Desktop = 135 }
Rules.MediumDistance = { Touch = 150, Desktop = 250 }
Rules.MaxDecorativeParts = 24 -- referencias para assets/Blender (nao sao limite do casco V1)
Rules.MaxActiveEffects = 4
-- V2-15: limites efetivos da física (não das partes da oficina V1).
-- Modelos excedentes usam o fallback físico simples, não são clonados.
Rules.MaxDriveShellParts=95
Rules.MaxDriveShellDescendants=350
Rules.MaxDriveSurfaceAppearances=24
Rules.MaxConcurrentDriveRigs=5
Rules.MaxAmbientTemplateParts=90
Rules.MaxAmbientTemplateDescendants=280

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
-- Vistoriar ANTES do Clone(): modelos de marketplace podem conter
-- dezenas de milhares de objetos mesmo com poucas peças visíveis.
function Rules.PreflightTemplate(source:any,kind:any):(boolean,string)
    if typeof(source)~="Instance" or not source:IsA("Model") then
        return false,"Modelo inválido."
    end
    if kind~="Drive" and kind~="Ambient" then
        return false,"Perfil de orçamento inexistente."
    end
    local parts=0
    local appearances=0
    local nodes=0
    local maxParts=kind=="Drive" and Rules.MaxDriveShellParts
        or Rules.MaxAmbientTemplateParts
    local maxNodes=kind=="Drive" and Rules.MaxDriveShellDescendants
        or Rules.MaxAmbientTemplateDescendants
    for _,node in ipairs(source:GetDescendants()) do
        nodes+=1
        if nodes>maxNodes then return false,"Modelo excede orçamento de instâncias." end
        if node:IsA("BasePart") then
            parts+=1
            if parts>maxParts then return false,"Modelo excede orçamento de peças." end
        elseif node:IsA("SurfaceAppearance") then
            appearances+=1
            if appearances>Rules.MaxDriveSurfaceAppearances then
                return false,"Modelo excede orçamento de texturas de superfície."
            end
        end
    end
    if parts<1 then return false,"Sem peças visíveis." end
    local ok,size=pcall(function() return source:GetExtentsSize() end)
    if not ok or typeof(size)~="Vector3" then return false,"Extensão inválida." end
    if size.X>50 or size.Y>25 or size.Z>60
        or size.X<=0 or size.Y<=0 or size.Z<=0 then
        return false,"Escala incompatível."
    end
    return true,""
end

function Rules.CanStartDrive(activeCount:any):boolean
    return type(activeCount)=="number" and activeCount>=0
        and activeCount<Rules.MaxConcurrentDriveRigs
end

return Rules
