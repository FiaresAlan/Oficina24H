--!strict
-- Layout do lote no espaço local do prédio (mesmo referencial de tools/WorkshopBuilding):
-- origem no centro da base do lote, +X lateral (para o lado do portão), +Z rumo ao fundo. Medidas em studs.
-- Fonte única para o prédio, as vagas dos carros e os espaços dos equipamentos (e para os testes de colisão).
local Layout = {}

Layout.Interior = { x0 = -20, x1 = 20, z0 = 7, z1 = 33 }

-- Vagas dentro do prédio, sob o portão (aberto de x=-1 a x=21). Carros têm no máximo 9,4 x 20,5 (picapes).
-- O carro entra de frente pela calçada e pelo pátio (corredor livre de x=-1 a x=21 entre a rua e o portão).
Layout.Bays = {
	{ x = 15, z = 19.5, w = 9, d = 22 },
	{ x = 4, z = 19.5, w = 9, d = 22 },
}

-- Corredor por onde os carros dos clientes entram (nada pode ficar aqui: placas, vasos, colunas).
Layout.Driveway = { x0 = -1.5, x1 = 21.5, z0 = -45, z1 = 8 }

-- Placa e entrada do lote (fora do corredor dos carros).
Layout.Sign = { x = -14, z = -40.5 }

-- Espaços de equipamento: pequenos dentro do prédio (rente às paredes), grandes no pátio ao lado.
Layout.Slots = {
	BasicToolset = { x = -3, z = 27, rot = 0 },
	Jack = { x = -2.5, z = 17, rot = 90 },
	Scanner = { x = -3, z = 23, rot = 0 },
	ElectricalBench = { x = -9, z = 27.5, rot = 0 },
	EngineBench = { x = -16, z = 27.5, rot = 0 },
	Compressor = { x = -18.3, z = 21.5, rot = 90 },
	Balancer = { x = -10, z = 22, rot = 0 },
	TireMachine = { x = -40, z = 6, rot = 0 },
	AlignmentRig = { x = -34, z = 18, rot = 0 },
	SuspensionLift = { x = 36, z = 10, rot = 0 },
	BodyworkKit = { x = 36, z = 22, rot = 0 },
}

return Layout
