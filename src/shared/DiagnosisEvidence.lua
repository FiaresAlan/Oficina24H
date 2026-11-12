--!strict
-- Diagnóstico em 15 defeitos: o laudo é gerado pelo servidor, nunca escolhe o defeito por conta do cliente.
-- Evidências observáveis simuladas, não valores de um equipamento certificado.
local Catalog = require(script.Parent.Catalog)
local DiagnosisEvidence = {}

DiagnosisEvidence.Exams = {
	{ Id = "TirePressure", Name = "Pressão do pneu" },
	{ Id = "BatteryVoltage", Name = "Tensão da bateria" },
	{ Id = "CoolingTemperature", Name = "Temperatura do motor" },
	{ Id = "WheelInspection", Name = "Rodas e pneus" },
	{ Id = "BrakeInspection", Name = "Sistema de freios" },
	{ Id = "ChassisInspection", Name = "Suspensão e geometria" },
	{ Id = "EngineScan", Name = "Diagnóstico do motor" },
	{ Id = "CircuitTest", Name = "Teste elétrico" },
	{ Id = "BodySurface", Name = "Lataria e pintura" },
}

-- Defeitos diferentes podem pertencer ao mesmo teste físico. O texto simula uma
-- leitura de equipamento e não revela IDs internos, recompensa ou escolha correta.
local readings: { [string]: { Normal: string, Defects: { [string]: string } } } = {
	TirePressure = {
		Normal = "Pressão estável: 32 psi. Sem fuga de ar detectada.",
		Defects = { FlatTire = "Leitura: 17 psi; bolhas e queda de pressão contínua no pneu dianteiro." },
	},
	BatteryVoltage = {
		Normal = "Bateria: 12,7 V em repouso, sem queda anormal.",
		Defects = { WeakBattery = "Bateria: 10,9 V, queda acentuada ao tentar a partida." },
	},
	CoolingTemperature = {
		Normal = "Arrefecimento: temperatura estabilizada em 90 °C.",
		Defects = { Overheating = "Temperatura: 115 °C; retorno quente e circulação de fluido insuficiente." },
	},
	WheelInspection = {
		Normal = "Sulcos, desgaste e distribuição de peso sem anormalidades.",
		Defects = {
			WornTire = "Sulco com 1,2 mm e desgaste desigual; substituição indicada.",
			WheelImbalance = "Desequilíbrio de massa: 35 g no conjunto dianteiro; roda vibra na rotação.",
		},
	},
	BrakeInspection = {
		Normal = "Pastilhas com espessura adequada; ruído de frenagem ausente.",
		Defects = { BrakeWear = "Pastilha próxima do limite: 2 mm; superfície de fricção irregular." },
	},
	ChassisInspection = {
		Normal = "Suspensão firme, braços íntegros e geometria dentro do intervalo.",
		Defects = {
			LooseSuspension = "Folga de 7 mm na bucha da dianteira; estalo durante o teste de carga.",
			BrokenArm = "Braço inferior trincado e desalinhado sob peso, peça sem integridade.",
			Misalignment = "Convergência esquerda em +1,8°, acima da tolerância de alinhamento.",
		},
	},
	EngineScan = {
		Normal = "Scanner e compressão: ignição estável, sem cilindros inconsistentes.",
		Defects = {
			EngineMisfire = "Falha P0302 no cilindro 2; frequência de ignição irregular.",
			EngineOverhaul = "Compressão desigual entre cilindros: 85 psi no cilindro 3 e fumaça no escape.",
		},
	},
	CircuitTest = {
		Normal = "Continuidade elétrica presente; fusíveis e circuitos dentro do esperado.",
		Defects = { ElectricalFault = "Circuito aberto no ramo de acessórios; fusível e alimentação requerem revisão." },
	},
	BodySurface = {
		Normal = "Painéis alinhados, sem deformações ou perda anormal de tinta.",
		Defects = {
			Dent = "Deformação localizada de 9 mm na porta; pintura preservada.",
			BodyDamage = "Painel desalinhado: folga de 12 mm entre porta e para-lama após impacto.",
			PaintJob = "Verniz descascando; espessura de tinta irregular e base exposta.",
		},
	},
}

-- Todo defeito do catálogo tem uma prova relevante antes de oferecer hipótese.
local relevant: { [string]: string } = {
	FlatTire = "TirePressure", WornTire = "WheelInspection",
	WeakBattery = "BatteryVoltage", ElectricalFault = "CircuitTest",
	Overheating = "CoolingTemperature", EngineMisfire = "EngineScan", EngineOverhaul = "EngineScan",
	LooseSuspension = "ChassisInspection", BrokenArm = "ChassisInspection", Misalignment = "ChassisInspection",
	BrakeWear = "BrakeInspection", WheelImbalance = "WheelInspection",
	Dent = "BodySurface", BodyDamage = "BodySurface", PaintJob = "BodySurface",
}

function DiagnosisEvidence.IsValidExam(examId: any): boolean
	return type(examId) == "string" and readings[examId] ~= nil
end

function DiagnosisEvidence.RequiredExam(defectId: any): string?
	if type(defectId) ~= "string" then return nil end
	return relevant[defectId]
end

function DiagnosisEvidence.RequiresExam(defectId: any): boolean
	return DiagnosisEvidence.RequiredExam(defectId) ~= nil
end

function DiagnosisEvidence.HasAnyExam(done: { [string]: boolean }?): boolean
	for id, examined in pairs(done or {}) do
		if examined == true and DiagnosisEvidence.IsValidExam(id) then return true end
	end
	return false
end

function DiagnosisEvidence.HasRelevantExam(defectId: string, done: { [string]: boolean }?): boolean
	local id = relevant[defectId]
	return id == nil or (done ~= nil and done[id] == true)
end

function DiagnosisEvidence.Read(defectId: string, examId: any): string?
	local reading = readings[examId]
	if not reading then return nil end
	return reading.Defects[defectId] or reading.Normal
end

function DiagnosisEvidence.Findings(defectId: string, done: { [string]: boolean }?): { any }
	local results = {}
	for _, exam in ipairs(DiagnosisEvidence.Exams) do
		if done and done[exam.Id] then
			table.insert(results, { Id = exam.Id, Name = exam.Name, Text = DiagnosisEvidence.Read(defectId, exam.Id) })
		end
	end
	return results
end

-- Auditoria de cobertura: útil para impedir um novo serviço sem hipótese demonstrável.
function DiagnosisEvidence.Coverage(): (number, { string })
	local missing = {}
	local total = 0
	for id in pairs(Catalog.Defects) do
		total += 1
		local exam = relevant[id]
		if not exam or not readings[exam] or not readings[exam].Defects[id] then
			table.insert(missing, id)
		end
	end
	table.sort(missing)
	return total, missing
end

return DiagnosisEvidence
