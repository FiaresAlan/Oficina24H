-- Regressões de doze receitas especializadas, quatro famílias e contrato de rede.
local P = require(game:GetService("ServerScriptService").Server.WorkshopProcedures)
local Ops = require(game:GetService("ServerScriptService").Server.RepairOperations)
local Catalog = require(game.ReplicatedStorage.Shared.Catalog)
local result = {}
local function check(name, success)
	table.insert(result, (success and "PASS " or "FAIL ") .. name)
end
local mods = { Margin = 0, EquipmentEfficiency = 0, PartReliability = 1, DiagnosisAttempts = 1 }
local coverage, missing = P.Coverage()
check("catálogo completo sem lacunas de procedimento", coverage == 15 and #missing == 0)
local families = { Sequence = 0, Calibration = 0, Circuit = 0, Surface = 0, Tire = 0, Battery = 0, Cooling = 0 }
local count = 0
for defectId in pairs(Catalog.Defects) do
	count += 1
	local plan = Ops.BuildPlan(defectId, 170)
	check(defectId .. ": possui procedimento", plan ~= nil and plan.Kind == "Operations")
	if plan then
		families[plan.Mode] = (families[plan.Mode] or 0) + 1
		local public = Ops.PublicPlan(plan)
		check(defectId .. ": payload público existe", type(public) == "table" and public.Mode == plan.Mode)
		check(defectId .. ": gabarito não exposto", public.Correct == nil and public.CorrectSource == nil
			and public.CorrectAction == nil and public.DefectId == nil and public.LeakSpot == nil
			and public.Sequence == nil and public.TargetFluid == nil)
	end
end
check("todos 15 defeitos percorridos", count == 15)
check("famílias separadas sem timing genérico", families.Sequence == 5 and families.Calibration == 2
	and families.Circuit == 2 and families.Surface == 3 and families.Tire == 1
	and families.Battery == 1 and families.Cooling == 1)
check("defeito desconhecido mantém fallback", Ops.BuildPlan("InvalidDefect", 2) == nil)
local cases = {
	WornTire = "Sequence", LooseSuspension = "Sequence", BrakeWear = "Sequence",
	BrokenArm = "Sequence", EngineOverhaul = "Sequence",
	WheelImbalance = "Calibration", Misalignment = "Calibration",
	EngineMisfire = "Circuit", ElectricalFault = "Circuit",
	Dent = "Surface", BodyDamage = "Surface", PaintJob = "Surface",
}
for defectId, mode in pairs(cases) do
	local plan = P.BuildPlan(defectId, 2)
	check(defectId .. ": modo dedicado", plan ~= nil and plan.Mode == mode)
	local input, bad
	if mode == "Sequence" then
		input = { Steps = table.clone(plan.Correct) }
		bad = { Steps = table.clone(plan.Correct) }
		bad.Steps[1] = bad.Steps[2] -- repetição deve ser invalidada
		check(defectId .. ": sequência pública não contém ordem correta", P.PublicPlan(plan).Correct == nil)
	elseif mode == "Calibration" then
		local values = {}
		local wrong = {}
		for _, field in ipairs(plan.Fields) do
			values[field.Id] = field.Target
			wrong[field.Id] = field.Initial
		end
		input = { Values = values }
		bad = { Values = { [plan.Fields[1].Id] = "1000" } }
		check(defectId .. ": alvo dentro do instrumento", values[plan.Fields[1].Id] >= plan.Fields[1].Min
			and values[plan.Fields[1].Id] <= plan.Fields[1].Max)
		local imprecise = P.Evaluate(plan, { Values = wrong }, plan.MinSeconds + 1, mods)
		local perfect = P.Evaluate(plan, input, plan.MinSeconds + 1, mods)
		check(defectId .. ": calibração precisa melhora qualidade", imprecise.Valid and perfect.Valid
			and perfect.Quality > imprecise.Quality)
	elseif mode == "Circuit" then
		input = { Source = plan.CorrectSource, Action = plan.CorrectAction }
		bad = { Source = "HACK", Action = plan.CorrectAction }
		check(defectId .. ": fonte e ação ocultas", P.PublicPlan(plan).CorrectSource == nil
			and P.PublicPlan(plan).CorrectAction == nil)
		local wrongSource = plan.Sources[1].Id == plan.CorrectSource and plan.Sources[2].Id or plan.Sources[1].Id
		local wrong = P.Evaluate(plan, { Source = wrongSource, Action = plan.CorrectAction }, plan.MinSeconds + 1, mods)
		local good = P.Evaluate(plan, input, plan.MinSeconds + 1, mods)
		check(defectId .. ": escolha errada reduz qualidade", wrong.Valid and good.Valid and good.Quality > wrong.Quality)
	else
		local levels = {}
		local incorrect = {}
		for _, zone in ipairs(plan.Zones) do
			levels[zone.Id] = zone.Target
			incorrect[zone.Id] = 0
		end
		input = { Levels = levels }
		bad = { Levels = { [plan.Zones[1].Id] = 999 } }
		check(defectId .. ": alvo da região oculto", P.PublicPlan(plan).Zones[1].Target == nil)
		local poor = P.Evaluate(plan, { Levels = incorrect }, plan.MinSeconds + 1, mods)
		local good = P.Evaluate(plan, input, plan.MinSeconds + 1, mods)
		check(defectId .. ": intensidade correta melhora reparo", poor.Valid and good.Valid and good.Quality > poor.Quality)
	end
	local good = Ops.Evaluate(plan, input, plan.MinSeconds + 1, mods)
	check(defectId .. ": execução correta validada pelo servidor", good.Valid and good.Quality >= 90)
	local invalid = Ops.Evaluate(plan, bad, plan.MinSeconds + 1, mods)
	check(defectId .. ": payload adulterado rejeitado", not invalid.Valid)
	check(defectId .. ": envio instantâneo rejeitado", not Ops.Evaluate(plan, input, 0.1, mods).Valid)
	check(defectId .. ": tempo absurdo rejeitado", not Ops.Evaluate(plan, input, 1000, mods).Valid)
end
check("gabarito de sequência é determinístico", P.BuildPlan("EngineOverhaul", 3).Correct[1] == "Drain")
check("opções de sequência preservam tamanho", #P.PublicPlan(P.BuildPlan("EngineOverhaul", 3)).Options == 5)
check("níveis de acabamento fora de 0–3 rejeitados", not P.Evaluate(P.BuildPlan("Dent", 1),
	{ Levels = { Top = 1.5, Center = 3, Bottom = 1 } }, 6, mods).Valid)
check("calibração fora de passo rejeitada", not P.Evaluate(P.BuildPlan("Misalignment", 1),
	{ Values = { Toe = 0.1, Camber = -0.5 } }, 6, mods).Valid)
return table.concat(result, "\n")
