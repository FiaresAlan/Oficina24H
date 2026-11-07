-- Troca os prédios do bairro pelos da cidade "Low Poly city" (ORKQN, CGTrader #4359726, Royalty Free; ver
-- docs/ORIGEM_ASSETS.md). Rodar no modo Edit (MCP execute_luau) DEPOIS do BuildNeighborhood. Idempotente.
--
-- O que NÃO muda (o jogo depende disso): rua principal (z = 0) e calçadas, rua lateral (x = 220), os 6 lotes,
-- Loja de Autopeças, Construtora (DistribuidoraEquipamentos), estacionamento público, praça, carros estacionados e
-- mobiliário de rua. Cada prédio é conferido contra essas áreas (KEEP_OUT) e contra os outros prédios; o que colidir
-- não é colocado e aparece no relatório.
--
-- Modelos em ServerStorage.Assets.Cenario (Cid_*): pivô no centro da base, frente = LookVector (-Z do modelo).
-- FRONT_PLUS_Z: modelos cuja fachada está no +Z (giram 180°).
local Cenario = game.ServerStorage.Assets.Cenario
local Bairro = workspace.Bairro
local SEED = 24

local FRONT_PLUS_Z = { Cid_Curvo = true }

-- Áreas que ficam livres: {x0, x1, z0, z1}
local KEEP_OUT = {
	{ -460, 460, -28, 28, "rua principal + calçadas" },
	{ 196, 244, -28, 300, "rua lateral" },
	{ -250, 50, -122, -24, "lotes norte" },
	{ -250, 50, 24, 122, "lotes sul" },
	{ 101, 159, -104, -28, "Loja de Autopeças + acesso" },
	{ 244, 334, 91, 149, "Construtora + acesso" },
	{ 91, 169, 28, 109, "estacionamento público" },
	{ -444, -376, -154, -28, "praça" },
	{ 296, 394, 45, 95, "estacionamento da galeria" },
	{ 183, 193, 26, 36, "banca" },
	{ 79, 101, -154, -146, "outdoor" },
	{ 207, 223, -106, -94, "caçamba" },
	{ 372, 388, -116, -104, "caçamba" },
}
local BOUNDS = { -452, 452, -352, 352 }

-- 1) Limpa: prédios antigos (casas e lojas), menos o que fica; colisores dos prédios antigos; cidade nova anterior.
local KEEP_OLD = { Loja_Estacionamento = true, Loja_Banca = true, Rua_Outdoor = true, Loja_LavaRapido = true }
for _, groupName in ipairs({ "Residencial", "Comercial" }) do
	for _, m in ipairs(Bairro[groupName]:GetChildren()) do
		if not KEEP_OLD[m.Name] then
			m:Destroy()
		end
	end
end
for _, c in ipairs(Bairro.Colisores:GetChildren()) do
	c:Destroy()
end
local old = Bairro:FindFirstChild("Cidade")
if old then
	old:Destroy()
end
local city = Instance.new("Folder")
city.Name = "Cidade"
city.Parent = Bairro
local trees = Instance.new("Folder")
trees.Name = "Arvores"
trees.Parent = city

local placed = {} -- {x0, x1, z0, z1, nome}
local report = { ok = 0, skipped = {} }

local function overlaps(a, b)
	return a[1] < b[2] and a[2] > b[1] and a[3] < b[4] and a[4] > b[3]
end

local function blocked(rect)
	if rect[1] < BOUNDS[1] or rect[2] > BOUNDS[2] or rect[3] < BOUNDS[3] or rect[4] > BOUNDS[4] then
		return "fora do mapa"
	end
	for _, k in ipairs(KEEP_OUT) do
		if overlaps(rect, k) then
			return k[5]
		end
	end
	for _, p in ipairs(placed) do
		if overlaps(rect, p) then
			return p[5]
		end
	end
	return nil
end

local DIRS = { S = Vector3.new(0, 0, 1), N = Vector3.new(0, 0, -1), E = Vector3.new(1, 0, 0), W = Vector3.new(-1, 0, 0) }

