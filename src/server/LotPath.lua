--!strict
-- LotPath: trajetos dos carros dos clientes e movimento suave da Raiz (PrimaryPart ancorada; o resto do carro é soldado).
-- Tudo é calculado no espaço local do lote (mesmo referencial de shared/Layout): +X lateral, +Z rumo ao fundo, rua em -Z.
-- Os carros andam na faixa do lado do lote no sentido +X local (mão direita nos dois lados da rua), param junto ao
-- meio-fio antes das entradas e, quando a ordem é aceita, fazem a curva e entram de frente na vaga.
local RunService = game:GetService("RunService")

local LotPath = {}

LotPath.LaneZ = -67 -- faixa de rodagem do lado do lote (a rua vai de z=-93 a z=-53 no espaço do lote)
LotPath.ParkZ = -57.5 -- faixa junto ao meio-fio: onde o carro espera
LotPath.CurbZ = -47 -- calçada: onde o cliente espera em pé
LotPath.TurnRadius = 12
LotPath.SlotX = { -28, -49, -70 } -- vagas do meio-fio, antes das entradas (os carros vêm de -X)
LotPath.StreetSpan = 160 -- distância de onde o carro surge e para onde some
LotPath.StreetSpeed = 26
LotPath.YardSpeed = 12

local STEP = 2 -- espaçamento dos pontos (para a altura do chão acompanhar meio-fio, calçada e vaga)

-- Referencial do lote: origem no centro do topo da base, girado conforme o lado da rua.
function LotPath.Frame(plot: Instance): CFrame?
	local base = plot:FindFirstChild("Base")
	if not base or not base:IsA("BasePart") then
		return nil
	end
	local side = plot:GetAttribute("Side")
	local top = base.Position.Y + base.Size.Y / 2
	return CFrame.new(base.Position.X, top, base.Position.Z) * CFrame.Angles(0, side == -1 and math.pi or 0, 0)
end

