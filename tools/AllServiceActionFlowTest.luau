-- C26: teste de INTEGRAÇÃO das regras dos 15 reparos.
-- Plano -> ações validadas no servidor -> estado reconstruído -> avaliação.
-- Regras puras; NÃO simula UI, veículo físico, economia nem DataStore.
local Catalog = require(game.ReplicatedStorage.Shared.Catalog)
local Operations = require(game:GetService("ServerScriptService").Server.RepairOperations)
local Actions = require(game.ReplicatedStorage.Shared.RepairActionRules)
local results, failures, count = {}, 0, 0
local mods = { Margin = 0, EquipmentEfficiency = 0,
	PartReliability = 1, DiagnosisAttempts = 1 }
local function check(label, ok, detail)
	if not ok then failures += 1 end
	table.insert(results, (ok and "PASS " or "FAIL ") .. label
		.. ((not ok and detail) and (" | " .. tostring(detail)) or ""))
end

local function run(defectId)
	local plan = Operations.BuildPlan(defectId, 113)
	assert(plan and plan.Kind == "Operations", "procedimento ausente")
	local public = Operations.PublicPlan(plan)
	assert(public and public.Kind == "Operations" and public.Mode == plan.Mode,
		"plano público ausente ou incompatível")
	assert(public.Correct == nil and public.CorrectSource == nil and public.CorrectAction == nil
		and public.LeakSpot == nil and public.Sequence == nil and public.TargetFluid == nil
		and public.DefectId == nil, "gabarito privado vazou")
	local state = Actions.New(plan)
	assert(state ~= nil, "estado incremental inexistente")
	assert(Actions.FinalInput(plan, state) == nil, "zero gestos concluíram o reparo")
	local function send(kind, id, value)
		local revision = state.Revision
		local cmd = { Revision = revision, Kind = kind, Id = id, Value = value }
		local ok, reason = Actions.Apply(plan, state, cmd)
		assert(ok, "ação rejeitada: " .. tostring(reason))
		assert(state.Revision == revision + 1, "revisão não avançou")
		assert(Actions.IsReplay(state, cmd), "ACK idempotente falhou")
	end
	if plan.Mode == "Tire" then
		send("Spot", nil, plan.LeakSpot)
		send("Pressure", nil, 30)
		send("Pressure", nil, 32)
	elseif plan.Mode == "Battery" then
		for _, action in ipairs(plan.Sequence) do send("Step", nil, action) end
	elseif plan.Mode == "Cooling" then
		send("Fluid", nil, 1.75)
		send("Fluid", nil, 2)
		send("Bleed", nil, 1)
		send("Bleed", nil, 2)
		send("Fan", nil, true)
	elseif plan.Mode == "Sequence" then
		for _, action in ipairs(plan.Correct) do send("Step", nil, action) end
	elseif plan.Mode == "Calibration" then
		for _, field in ipairs(plan.Fields) do
			local value = field.Initial
			local steps = 0
			while math.abs(value - field.Target) > 0.00001 do
				steps += 1
				assert(steps <= 40, "calibração inatingível: " .. field.Id)
				value += (value < field.Target and field.Step or -field.Step)
				value = math.round(value * 10000) / 10000
				send("Measure", field.Id, value)
			end
		end
	elseif plan.Mode == "Circuit" then
		send("Source", nil, plan.CorrectSource)
		send("Action", nil, plan.CorrectAction)
	elseif plan.Mode == "Surface" then
		for _, zone in ipairs(plan.Zones) do
			for value = 1, zone.Target do send("Level", zone.Id, value) end
		end
	else
		error("modo desconhecido: " .. tostring(plan.Mode))
	end
	assert(state.Commands > 0 and state.Commands <= Actions.MaxCommands,
		"passos excederam limite do servidor")
	local input, why = Actions.FinalInput(plan, state)
	assert(input ~= nil, "reparo ficou incompleto: " .. tostring(why))
	local time = (public.MinSeconds or plan.MinSeconds or 3) + 2
	local evaluation = Operations.Evaluate(plan, input, time, mods)
	assert(evaluation.Valid and evaluation.Quality >= 90,
		"qualidade/resultado incorreto: " .. tostring(evaluation.Reason)
			.. " qualidade=" .. tostring(evaluation.Quality))
	-- Uma revisão antiga ou um comando adulterado não deve reabrir execução.
	local revision = state.Revision
	assert(not Actions.Apply(plan, state, { Revision = revision - 2, Kind = "Unknown" }),
		"revisão antiga aceita")
	assert(state.Revision == revision, "replay alterou revisão")
	return plan.Mode, state.Commands
end

for defectId, defect in pairs(Catalog.Defects) do
	count += 1
	local ok, modeOrError, actions = pcall(run, defectId)
	check(defectId .. " / " .. tostring(defect.ServiceId)
		.. ": pipeline incremental do servidor", ok,
		not ok and modeOrError or nil)
	if ok then
		check(defectId .. ": comandos válidos aplicados",
			type(actions) == "number" and actions > 0)
	end
end
check("C26: todos 15 serviços cobertos", count == 15)
table.insert(results, failures == 0 and "TODOS OS TESTES PASSARAM"
	or (failures .. " TESTE(S) FALHARAM"))
return table.concat(results, "\n")
