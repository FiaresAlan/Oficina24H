--!strict
-- Trabalho mecânico diversificado para os 12 defeitos que anteriormente só tinham o minijogo genérico.
-- Quatro famílias de interação: montagem sequencial, calibragem, circuito e acabamento de carroceria.
-- O cliente recebe apenas objetivos e controles; o servidor conserva os gabaritos.
local Catalog = require(script.Parent.Catalog)
local RepairRules = require(script.Parent.RepairRules)
local WorkshopProcedures = {}

local sequence: { [string]: { Hint: string, Steps: { { Id: string, Name: string } } } } = {
	WornTire = { Hint = "Substitua o par gasto respeitando a segurança do conjunto.",
		Steps = { { Id = "Lift", Name = "Elevar" }, { Id = "Loosen", Name = "Retirar rodas" },
			{ Id = "Fit", Name = "Montar pneus" }, { Id = "Balance", Name = "Balancear" } } },
	LooseSuspension = { Hint = "Encontre a folga e conclua o reaperto com verificação.",
		Steps = { { Id = "Support", Name = "Apoiar chassi" }, { Id = "Inspect", Name = "Inspecionar bucha" },
			{ Id = "Torque", Name = "Aplicar torque" }, { Id = "RoadTest", Name = "Testar carga" } } },
	BrakeWear = { Hint = "Troque as pastilhas com segurança e confira a resposta do pedal.",
		Steps = { { Id = "Lift", Name = "Elevar" }, { Id = "Caliper", Name = "Abrir pinça" },
			{ Id = "Pads", Name = "Substituir pastilhas" }, { Id = "BedIn", Name = "Assentar freio" } } },
	BrokenArm = { Hint = "Apoie a suspensão antes de soltar o componente estrutural.",
		Steps = { { Id = "Support", Name = "Apoiar" }, { Id = "RemoveArm", Name = "Remover braço" },
			{ Id = "InstallArm", Name = "Instalar braço" }, { Id = "Geometry", Name = "Conferir geometria" } } },
	EngineOverhaul = { Hint = "Uma retífica precisa de desmontagem, medição e teste de compressão.",
		Steps = { { Id = "Drain", Name = "Drenar fluidos" }, { Id = "Disassemble", Name = "Desmontar bloco" },
			{ Id = "Measure", Name = "Medir cilindros" }, { Id = "Rebuild", Name = "Remontar kit" },
			{ Id = "Compression", Name = "Testar compressão" } } },
}

local calibration: { [string]: { Hint: string, Fields: { any } } } = {
	WheelImbalance = { Hint = "Ajuste a massa de contrapeso e a posição na roda.",
		Fields = {
			{ Id = "Mass", Name = "Contrapeso", Unit = "g", Min = 0, Max = 70, Step = 5, Initial = 10, Target = 35, Tolerance = 5 },
			{ Id = "Angle", Name = "Ângulo de colocação", Unit = "°", Min = 0, Max = 180, Step = 15, Initial = 30, Target = 90, Tolerance = 15 },
		} },
	Misalignment = { Hint = "Corrija convergência e cambagem antes do teste de direção.",
		Fields = {
			{ Id = "Toe", Name = "Convergência", Unit = "°", Min = -2, Max = 2, Step = 0.25, Initial = 1.5, Target = 0, Tolerance = 0.25 },
			{ Id = "Camber", Name = "Cambagem", Unit = "°", Min = -3, Max = 1, Step = 0.25, Initial = -2, Target = -0.5, Tolerance = 0.25 },
		} },
}

local circuits: { [string]: { Hint: string, Sources: { { Id: string, Name: string } }, Actions: { { Id: string, Name: string } }, CorrectSource: string, CorrectAction: string } } = {
	EngineMisfire = { Hint = "Código P0302 e falha no cilindro 2. Escolha o circuito e o reparo adequado.",
		Sources = { { Id = "C1", Name = "Cil. 1" }, { Id = "C2", Name = "Cil. 2" }, { Id = "C3", Name = "Cil. 3" }, { Id = "C4", Name = "Cil. 4" } },
		Actions = { { Id = "Wire", Name = "Fiação" }, { Id = "Plug", Name = "Vela" }, { Id = "Fuel", Name = "Injetor" } },
		CorrectSource = "C2", CorrectAction = "Plug" },
	ElectricalFault = { Hint = "Alimentação interrompida no ramo de acessórios. Identifique o circuito e o fusível.",
		Sources = { { Id = "Lights", Name = "Faróis" }, { Id = "Accessories", Name = "Acessórios" }, { Id = "Starter", Name = "Partida" } },
		Actions = { { Id = "Relay", Name = "Relé" }, { Id = "Fuse", Name = "Fusível" }, { Id = "Motor", Name = "Atuador" } },
		CorrectSource = "Accessories", CorrectAction = "Fuse" },
}

