--!strict
-- RouteMotion: a MESMA conta de movimento dos carros no servidor e no cliente.
-- O servidor manda a rota uma vez (pontos, velocidade, ré?, hora de início no relógio do servidor); cada cliente anima
-- a Raiz localmente, liso a 60 fps, e o servidor só grava a posição final quando termina. Antes o servidor movia a
-- Raiz a cada frame (muito tráfego e tranco no 4G).
-- Perfil de velocidade: acelera em ~1,2 s, freia a tempo de parar no fim, mínimo de 2 studs/s perto do fim.
local RouteMotion = {}

local DT = 1 / 60
local LOOK = 3

export type Route = { Points: { Vector3 }, Cum: { number }, Total: number, Samples: { number }, Duration: number, Backward: boolean }

function RouteMotion.Build(points: { Vector3 }, speed: number, backward: boolean?): Route?
	local n = #points
	if n < 2 or speed <= 0 then
		return nil
	end
	local cum = { 0 }
	for i = 2, n do
		cum[i] = cum[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	local total = cum[n]
	if total < 0.05 then
		return nil
	end
	-- integra a distância percorrida em passos fixos (determinístico: igual no servidor e no cliente)
	local accel = speed / 1.2
	local s, v = 0, 0
	local samples = { 0 }
	local guard = 0
	while s < total and guard < 60 * 600 do
		guard += 1
		local brake = math.sqrt(2 * accel * math.max(total - s, 0))
		v = math.min(speed, v + accel * DT, math.max(brake, 2))
		s = math.min(total, s + v * DT)
		table.insert(samples, s)
	end
	return { Points = points, Cum = cum, Total = total, Samples = samples, Duration = (#samples - 1) * DT, Backward = backward == true }
end

local function sample(route: Route, s: number): Vector3
	local points, cum, n, total = route.Points, route.Cum, #route.Points, route.Total
	if s <= 0 then
		local dir = points[2] - points[1]
		return points[1] + (dir.Magnitude > 0 and dir.Unit * s or Vector3.zero)
	elseif s >= total then
		local dir = points[n] - points[n - 1]
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

-- Distância percorrida depois de `elapsed` segundos (interpola entre os passos).
function RouteMotion.DistanceAt(route: Route, elapsed: number): number
	local f = math.max(0, elapsed) / DT
	local i = math.floor(f)
	local samples = route.Samples
	if i + 1 >= #samples then
		return route.Total
	end
	local a, b = samples[i + 1], samples[i + 2]
	return a + (b - a) * (f - i)
end

-- Pose da Raiz a uma distância `s`: posição na rota e frente (LookVector) para onde vai (ou ao contrário, na ré).
function RouteMotion.Pose(route: Route, s: number, fallbackRotation: CFrame?): CFrame
	local pos = sample(route, s)
	local dir = (sample(route, s + LOOK) - sample(route, s - LOOK)) * Vector3.new(1, 0, 1)
	if dir.Magnitude > 0.01 then
		if route.Backward then
			dir = -dir
		end
		return CFrame.lookAt(pos, pos + dir.Unit)
	end
	return CFrame.new(pos) * (fallbackRotation or CFrame.identity)
end

return RouteMotion
