--!strict
-- V2-01: paleta industrial/veicular. Preserva todas as texturas de origem, alterando
-- somente partes de arte que o artista marcar explicitamente com V2ArtRole.
local Rules = {}
Rules.Styles = {
    Hatch = { Paint = Color3.fromRGB(214, 160, 38), Trim = Color3.fromRGB(32, 37, 43) },
    Sedan = { Paint = Color3.fromRGB(61, 101, 145), Trim = Color3.fromRGB(27, 32, 38) },
    Pickup = { Paint = Color3.fromRGB(118, 113, 103), Trim = Color3.fromRGB(35, 39, 43) },
}
Rules.Roles = { Paint = true, Trim = true, Glass = true, Mechanical = true }
function Rules.Apply(model: Model, pilotId: string): number
    local style = Rules.Styles[pilotId]
    if not style then return 0 end
    local styled = 0
    for _, item in ipairs(model:GetDescendants()) do
        if item:IsA("BasePart") then
            local role = item:GetAttribute("V2ArtRole")
            if role == "Paint" then
                item.Color = style.Paint
                item.Material = Enum.Material.Metal
                styled += 1
            elseif role == "Trim" then
                item.Color = style.Trim
                item.Material = Enum.Material.SmoothPlastic
                styled += 1
            elseif role == "Glass" then
                item.Material = Enum.Material.Glass
                item.Transparency = math.max(0.12, item.Transparency)
                styled += 1
            elseif role == "Mechanical" then
                item.Material = Enum.Material.Metal
                styled += 1
            end
        end
    end
    return styled
end
return Rules
