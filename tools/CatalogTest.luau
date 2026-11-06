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
	check("equipamento " .. id .. ": espaço (slot) definido", EquipmentService.GetSlot(id) ~= nil)
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
check("variedade de serviços cresce com equipamento", varietyFor(allEquip) > varietyFor(newEquip), varietyFor(allEquip) .. "/" .. varietyFor(newEquip))

-- Todo equipamento comprável libera pelo menos um serviço (senão seria dinheiro jogado fora)
local used = {}
for _, d in pairs(Catalog.Defects) do used[d.RequiredEquipment] = true end
for id, e in pairs(Catalog.Equipment) do
	if e.Cost > 0 then check("equipamento " .. id .. " é exigido por algum defeito", used[id] == true) end
end

-- Dois slots nunca no mesmo lugar
local seen = {}
for id in pairs(Catalog.Equipment) do
	local s = EquipmentService.GetSlot(id)
	if s then
		local key = s.x .. "," .. s.z
		check("slot de " .. id .. " é único", seen[key] == nil, key)
		seen[key] = id
	end
end

-- Layout: vagas dentro do prédio, equipamentos sem sobreposição entre si nem com vagas, os internos dentro das paredes
do
	local Layout = require(sharedClone.Layout)
	local function rect(cx, cz, w, d) return { x0 = cx - w / 2, x1 = cx + w / 2, z0 = cz - d / 2, z1 = cz + d / 2 } end
	local function overlap(a, b) return a.x0 < b.x1 and b.x0 < a.x1 and a.z0 < b.z1 and b.z0 < a.z1 end
	local I = Layout.Interior
	local rects = {}
	for i, bay in ipairs(Layout.Bays) do
		local r = rect(bay.x, bay.z, bay.w, bay.d)
		check("vaga " .. i .. " dentro do prédio", r.x0 >= I.x0 and r.x1 <= I.x1 and r.z0 >= I.z0 and r.z1 <= I.z1)
		for _, other in ipairs(rects) do check("vagas não se sobrepõem", not overlap(r, other.r)) end
		table.insert(rects, { id = "vaga" .. i, r = r })
	end
	for id in pairs(Catalog.Equipment) do
		local s = Layout.Slots[id]
		local model = s and EquipmentModels.Build(id)
		if s and model then
			local cf, size = model:GetBoundingBox()
			local off = cf.Position - model:GetPivot().Position
			local rotated = math.abs(s.rot) % 180 == 90
			local w, d = rotated and size.Z or size.X, rotated and size.X or size.Z
			local ox, oz = off.X, off.Z
			if rotated then ox, oz = off.Z, off.X end
			local r = rect(s.x + ox, s.z + oz, w, d)
			local inside = r.x0 >= I.x0 - 0.01 and r.x1 <= I.x1 + 0.01 and r.z0 >= I.z0 and r.z1 <= I.z1
			local isOutside = r.x1 < -22.5 or r.x0 > 22.5 or r.z1 < 4.5 or r.z0 > 35.5
			check("equipamento " .. id .. " totalmente dentro ou totalmente fora do prédio", inside or isOutside, string.format("x %.1f..%.1f z %.1f..%.1f", r.x0, r.x1, r.z0, r.z1))
			for _, other in ipairs(rects) do
				check("equipamento " .. id .. " não bate em " .. other.id, not overlap(r, other.r))
			end
			table.insert(rects, { id = id, r = r })
			model:Destroy()
		end
	end
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
sharedClone:Destroy()
serverClone:Destroy()
table.insert(results, string.format("defeitos=%d", defectCount))
table.insert(results, failures == 0 and "TODOS OS TESTES PASSARAM" or (failures .. " TESTE(S) FALHARAM"))
return table.concat(results, "\n")
