--!strict
-- V2-01: contrato nao destrutivo de 3 carros piloto. Sem rig V2 fisico, nao simula pivot.
local Catalog = require(script.Parent.Catalog)
local Integrity = require(script.Parent.AssetIntegrityRules)
local Rules = {}
Rules.Pilots = {
    {Id = "Hatch", Name = "Hatch amarelo", Model = "Veiculo_Hatch_MG3"},
    {Id = "Sedan", Name = "Sedã azul", Model = "Veiculo_Sedan_Civic"},
    {Id = "Pickup", Name = "Picape antiga", Model = "Veiculo_Picape_S10"},
}
Rules.Pivots = {
    "V2Pivot_Hood", "V2Pivot_DoorLeft", "V2Pivot_DoorRight", "V2Pivot_Trunk",
    "V2Pivot_WheelFL", "V2Pivot_WheelFR", "V2Pivot_WheelRL", "V2Pivot_WheelRR",
}
function Rules.ValidateCatalog(): {string}
    local errors, seen = {}, {}
    for _, spec in ipairs(Rules.Pilots) do
        if Catalog.VehicleModels[spec.Name] ~= spec.Model then
            table.insert(errors, "Catalog divergiu: " .. spec.Id)
        end
        if seen[spec.Model] then table.insert(errors, "piloto repetido: " .. spec.Model) end
        seen[spec.Model] = true
    end
    return errors
end
function Rules.Inspect(instance: Instance?): ({string}, {string})
    local errors, warnings = Integrity.Vehicle(instance)
    if not instance or not instance:IsA("Model") then return errors, warnings end
    local expected, found = {}, {}
    for _, name in ipairs(Rules.Pivots) do expected[name] = true end
    for _, child in ipairs(instance:GetDescendants()) do
        if expected[child.Name] then
            found[child.Name] = (found[child.Name] or 0) + 1
            if not child:IsA("Attachment") or not child.Parent or not child.Parent:IsA("BasePart") then
                table.insert(errors, child.Name .. " deve ser Attachment filho de BasePart")
            end
        end
    end
    for _, name in ipairs(Rules.Pivots) do
        if not found[name] then
            table.insert(warnings, name .. " ainda nao configurado no modelo")
        elseif found[name] > 1 then
            table.insert(errors, name .. " duplicado")
        end
    end
    return errors, warnings
end
function Rules.Resolve(car: Model, name: string): CFrame?
    local expected = false
    for _, pivot in ipairs(Rules.Pivots) do
        if pivot == name then expected = true break end
    end
    if not expected then return nil end
    local item = car:FindFirstChild(name, true)
    if item and item:IsA("Attachment") and item.Parent and item.Parent:IsA("BasePart")
        and item:IsDescendantOf(car) then
        return item.WorldCFrame
    end
    return nil
end
return Rules
