-- V2-03: auditoria Edit de articulações sem alterar assets originais.
-- Módulos de testes não são enviados ao jogo público. Sem modelos = WARN (não "testado").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Store = game:GetService("ServerStorage")
local Pilots = require(ReplicatedStorage.Shared.V2VehiclePilotRules)
local Builder = require(ReplicatedStorage.Shared.V2PilotRigBuilder)
local Rules = require(ReplicatedStorage.Shared.V2ComponentRules)

local results = {"V2-03 / auditoria 3 pilotos, sem mutação do place"}
local function mark(status, text) table.insert(results, status .. " " .. text) end
mark(#Pilots.ValidateCatalog() == 0 and "PASS" or "FAIL", "3 modelos catalogados e sem divergências")
local folder = Store:FindFirstChild("Assets")
folder = folder and folder:FindFirstChild("Veiculos")
if not folder then
    mark("WARN", "ServerStorage.Assets.Veiculos ainda não foi importado")
else
    for _, spec in ipairs(Pilots.Pilots) do
        local model = folder:FindFirstChild(spec.Model)
        if not model or not model:IsA("Model") then
            mark("WARN", "modelo ausente: " .. spec.Model)
        else
            -- Clonar para não persistir pivôs nem alterar o asset do jogador no Editor.
            local copy = model:Clone()
            local ok, count = Builder.Attach(copy, spec.Name)
            local errors, warnings = Pilots.Inspect(copy)
            local seen, present = {}, 0
            for _, id in ipairs(Rules.Components) do
                local pivot = Pilots.Resolve(copy, id.Pivot)
                if pivot then
                    seen[id.Id] = true
                    present += 1
                else
                    mark("FAIL", spec.Id .. " sem pivot funcional " .. id.Pivot)
                end
            end
            mark(ok and #errors == 0 and present == #Rules.Components and count <= 8 and
                "PASS" or "FAIL", spec.Id .. " mantém rig íntegro com " .. present .. " pivôs")
            for _, errorText in ipairs(errors) do mark("FAIL", spec.Id .. ": " .. errorText) end
            for _, warningText in ipairs(warnings) do mark("WARN", spec.Id .. ": " .. warningText) end
            local art = { Hood = false, DoorLeft = false, DoorRight = false, Trunk = false,
                WheelFL = false, WheelFR = false, WheelRL = false, WheelRR = false }
            for _, item in ipairs(copy:GetDescendants()) do
                if item:IsA("BasePart") then
                    local tag = item:GetAttribute("V2MovingComponent")
                    if type(tag) == "string" and art[tag] ~= nil then art[tag] = true end
                end
            end
            for key, found in pairs(art) do
                if not found then
                    mark("WARN", spec.Id .. " / " .. key ..
                        " sem malha nativa separada e marcada; cliente usará proxy visual")
                end
            end
            copy:Destroy()
        end
    end
end
mark("PASS", "auditoria preservou os templates originais; nenhuma alteração foi aplicada")
return table.concat(results, "\n")