-- Chão: grama verde (o Ground já usa o material Grass) e calçada de concreto em volta de cada prédio, na altura das
-- calçadas da rua (topo 0,8). Prédios de frente para a rua ganham calçada até a calçada da rua. A calçada é cortada
-- onde encostaria nas peças físicas do jogo (lotes, rua, loja, Construtora, estacionamentos, praça).
local ground = workspace.Map:FindFirstChild("Ground")
if ground then
	ground.Color = Color3.fromRGB(98, 142, 70)
end
local pads = Instance.new("Folder")
pads.Name = "Calcadas"
pads.Parent = city
local PAD_MARGIN = 6
local PAD_TOPS = { 0.72, 0.74, 0.76, 0.78 } -- alturas alternadas: calçadas sobrepostas não piscam (z-fighting)
local HARD = { -- peças físicas que a calçada não pode cobrir {x0, x1, z0, z1}
	{ -350, 350, -20, 20 }, { 200, 240, -20, 280 }, -- asfalto
	{ -245, 45, -118, -28 }, { -245, 45, 28, 118 }, -- lotes
	{ 105, 155, -100, -60 }, { 270, 330, 95, 145 }, { 95, 165, 55, 105 }, -- loja, Construtora, estacionamento
	{ -440, -380, -150, -32 }, { 296, 394, 45, 95 }, -- praça, estacionamento da galeria
}
local padCount = 0
local padRects = {}

local function clipPad(p, keep)
	for _, h in ipairs(HARD) do
		if p[1] < h[2] and p[2] > h[1] and p[3] < h[4] and p[4] > h[3] then
			-- corta pelo lado que tira menos, sem invadir o prédio
			local best, cost = nil, math.huge
			local options = {
				{ 2, h[1], p[2] - h[1], h[1] >= keep[2] },
				{ 1, h[2], h[2] - p[1], h[2] <= keep[1] },
				{ 4, h[3], p[4] - h[3], h[3] >= keep[4] },
				{ 3, h[4], h[4] - p[3], h[4] <= keep[3] },
			}
			for _, o in ipairs(options) do
				if o[4] and o[3] < cost then
					best, cost = o, o[3]
				end
			end
			if best then
				p[best[1]] = best[2]
			end
		end
	end
	return p
end