-- Pontos locais (x, z) -> mundo, com a altura do chão medida por raio (limitada a ±1 da base do lote).
local function exclusions(): { Instance }
	local list: { Instance } = {}
	for _, name in ipairs({ "Vehicles", "Arrivals" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function groundParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions()
	params.IgnoreWater = true
	return params
end

function LotPath.Ground(frame: CFrame, x: number, z: number, reuse: RaycastParams?): Vector3
	local flat = frame * Vector3.new(x, 0, z)
	local params = reuse or groundParams()
	local hit = workspace:Raycast(flat + Vector3.new(0, 3.5, 0), Vector3.new(0, -8, 0), params)
	local y = hit and math.clamp(hit.Position.Y, flat.Y - 1, flat.Y + 1) or flat.Y
	return Vector3.new(flat.X, y, flat.Z)
end

local function toWorld(frame: CFrame, pts: { Vector2 }): { Vector3 }
	-- densifica e mede o chão
	local dense: { Vector2 } = {}
	for i, p in ipairs(pts) do
		if i > 1 then
			local a = pts[i - 1]
			local n = math.max(1, math.ceil((p - a).Magnitude / STEP))
			for k = 1, n do
				table.insert(dense, a:Lerp(p, k / n))
			end
		else
			table.insert(dense, p)
		end
	end
	local out: { Vector3 } = {}
	local params = groundParams() -- um filtro para o trajeto inteiro
	for i, p in ipairs(dense) do
		out[i] = LotPath.Ground(frame, p.X, p.Y, params)
	end
	-- suaviza a altura (degrau do meio-fio vira rampa curta)
	local smooth: { Vector3 } = {}
	for i, p in ipairs(out) do
		local a, b = out[math.max(1, i - 1)], out[math.min(#out, i + 1)]
		smooth[i] = Vector3.new(p.X, (a.Y + p.Y * 2 + b.Y) / 4, p.Z)
	end
	return smooth
end

-- Curva em S entre duas faixas (de (x0, z0) a (x1, z1)), com tangentes paralelas ao eixo X.
-- Os últimos 4 studs são retos: o carro termina alinhado com a faixa (sem ficar torto no meio-fio).
local function sCurve(pts: { Vector2 }, x0: number, z0: number, x1: number, z1: number)
	local n = 12
	local xc = x1 - math.sign(x1 - x0) * 4
	for i = 1, n do
		local t = i / n
		local s = t * t * (3 - 2 * t)
		table.insert(pts, Vector2.new(x0 + (xc - x0) * t, z0 + (z1 - z0) * s))
	end
	table.insert(pts, Vector2.new(x1, z1))
end

-- Quarto de círculo da faixa (bayX - R, LaneZ) até a entrada (bayX, LaneZ + R); `reverse` percorre ao contrário.
local function arc(pts: { Vector2 }, bayX: number, reverse: boolean)
	local R = LotPath.TurnRadius
	local cx, cz = bayX - R, LotPath.LaneZ + R
	local n = 10
	for i = 1, n do
		local t = reverse and (1 - i / n) or (i / n)
		local theta = -math.pi / 2 + t * math.pi / 2
		table.insert(pts, Vector2.new(cx + R * math.cos(theta), cz + R * math.sin(theta)))
	end
end

-- Caminho interno do anexo (Layout.AnnexRoute): do fim da curva do corredor principal (mainX, LaneZ + R) até o box do
-- anexo. Sobe pelo corredor, vira para -X em turnZ e entra no anexo de frente (+Z).
local Layout = require(game:GetService("ReplicatedStorage").Shared.Layout)

local function arcPts(pts: { Vector2 }, cx: number, cz: number, r: number, a0: number, a1: number)
	local n = 10
	for i = 1, n do
		local a = a0 + (a1 - a0) * i / n
		table.insert(pts, Vector2.new(cx + r * math.cos(a), cz + r * math.sin(a)))
	end
end

local function annexRoute(pts: { Vector2 }, bayX: number, bayZ: number)
	local route = Layout.AnnexRoute
	local r, mx, tz = route.radius, route.mainX, route.turnZ
	table.insert(pts, Vector2.new(mx, tz - r))
	arcPts(pts, mx - r, tz - r, r, 0, math.pi / 2) -- vira para -X
	table.insert(pts, Vector2.new(bayX + r, tz))
	arcPts(pts, bayX + r, tz + r, r, -math.pi / 2, -math.pi) -- vira para +Z, entrando no anexo
	table.insert(pts, Vector2.new(bayX, bayZ))
end

-- Chegada: surge longe na faixa e encosta no meio-fio na vaga `slotX`.
function LotPath.Arrival(frame: CFrame, slotX: number): { Vector3 }
	local pts = { Vector2.new(slotX - LotPath.StreetSpan, LotPath.LaneZ), Vector2.new(slotX - 18, LotPath.LaneZ) }
	sCurve(pts, slotX - 18, LotPath.LaneZ, slotX, LotPath.ParkZ)
	return toWorld(frame, pts)
end

-- Do meio-fio (ou de longe, se `slotX` for nil) até a vaga da oficina, entrando de frente.
-- `annex` = o box fica no anexo: entra pelo corredor principal e segue o caminho interno.
function LotPath.Enter(frame: CFrame, slotX: number?, bayX: number, bayZ: number, annex: boolean?): { Vector3 }
	local R = LotPath.TurnRadius
	local gateX = annex and Layout.AnnexRoute.mainX or bayX
	local pts: { Vector2 }
	if slotX then
		pts = { Vector2.new(slotX, LotPath.ParkZ) }
		sCurve(pts, slotX, LotPath.ParkZ, math.min(slotX + 14, gateX - R), LotPath.LaneZ)
	else
		pts = { Vector2.new(gateX - R - LotPath.StreetSpan, LotPath.LaneZ) }
	end
	table.insert(pts, Vector2.new(gateX - R, LotPath.LaneZ))
	arc(pts, gateX, false)
	if annex then
		annexRoute(pts, bayX, bayZ)
	else
		table.insert(pts, Vector2.new(bayX, bayZ))
	end
	return toWorld(frame, pts)
end

-- Saída da vaga: dá ré até a faixa (terminando de frente para +X) ... Retorna também o x de onde segue pela faixa.
function LotPath.BackOut(frame: CFrame, bayX: number, bayZ: number, annex: boolean?): ({ Vector3 }, number)
	local R = LotPath.TurnRadius
	local pts: { Vector2 }
	local gateX = bayX
	if annex then
		-- o mesmo caminho interno, de ré, até o corredor principal
		gateX = Layout.AnnexRoute.mainX
		local forward: { Vector2 } = {}
		annexRoute(forward, bayX, bayZ)
		pts = {}
		for i = #forward, 1, -1 do
			table.insert(pts, forward[i])
		end
		table.insert(pts, Vector2.new(gateX, LotPath.LaneZ + R))
	else
		pts = { Vector2.new(bayX, bayZ), Vector2.new(bayX, LotPath.LaneZ + R) }
	end
	arc(pts, gateX, true)
	return toWorld(frame, pts), gateX - R
end

-- ... e segue pela faixa até sumir.
function LotPath.DriveOff(frame: CFrame, fromX: number): { Vector3 }
	return toWorld(frame, { Vector2.new(fromX, LotPath.LaneZ), Vector2.new(fromX + LotPath.StreetSpan, LotPath.LaneZ) })
end

-- Sai do meio-fio direto para a rua (cliente dispensado ou que cansou de esperar).
function LotPath.LeaveCurb(frame: CFrame, slotX: number): { Vector3 }
	local pts = { Vector2.new(slotX, LotPath.ParkZ) }
	sCurve(pts, slotX, LotPath.ParkZ, slotX + 16, LotPath.LaneZ)
	table.insert(pts, Vector2.new(slotX + LotPath.StreetSpan, LotPath.LaneZ))
	return toWorld(frame, pts)
end

function LotPath.Length(points: { Vector3 }): number
	local total = 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
	end
	return total
end

-- Tempo aproximado de Drive (aceleração e frenagem de ~1,2 s cada).
function LotPath.Duration(points: { Vector3 }, speed: number): number
	return LotPath.Length(points) / speed + 1.2
end

-- Move a Raiz ao longo dos pontos: acelera, freia antes do fim e aponta a frente (LookVector) para onde vai.
-- `backward` = dá ré (a frente aponta para o lado oposto ao movimento). Retorna quando chega (ou o carro some).
function LotPath.Drive(root: BasePart, points: { Vector3 }, speed: number, backward: boolean?)
	local n = #points
	if n < 2 then
		return
	end
	local cum = { 0 }
	for i = 2, n do
		cum[i] = cum[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	local total = cum[n]
	if total < 0.05 then
		return
	end
	local function sample(s: number): Vector3
		if s <= 0 then
			local dir = (points[2] - points[1])
			return points[1] + (dir.Magnitude > 0 and dir.Unit * s or Vector3.zero)
		elseif s >= total then
			local dir = (points[n] - points[n - 1])
			return points[n] + (dir.Magnitude > 0 and dir.Unit * (s - total) or Vector3.zero)
		end
		local lo, hi = 1, n
		while hi - lo > 1 do
			local mid = (lo + hi) // 2
			if cum[mid] <= s then
				lo = mid
			else
				hi = mid
			end
		end
		local len = cum[hi] - cum[lo]
		return points[lo]:Lerp(points[hi], len > 0 and (s - cum[lo]) / len or 0)
	end
	local accel = speed / 1.2
	local s, v = 0, 0
	local look = 3
	while s < total and root.Parent do
		local dt = RunService.Heartbeat:Wait()
		local brake = math.sqrt(2 * accel * math.max(total - s, 0))
		v = math.min(speed, v + accel * dt, math.max(brake, 2))
		s = math.min(total, s + v * dt)
		local pos = sample(s)
		local dir = (sample(s + look) - sample(s - look)) * Vector3.new(1, 0, 1)
		if dir.Magnitude > 0.01 then
			if backward then
				dir = -dir
			end
			root.CFrame = CFrame.lookAt(pos, pos + dir.Unit)
		else
			root.CFrame = CFrame.new(pos) * root.CFrame.Rotation
		end
	end
end

return LotPath
