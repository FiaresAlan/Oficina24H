-- Regressões puras da leitura dos exames (Studio > RunAllTests).
local E = require(game.ReplicatedStorage.Shared.DiagnosisEvidence)
local results = {}
local function check(label, ok)
	table.insert(results, (ok and "PASS " or "FAIL ") .. label)
end
check("9 modalidades de exame registradas", #E.Exams == 9)
check("exame valido", E.IsValidExam("TirePressure"))
check("exame desconhecido negado", not E.IsValidExam("Unknown") and not E.IsValidExam(10))
check("pilotos exigem exame", E.RequiresExam("FlatTire") and E.RequiresExam("WeakBattery") and E.RequiresExam("Overheating"))
check("funilaria e freios exigem exame", E.RequiresExam("Dent") and E.RequiresExam("BrakeWear"))
check("sem exame nao comprova nada", not E.HasAnyExam({}))
check("id adulterado nao conta", not E.HasAnyExam({ Fake = true }))
check("exame completo conta", E.HasAnyExam({ TirePressure = true }))
check("exame relevante de pneu conta", E.HasRelevantExam("FlatTire", { TirePressure = true }))
check("outro exame nao substitui o de pneu", not E.HasRelevantExam("FlatTire", { BatteryVoltage = true }))
check("exame relevante de bateria conta", E.HasRelevantExam("WeakBattery", { BatteryVoltage = true }))
check("outro exame nao substitui o de arrefecimento", not E.HasRelevantExam("Overheating", { TirePressure = true }))
check("lataria exige evidencia real", not E.HasRelevantExam("Dent", nil))

check("pneu furado gera evidencia", string.find(E.Read("FlatTire", "TirePressure") or "", "17 psi", 1, true) ~= nil)
check("bateria ruim gera evidencia", string.find(E.Read("WeakBattery", "BatteryVoltage") or "", "10,9 V", 1, true) ~= nil)
check("motor quente gera evidencia", string.find(E.Read("Overheating", "CoolingTemperature") or "", "115", 1, true) ~= nil)
check("teste irrelevante nao diagnostica falha", string.find(E.Read("FlatTire", "BatteryVoltage") or "", "normal", 1, true) ~= nil)
check("resultado desconhecido nil", E.Read("FlatTire", "Fake") == nil)
local findings = E.Findings("Overheating", { CoolingTemperature = true, BatteryVoltage = true })
check("so resultados realizados retornados", #findings == 2 and findings[1].Id == "BatteryVoltage" and findings[2].Id == "CoolingTemperature")
check("resposta UI nao contem DefectId", findings[1].DefectId == nil and findings[2].DefectId == nil)
local Catalog = require(game.ReplicatedStorage.Shared.Catalog)
local Inspection = require(game.ReplicatedStorage.Shared.InspectionPointRules)
local coverage, missing = E.Coverage()
check("15 defeitos cobertos por laudos", coverage == 15 and #missing == 0)
local physical = {}
for _, exam in ipairs(Inspection.Exams) do physical[exam.Id] = true end
local count = 0
for _, exam in ipairs(E.Exams) do
	count += 1
	check("exame " .. exam.Id .. " existe fisicamente", physical[exam.Id] == true)
end
check("9 laudos correspondem aos 9 pontos", count == 9 and #Inspection.Exams == count)
for defectId in pairs(Catalog.Defects) do
	local exam = E.RequiredExam(defectId)
	check("defeito " .. defectId .. " exige evidencia", type(exam) == "string" and E.RequiresExam(defectId))
	check("laudo de " .. defectId .. " tem leitura", type(E.Read(defectId, exam)) == "string")
	check("nao valida palpite sem exame de " .. defectId, not E.HasRelevantExam(defectId, {}))
	check("habilita hipoteses apos exame de " .. defectId, E.HasRelevantExam(defectId, { [exam] = true }))
end
check("código de laudo externo negado", E.Read("FlatTire", "HackedExam") == nil)
check("controle de evidências estritas", not E.HasAnyExam({ TirePressure = "true" }))
return table.concat(results, "\n")
