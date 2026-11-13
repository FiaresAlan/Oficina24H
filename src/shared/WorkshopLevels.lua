--!strict
-- Níveis da oficina (compra na Construtora do bairro). Fonte única para servidor, cliente e testes.
--   0 Garagem de bairro  — 1 box  (todo jogador começa aqui)
--   1 Oficina            — 2 boxes, permite 1 funcionário
--   2 Centro automotivo  — 4 boxes (libera o quadro de funcionários)
--   3 Oficina premium    — 6 boxes (ocupa o terreno inteiro)
-- Cada nível pede dinheiro + nível empresarial (total ganho) + reputação + XP (soma dos níveis de habilidade) +
-- equipamentos instalados: dá vontade de se esforçar, mas cada degrau é alcançável jogando (ver docs/PROGRESSO.md).
-- Geometria no espaço local do lote (+X lateral, +Z rumo ao fundo, rua em -Z): boxes numa fileira de frente para a rua,
-- sala dos fundos com os equipamentos, sala lateral com prateleira; carros entram pelo portão da direita (x = 40) e
-- saem pelo da saída (x = 31), circulando no pátio da frente.
local WorkshopLevels = {}

export type Level = {
	Id: number,
	Name: string,
	Bays: { number }, -- x do centro de cada box
	X0: number, -- paredes laterais do prédio
	X1: number,
	Height: number,
	Cost: number,
	MinBusinessLevel: number,
	MinReputation: number,
	MinSkillTotal: number,
	MinEquipment: number,
	MaxEmployees: number,
	Color: Color3, -- cor de destaque (faixas, letreiro)
}

WorkshopLevels.Levels = {
	[0] = {
		Id = 0, Name = "Garagem de bairro", Bays = { 5.5 }, X0 = -9, X1 = 11, Height = 12,
		Cost = 0, MinBusinessLevel = 1, MinReputation = 0, MinSkillTotal = 0, MinEquipment = 0, MaxEmployees = 0,
		Color = Color3.fromRGB(255, 196, 40),
	},
	[1] = {
		Id = 1, Name = "Oficina", Bays = { 5.5, 16.5 }, X0 = -9, X1 = 22, Height = 13,
		Cost = 1500, MinBusinessLevel = 4, MinReputation = 20, MinSkillTotal = 8, MinEquipment = 3, MaxEmployees = 1,
		Color = Color3.fromRGB(255, 140, 40),
	},
	[2] = {
		Id = 2, Name = "Centro automotivo", Bays = { -5.5, 5.5, 16.5, 27.5 }, X0 = -20, X1 = 33, Height = 14,
		Cost = 6000, MinBusinessLevel = 8, MinReputation = 70, MinSkillTotal = 14, MinEquipment = 5, MaxEmployees = 2,
		Color = Color3.fromRGB(70, 190, 255),
	},
	[3] = {
		Id = 3, Name = "Oficina premium", Bays = { -27.5, -16.5, -5.5, 5.5, 16.5, 27.5 }, X0 = -44, X1 = 33, Height = 15,
		Cost = 18000, MinBusinessLevel = 13, MinReputation = 160, MinSkillTotal = 22, MinEquipment = 8, MaxEmployees = 2,
		Color = Color3.fromRGB(255, 205, 80),
	},
} :: { [number]: Level }

WorkshopLevels.MaxLevel = 3

-- Geometria comum
WorkshopLevels.FrontZ = 9 -- fachada (portas dos boxes)
WorkshopLevels.BayZ = 20 -- centro dos boxes
WorkshopLevels.BayWidth = 9
WorkshopLevels.BayDepth = 22
WorkshopLevels.BackWallZ = 44 -- fundo do prédio; a sala dos fundos vai de z = 31 até aqui
WorkshopLevels.EquipmentZ = 38.5 -- fileira dos equipamentos
WorkshopLevels.EquipmentStep = 6
WorkshopLevels.SideRoomWidth = 9 -- sala lateral (prateleira) à esquerda do 1º box
WorkshopLevels.GateIn = 40 -- portão de entrada (faixa do pátio)
WorkshopLevels.GateOut = 31 -- portão de saída
WorkshopLevels.EntryRowZ = -12 -- fileira por onde o carro vai até o box
WorkshopLevels.ExitRowZ = -28 -- fileira por onde o carro volta ao portão de saída
WorkshopLevels.YardTurn = 6 -- raio das curvas dentro do pátio

-- Posições dos equipamentos na sala dos fundos, da esquerda para a direita (uma por equipamento instalado).
function WorkshopLevels.EquipmentSlots(level: number): { Vector2 }
	local L = WorkshopLevels.Levels[level] or WorkshopLevels.Levels[0]
	local slots = {}
	local x = L.X0 + 3.5
	while x <= L.X1 - 3.5 do
		table.insert(slots, Vector2.new(x, WorkshopLevels.EquipmentZ))
		x += WorkshopLevels.EquipmentStep
	end
	return slots
end

-- Quantos equipamentos cabem no prédio do nível.
function WorkshopLevels.MaxEquipment(level: number): number
	return #WorkshopLevels.EquipmentSlots(level)
end

export type Stats = { Coins: number, BusinessLevel: number, Reputation: number, SkillTotal: number, Equipment: number }

-- Requisitos para COMPRAR `level` (a partir do anterior). Retorna (pode comprar, lista {Label, Have, Need, Ok}).
function WorkshopLevels.Check(level: number, stats: Stats): (boolean, { { Label: string, Have: number, Need: number, Ok: boolean } })
	local L = WorkshopLevels.Levels[level]
	if not L then
		return false, {}
	end
	local rows = {
		{ Label = "Moedas", Have = stats.Coins, Need = L.Cost },
		{ Label = "Nível da oficina", Have = stats.BusinessLevel, Need = L.MinBusinessLevel },
		{ Label = "Reputação", Have = stats.Reputation, Need = L.MinReputation },
		{ Label = "XP (soma das habilidades)", Have = stats.SkillTotal, Need = L.MinSkillTotal },
		{ Label = "Equipamentos instalados", Have = stats.Equipment, Need = L.MinEquipment },
	}
	local ok = true
	for _, row in ipairs(rows) do
		(row :: any).Ok = row.Have >= row.Need
		ok = ok and row.Have >= row.Need
	end
	return ok, rows :: any
end

-- Limites de vagas e ordens abertas acompanham os boxes.
function WorkshopLevels.MaxOpenJobs(level: number): number
	local L = WorkshopLevels.Levels[level] or WorkshopLevels.Levels[0]
	return #L.Bays + 1
end

return WorkshopLevels