local function pad(rect, face: string): number
	local p = { rect[1] - PAD_MARGIN, rect[2] + PAD_MARGIN, rect[3] - PAD_MARGIN, rect[4] + PAD_MARGIN }
	if face == "S" and p[4] > -60 and p[4] < -20 then
		p[4] = -24 -- até a calçada norte da rua principal
	elseif face == "N" and p[3] < 60 and p[3] > 20 then
		p[3] = 24
	elseif face == "E" and p[2] > 160 and p[2] < 200 then
		p[2] = 188
	elseif face == "W" and p[1] < 285 and p[1] > 240 then
		p[1] = 252
	end
	clipPad(p, rect)
	padCount += 1
	local top = PAD_TOPS[(padCount - 1) % #PAD_TOPS + 1]
	local w, d = p[2] - p[1], p[4] - p[3]
	table.insert(padRects, p)
	if w > 2 and d > 2 then
		local part = Instance.new("Part")
		part.Name = "Calcada"
		part.Anchored = true
		part.Material = Enum.Material.Concrete
		part.Color = Color3.fromRGB(176, 172, 164)
		part.Size = Vector3.new(w, top, d)
		part.CFrame = CFrame.new((p[1] + p[2]) / 2, top / 2, (p[3] + p[4]) / 2)
		part.TopSurface = Enum.SurfaceType.Smooth
		part.CastShadow = false
		part.CanTouch = false
		part.Parent = pads
	end
	return top
end

local function collider(name: string, cf: CFrame, size: Vector3)
	local c = Instance.new("Part")
	c.Name = "Colisor_" .. name
	c.Anchored = true
	c.Transparency = 1
	c.CanQuery = false
	c.CanTouch = false
	c.CastShadow = false
	c.Size = Vector3.new(size.X * 0.92, size.Y, size.Z * 0.92)
	c.CFrame = cf
	c.Parent = Bairro.Colisores
end

-- Prédio com a fachada virada para `face` (S = +Z, N = -Z, E = +X, W = -X), centro em (x, z).
local function building(name: string, x: number, z: number, face: string)
	local template = Cenario:FindFirstChild(name)
	if not template then
		table.insert(report.skipped, name .. " (modelo ausente)")
		return
	end
	local sx, sz = template:GetAttribute("SizeX"), template:GetAttribute("SizeZ")
	local alongX = face == "S" or face == "N"
	local hx, hz = (alongX and sx or sz) / 2, (alongX and sz or sx) / 2
	local rect = { x - hx, x + hx, z - hz, z + hz, name }
	local why = blocked(rect)
	if why then
		table.insert(report.skipped, string.format("%s em (%d, %d): %s", name, x, z, why))
		return
	end
	local dir = DIRS[face]
	if FRONT_PLUS_Z[name] then
		dir = -dir
	end
	local m = template:Clone()
	local top = pad(rect, face) -- o prédio fica em cima da própria calçada
	local pos = Vector3.new(x, top, z)
	m:PivotTo(CFrame.lookAt(pos, pos + dir))
	m.Parent = city
	table.insert(placed, rect)
	local cf, size = m:GetBoundingBox()
	collider(name, cf, size)
	report.ok += 1
	return m
end

-- 2) Prédios -------------------------------------------------------------------------------------------------------
-- Norte da rua principal (fachada para a rua, +Z), a leste dos lotes
building("Cid_Casa_Terraco", 70, -40, "S")
building("Cid_Loja_Pequena", 185, -40, "S")
building("Cid_Esquina_Redonda", 232, -61, "S")
building("Cid_Lojas_Fileira", 302, -46, "S")
building("Cid_Posto", 385, -44, "S")
-- segunda fileira (prédios altos = horizonte da cidade)
building("Cid_PredioAlto", 190, -130, "S")
building("Cid_Torre_Fina", 240, -130, "S")
building("Cid_Apartamentos", 290, -130, "S")
building("Cid_Banco", 360, -150, "S")
building("Cid_Predio_Vertical", 425, -130, "S")
building("Cid_Mercado", 200, -215, "S")
building("Cid_Torre_Torcida", 300, -215, "S") -- marco da cidade: visível de qualquer lote
building("Cid_Pilotis", 410, -215, "S")
building("Cid_Fabrica", 330, -300, "S")
-- atrás dos lotes do norte
building("Cid_Sobrado", -215, -150, "S")
building("Cid_Bloco", -170, -150, "S")
building("Cid_Curvo", -115, -155, "S")
building("Cid_Predio_Vertical", -50, -155, "S")
building("Cid_Galpao", 0, -150, "S")
building("Cid_PredioEstreito", 45, -150, "S")
building("Cid_Escritorio", 130, -135, "S")
building("Cid_Comercial_Longo", -130, -255, "S")
building("Cid_Predio_Largo", 20, -255, "S")
building("Cid_Torre_Fina", 100, -230, "S")
building("Cid_Apartamentos", 150, -280, "S")
-- oeste, norte
building("Cid_Mercado", -300, -63, "S")
building("Cid_Loja_Baixa", -300, -125, "S")
building("Cid_PredioAlto", -320, -210, "S")
building("Cid_Torre_Fina", -390, -210, "S")
building("Cid_Banco", -330, -290, "S")
-- Sul da rua principal (fachada -Z), oeste
building("Cid_Loja_Pequena", -280, 40, "N")
building("Cid_Sobrado", -325, 42, "N")
building("Cid_Esquina_Redonda", -380, 61, "N")
building("Cid_Casa_Terraco", -430, 40, "N")
-- atrás dos lotes do sul
building("Cid_Bloco", -215, 140, "N")
building("Cid_Casa_Terraco", -175, 137, "N")
building("Cid_PredioEstreito", -130, 140, "N")
building("Cid_Curvo", -75, 142, "N")
building("Cid_Sobrado", -20, 140, "N")
building("Cid_Galpao", 30, 140, "N")
building("Cid_Banco", -150, 230, "N")
building("Cid_Torre_Fina", -60, 225, "N")
building("Cid_PredioAlto", 0, 225, "N")
building("Cid_Predio_Largo", -260, 240, "N")
building("Cid_Apartamentos", -340, 200, "N")
building("Cid_Predio_Vertical", -400, 200, "N")
-- ao longo da rua lateral (x = 220): oeste com fachada +X, leste com fachada -X
building("Cid_Mercado", 177, 145, "E")
building("Cid_Sobrado", 182, 210, "E")
building("Cid_Curvo", 179, 260, "E")
building("Cid_Torre_Fina", 120, 160, "S")
building("Cid_PredioEstreito", 120, 230, "N")
building("Cid_Torre_Fina", 260, 180, "W")
building("Cid_Apartamentos", 258, 235, "W")
building("Cid_Bloco", 257, 280, "W")
-- sudeste
building("Cid_PredioAlto", 410, 140, "N")
building("Cid_Predio_Largo", 340, 240, "N")
building("Cid_Esquina_Redonda", 418, 230, "W")
building("Cid_Pilotis", 410, 310, "N")

