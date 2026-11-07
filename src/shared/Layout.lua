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

-- Placa e entrada do lote (fora do corredor dos carros e do caminho do anexo): lado direito da frente.
Layout.Sign = { x = 33, z = -40.5 }

-- Estações físicas dentro do prédio (y = altura do centro; yaw: 0 = de frente para a rua).
Layout.Stations = {
	Orders = { x = -12, y = 7.5, z = 32.3, yaw = 0 }, -- TV de ordens na parede do fundo
	Stock = { x = -18.6, y = 0, z = 11.5, yaw = -90 }, -- prateleira na parede esquerda, de frente para dentro
	Staff = { x = -1.5, y = 6, z = 32.3, yaw = 0 }, -- quadro de funcionários no fundo, 10 studs à direita da TV
}

-- Expansão nível 1: anexo no pátio esquerdo com um box (Bay3), carro de frente para o fundo (+Z).
Layout.Annex = { x0 = -44, x1 = -23, z0 = 6, z1 = 36 }
Layout.AnnexBay = { x = -33.5, z = 21, w = 9, d = 22 }
-- Caminho interno até o anexo: sobe pelo corredor principal (x = 4), vira à esquerda em z = -15 e entra no anexo.
Layout.AnnexRoute = { mainX = 4, turnZ = -15, radius = 10 }

-- Espaços de equipamento: pequenos dentro do prédio (rente às paredes), grandes no pátio ao lado.
Layout.Slots = {
	BasicToolset = { x = -3, z = 27, rot = 0 },
	Jack = { x = -2.5, z = 17, rot = 90 },
	Scanner = { x = -3, z = 23, rot = 0 },
	ElectricalBench = { x = -9, z = 27.5, rot = 0 },
	EngineBench = { x = -16, z = 27.5, rot = 0 },
	Compressor = { x = -18.3, z = 21.5, rot = 90 },
	Balancer = { x = -10, z = 22, rot = 0 },
	TireMachine = { x = -30, z = 40.5, rot = 0 }, -- atrás do anexo (o pátio esquerdo é do anexo)
	AlignmentRig = { x = 36, z = 35, rot = 0 }, -- fundo do pátio direito
	SuspensionLift = { x = 36, z = 10, rot = 0 },
	BodyworkKit = { x = 36, z = 22, rot = 0 },
}

return Layout
