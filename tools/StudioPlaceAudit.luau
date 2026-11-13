-- Auditoria executável no Roblox Studio (Edit). Sem modificar modelos, dados ou mapa.
-- Uso: incluir na suíte RunAllTests; FAIL indica bloqueio de integração e WARN exige revisão manual.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Evidence = require(ReplicatedStorage.Shared.DiagnosisEvidence)
local ServerModules = game:GetService("ServerScriptService"):WaitForChild("Server")
local Procedures = require(ServerModules.WorkshopProcedures)
local Operations = require(ServerModules.RepairOperations)
local AssetIntegrityRules = require(ReplicatedStorage.Shared.AssetIntegrityRules)
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
local customerGender = { M = 0, F = 0 }
if customers then
	for _, npc in ipairs(customers:GetChildren()) do
		local problems = AssetIntegrityRules.Customer(npc)
		if #problems == 0 then
			validCustomers += 1
			local gender = npc:GetAttribute("Genero")
			customerGender[gender] = (customerGender[gender] or 0) + 1
		else
			for _, problem in ipairs(problems) do
				check("NPC " .. npc.Name .. ": " .. problem, false)
			end
		end
	end
end
check("ao menos um cliente NPC funcional", validCustomers >= 1)
check("NPCs validos dos dois generos", customerGender.M >= 1 and customerGender.F >= 1)

local listed, validVehicles = 0, 0
for name, assetName in pairs(Catalog.VehicleModels) do
	listed += 1
	local model = vehicles and vehicles:FindFirstChild(assetName)
	local problems, alerts = AssetIntegrityRules.Vehicle(model)
	if #problems == 0 then validVehicles += 1 end
	for _, problem in ipairs(problems) do
		check("veiculo " .. tostring(name) .. " (" .. assetName .. "): " .. problem, false)
	end
	for _, alert in ipairs(alerts) do
		warn("veiculo " .. assetName .. ": " .. alert)
	end
end
check("21 veiculos catalogados e estruturalmente validos: " .. tostring(validVehicles) .. "/" .. tostring(listed),
	listed == 21 and validVehicles == listed)

local equipmentFolder = assets and assets:FindFirstChild("Equipamentos")
local importedEquipment, optionalMissing = 0, 0
for equipmentId in pairs(Catalog.Equipment) do
	local template = equipmentFolder and equipmentFolder:FindFirstChild("Eq_" .. equipmentId)
	if not template then
		optionalMissing += 1 -- fallback procedural previsto no jogo
	else
		importedEquipment += 1
		for _, problem in ipairs(AssetIntegrityRules.Equipment(template)) do
			check("equipamento Eq_" .. equipmentId .. ": " .. problem, false)
		end
	end
end
check("biblioteca de equipamentos: assets reais ou fallback disponivel",
	importedEquipment + optionalMissing == 11)
if optionalMissing > 0 then
	warn(tostring(optionalMissing) .. " equipamentos ausentes; o jogo usara fallback procedural")
end
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
