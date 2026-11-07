-- Monta o bairro no place (Edit): casas, comércio, mobiliário urbano e carros estacionados em Workspace.Bairro.
-- Uso: rodar no modo Edit (MCP execute_luau). Idempotente: apaga Workspace.Bairro e refaz. Os modelos vêm de ServerStorage.Assets
-- (Cenario e Veiculos); origem e licença em docs/ORIGEM_ASSETS.md. Frente de cada prop = LookVector; frente dos carros = +Z.
local Assets = game.ServerStorage.Assets
local old = workspace:FindFirstChild("Bairro")
if old then old:Destroy() end
local root = Instance.new("Folder")
root.Name = "Bairro"
local groups = {}
for _, g in ipairs({ "Residencial", "Comercial", "Rua", "Estacionados", "Colisores" }) do
	local f = Instance.new("Folder")
	f.Name = g
	f.Parent = root
	groups[g] = f
end

local footprints = {} -- retângulos ocupados (para limpar árvores do cenário antigo)

local function lookAtDir(pos: Vector3, dx: number, dz: number): CFrame
	return CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz))
end

-- Coloca um prop do cenário. (dx,dz) = direção da frente (para onde a fachada olha).
local function place(name: string, x: number, z: number, dx: number, dz: number, group: string, y: number?, collide: boolean?)
	local template = Assets.Cenario:FindFirstChild(name)
	assert(template, "prop ausente: " .. name)
	local m = template:Clone()
	m:PivotTo(lookAtDir(Vector3.new(x, y or 0, z), dx, dz))
	m.Parent = groups[group]
	local cf, sz = m:GetBoundingBox()
	table.insert(footprints, { x = cf.Position.X, z = cf.Position.Z, hx = math.max(sz.X, sz.Z) / 2 + 4, hz = math.max(sz.X, sz.Z) / 2 + 4 })
	if collide then
		local c = Instance.new("Part")
		c.Name = "Colisor_" .. name
		c.Anchored = true
		c.Transparency = 1
		c.CanQuery = false
		c.CanTouch = false
		c.Size = Vector3.new(sz.X * 0.92, sz.Y, sz.Z * 0.92)
		c.CFrame = cf
		c.Parent = groups.Colisores
	end
	return m
end

-- Carro estacionado (cópia do modelo de veículo do jogo): Raiz no chão, frente = LookVector, Casco com colisão.
local function parkCar(name: string, x: number, z: number, frontDx: number, frontDz: number)
	local template = Assets.Veiculos:FindFirstChild(name)
	if not template then
		return
	end
	local m = template:Clone()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { groups.Estacionados }
	local hit = workspace:Raycast(Vector3.new(x, 12, z), Vector3.new(0, -20, 0), params)
	local y = hit and hit.Position.Y or 0.4
	m:PivotTo(CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x + frontDx, y, z + frontDz)))
	m.Parent = groups.Estacionados
end

-- Remove o cenário procedural antigo que será substituído (postes) e as árvores dentro dos novos prédios.
local Scenery = workspace:FindFirstChild("Scenery")
if Scenery then
	for _, c in ipairs(Scenery:GetChildren()) do
		if c.Name == "Poste" or c.Name == "Braco" or c.Name == "Lampada" then
			c:Destroy()
		end
	end
end

-- 1) Postes de rua (calçadas z = +-24), evitando as entradas dos lotes
local poleX = { -415, -345, -275, -150, -50, 50, 120, 190, 290, 360, 430 }
for _, px in ipairs(poleX) do
	place("Rua_Poste", px, -23.5, 0, 1, "Rua", 0.5)
	place("Rua_Poste", px + 22, 23.5, 0, -1, "Rua", 0.5)
end

-- 2) Residencial oeste (x < -255): casas viradas para a rua
place("Casa_Familia", -310, -62, 0, 1, "Residencial", 0, true)
place("Casa_Terrea", -385, -58, 0, 1, "Residencial", 0, true)
place("Casa_Villa", -310, 62, 0, -1, "Residencial", 0, true)
place("Casa_Sobrado", -362, 62, 0, -1, "Residencial", 0, true)
place("Casa_Duplex", -418, 64, 0, -1, "Residencial", 0, true)
-- segunda fileira, atrás dos lotes
place("Casa_Inicial", -215, -168, 0, 1, "Residencial", 0, true)
place("Casa_Garagem", -140, -166, 0, 1, "Residencial", 0, true)
place("Casa_Familia", -60, -170, 0, 1, "Residencial", 0, true)
place("Casa_Duplex", -215, 170, 0, -1, "Residencial", 0, true)
place("Predio_Apartamentos", -120, 172, 0, -1, "Residencial", 0, true)
place("Casa_Terrea", -35, 166, 0, -1, "Residencial", 0, true)
-- ao longo da rua lateral (x = 220, z > 20)
place("Casa_Inicial", 172, 125, 1, 0, "Residencial", 0, true)
place("Casa_Familia", 168, 195, 1, 0, "Residencial", 0, true)
place("Casa_Villa", 172, 255, 1, 0, "Residencial", 0, true)
place("Casa_Sobrado", 268, 200, -1, 0, "Residencial", 0, true)
place("Casa_Terrea", 278, 262, -1, 0, "Residencial", 0, true)

