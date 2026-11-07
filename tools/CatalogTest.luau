-- Consistência dos dados do jogo (Catalog) e dos modelos de equipamento. Rodar no Edit via MCP.
-- Clona as pastas para ter instâncias novas: o cache do require no Edit guarda versões antigas dos módulos.
local ServerStorage = game:GetService("ServerStorage")
local sharedClone = game.ReplicatedStorage.Shared:Clone()
sharedClone.Parent = ServerStorage
local serverClone = game.ServerScriptService.Server:Clone()
serverClone.Parent = ServerStorage
local Catalog = require(sharedClone.Catalog)
local Locale = require(sharedClone.Locale)
local EquipmentModels = require(serverClone.EquipmentModels)
local EquipmentService = require(serverClone.EquipmentService)

local results, failures = {}, 0
local function check(name, cond, detail)
	if not cond then failures += 1 end
	table.insert(results, (cond and "PASS " or "FAIL ") .. name .. (cond and "" or (" -> " .. tostring(detail))))
end

local specs = {}
for _, s in ipairs(Catalog.Specializations) do specs[s] = 0 end

local defectCount = 0
for id, d in pairs(Catalog.Defects) do
	defectCount += 1
	local svc = Catalog.Services[d.ServiceId]
	check("defeito " .. id .. ": serviço existe", svc ~= nil, d.ServiceId)
	check("defeito " .. id .. ": serviço aponta de volta", svc and svc.DefectId == id, svc and svc.DefectId)
	check("defeito " .. id .. ": equipamento existe", Catalog.Equipment[d.RequiredEquipment] ~= nil, d.RequiredEquipment)
	check("defeito " .. id .. ": especialização válida", specs[d.Specialization] ~= nil, d.Specialization)
	check("defeito " .. id .. ": nível >= 1", d.RequiredLevel >= 1)
	if specs[d.Specialization] then specs[d.Specialization] += 1 end
	if svc then
		check("serviço " .. d.ServiceId .. ": valores positivos", svc.Reward > 0 and svc.XP > 0 and svc.Reputation >= 0)
	end
end
for s, n in pairs(specs) do
	check("especialização " .. s .. " tem serviços", n >= 1, n)
	check("texto da especialização " .. s .. " existe", Locale.t("spec_" .. s) ~= "spec_" .. s)
end
for id, e in pairs(Catalog.Equipment) do
	check("equipamento " .. id .. ": custo >= 0", e.Cost >= 0)
	check("equipamento " .. id .. ": modelo físico existe", EquipmentModels.Has(id))
	check("equipamento " .. id .. ": tem lugar na ordem da sala dos fundos", table.find(EquipmentService.Order, id) ~= nil)
end

-- Peças: existem, têm custo, e o serviço dá margem (receita >= 1,5x o custo das peças)
for id, d in pairs(Catalog.Defects) do
	local cost = 0
	for partId, count in pairs(d.Parts or {}) do
		check("defeito " .. id .. ": peça " .. partId .. " existe", Catalog.Parts[partId] ~= nil)
		check("defeito " .. id .. ": quantidade de " .. partId .. " positiva", count >= 1 and count == math.floor(count))
		if Catalog.Parts[partId] then cost += Catalog.Parts[partId].Cost * count end
	end
	local svc = Catalog.Services[d.ServiceId]
	if svc then check("defeito " .. id .. ": margem sobre peças", svc.Reward >= cost * 1.5, svc.Reward .. " vs " .. cost) end
end
local partUsed = {}
for _, d in pairs(Catalog.Defects) do for partId in pairs(d.Parts or {}) do partUsed[partId] = true end end
for partId, p in pairs(Catalog.Parts) do
	check("peça " .. partId .. ": custo positivo", p.Cost > 0)
	check("peça " .. partId .. ": usada por algum defeito", partUsed[partId] == true)
end

-- Geração de clientes (JobRules): novo jogador recebe maioria atendível; todo defeito continua possível
local JobRules = require(sharedClone.JobRules)
local newLevels, newEquip = {}, { BasicToolset = true }
for _, s in ipairs(Catalog.Specializations) do newLevels[s] = 1 end
local rng = Random.new(7)
local picked, serviceable, N = {}, 0, 4000
for _ = 1, N do
	local id = JobRules.PickDefectId(newLevels, newEquip, function() return rng:NextNumber() end)
	picked[id] = (picked[id] or 0) + 1
	local d = Catalog.Defects[id]
	if d.RequiredLevel <= 1 and newEquip[d.RequiredEquipment] then serviceable += 1 end
