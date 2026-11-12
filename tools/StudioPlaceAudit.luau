-- Auditoria executável no Roblox Studio (Edit). Sem modificar modelos, dados ou mapa.
-- Uso: incluir na suíte RunAllTests; FAIL indica bloqueio de integração e WARN exige revisão manual.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Evidence = require(ReplicatedStorage.Shared.DiagnosisEvidence)
local Procedures = require(ReplicatedStorage.Shared.WorkshopProcedures)
local Operations = require(ReplicatedStorage.Shared.RepairOperations)
local output = {}
local function check(label, ok)
	table.insert(output, (ok and "PASS " or "FAIL ") .. label)
end
local function warn(label)
	table.insert(output, "WARN " .. label)
end
local shared = ReplicatedStorage:FindFirstChild("Shared")
check("Shared replicado", shared ~= nil)
local server = game:GetService("ServerScriptService"):FindFirstChild("Server")
check("servicos do servidor presentes", server ~= nil and server:FindFirstChild("WorkshopService") ~= nil)
local tools = ServerStorage:FindFirstChild("Tools")
check("testes montados no ServerStorage", tools ~= nil and tools:FindFirstChild("RunAllTests") ~= nil)
local worldPlots = workspace:FindFirstChild("Plots")
check("terrenos fisicos de oficina", worldPlots ~= nil and #worldPlots:GetChildren() >= 1)
local areas = workspace:FindFirstChild("PublicAreas")
check("loja publica de autopecas", areas ~= nil and areas:FindFirstChild("LojaAutopecas") ~= nil)
check("construtora fisica", areas ~= nil and areas:FindFirstChild("DistribuidoraEquipamentos") ~= nil)
local assets = ServerStorage:FindFirstChild("Assets")
check("pasta de assets privados", assets ~= nil)
local vehicles = assets and assets:FindFirstChild("Veiculos")
check("biblioteca de modelos de veiculos", vehicles ~= nil)
local customers = assets and assets:FindFirstChild("Clientes")
check("biblioteca de NPCs clientes", customers ~= nil)
local validCustomers = 0
if customers then
	for _, model in ipairs(customers:GetChildren()) do
		if model:IsA("Model") and model.PrimaryPart and model:FindFirstChildOfClass("Humanoid") then
			validCustomers += 1
		end
	end
end
check("ao menos um cliente NPC funcional", validCustomers >= 1)
local listed = 0
local missing = 0
for name, assetName in pairs(Catalog.VehicleModels) do
	listed += 1
	local model = vehicles and vehicles:FindFirstChild(assetName)
	local good = model ~= nil and model:IsA("Model") and model.PrimaryPart ~= nil
	if not good then
		missing += 1
		warn("modelo ausente ou sem PrimaryPart: " .. tostring(name) .. " -> " .. assetName)
	end
end
check("todos modelos do catalogo disponíveis: " .. tostring(listed - missing) .. "/" .. tostring(listed), missing == 0)
local embeddedScripts = {}
if assets then
	for _, item in ipairs(assets:GetDescendants()) do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then
			table.insert(embeddedScripts, item:GetFullName())
		end
	end
end
check("modelos importados sem scripts embutidos", #embeddedScripts == 0)
for i = 1, math.min(#embeddedScripts, 10) do warn("script em asset: " .. embeddedScripts[i]) end
local covered, missingEvidence = Evidence.Coverage()
check("15 defeitos com exame específico", covered == 15 and #missingEvidence == 0)
local planned, missingPlans = Procedures.Coverage()
check("15 defeitos com receita", planned == 15 and #missingPlans == 0)
local allPlans = true
for defectId in pairs(Catalog.Defects) do
	local plan = Operations.BuildPlan(defectId, 12)
	allPlans = allPlans and plan ~= nil and plan.Kind == "Operations"
end
check("todos defeitos com operação, sem minijogo genérico", allPlans)
warn("Revisar manualmente licenças dos sprites, miniaturas, 3D e créditos CC BY antes de publicar.")
warn("Homologar em dois jogadores, celular real, DataStore de homologação e FPS/StreamingEnabled.")
return table.concat(output, "\n")