-- Lava-rápido antigo continua, na ponta leste (fachada para a rua)
local lava = Bairro.Comercial:FindFirstChild("Loja_LavaRapido")
if lava then
	local pos = Vector3.new(432, 0, -53)
	lava:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)))
	local cf, size = lava:GetBoundingBox()
	collider("Loja_LavaRapido", cf, size)
	table.insert(placed, { cf.Position.X - size.X / 2, cf.Position.X + size.X / 2, cf.Position.Z - size.Z / 2, cf.Position.Z + size.Z / 2, "lava-rápido" })
end

-- 3) Árvores: troca as árvores de blocos (Scenery Tronco/Copa) por pinheiros da cidade, nos mesmos lugares quando
-- estão livres, e completa com pinheiros nas bordas do mapa. Sem colisão (decoração).
local rng = Random.new(SEED)
local pine = Cenario:FindFirstChild("Cid_Pinheiro")
local function tree(x: number, z: number)
	if not pine then
		return false
	end
	local rect = { x - 5, x + 5, z - 5, z + 5, "árvore" }
	if blocked(rect) then
		return false
	end
	for _, p in ipairs(padRects) do
		if overlaps(rect, p) then
			return false -- árvore só na grama
		end
	end
	local t = pine:Clone()
	t:ScaleTo(rng:NextNumber(0.8, 1.3))
	t:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	t.Parent = trees
	table.insert(placed, rect)
	return true
end
local Scenery = workspace:FindFirstChild("Scenery")
local moved = 0
if Scenery then
	for _, c in ipairs(Scenery:GetChildren()) do
		if c.Name == "Tronco" then
			if tree(c.Position.X, c.Position.Z) then
				moved += 1
			end
		end
	end
	for _, c in ipairs(Scenery:GetChildren()) do
		if c.Name == "Tronco" or c.Name == "Copa" then
			c:Destroy()
		end
	end
end
local edge = 0
for _ = 1, 400 do
	if edge >= 70 then
		break
	end
	local side = rng:NextInteger(1, 4)
	local x, z
	if side == 1 then
		x, z = rng:NextNumber(-445, 445), rng:NextNumber(-345, -315)
	elseif side == 2 then
		x, z = rng:NextNumber(-445, 445), rng:NextNumber(315, 345)
	elseif side == 3 then
		x, z = rng:NextNumber(-445, -415), rng:NextNumber(-345, 345)
	else
		x, z = rng:NextNumber(415, 445), rng:NextNumber(-345, 345)
	end
	if tree(x, z) then
		edge += 1
	end
end

-- pinheiros em grupos (3 a 5) nos gramados entre os prédios: densos nas bordas, nunca na rua, lote ou calçada
local inner = 0
for _ = 1, 600 do
	if inner >= 45 then
		break
	end
	local cx, cz = rng:NextNumber(-440, 440), rng:NextNumber(-340, 340)
	for _ = 1, rng:NextInteger(3, 5) do
		if tree(cx + rng:NextNumber(-14, 14), cz + rng:NextNumber(-14, 14)) then
			inner += 1
		end
	end
end

return string.format("prédios: %d | pulados: %d | calçadas: %d | árvores: %d antigas, %d nas bordas, %d nos gramados\n%s",
	report.ok, #report.skipped, padCount, moved, edge, inner, table.concat(report.skipped, "\n"))