end
check("novo jogador: >= 50% dos clientes atendíveis", serviceable / N >= 0.5, serviceable / N)
check("novo jogador: <= 85% atendíveis (ainda há desafio)", serviceable / N <= 0.85, serviceable / N)
for id in pairs(Catalog.Defects) do
	check("defeito " .. id .. " pode aparecer para novo jogador", (picked[id] or 0) > 0)
end
local maxLevels = {}
for _, s in ipairs(Catalog.Specializations) do maxLevels[s] = 9 end
local allEquip = {}
for id in pairs(Catalog.Equipment) do allEquip[id] = true end
check("oficina completa: 100% atendível", math.abs(JobRules.ServiceableShare(maxLevels, allEquip) - 1) < 1e-9)
-- (a "parcela" atendível não cresce necessariamente: o gerador só sorteia defeitos compatíveis; o que cresce é a variedade)
local function varietyFor(equip: { [string]: boolean }): number
	local n = 0
	for _, d in pairs(Catalog.Defects) do
		if d.RequiredLevel <= 1 and equip[d.RequiredEquipment] then n += 1 end
	end
	return n
end
local function tierAt(total: number): number
	local t = Catalog.WorkshopTier(total)
	return t
end
check("tipo de oficina: níveis 1-3 = bairro, 4-6 = centro, 7+ = premium",
	tierAt(0) == 1 and tierAt(899) == 1 and tierAt(900) == 2 and tierAt(3599) == 2 and tierAt(3600) == 3 and tierAt(1e9) == 3,
	tierAt(0) .. "/" .. tierAt(899) .. "/" .. tierAt(900) .. "/" .. tierAt(3600))
check("tipo de oficina: nunca diminui com mais ganhos", (function()
	local last = 0
	for total = 0, 20000, 50 do
		local t = tierAt(total)
		if t < last then return false end
		last = t
	end
	return true
end)())
check("tipo de oficina: nome por tipo", select(2, Catalog.WorkshopTier(0)) == "Oficina de bairro" and select(2, Catalog.WorkshopTier(5000)) == "Oficina premium")
check("tipo de oficina: dados inválidos não quebram", tierAt(-5) == 1 and tierAt(0 / 0) >= 1)
check("variedade de serviços cresce com equipamento", varietyFor(allEquip) > varietyFor(newEquip), varietyFor(allEquip) .. "/" .. varietyFor(newEquip))

-- Todo equipamento comprável libera pelo menos um serviço (senão seria dinheiro jogado fora)
local used = {}
for _, d in pairs(Catalog.Defects) do used[d.RequiredEquipment] = true end
for id, e in pairs(Catalog.Equipment) do
	if e.Cost > 0 then check("equipamento " .. id .. " é exigido por algum defeito", used[id] == true) end
end