-- 3) Comércio leste (x > 170), norte da rua
place("Loja_Cafe", 195, -58, 0, 1, "Comercial", 0, true)
place("Loja_Esquina", 240, -58, 0, 1, "Comercial", 0, true)
place("Loja_Galeria", 325, -78, 0, 1, "Comercial", 0, false)
place("Loja_LavaRapido", 398, -62, 0, 1, "Comercial", 0, true)
place("Loja_Posto", 432, -40, 0, 1, "Comercial", 0, false)
place("Rua_Outdoor", 90, -150, 0, 1, "Comercial", 0, false)
-- sul da rua: estacionamento e prédio
place("Loja_Estacionamento", 345, 70, 0, -1, "Comercial", 0, false)
place("Predio_Apartamentos", 410, 150, 0, -1, "Residencial", 0, true)
place("Loja_Banca", 188, 31, 0, -1, "Comercial", 0.5, false)

-- 4) Mobiliário urbano
for _, s in ipairs({ { 75, -28, 1 }, { 75, 28, -1 }, { -295, -28, 1 }, { -295, 28, -1 } }) do
	place("Rua_PontoOnibus", s[1], s[2], 0, s[3], "Rua", 0.5)
end
place("Rua_Maquina", 96, -26, 0, 1, "Rua", 0.5)
place("Rua_Maquina", -318, 26, 0, -1, "Rua", 0.5)
place("Rua_Telefone", 58, -25, 0, 1, "Rua", 0.5)
place("Rua_Telefone", -270, 25, 0, -1, "Rua", 0.5)
for _, jx in ipairs({ 150, 215, 270, 330 }) do
	place("Rua_Jardineira", jx, 26, 0, -1, "Rua", 0.5)
end
place("Rua_Mobiliario", -262, -26, 0, 1, "Rua", 0.5)
place("Rua_Mobiliario", 60, 26, 0, -1, "Rua", 0.5)
place("Rua_Mobiliario", 180, -26, 0, 1, "Rua", 0.5)
place("Rua_Semaforo", 202, 27, 0, -1, "Rua", 0.5)
place("Rua_Cacamba", 215, -100, 0, 1, "Rua", 0)
place("Rua_Cacamba", 380, -110, 0, 1, "Rua", 0)
place("Rua_Praca", -430, -110, 0, 1, "Rua", 0)
place("Rua_Praca", -440, 130, 0, -1, "Rua", 0)
place("Rua_Boasvindas", -425, -27, 0, 1, "Rua", 0.5)

-- 5) Carros estacionados (modelos do jogo)
local carNames = { "Veiculo_Hatch_MG3", "Veiculo_Sedan_Civic", "Veiculo_Picape_S10", "Veiculo_SUV_RAV4", "Veiculo_Sedan_Fury", "Veiculo_Sedan_Camry", "Veiculo_SUV_Wrangler", "Veiculo_Hatch_AE86", "Veiculo_SUV_Evoque", "Veiculo_Hatch_Punto" }
for i = 1, 5 do -- estacionamento público (95..165, 55..105)
	parkCar(carNames[i], 104 + (i - 1) * 14, 66, 0, -1)
	parkCar(carNames[i + 5], 104 + (i - 1) * 14, 94, 0, 1)
end
for i = 1, 6 do -- estacionamento da galeria/lote leste
	parkCar(carNames[(i % 10) + 1], 306 + (i - 1) * 14, 58, 0, -1)
end
parkCar("Veiculo_Picape_C1500", 200, -26.5 - 6, 1, 0) -- carro ao longo do meio-fio, norte (vaga na rua)
parkCar("Veiculo_VIP_Charger", 245, 40, 1, 0)

-- 6) Limpa árvores antigas que ficaram dentro dos novos prédios
local removed = 0
if Scenery then
	for _, c in ipairs(Scenery:GetChildren()) do
		if c.Name == "Tronco" or c.Name == "Copa" then
			local p = c.Position
			for _, f in ipairs(footprints) do
				if math.abs(p.X - f.x) < f.hx and math.abs(p.Z - f.z) < f.hz then
					c:Destroy()
					removed += 1
					break
				end
			end
		end
	end
end
root.Parent = workspace
return { casas = #groups.Residencial:GetChildren(), comercio = #groups.Comercial:GetChildren(), rua = #groups.Rua:GetChildren(), carros = #groups.Estacionados:GetChildren(), arvoresRemovidas = removed }
