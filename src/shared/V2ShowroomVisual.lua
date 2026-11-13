--!strict
-- V2-10: a mesma regra visual é usada pelo pátio (servidor) e pelo preview
-- antes/depois (cliente). Só trabalha em CLONES de modelos autorizados.
local Appearance = require(script.Parent.V2ShowroomRules)
local Visual = {}

function Visual.Role(part: BasePart): string
    local tagged = part:GetAttribute("V2CosmeticRole")
    if tagged == "Body" or tagged == "Rim" or tagged == "Rubber" or tagged == "Ignore" then
        return tagged
    end
    local n = string.lower(part.Name)
    if n == "raiz" or n == "casco" or string.find(n,"hitbox")
        or string.find(n,"invisible") or string.find(n,"root")
        or string.find(n,"license") or string.find(n,"placa")
        or string.find(n,"light") or string.find(n,"farol")
        or string.find(n,"glass") or string.find(n,"vidro")
        or string.find(n,"windshield") then return "Ignore" end
    if string.find(n,"tire") or string.find(n,"tyre") or string.find(n,"pneu") then return "Rubber" end
    if string.find(n,"wheel") or string.find(n,"roda")
        or string.find(n,"rim") or string.find(n,"aro") then return "Rim" end
    return "Body"
end

function Visual.Apply(model: Model, car: any)
    local raw = type(car) == "table" and car or {}
    local stage = raw.Stage
    local cosmetics = Appearance.Appearance(raw)
    local paint = Appearance.Catalog.Paint[cosmetics.Paint]
    local finish = cosmetics.Finish
    local wheels = Appearance.Catalog.Wheels[cosmetics.Wheels]
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            local role = Visual.Role(descendant)
            if descendant.Transparency < 0.5 and role ~= "Ignore" then
                if stage ~= "Restored" then
                    -- Desgaste leve e reversível: sempre em clone, nunca no asset original.
                    if role == "Body" then
                        descendant.Color = descendant.Color:Lerp(Color3.fromRGB(92,87,79),0.32)
                    end
                elseif role == "Body" then
                    if paint then
                        descendant.Color = descendant.Color:Lerp(paint.Color,0.74)
                    end
                    if finish == "Matte" then
                        descendant.Reflectance = 0
                        descendant.Material = Enum.Material.SmoothPlastic
                    elseif finish == "Gloss" then
                        descendant.Reflectance = 0.13
                        if descendant.Material ~= Enum.Material.Glass then
                            descendant.Material = Enum.Material.Metal
                        end
                    end
                elseif role == "Rim" and wheels then
                    descendant.Color = wheels.Color
                    descendant.Material = Enum.Material.Metal
                    descendant.Reflectance = cosmetics.Wheels == "Sport" and 0.15 or 0.03
                end
            end
        end
    end
end

return Visual