-- Níveis da oficina (shared/WorkshopLevels): 1/2/4/6 boxes, prédios cada vez maiores, requisitos crescentes,
-- equipamentos cabendo na sala dos fundos, nada no caminho dos carros
do
	local WL = require(sharedClone.WorkshopLevels)
	local Config = require(sharedClone.Config)
	local expected = { [0] = 1, [1] = 2, [2] = 4, [3] = 6 }
	local prevWidth, prevCost = 0, -1
	for level = 0, WL.MaxLevel do
		local L = WL.Levels[level]
		check("nível " .. level .. ": " .. expected[level] .. " boxes", #L.Bays == expected[level], #L.Bays)
		check("nível " .. level .. ": prédio maior que o anterior", L.X1 - L.X0 > prevWidth, L.X1 - L.X0)
		check("nível " .. level .. ": custa mais que o anterior", L.Cost > prevCost, L.Cost)
		prevWidth, prevCost = L.X1 - L.X0, L.Cost
		check("nível " .. level .. ": prédio dentro do lote", L.X0 >= -45 and L.X1 <= 45)
		local half = WL.BayWidth / 2
		for i, x in ipairs(L.Bays) do
			check(string.format("nível %d box %d dentro do prédio", level, i), x - half >= L.X0 + 1 and x + half <= L.X1 - 1)
			check(string.format("nível %d box %d alcançável pelo pátio", level, i), x + 2 * WL.YardTurn <= WL.GateIn and x - WL.YardTurn <= WL.GateOut - WL.YardTurn)
			for j, y in ipairs(L.Bays) do
				if j > i then
					check(string.format("nível %d boxes %d e %d não se sobrepõem", level, i, j), math.abs(x - y) >= WL.BayWidth + 1)
				end
			end
		end
		local slots = WL.EquipmentSlots(level)
		check("nível " .. level .. ": cabe pelo menos o pedido para o próximo nível", level == WL.MaxLevel or #slots >= WL.Levels[level + 1].MinEquipment, #slots)
		check("nível " .. level .. ": sala dos fundos atrás dos boxes", WL.EquipmentZ - 3 > WL.BayZ + WL.BayDepth / 2)
	end
	check("nível máximo cabe todos os equipamentos", WL.MaxEquipment(WL.MaxLevel) >= #EquipmentService.Order)
	check("funcionários só a partir do nível 2", WL.Levels[0].MaxEmployees == 0 and WL.Levels[1].MaxEmployees == 0 and WL.Levels[2].MaxEmployees >= 1)
	check("limite de funcionários do jogo cobre o maior prédio", Config.MaxEmployees >= WL.Levels[WL.MaxLevel].MaxEmployees)
	-- requisitos: com tudo zerado não compra; com tudo no mínimo compra; faltando uma coisa não compra
	local L1 = WL.Levels[1]
	local enough = { Coins = L1.Cost, BusinessLevel = L1.MinBusinessLevel, Reputation = L1.MinReputation, SkillTotal = L1.MinSkillTotal, Equipment = L1.MinEquipment }
	check("Check: requisitos mínimos compram", (WL.Check(1, enough)))
	local missing = table.clone(enough)
	missing.Reputation -= 1
	check("Check: faltando reputação não compra", not (WL.Check(1, missing)))
	check("Check: tudo zerado não compra", not (WL.Check(2, { Coins = 0, BusinessLevel = 1, Reputation = 0, SkillTotal = 5, Equipment = 1 })))
	-- placa 3D fora dos portões e das fileiras do pátio
	local Layout = require(sharedClone.Layout)
	local S = Layout.Sign
	check("placa 3D longe dos portões", S.x + 8 < WL.GateOut - 4.4)
	check("placa 3D abaixo da fileira de saída", S.z + 1.5 < WL.ExitRowZ - 4.4)
	check("funcionário: salário e contratação positivos", Config.EmployeeSalary > 0 and Config.EmployeeHireCost > 0)
	check("rivais sempre deixam lote livre", Config.RivalKeepFreePlots >= 1)
end

-- Modelos constroem sem erro e apoiados no piso (y=0 local)
for id in pairs(Catalog.Equipment) do
	local ok, model = pcall(EquipmentModels.Build, id)
	check("modelo " .. id .. " constrói", ok and model ~= nil, model)
	if ok and model then
		local cf, size = model:GetBoundingBox()
		check("modelo " .. id .. " apoiado no piso", math.abs(cf.Position.Y - size.Y / 2) < 0.5, cf.Position.Y - size.Y / 2)
		model:Destroy()
	end
end

-- Progressão: toda especialização tem ao menos um serviço de nível 1 (o XP é por especialização: sem isso ela nunca sobe)
for _, specialization in ipairs(Catalog.Specializations) do
	local hasStarter = false
	for _, defect in pairs(Catalog.Defects) do
		if defect.Specialization == specialization and defect.RequiredLevel <= 1 then hasStarter = true end
	end
	check("especialização " .. specialization .. " tem serviço de nível 1", hasStarter)
end

-- Categorias derivadas e modelos 3D das peças (miniaturas da Loja e do Estoque)
do
	local PartModels = require(sharedClone.PartModels)
	local order = {}
	for _, category in ipairs(Catalog.CategoryOrder) do order[category] = true end
	for partId in pairs(Catalog.Parts) do
		check("peça " .. partId .. ": categoria válida", order[Catalog.PartCategory[partId]] == true, Catalog.PartCategory[partId])
		local ok, model = pcall(PartModels.Build, partId)
		check("peça " .. partId .. ": modelo 3D constrói", ok and model ~= nil, model)
		if ok and model then
			local _, size = model:GetBoundingBox()
			check("peça " .. partId .. ": modelo com tamanho útil", math.max(size.X, size.Y, size.Z) > 1 and math.max(size.X, size.Y, size.Z) < 8, size)
			model:Destroy()
		end
	end
	for equipmentId in pairs(Catalog.Equipment) do
		check("equipamento " .. equipmentId .. ": categoria válida", order[Catalog.EquipmentCategory[equipmentId]] == true)
	end
	for _, name in ipairs(Catalog.VehicleNames) do
		check("veículo " .. name .. ": modelo definido", Catalog.VehicleModels[name] ~= nil)
	end
end

check("níveis empresariais crescem", Catalog.BusinessLevel(0) == 1 and Catalog.BusinessLevel(10000) > Catalog.BusinessLevel(100))
do
	local level, total, startOfLevel, nextLevel = Catalog.BusinessProgress(2250)
	check("progresso de nível: coerente com BusinessLevel", level == Catalog.BusinessLevel(2250) and total == 2250)
	check("progresso de nível: total entre início e próximo", total >= startOfLevel and total < nextLevel, startOfLevel .. "/" .. nextLevel)
	local l0, t0, s0, n0 = Catalog.BusinessProgress(0)
	check("progresso de nível: zero", l0 == 1 and t0 == 0 and s0 == 0 and n0 == 100)
	check("progresso de nível: negativo vira zero", select(2, Catalog.BusinessProgress(-50)) == 0)
	check("nomes de clientes definidos", #Catalog.CustomerNames >= 8)
end

-- Clientes: nome combina com o gênero (listas separadas, sem nome repetido entre elas) e há modelo para cada gênero
do
	local male = {}
	for _, n in ipairs(Catalog.CustomerNamesMale) do male[n] = true end
	local clash = 0
	for _, n in ipairs(Catalog.CustomerNamesFemale) do if male[n] then clash += 1 end end
	check("nomes masculinos e femininos não se repetem", clash == 0, clash)
	local okPick = true
	for _ = 1, 200 do
		local gender, name = Catalog.PickCustomer()
		local list = gender == "M" and Catalog.CustomerNamesMale or Catalog.CustomerNamesFemale
		if (gender ~= "M" and gender ~= "F") or not table.find(list, name) then okPick = false end
	end
	check("PickCustomer: nome sempre da lista do gênero sorteado", okPick)
	local clientes = game:GetService("ServerStorage"):FindFirstChild("Assets") and game.ServerStorage.Assets:FindFirstChild("Clientes")
	local count = { M = 0, F = 0 }
	for _, m in ipairs(clientes and clientes:GetChildren() or {}) do
		local g = m:GetAttribute("Genero")
		if count[g] then count[g] += 1 end
		local scripts = 0
		for _, d in ipairs(m:GetDescendants()) do if d:IsA("LuaSourceContainer") then scripts += 1 end end
		check("NPC " .. m.Name .. ": sem scripts", scripts == 0, scripts)
	end
	check("há NPCs masculinos e femininos", count.M >= 3 and count.F >= 3, count.M .. "/" .. count.F)
end

-- Veículos: todo nome tem modelo no ServerStorage com Raiz, Casco (colisão), banco do motorista e tamanho que cabe na vaga
do
	local WL = require(game.ReplicatedStorage.Shared.WorkshopLevels)
	local bay = { w = WL.BayWidth, d = WL.BayDepth }
	local folder = game.ServerStorage:FindFirstChild("Assets") and game.ServerStorage.Assets:FindFirstChild("Veiculos")
	local all = table.clone(Catalog.VehicleNames)
	for _, n in ipairs(Catalog.VipVehicleNames) do table.insert(all, n) end
	for _, name in ipairs(all) do
		local model = folder and folder:FindFirstChild(Catalog.VehicleModels[name] or "")
		check("veículo " .. name .. ": modelo existe", model ~= nil, Catalog.VehicleModels[name])
		if model then
			local root = model.PrimaryPart
			local hull = model:FindFirstChild("Casco")
			check("veículo " .. name .. ": Raiz ancorada", root ~= nil and root.Name == "Raiz" and root.Anchored)
			check("veículo " .. name .. ": Casco com colisão", hull ~= nil and hull:IsA("BasePart") and hull.CanCollide)
			check("veículo " .. name .. ": banco do motorista", typeof(model:GetAttribute("Motorista")) == "Vector3")
			local L, W = model:GetAttribute("Comprimento") or 99, model:GetAttribute("Largura") or 99
			check("veículo " .. name .. ": cabe na vaga", L <= bay.d - 1 and W <= bay.w + 0.5, string.format("%.1f x %.1f", L, W))
			local scripts = 0
			for _, d in ipairs(model:GetDescendants()) do if d:IsA("LuaSourceContainer") then scripts += 1 end end
			check("veículo " .. name .. ": sem scripts", scripts == 0, scripts)
		end
	end
	for _, name in ipairs(Catalog.VipVehicleNames) do
		check("VIP " .. name .. " não aparece para cliente comum", table.find(Catalog.VehicleNames, name) == nil)
	end
end
sharedClone:Destroy()
serverClone:Destroy()
table.insert(results, string.format("defeitos=%d", defectCount))
table.insert(results, failures == 0 and "TODOS OS TESTES PASSARAM" or (failures .. " TESTE(S) FALHARAM"))
return table.concat(results, "\n")
