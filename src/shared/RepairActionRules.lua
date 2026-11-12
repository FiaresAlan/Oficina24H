--!strict
-- Registro incremental autoritativo: o servidor observa comandos, não aceita um formulário final fabricado.
-- Não impede bots com entradas válidas; impede pular etapas / injetar resultados sem registrar ações.
local RepairActionRules = {}

RepairActionRules.MaxCommands = 64

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function has(options: any, id: any): boolean
	if type(id) ~= "string" or type(options) ~= "table" then return false end
	for _, option in ipairs(options) do
		if type(option) == "table" and option.Id == id then return true end
	end
	return false
end

local function arrayHas(options: any, id: any): boolean
	if type(id) ~= "string" or type(options) ~= "table" then return false end
	return table.find(options, id) ~= nil
end

local function fieldById(options: any, id: any): any?
	if type(id) ~= "string" or type(options) ~= "table" then return nil end
	for _, field in ipairs(options) do
		if type(field) == "table" and field.Id == id then return field end
	end
	return nil
end

local function stepValid(old: number, value: any, step: number): boolean
	return finite(value) and finite(step) and step > 0 and math.abs(math.abs(value - old) - step) < 0.0001
end

function RepairActionRules.New(plan: any): any?
	if type(plan) ~= "table" or plan.Kind ~= "Operations" then return nil end
	local mode = plan.Mode
	local allowed = { Tire = true, Battery = true, Cooling = true, Sequence = true,
		Calibration = true, Circuit = true, Surface = true }
	if allowed[mode] ~= true then return nil end
	local state: any = {
		Mode = mode, Revision = 0, Commands = 0,
		Spot = nil, Pressure = 28, Steps = {}, Fluid = 1.5, BleedCycles = 0, FanChecked = false,
		Values = {}, Source = nil, Action = nil, Levels = {}, Touched = {},
	}
	if mode == "Calibration" then
		for _, field in ipairs(plan.Fields) do state.Values[field.Id] = field.Initial end
	elseif mode == "Surface" then
		for _, zone in ipairs(plan.Zones) do state.Levels[zone.Id] = 0 end
	end
	return state
end

