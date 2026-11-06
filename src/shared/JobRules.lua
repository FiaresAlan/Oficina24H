--!strict
-- Regras puras (sem acesso ao jogo) para escolher qual defeito o próximo cliente traz.
-- Objetivo: a oficina atrai principalmente serviços que ela consegue fazer, com uma parte "aspiracional"
-- que motiva comprar equipamento ou subir de nível. Pura = testável sem jogadores (tools/CatalogTest.luau).
local Catalog = require(script.Parent.Catalog)

local JobRules = {}

-- Peso de um defeito para esta oficina.
function JobRules.Weight(defect: any, skillLevels: { [string]: number }, equipment: { [string]: boolean }): number
	local level = skillLevels[defect.Specialization] or 1
	local levelOk = level >= defect.RequiredLevel
	local equipOk = equipment[defect.RequiredEquipment] == true
	local near = level + 1 >= defect.RequiredLevel
	if levelOk and equipOk then
		return 6 -- serviço que ela já sabe e pode fazer
	elseif levelOk then
		return 2.5 -- falta equipamento: incentiva a compra
	elseif equipOk then
		return near and 2 or 0.6 -- falta pouco de nível: incentiva a evoluir
	else
		return near and 0.8 or 0.3
	end
end

-- rand() deve devolver um número em [0, 1). Iteração em ordem alfabética: resultado determinístico para um dado rand.
function JobRules.PickDefectId(skillLevels: { [string]: number }, equipment: { [string]: boolean }, rand: () -> number, specialization: string?): string
	local ids = {}
	for id, defect in pairs(Catalog.Defects) do
		-- Com `specialization`, só defeitos dessa área (o cliente procurou um especialista nela).
		if specialization == nil or defect.Specialization == specialization then
			table.insert(ids, id)
		end
	end
	if #ids == 0 then
		for id in pairs(Catalog.Defects) do
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local total = 0
	local weights = {}
	for i, id in ipairs(ids) do
		weights[i] = JobRules.Weight(Catalog.Defects[id], skillLevels, equipment)
		total += weights[i]
	end
	local roll = rand() * total
	for i, id in ipairs(ids) do
		roll -= weights[i]
		if roll < 0 then
			return id
		end
	end
	return ids[#ids]
end

-- Quantos defeitos da especialização a oficina consegue atender agora (nível e equipamento).
function JobRules.ServiceableCountIn(specialization: string, skillLevels: { [string]: number }, equipment: { [string]: boolean }): number
	local n = 0
	for _, defect in pairs(Catalog.Defects) do
		if defect.Specialization == specialization
			and (skillLevels[specialization] or 1) >= defect.RequiredLevel
			and equipment[defect.RequiredEquipment] == true then
			n += 1
		end
	end
	return n
end

-- Parcela esperada de clientes que a oficina consegue atender agora (nível e equipamento).
function JobRules.ServiceableShare(skillLevels: { [string]: number }, equipment: { [string]: boolean }): number
	local total, ok = 0, 0
	for _, defect in pairs(Catalog.Defects) do
		local w = JobRules.Weight(defect, skillLevels, equipment)
		total += w
		if (skillLevels[defect.Specialization] or 1) >= defect.RequiredLevel and equipment[defect.RequiredEquipment] == true then
			ok += w
		end
	end
	return total > 0 and ok / total or 0
end

return JobRules
