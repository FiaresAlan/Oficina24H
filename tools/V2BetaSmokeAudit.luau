-- V2-16: observações estruturais do place real no Studio Edit/Play.
-- Não teleporta players, não paga reparos, não altera DataStore nem
-- habilita test-drives opcionais. PASS aqui != autorização de release.
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local Workspace=game:GetService("Workspace")
local Catalog=require(ReplicatedStorage.Shared.Catalog)
local ReleaseRules=require(ReplicatedStorage.Shared.V2ReleaseGateRules)
local DriveScenario=require(ReplicatedStorage.Shared.V2DriveScenarioRules)
local Credits=require(ReplicatedStorage.Shared.V2Credits)
local out={}
local function check(name,ok)
    table.insert(out,(ok and "PASS " or "FAIL ")..name)
end
local function note(name)
    table.insert(out,"WARN "..name)
end
check("QA V2-16 executada dentro do Roblox Studio",RunService:IsStudio())
check("matriz técnica do release possui 16 gates",
    #ReleaseRules.Gates==16)
check("sem registros do operador o release é BLOQUEADO",
    not ReleaseRules.Evaluate(ReleaseRules.NewEvidence(),
        string.rep("a",40)).Approved)
local count=0
for _ in pairs(Catalog.Defects) do count+=1 end
check("15 defeitos continuam carregados na versão executável",count==15)
check("registro de fontes e pendências de licenças disponível",
    #Credits.Validate()==0 and #Credits.Pending>=4)
local tools=ServerStorage:FindFirstChild("Tools")
local runner=tools and tools:FindFirstChild("RunAllTests")
check("runner Studio Edit está disponível",
    runner~=nil and runner:IsA("ModuleScript"))
check("auditoria estrutural do place disponível",
    tools~=nil and tools:FindFirstChild("StudioPlaceAudit")~=nil)
check("gate opcional test-drive 12/13 não foi ativado silenciosamente",
    DriveScenario.LiveEnabled==false)
local assets=ServerStorage:FindFirstChild("Assets")
local vehicles=assets and assets:FindFirstChild("Veiculos")
local customers=assets and assets:FindFirstChild("Clientes")
if not assets or not vehicles or not customers then
    note("Biblioteca de assets do place incompleta; importar 21 veículos, clientes e equipamentos e reexecutar StudioPlaceAudit.")
else
    local numVehicles,numCustomers=0,0
    for _,model in ipairs(vehicles:GetChildren()) do
        if model:IsA("Model") then numVehicles+=1 end
    end
    for _,model in ipairs(customers:GetChildren()) do
        if model:IsA("Model") then numCustomers+=1 end
    end
    note(string.format("Assets locais observados: %d modelos de carro, %d clientes; StudioPlaceAudit define validade.",
        numVehicles,numCustomers))
    if numVehicles<21 then
        note("Faltam carros (mínimo 21) no place final. TESTE DE RELEASE BLOQUEADO.")
    end
end
if not Workspace.StreamingEnabled then
    note("StreamingEnabled não está ativado no place. Medir e configurar no Studio.")
end
local remoteFolder=ReplicatedStorage:FindFirstChild("OficinaRemotes")
if RunService:IsRunning() then
    check("RemoteEvent e GetSnapshot criados ao rodar servidor",
        remoteFolder and remoteFolder:FindFirstChild("Action")
            and remoteFolder:FindFirstChild("GetSnapshot")
            and remoteFolder:FindFirstChild("DriveInput"))
    if #Players:GetPlayers()<2 then
        note("Apenas "..tostring(#Players:GetPlayers())..
            " jogador(es) em Play: iniciar Start Server com 2 jogadores.")
    end
else
    note("Auditoria em Edit: remotes, comportamento de jogador e DataStore requerem Play/Start Server.")
end
local rigs=0
local rigsFolder=Workspace:FindFirstChild("V2DriveCars")
for _,m in ipairs(rigsFolder and rigsFolder:GetChildren() or {}) do
    if m:IsA("Model") and m:GetAttribute("V2Drive")==true then
        rigs+=1
    end
end
check("número de Hatch físicos não ultrapassa limite global",
    rigs<=5)
note("Testes manuais ainda obrigatórios: 15 OS, loja, 2 jogadores, Save falho, touch/gamepad, FPS e auditoria de licenças.")
note("Nenhum teste deste módulo cria prova no GitHub nem pode aprovar a publicação.")
return table.concat(out,"\n")
