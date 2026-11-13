--!strict
-- V2-01: pivôs tecnicos gerados sobre copia de veiculo V1, sem destruir modelagem original.
-- O artista pode substituir os Attachment gerados por pivôs reais nos modelos de origem.
local PilotRules = require(script.Parent.V2VehiclePilotRules)
local Rules = {}
local names = {}
for _, pilot in ipairs(PilotRules.Pilots) do names[pilot.Name] = pilot.Id end

local function safeDimension(value: any, fallback: number, low: number, high: number): number
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return fallback
    end
    return math.clamp(value, low, high)
end

function Rules.Attach(model: Model, vehicleName: string): (boolean, number)
    local pilotId = names[vehicleName]
    if not pilotId then return false, 0 end
    local root = model.PrimaryPart
    if not root then return false, 0 end
    local width = safeDimension(model:GetAttribute("Largura"), 8, 4, 14)
    local length = safeDimension(model:GetAttribute("Comprimento"), 16, 8, 32)
    local height = safeDimension(model:GetAttribute("Altura"), 4, 2, 9)
    -- LookVector (-Z local) aponta para frente.
    local positions: { [string]: Vector3 } = {
        V2Pivot_Hood = Vector3.new(0, height * 0.73, -length * 0.27),
        V2Pivot_DoorLeft = Vector3.new(-width * 0.47, height * 0.48, -length * 0.08),
        V2Pivot_DoorRight = Vector3.new(width * 0.47, height * 0.48, -length * 0.08),
        V2Pivot_Trunk = Vector3.new(0, height * 0.72, length * 0.30),
        V2Pivot_WheelFL = Vector3.new(-width * 0.44, height * 0.25, -length * 0.34),
        V2Pivot_WheelFR = Vector3.new(width * 0.44, height * 0.25, -length * 0.34),
        V2Pivot_WheelRL = Vector3.new(-width * 0.44, height * 0.25, length * 0.33),
        V2Pivot_WheelRR = Vector3.new(width * 0.44, height * 0.25, length * 0.33),
    }
    local created = 0
    for _, name in ipairs(PilotRules.Pivots) do
        if not model:FindFirstChild(name, true) then
            local anchor = Instance.new("Attachment")
            anchor.Name = name
            anchor.CFrame = CFrame.new(positions[name])
            anchor:SetAttribute("V2Generated", true)
            anchor.Parent = root
            created += 1
        end
    end
    model:SetAttribute("V2PilotId", pilotId)
    model:SetAttribute("V2RigVersion", 1)
    model:SetAttribute("V2RigGeneratedCount", created)
    return true, created
end

return Rules