local surfaces: { [string]: { Hint: string, Zones: { { Id: string, Name: string, Reading: string, Target: number } } } } = {
	Dent = { Hint = "Ajuste a intensidade de repuxo por região. Excesso de força ondula a chapa.",
		Zones = { { Id = "Top", Name = "Borda", Reading = "Amassado moderado", Target = 2 },
			{ Id = "Center", Name = "Centro", Reading = "Dobra profunda", Target = 3 },
			{ Id = "Bottom", Name = "Canto", Reading = "Marca superficial", Target = 1 } } },
	BodyDamage = { Hint = "Realinhe o painel: as regiões não recebem a mesma pressão.",
		Zones = { { Id = "Top", Name = "Longarina", Reading = "Deformação estrutural", Target = 3 },
			{ Id = "Center", Name = "Porta", Reading = "Deslocamento moderado", Target = 2 },
			{ Id = "Bottom", Name = "Guia", Reading = "Folga leve", Target = 1 } } },
	PaintJob = { Hint = "Uniformize as camadas; excesso de tinta pode escorrer.",
		Zones = { { Id = "Top", Name = "Capô", Reading = "Base exposta", Target = 3 },
			{ Id = "Center", Name = "Porta", Reading = "Verniz desgastado", Target = 2 },
			{ Id = "Bottom", Name = "Traseira", Reading = "Desgaste leve", Target = 1 } } },
}

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end
local function copyOptions(options: { any }): { any }
	local result = {}
	for _, value in ipairs(options) do table.insert(result, { Id = value.Id, Name = value.Name }) end
	return result
end
local function readIds(options: { any }): { string }
	local result = {}
	for _, option in ipairs(options) do table.insert(result, option.Id) end
	return result
end
local function shuffle(options: { any }, seed: number): { any }
	local result = copyOptions(options)
	local rng = Random.new(math.floor(math.abs(seed)) % 2147483646 + 1)
	for i = #result, 2, -1 do
		local j = rng:NextInteger(1, i)
		result[i], result[j] = result[j], result[i]
	end
	return result
end

function WorkshopProcedures.BuildPlan(defectId: string, seed: number): any?
	local seq = sequence[defectId]
	if seq then
		return {
			Kind = "Operations", Mode = "Sequence", DefectId = defectId,
			Hint = seq.Hint, Options = shuffle(seq.Steps, seed),
			Correct = readIds(seq.Steps), MinSeconds = #seq.Steps * 1.4,
		}
	end
	local cal = calibration[defectId]
	if cal then
		return { Kind = "Operations", Mode = "Calibration", DefectId = defectId,
			Hint = cal.Hint, Fields = cal.Fields, MinSeconds = 5 }
	end
	local circuit = circuits[defectId]
	if circuit then
		return { Kind = "Operations", Mode = "Circuit", DefectId = defectId,
			Hint = circuit.Hint, Sources = shuffle(circuit.Sources, seed), Actions = shuffle(circuit.Actions, seed + 71),
			CorrectSource = circuit.CorrectSource, CorrectAction = circuit.CorrectAction, MinSeconds = 5 }
	end
	local surface = surfaces[defectId]
	if surface then
		return { Kind = "Operations", Mode = "Surface", DefectId = defectId,
			Hint = surface.Hint, Zones = surface.Zones, MinSeconds = 5 }
	end
	return nil
end

-- Nunca enviar os campos Correct para o cliente, mesmo quando outros campos públicos coincidam.
function WorkshopProcedures.PublicPlan(plan: any): any
	if type(plan) ~= "table" or plan.Kind ~= "Operations" then return nil end
	local base: any = { Kind = "Operations", Mode = plan.Mode, Hint = plan.Hint, MinSeconds = plan.MinSeconds }
	if plan.Mode == "Sequence" then
		base.Options = copyOptions(plan.Options)
	elseif plan.Mode == "Calibration" then
		base.Fields = {}
		for _, field in ipairs(plan.Fields) do
			table.insert(base.Fields, {
				Id = field.Id, Name = field.Name, Unit = field.Unit,
				Min = field.Min, Max = field.Max, Step = field.Step,
				Initial = field.Initial, Target = field.Target,
			})
		end
	elseif plan.Mode == "Circuit" then
		base.Sources, base.Actions = copyOptions(plan.Sources), copyOptions(plan.Actions)
	elseif plan.Mode == "Surface" then
		base.Zones = {}
		for _, zone in ipairs(plan.Zones) do
			table.insert(base.Zones, { Id = zone.Id, Name = zone.Name, Reading = zone.Reading })
		end
	end
	return base
end

