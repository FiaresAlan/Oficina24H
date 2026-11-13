-- V2-01 / EDITOR: execute SOMENTE apos backup. Acrescenta oito Attachments
-- ao PrimaryPart de cada carro piloto, mas nunca altera geometria ou modelos nao-piloto.
-- E script de autoracao (MUTAVEL), nao suite automatica de QA.
local Store = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage.Shared.V2PilotRigBuilder)
local Pilots = require(ReplicatedStorage.Shared.V2VehiclePilotRules)
local folder = Store:FindFirstChild("Assets")
folder = folder and folder:FindFirstChild("Veiculos")
local logs = {"V2-01 / autoracao de pivots: execute apos salvar copia do place"}
local installed, failures = 0, 0
if not folder then
    table.insert(logs, "FAIL ServerStorage.Assets.Veiculos ausente")
    return table.concat(logs, "\n")
end
for _, spec in ipairs(Pilots.Pilots) do
    local model = folder:FindFirstChild(spec.Model)
    if not model or not model:IsA("Model") or not model.PrimaryPart then
        failures += 1
        table.insert(logs, "FAIL modelo ausente/invalido: " .. spec.Model)
    else
        -- Inspeção de contrato V1 ANTES de editar: sem normalização arbitraria.
        local errors = Pilots.Inspect(model)
        if #errors > 0 then
            failures += 1
            table.insert(logs, "FAIL " .. spec.Model .. " possui " .. #errors .. " falhas de integridade")
        else
            local ok, count = Builder.Attach(model, spec.Name)
            if ok then
                installed += count
                table.insert(logs, "PASS " .. spec.Model .. " - " .. count .. " pivots acrescentados")
            else
                failures += 1
                table.insert(logs, "FAIL " .. spec.Model .. " nao recebeu pivots")
            end
        end
    end
end
table.insert(logs, "TOTAL: " .. installed .. " pivots autorados; " .. failures .. " modelos com falha.")
table.insert(logs, "Agora rode V2PilotPlaceAudit e salve seu place, caso esteja correto.")
return table.concat(logs, "\n")
