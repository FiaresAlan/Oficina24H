--!strict
-- Exames não invasivos de diagnóstico: o servidor conhece o defeito; o cliente recebe só o laudo.
-- Valores de leitura são sinais de gameplay, não medições profissionais de um veículo real.
local DiagnosisEvidence = {}

DiagnosisEvidence.Exams = {
	{ Id = "TirePressure", Name = "Pressão do pneu" },
	{ Id = "BatteryVoltage", Name = "Teste da bateria" },
	{ Id = "CoolingTemperature", Name = "Arrefecimento" },
}

local readings = {
	TirePressure = {
		Target = "FlatTire",
		Positive = "Pressão: 17 psi. Perda de ar localizada no pneu.",
		Negative = "Pressão: 32 psi. Não há vazamento anormal.",
	},
	BatteryVoltage = {
		Target = "WeakBattery",
		Positive = "Tensão: 10,9 V. Alimentação insuficiente na partida.",
		Negative = "Tensão: 12,7 V. Alimentação da bateria normal.",
	},
	CoolingTemperature = {
		Target = "Overheating",
		Positive = "Temperatura: 115 °C. Sistema de arrefecimento superaquecendo.",
		Negative = "Temperatura: 90 °C. Sem aquecimento anormal detectado.",
	},
}

function DiagnosisEvidence.IsValidExam(examId: any): boolean
	return type(examId) == "string" and readings[examId] ~= nil
end

function DiagnosisEvidence.RequiresExam(defectId: string): boolean
	return defectId == "FlatTire" or defectId == "WeakBattery" or defectId == "Overheating"
end

function DiagnosisEvidence.HasAnyExam(done: { [string]: boolean }?): boolean
	for id, examined in pairs(done or {}) do
		if examined and DiagnosisEvidence.IsValidExam(id) then
			return true
		end
	end
	return false
end

function DiagnosisEvidence.Read(defectId: string, examId: any): string?
	local reading = readings[examId]
	if not reading then return nil end
	return defectId == reading.Target and reading.Positive or reading.Negative
end

-- Array de UI com apenas exames já executados; não fornece DefectId ao cliente.
function DiagnosisEvidence.Findings(defectId: string, done: { [string]: boolean }?): { any }
	local result = {}
	for _, exam in ipairs(DiagnosisEvidence.Exams) do
		if done and done[exam.Id] then
			table.insert(result, { Id = exam.Id, Name = exam.Name, Text = DiagnosisEvidence.Read(defectId, exam.Id) })
		end
	end
	return result
end

return DiagnosisEvidence