local function invalid(reason: string): any
	return { Valid = false, Reason = reason, Quality = 0,
		Perfect = 0, Good = 0, Miss = 0, Corrected = 0, Uncorrected = 0,
		Breakdown = { Execution = 0, Errors = 0, Skill = 0, Equipment = 0, Part = 0, Diagnosis = 0 } }
end
local function hasOption(options: { any }, value: any): boolean
	if type(value) ~= "string" then return false end
	for _, option in ipairs(options) do
		if option.Id == value then return true end
	end
	return false
end

function WorkshopProcedures.Evaluate(plan: any, input: any, elapsed: number, mods: RepairRules.Mods): any
	if type(plan) ~= "table" or plan.Kind ~= "Operations" or type(input) ~= "table" then
		return invalid("plano ou ações inválidas")
	end
	if not finite(elapsed) or elapsed < plan.MinSeconds or elapsed > RepairRules.MaxSessionSeconds then
		return invalid("tempo incompatível com o procedimento")
	end
	local successes, errors, execution, count = 0, 0, 0, 0
	if plan.Mode == "Sequence" then
		if type(input.Steps) ~= "table" or #input.Steps ~= #plan.Correct then return invalid("etapas incompletas") end
		local seen = {}
		count = #plan.Correct
		local received = 0
		for index, id in ipairs(input.Steps) do
			if not hasOption(plan.Options, id) or seen[id] then return invalid("sequência adulterada") end
			seen[id] = true
			received += 1
			if id == plan.Correct[index] then successes += 1 end
		end
		if received ~= count then return invalid("etapas ausentes") end
		execution = successes / count * 100
	elseif plan.Mode == "Calibration" then
		if type(input.Values) ~= "table" then return invalid("medidas ausentes") end
		count = #plan.Fields
		local sum = 0
		for _, field in ipairs(plan.Fields) do
			local value = input.Values[field.Id]
			if not finite(value) or value < field.Min or value > field.Max then
				return invalid("medida fora do instrumento")
			end
			local units = (value - field.Min) / field.Step
			if math.abs(units - math.round(units)) > 0.001 then
				return invalid("medida fora do passo permitido")
			end
			local delta = math.abs(value - field.Target)
			if delta <= field.Tolerance then successes += 1 end
			sum += math.max(0, 100 - delta / field.Tolerance * 28)
		end
		execution = sum / count
	elseif plan.Mode == "Circuit" then
		if not hasOption(plan.Sources, input.Source) or not hasOption(plan.Actions, input.Action) then
			return invalid("ramo ou componente inválido")
		end
		count = 2
		successes = (input.Source == plan.CorrectSource and 1 or 0)
			+ (input.Action == plan.CorrectAction and 1 or 0)
		execution = successes * 50
	elseif plan.Mode == "Surface" then
		if type(input.Levels) ~= "table" then return invalid("intensidades ausentes") end
		count = #plan.Zones
		local sum = 0
		for _, zone in ipairs(plan.Zones) do
			local level = input.Levels[zone.Id]
			if not finite(level) or level % 1 ~= 0 or level < 0 or level > 3 then
				return invalid("força inválida")
			end
			local delta = math.abs(level - zone.Target)
			if delta == 0 then successes += 1 end
			sum += math.max(0, 100 - delta * 30)
		end
		execution = sum / count
	else
		return invalid("família de procedimento desconhecida")
	end
	errors = count - successes
	local breakdown = {
		Execution = math.floor(math.clamp(execution, 0, 100) + 0.5),
		Errors = 0, Skill = RepairRules.SkillPoints(mods.Margin),
		Equipment = math.clamp(math.floor(mods.EquipmentEfficiency + 0.5), 0, 4),
		Part = RepairRules.PartPoints(mods.PartReliability),
		Diagnosis = RepairRules.DiagnosisPoints(mods.DiagnosisAttempts),
	}
	local quality = math.clamp(breakdown.Execution + breakdown.Skill + breakdown.Equipment
		+ breakdown.Part + breakdown.Diagnosis, 0, 100)
	return { Valid = true, Reason = nil, Quality = math.floor(quality + 0.5),
		Perfect = successes, Good = 0, Miss = errors, Corrected = 0, Uncorrected = errors,
		Breakdown = breakdown }
end

function WorkshopProcedures.Coverage(): (number, { string })
	local total, missing = 0, {}
	for defectId in pairs(Catalog.Defects) do
		total += 1
		if not sequence[defectId] and not calibration[defectId] and not circuits[defectId]
			and not surfaces[defectId] and defectId ~= "FlatTire"
			and defectId ~= "WeakBattery" and defectId ~= "Overheating" then
			table.insert(missing, defectId)
		end
	end
	table.sort(missing)
	return total, missing
end

return WorkshopProcedures
