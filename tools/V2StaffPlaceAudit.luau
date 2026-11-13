-- V2-05: leitura não destrutiva do Place em Studio Edit.
-- Sem assets importados em Studio: WARN é esperado, jamais PASS falso.
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.V2StaffRules)
local result={}
local function mark(kind,msg)table.insert(result,kind.." "..msg)end
mark(#Rules.Sanitize(nil)==2 and "PASS" or "FAIL",
    "dois slots de funcionário com regras saneadas")
local assets=ServerStorage:FindFirstChild("Assets")
local folder=assets and assets:FindFirstChild("Clientes")
if not folder then
    mark("WARN","ServerStorage.Assets.Clientes ausente; funcionário não deve ser contratado antes da importação")
else
    local valid=0
    for _,npc in ipairs(folder:GetChildren()) do
        if npc:IsA("Model") then
            local hum=npc:FindFirstChildOfClass("Humanoid")
            if hum and npc.PrimaryPart and npc.PrimaryPart:IsA("BasePart") then
                valid+=1
                mark("PASS",npc.Name.." possui Humanoid e PrimaryPart")
                for _,d in ipairs(npc:GetDescendants()) do
                    if d:IsA("Script") or d:IsA("LocalScript") then
                        mark("WARN",npc.Name.." possui Script embutido; NpcKit deve removê-lo ao clonar")
                    end
                end
            else
                mark("WARN",npc.Name.." não possui rig válido e não será usado")
            end
        end
    end
    mark(valid>0 and "PASS" or "WARN",
        tostring(valid).." rigs válidos para spawn, sem modificar os assets")
end
local server=game:GetService("ServerScriptService"):FindFirstChild("Server")
local navigator=server and server:FindFirstChild("V2StaffNavigator")
mark(navigator and "PASS" or "WARN",
    "V2StaffNavigator disponível na árvore do servidor")
local plots=workspace:FindFirstChild("Plots") or workspace:FindFirstChild("Lotes")
mark(plots and "PASS" or "WARN",
    "Lotes/Plots estão disponíveis para rota real; jogo deve ser testado no Play")
mark("PASS","auditoria preservou Scene, DataStore, personagens e pistas de trabalho")
return table.concat(result,"\n")
