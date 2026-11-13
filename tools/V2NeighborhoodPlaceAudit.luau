-- V2-07: auditoria não destrutiva do place e dos assets de trânsito.
-- Executar em Studio Edit; faltas reais de importação geram WARN, nunca PASS.
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.V2NeighborhoodRules)
local lines={}
local function mark(level,message)
    table.insert(lines,level.." "..message)
end
for _,failure in ipairs(Rules.Validate()) do mark("FAIL","rota: "..failure) end
local bairro=workspace:FindFirstChild("Bairro")
if bairro then mark("PASS","cenário Bairro presente") else
    mark("WARN","Workspace.Bairro ainda não criado no Studio")
end
local map=workspace:FindFirstChild("Map")
local ground=map and map:FindFirstChild("Ground")
if ground and ground:IsA("BasePart") then
    mark("PASS","piso para raycast ambiental disponível")
else
    mark("WARN","Workspace.Map.Ground ausente; verificar altura de modelos")
end
local assets=ServerStorage:FindFirstChild("Assets")
local clientes=assets and assets:FindFirstChild("Clientes")
local veiculos=assets and assets:FindFirstChild("Veiculos")
local count=0
for _,npc in ipairs(clientes and clientes:GetChildren() or {}) do
    if npc:IsA("Model") and npc.PrimaryPart and npc:FindFirstChildOfClass("Humanoid") then
        count+=1
    end
end
if count>0 then
    mark("PASS",string.format("%d avatares autorizáveis para V2PedestrianPreviews",count))
else
    mark("WARN","nenhum avatar NPC funcional; pedestres ambientados ficam desativados")
end
for _,modelName in ipairs({"Veiculo_Hatch_MG3","Veiculo_Sedan_Civic","Veiculo_Picape_S10"}) do
    local car=veiculos and veiculos:FindFirstChild(modelName)
    if car and car:IsA("Model") and car.PrimaryPart then
        mark("PASS","template de tráfego: "..modelName)
    else
        mark("WARN","carro do tráfego não importado: "..modelName)
    end
end
local cars,peds=0,0
for _,r in ipairs(Rules.Routes) do
    if r.Kind=="Vehicle" then
        cars+=1
        if math.abs(r.From.Z)>12 and math.abs(r.From.X-220)>20 then
            mark("WARN","veículo fora do corredor esperado: "..r.Id)
        end
    else
        peds+=1
    end
end
mark("PASS",string.format("%d rotas veiculares e %d faixas de pedestres",cars,peds))
local mobile=Rules.Budget(true,28,10)
mark("PASS",string.format(
    "limite mobile em fps baixo: até %d pedestrians/%d vehicles, intervalo %.2fs",
    mobile.Pedestrian,mobile.Vehicle,mobile.Tick))
mark("WARN","executar Play/Start com público real; confirmar movimento, curva, LOD, FPS e ausência de sobreposição no Studio")
return table.concat(lines,"\n")