function RepairActionRules.Apply(plan: any, state: any, command: any): (boolean, string)
	if type(plan) ~= "table" or type(state) ~= "table" or type(command) ~= "table"
		or plan.Kind ~= "Operations" or state.Mode ~= plan.Mode then
		return false, "Sessão inválida."
	end
	if not finite(command.Revision) or command.Revision % 1 ~= 0 or command.Revision ~= state.Revision then
		return false, "Ação desatualizada. Aguarde a confirmação."
	end
	if state.Commands >= RepairActionRules.MaxCommands then
		return false, "Limite de ajustes atingido: reinicie o reparo."
	end
	local kind, id, value = command.Kind, command.Id, command.Value
	if type(kind) ~= "string" then return false, "Comando inválido." end
	local mode = plan.Mode
	if mode == "Tire" then
		if kind == "Spot" and arrayHas({ "Inner", "Center", "Outer" }, value) then
			state.Spot = value
		elseif kind == "Pressure" and finite(value) and value >= 0 and value <= 44
			and stepValid(state.Pressure, value, 2) then
			state.Pressure = value
		else
			return false, "Local ou pressão inválida."
		end
	elseif mode == "Battery" or mode == "Sequence" then
		local options = mode == "Battery"
			and { "OffNegative", "OffPositive", "OnPositive", "OnNegative" }
			or nil
		if kind == "Reset" then
			state.Steps = {}
		elseif kind == "Step" then
			local allowed = if mode == "Battery" then arrayHas(options, value)
				else has(plan.Options, value)
			local maximum = if mode == "Battery" then 4 else #plan.Correct
			if not allowed or #state.Steps >= maximum or table.find(state.Steps, value) then
				return false, "Etapa duplicada ou desconhecida."
			end
			table.insert(state.Steps, value)
		else
			return false, "Operação inválida."
		end
	elseif mode == "Cooling" then
		if kind == "Fluid" and finite(value) and value >= 0 and value <= 3
			and stepValid(state.Fluid, value, 0.25) then
			state.Fluid = value
			state.Touched.Fluid = true
		elseif kind == "Bleed" and finite(value) and value >= 0 and value <= 5
			and value % 1 == 0 and stepValid(state.BleedCycles, value, 1) then
			state.BleedCycles = value
			state.Touched.Bleed = true
		elseif kind == "Fan" and type(value) == "boolean" and value ~= state.FanChecked then
			state.FanChecked = value
			state.Touched.Fan = true
		else
			return false, "Ajuste de arrefecimento inválido."
		end
	elseif mode == "Calibration" then
		local field = fieldById(plan.Fields, id)
		local old = field and state.Values[field.Id]
		if kind ~= "Measure" or not field or not finite(old) or not finite(value)
			or value < field.Min or value > field.Max or not stepValid(old, value, field.Step) then
			return false, "Valor de regulagem inválido."
		end
		state.Values[id] = value
		state.Touched[id] = true
	elseif mode == "Circuit" then
		if kind == "Source" and has(plan.Sources, value) then
			state.Source = value
		elseif kind == "Action" and has(plan.Actions, value) then
			state.Action = value
		else
			return false, "Circuito ou intervenção desconhecido."
		end
	elseif mode == "Surface" then
		local zone = fieldById(plan.Zones, id)
		local old = zone and state.Levels[id]
		if kind ~= "Level" or not zone or not finite(old) or not finite(value)
			or value % 1 ~= 0 or value < 0 or value > 3 or not stepValid(old, value, 1) then
			return false, "Ajuste de superfície inválido."
		end
		state.Levels[id] = value
		state.Touched[id] = true
	else
		return false, "Modo de reparo inválido."
	end
	state.Commands += 1
	state.Revision += 1
	return true, ""
end

-- Somente dados montados do estado confirmado podem chegar ao avaliador de qualidade.
function RepairActionRules.FinalInput(plan: any, state: any): (any?, string?)
	if type(plan) ~= "table" or type(state) ~= "table" or state.Mode ~= plan.Mode
		or state.Commands < 1 then
		return nil, "Nenhuma ação do procedimento foi confirmada."
	end
	local mode = plan.Mode
	if mode == "Tire" then
		if not state.Spot then return nil, "Selecione o ponto do vazamento." end
		return { Spot = state.Spot, Pressure = state.Pressure }, nil
	elseif mode == "Battery" or mode == "Sequence" then
		local required = mode == "Battery" and 4 or #plan.Correct
		if #state.Steps ~= required then return nil, "Etapas do procedimento incompletas." end
		return { Steps = table.clone(state.Steps) }, nil
	elseif mode == "Cooling" then
		if not state.Touched.Fluid or not state.Touched.Bleed or not state.Touched.Fan then
			return nil, "Revise fluido, sangria e ventoinha antes de entregar."
		end
		return { Fluid = state.Fluid, BleedCycles = state.BleedCycles, FanChecked = state.FanChecked }, nil
	elseif mode == "Calibration" then
		for _, field in ipairs(plan.Fields) do
			if not state.Touched[field.Id] then return nil, "Regule todas as medidas." end
		end
		return { Values = table.clone(state.Values) }, nil
	elseif mode == "Circuit" then
		if not state.Source or not state.Action then return nil, "Selecione circuito e componente." end
		return { Source = state.Source, Action = state.Action }, nil
	elseif mode == "Surface" then
		for _, zone in ipairs(plan.Zones) do
			if not state.Touched[zone.Id] then return nil, "Trabalhe todas as regiões." end
		end
		return { Levels = table.clone(state.Levels) }, nil
	end
	return nil, "Modo desconhecido."
end

return RepairActionRules
