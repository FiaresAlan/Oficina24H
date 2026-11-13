--!strict
-- VehicleFx: efeitos dos carros dos clientes, só no cliente (nada disso volta ao servidor nem muda as regras):
--   * rodas giram conforme o carro anda e o motor faz barulho (volume e tom pela velocidade);
--   * o DEFEITO aparece no carro estacionado (atributo "Sintoma" vindo do servidor):
--       Engine = fumaça no capô e no escapamento + chiado; Electrical = faíscas azuis, luz piscando e zumbido;
--       Tires = pneu murcho soltando fumaça; Suspension = roda torta (cambagem); Bodywork = sem efeito extra;
--   * durante o REPARO (atributo "Reparando"): o pneu sai do carro (pneu/suspensão), o capô abre (motor/elétrica,
--     quando o modelo tem capô separado), sons de parafusadeira/catraca e faíscas de trabalho.
-- As rodas são detectadas pela geometria (peças redondas perto dos 4 cantos e embaixo). Leve: só carros a até 160 studs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SoundIds = require(ReplicatedStorage.Shared.SoundIds)
local RouteMotion = require(ReplicatedStorage.Shared.RouteMotion)
local V2Art = require(ReplicatedStorage.Shared.V2PilotArtProfiles)

local MAX_DISTANCE = 160

-- Rotas dos carros (server/LotPath.Drive manda uma vez): a Raiz é animada aqui, liso a cada frame. O servidor só
-- atualiza a 5 Hz; a pose local é regravada a cada frame por cima. Depois do fim segura a pose final por 0,6 s
-- (a última atualização do servidor pode chegar atrasada).
type ClientRoute = { Route: RouteMotion.Route, Start: number, Rotation: CFrame }
local routes: { [BasePart]: ClientRoute } = {}
local HOLD_AFTER = 0.6

ReplicatedStorage:WaitForChild("OficinaCarRoute").OnClientEvent:Connect(function(root: BasePart?, points: { Vector3 }, speed: number, backward: boolean, start: number)
	if typeof(root) ~= "Instance" or not (root :: Instance):IsA("BasePart") or type(points) ~= "table" then
		return
	end
	local route = RouteMotion.Build(points, speed, backward)
	if route then
		routes[root :: BasePart] = { Route = route, Start = start, Rotation = (root :: BasePart).CFrame.Rotation }
	end
end)

local function stepRoutes()
	local now = workspace:GetServerTimeNow()
	for root, r in pairs(routes) do
		if not root.Parent then
			routes[root] = nil
			continue
		end
		local elapsed = now - r.Start
		root.CFrame = RouteMotion.Pose(r.Route, RouteMotion.DistanceAt(r.Route, elapsed), r.Rotation)
		if elapsed > r.Route.Duration + HOLD_AFTER then
			routes[root] = nil
		end
	end
end

type WheelGroup = {
	Parts: { BasePart },
	Offsets: { CFrame }, -- relativo ao eixo
	Axle: Vector3, -- centro do eixo, relativo à Raiz
	Radius: number,
	Side: number, -- -1 esquerda, +1 direita (X da Raiz)
	Front: boolean,
	Spin: number, -- ângulo atual da roda
    V2Removed: number, -- animação individual de desmontagem, só nos pilotos
}

type Hood = { Parts: { BasePart }, Offsets: { CFrame }, Hinge: Vector3 }

type CarFx = {
	Model: Model,
	Root: BasePart,
	Wheels: { WheelGroup },
	Hood: Hood?,
	LastPos: Vector3,
	Speed: number,
	LastMove: number,
	Engine: Sound,
	Remove: number, -- 0..1 pneu fora (reparo)
	HoodOpen: number, -- 0..1
	FxKey: string, -- efeito montado agora ("" = nenhum)
	FxParts: { Instance },
	NextBurst: number,
	NextTool: number,
	Light: PointLight?,
	Sparks: ParticleEmitter?,
	SparkSound: Sound?,
}

local cars: { [Model]: CarFx } = {}

local function sound(parent: Instance, id: string, volume: number, looped: boolean): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = looped
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 70
	s.Parent = parent
	return s
end

local function dims(model: Model): (number, number, number)
	return tonumber(model:GetAttribute("Comprimento")) or 18, tonumber(model:GetAttribute("Largura")) or 8, tonumber(model:GetAttribute("Altura")) or 5
end

-- Tamanho da peça medido nos eixos do carro.
local function extents(rel: CFrame, size: Vector3): Vector3
	local r, u, l = rel.RightVector, rel.UpVector, rel.LookVector
	local function axis(v: Vector3): number
		return math.abs(r:Dot(v)) * size.X + math.abs(u:Dot(v)) * size.Y + math.abs(l:Dot(v)) * size.Z
	end
	return Vector3.new(axis(Vector3.xAxis), axis(Vector3.yAxis), axis(Vector3.zAxis))
end

local function ownParts(model: Model, root: BasePart): { BasePart }
	local list = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root and d.Name ~= "Casco" and d.Name ~= "InteractPoint"
			and not d:FindFirstAncestor("InspectionPoints") and not d:FindFirstAncestor("RepairPrepPoints")
            and not d:FindFirstAncestor("V2ComponentPoints") then
			local owner = d:FindFirstAncestorWhichIsA("Model")
			if owner == model or (owner and not owner:FindFirstChildOfClass("Humanoid")) then
				table.insert(list, d) -- o cliente sentado ao volante (modelo com Humanoid) não é parte do carro
			end
		end
	end
	return list
end

-- Solta a peça do conjunto SÓ no cliente (para podermos girar/mover): remove a solda e ancora localmente.
local function detach(root: BasePart, p: BasePart)
	local car = root:FindFirstAncestorWhichIsA("Model")
    if car then
        for _, w in ipairs(car:GetDescendants()) do
            local attached = false
            if w:IsA("WeldConstraint") or w:IsA("Weld") or w:IsA("Motor6D") then
                attached = w.Part1 == p or w.Part0 == p
            elseif w:IsA("RigidConstraint") then
                local a0, a1 = w.Attachment0, w.Attachment1
                attached = (a0 ~= nil and a0:IsDescendantOf(p))
                    or (a1 ~= nil and a1:IsDescendantOf(p))
            end
            if attached then
                w:Destroy() -- somente no cliente: desliga malha visual para animar
            end
        end
    end
	p.Anchored = true
    p.CanCollide = false -- o Casco invisível mantém a colisão autoritativa do veículo
end

local function detectWheels(model: Model, root: BasePart, parts: { BasePart }): { WheelGroup }
	local L, W, H = dims(model)
	local buckets: { [string]: { { Part: BasePart, Rel: CFrame, Ext: Vector3 } } } = {}
	for _, p in ipairs(parts) do
		local rel = root.CFrame:ToObjectSpace(p.CFrame)
		local pos = rel.Position
        local tagged = p:GetAttribute("V2MovingComponent")
        local explicit = ({ WheelFL = "LF", WheelFR = "RF", WheelRL = "LB", WheelRR = "RB" })[tagged]
        if explicit or (pos.Y < H * 0.45 and math.abs(pos.X) > W * 0.15
            and math.abs(pos.Z) > L * 0.15) then
            local ext = extents(rel, p.Size)
            local big = math.max(ext.Y, ext.Z)
            local geometryWheel = ext.Y > 0.6 and ext.Z > 0.6
                and math.abs(ext.Y - ext.Z) < big * 0.35
                and ext.X < W * 0.35 and big < H * 0.7
            if explicit or geometryWheel then
                local key = explicit or ((pos.X > 0 and "R" or "L") .. (pos.Z > 0 and "B" or "F"))
                buckets[key] = buckets[key] or {}
                table.insert(buckets[key], { Part = p, Rel = rel, Ext = ext })
            end
        end
	end
	local groups: { WheelGroup } = {}
	for key, list in pairs(buckets) do
		-- o pneu é a peça redonda maior; o eixo passa pelo centro dela
		table.sort(list, function(a, b)
			return math.max(a.Ext.Y, a.Ext.Z) > math.max(b.Ext.Y, b.Ext.Z)
		end)
		local tire = list[1]
		local radius = math.max(tire.Ext.Y, tire.Ext.Z) / 2
		local axle = tire.Rel.Position
		local group: WheelGroup = {
			Parts = {},
			Offsets = {},
			Axle = axle,
			Radius = math.max(radius, 0.5),
			Side = string.sub(key, 1, 1) == "R" and 1 or -1,
			Front = string.sub(key, 2, 2) == "F",
			Spin = 0,
            V2Removed = 0,
		}
		for _, item in ipairs(list) do
			local d = item.Rel.Position - axle
			if math.abs(d.Y) < radius * 0.7 and math.abs(d.Z) < radius * 0.7 then
				table.insert(group.Parts, item.Part)
				table.insert(group.Offsets, CFrame.new(axle):ToObjectSpace(item.Rel))
			end
		end
		if #group.Parts > 0 then
			table.insert(groups, group)
		end
	end
	return groups
end

local function detectHood(_model: Model, root: BasePart, parts: { BasePart }): Hood?
	local hoodParts = {}
	for _, p in ipairs(parts) do
		local n = string.lower(p.Name)
		if p:GetAttribute("V2MovingComponent") == "Hood" or string.find(n, "hood", 1, true) or string.find(n, "bonnet", 1, true) or string.find(n, "capo", 1, true) then
			table.insert(hoodParts, p)
		end
	end
	if #hoodParts == 0 then
		return nil
	end
	local maxZ, topY = -math.huge, -math.huge
	for _, p in ipairs(hoodParts) do
		local rel = root.CFrame:ToObjectSpace(p.CFrame)
		local ext = extents(rel, p.Size)
		maxZ = math.max(maxZ, rel.Position.Z + ext.Z / 2)
		topY = math.max(topY, rel.Position.Y + ext.Y / 2)
	end
	local hinge = Vector3.new(0, topY, maxZ) -- borda de trás do capô (perto do para-brisa)
	local hood: Hood = { Parts = hoodParts, Offsets = {}, Hinge = hinge }
	for i, p in ipairs(hoodParts) do
		hood.Offsets[i] = CFrame.new(hinge):ToObjectSpace(root.CFrame:ToObjectSpace(p.CFrame))
	end
	return hood
end

local function setup(model: Model): CarFx?
	local root = model.PrimaryPart
	if not root or root.Name ~= "Raiz" then
		return nil
	end
	local parts = ownParts(model, root)
	local wheels = detectWheels(model, root, parts)
    if type(model:GetAttribute("V2PilotId")) == "string" then
        -- Complementa GLBs monobloco que não tenham rodas individuais.
        -- Visual cliente; o Casco e toda a física continuam no servidor.
        local L, W, H = dims(model)
        for _, spec in ipairs({
            { Id = "WheelFL", Front = true, Side = -1 },
            { Id = "WheelFR", Front = true, Side = 1 },
            { Id = "WheelRL", Front = false, Side = -1 },
            { Id = "WheelRR", Front = false, Side = 1 },
        }) do
            local exists = false
            for _, group in ipairs(wheels) do
                if group.Front == spec.Front and group.Side == spec.Side then
                    exists = true
                    break
                end
            end
            if not exists then
                local radius = math.clamp(H * 0.21, 0.65, 1.65)
                local axle = Vector3.new(spec.Side * W * 0.46, radius,
                    (spec.Front and -1 or 1) * L * 0.34)
                local tire = Instance.new("Part")
                tire.Name = "V2Proxy_" .. spec.Id
                tire.Shape = Enum.PartType.Cylinder
                tire.Size = Vector3.new(0.82, radius * 2, radius * 2)
                tire.Color = Color3.fromRGB(26, 28, 31)
                tire.Material = Enum.Material.SmoothPlastic
                tire.Anchored = true
                tire.CanCollide, tire.CanTouch, tire.CanQuery = false, false, false
                tire.CFrame = root.CFrame * CFrame.new(axle)
                tire:SetAttribute("V2GeneratedVisual", true)
                tire.Parent = model
                local hub = Instance.new("Part")
                hub.Name = "V2ProxyHub_" .. spec.Id
                hub.Shape = Enum.PartType.Cylinder
                hub.Size = Vector3.new(0.11, radius * 1.15, radius * 1.15)
                hub.Color = Color3.fromRGB(150, 158, 168)
                hub.Material = Enum.Material.Metal
                hub.Anchored = true
                hub.CanCollide, hub.CanTouch, hub.CanQuery = false, false, false
                hub.CFrame = tire.CFrame * CFrame.new(spec.Side * 0.44, 0, 0)
                hub:SetAttribute("V2GeneratedVisual", true)
                hub.Parent = model
                table.insert(wheels, {
                    Parts = { tire, hub },
                    Offsets = { CFrame.identity, CFrame.new(spec.Side * 0.44, 0, 0) },
                    Axle = axle,
                    Radius = radius,
                    Side = spec.Side,
                    Front = spec.Front,
                    Spin = 0,
                    V2Removed = 0,
                })
            end
        end
    end
	local hood = detectHood(model, root, parts)
    if not hood and type(model:GetAttribute("V2PilotId")) == "string" then
        -- Asset monobloco: painel articulável client-side até o artista fornecer capô separado.
        local L, W, H = dims(model)
        local hinge = Vector3.new(0, H * 0.80, -L * 0.17)
        local center = Vector3.new(0, H * 0.80, -L * 0.34)
        local p = Instance.new("Part")
        p.Name = "V2ProxyHood"
        p.Size = Vector3.new(W * 0.78, 0.12, L * 0.34)
        p.CFrame = root.CFrame * CFrame.new(center)
        p.Anchored = true
        p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
        p.CastShadow = false
        p.Material = Enum.Material.Metal
        local profile = V2Art.Styles[model:GetAttribute("V2PilotId")]
        p.Color = profile and profile.Paint or Color3.fromRGB(95, 110, 125)
        p:SetAttribute("V2GeneratedVisual", true)
        p.Parent = model
        hood = { Parts = {p}, Hinge = hinge,
            Offsets = {CFrame.new(hinge):ToObjectSpace(CFrame.new(center))} }
    end
	for _, g in ipairs(wheels) do
		for _, p in ipairs(g.Parts) do
			detach(root, p)
		end
	end
	if hood then
		for _, p in ipairs(hood.Parts) do
			detach(root, p)
		end
	end
	local fx: CarFx = {
		Model = model,
		Root = root,
		Wheels = wheels,
		Hood = hood,
		LastPos = root.Position,
		Speed = 0,
		LastMove = 0,
		Engine = sound(root, SoundIds.Engine, 0, true),
		Remove = 0,
		HoodOpen = 0,
		FxKey = "",
		FxParts = {},
		NextBurst = 0,
		NextTool = 0,
		Light = nil,
		Sparks = nil,
		SparkSound = nil,
	}
	return fx
end

local function clearFx(fx: CarFx)
	for _, inst in ipairs(fx.FxParts) do
		inst:Destroy()
	end
	table.clear(fx.FxParts)
	fx.Light, fx.Sparks, fx.SparkSound = nil, nil, nil
end

local function attachment(fx: CarFx, pos: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Position = pos
	a.Parent = fx.Root
	table.insert(fx.FxParts, a)
	return a
end

local function smoke(parent: Attachment, color: Color3, rate: number, size: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 3) })
	e.Lifetime = NumberRange.new(1.6, 2.6)
	e.Rate = rate
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(18, 18)
	e.Acceleration = Vector3.new(0, 2.5, 0)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
	return e
end

local function sparks(parent: Attachment, color: Color3): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.25, 0.6)
	e.Rate = 0
	e.Speed = NumberRange.new(8, 16)
	e.SpreadAngle = Vector2.new(70, 70)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Parent = parent
	return e
end

local function frontWheel(fx: CarFx): WheelGroup?
	for _, g in ipairs(fx.Wheels) do
		if g.Front and g.Side < 0 then
			return g
		end
	end
	return fx.Wheels[1]
end

-- Monta o efeito do defeito (e do reparo) quando muda.
local function applyFx(fx: CarFx)
	local model = fx.Model
	local parked = model:GetAttribute("Estacionado") == true
	local symptom = parked and tostring(model:GetAttribute("Sintoma") or "") or ""
	local repairing = parked and model:GetAttribute("Reparando") == true
	local key = symptom .. (repairing and ":R" or "")
	if key == fx.FxKey then
		return
	end
	fx.FxKey = key
	clearFx(fx)
	if symptom == "" then
		return
	end
	local L, W, H = dims(model)
	if symptom == "Engine" then
		smoke(attachment(fx, Vector3.new(0, H * 0.72, -L * 0.36)), Color3.fromRGB(190, 190, 190), repairing and 3 or 7, 0.9)
		smoke(attachment(fx, Vector3.new(W * 0.25, H * 0.15, L * 0.5)), Color3.fromRGB(70, 70, 75), 9, 0.6)
		table.insert(fx.FxParts, (function()
			local s = sound(fx.Root, SoundIds.Hiss, 0.25, true)
			s:Play()
			return s
		end)())
	elseif symptom == "Electrical" then
		local a = attachment(fx, Vector3.new(0, H * 0.7, -L * 0.36))
		fx.Sparks = sparks(a, Color3.fromRGB(90, 170, 255))
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(90, 160, 255)
		light.Range = 10
		light.Brightness = 0
		light.Shadows = false
		light.Parent = a
		fx.Light = light
		local buzz = sound(fx.Root, SoundIds.Buzz, 0.2, true)
		buzz:Play()
		table.insert(fx.FxParts, buzz)
		fx.SparkSound = sound(fx.Root, SoundIds.Sparks, 0.35, false)
		table.insert(fx.FxParts, fx.SparkSound)
	elseif symptom == "Tires" then
		local g = frontWheel(fx)
		if g then
			smoke(attachment(fx, g.Axle + Vector3.new(g.Side * 0.6, -g.Radius * 0.6, 0)), Color3.fromRGB(220, 220, 220), 4, 0.5)
		end
	end
	if repairing then
		-- faíscas de trabalho perto de onde o mecânico mexe
		local spot = (symptom == "Tires" or symptom == "Suspension") and frontWheel(fx)
		local pos = spot and (spot.Axle + Vector3.new(spot.Side * 1.5, 0, 0)) or Vector3.new(0, H * 0.75, -L * 0.42)
		local a = attachment(fx, pos)
		local e = sparks(a, Color3.fromRGB(255, 200, 90))
		e.Rate = 6
		if not fx.Sparks then
			fx.Sparks = e
		end
	end
end

local function track(model: Instance)
	if not model:IsA("Model") or cars[model] then
		return
	end
	task.defer(function()
		if not model.Parent or cars[model] then
			return
		end
		local ok, fx = pcall(setup, model)
		if ok and fx then
			cars[model] = fx
		end
	end)
end

local function watch(folderName: string)
	local function hook(folder: Instance)
		for _, m in ipairs(folder:GetChildren()) do
			track(m)
		end
		folder.ChildAdded:Connect(track)
	end
	local existing = workspace:FindFirstChild(folderName)
	if existing then
		hook(existing)
	end
	workspace.ChildAdded:Connect(function(child)
		if child.Name == folderName then
			hook(child)
		end
	end)
end
watch("Vehicles")
watch("Arrivals")

local lastComponentState: { [Model]: { [string]: string } } = {}

RunService.RenderStepped:Connect(function(dt: number)
    stepRoutes()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local now = os.clock()
    local camPos = camera.CFrame.Position
	for model, fx in pairs(cars) do
		if not model.Parent or not fx.Root.Parent then
			clearFx(fx)
			fx.Engine:Destroy()
            lastComponentState[model] = nil
			cars[model] = nil
			continue
		end
		local root = fx.Root
		local pos = root.Position
		local moved = (pos - fx.LastPos)
		fx.LastPos = pos
		local far = (pos - camPos).Magnitude > MAX_DISTANCE
		if far then
			-- longe: sem som nem efeitos, mas rodas/capô (soltos só no cliente) continuam acompanhando o carro
			if fx.Engine.IsPlaying then
				fx.Engine:Stop()
			end
			for _, g in ipairs(fx.Wheels) do
				local wheelId = "Wheel" .. (g.Front and "F" or "R") .. (g.Side < 0 and "L" or "R")
                local state = model:GetAttribute("V2State_" .. wheelId)
                local offset = state == "Detached" and Vector3.new(g.Side * 3, -0.4, 0) or Vector3.zero
                local axleWorld = root.CFrame * CFrame.new(g.Axle + offset) * CFrame.Angles(g.Spin, 0, 0)
				for i, p in ipairs(g.Parts) do
					p.CFrame = axleWorld * g.Offsets[i]
				end
			end
			local farHood = fx.Hood
			if farHood then
				local isOpen = model:GetAttribute("Estacionado") == true
                    and (model:GetAttribute("V2State_Hood") == "Open" or model:GetAttribute("PrepHoodOpen") == true)
                local hinge = root.CFrame * CFrame.new(farHood.Hinge) *
                    CFrame.Angles(math.rad(55) * (isOpen and 1 or 0), 0, 0)
				for i, p in ipairs(farHood.Parts) do
					p.CFrame = hinge * farHood.Offsets[i]
				end
			end
			continue
		end
		local forward = -root.CFrame.LookVector:Dot(moved) -- frente = LookVector; positivo andando para frente
		local speed = moved.Magnitude / math.max(dt, 1 / 240)
		fx.Speed += (speed - fx.Speed) * math.min(1, dt * 6)
		if speed > 0.3 then
			fx.LastMove = now
		end
		-- motor
		local running = now - fx.LastMove < 1.5
		local target = running and 0.45 or 0
		fx.Engine.Volume += (target - fx.Engine.Volume) * math.min(1, dt * 3)
		fx.Engine.PlaybackSpeed = 0.85 + math.min(fx.Speed / 26, 1) * 0.7
		if fx.Engine.Volume > 0.02 and not fx.Engine.IsPlaying then
			fx.Engine:Play()
		elseif fx.Engine.Volume <= 0.02 and fx.Engine.IsPlaying then
			fx.Engine:Stop()
		end
		-- Feedback mecânico: somente mudança autorizada de estado (sem despesas ou servidor).
        if model:GetAttribute("V2PilotId") ~= nil then
            local previous = lastComponentState[model]
            if not previous then
                previous = {}
                lastComponentState[model] = previous
            end
            for _, id in ipairs({ "Hood", "WheelFL", "WheelFR", "WheelRL", "WheelRR" }) do
                local value = model:GetAttribute("V2State_" .. id)
                if type(value) == "string" then
                    if previous[id] and previous[id] ~= value then
                        local s = sound(fx.Root,
                            id == "Hood" and SoundIds.Ratchet or SoundIds.AirWrench, 0.18, false)
                        s:Play()
                        game:GetService("Debris"):AddItem(s, 4)
                    end
                    previous[id] = value
                end
            end
        end
		-- efeitos de defeito / reparo
		applyFx(fx)
		local repairing = model:GetAttribute("Reparando") == true and model:GetAttribute("Estacionado") == true
		local symptom = tostring(model:GetAttribute("Sintoma") or "")
		-- Após soltar porcas e apoiar o carro, a roda pode ser deslocada VISUALMENTE
		-- antes mesmo de abrir o painel. É animação local; não altera encaixes físicos.
		local prepPoints = model:FindFirstChild("RepairPrepPoints")
		local jackPoint = prepPoints and prepPoints:FindFirstChild("Prep_JackSupport")
		local wheelPrepared = jackPoint ~= nil and jackPoint:GetAttribute("Completed") == true
		local wantRemove = (repairing or wheelPrepared) and (symptom == "Tires" or symptom == "Suspension") and 1 or 0
		local wantHood = ((model:GetAttribute("V2State_Hood") == "Open"
            and model:GetAttribute("Estacionado") == true)
            or ((repairing or model:GetAttribute("PrepHoodOpen") == true)
                and (symptom == "Engine" or symptom == "Electrical"))) and 1 or 0
		fx.Remove += (wantRemove - fx.Remove) * math.min(1, dt * 2)
		fx.HoodOpen += (wantHood - fx.HoodOpen) * math.min(1, dt * 2)
		if fx.Light then
			fx.Light.Brightness = math.random() < 0.15 and math.random() * 3 or fx.Light.Brightness * 0.8
		end
		if fx.Sparks and now >= fx.NextBurst and symptom == "Electrical" then
			fx.NextBurst = now + 0.4 + math.random() * 1.2
			fx.Sparks:Emit(10)
			if fx.SparkSound then
				fx.SparkSound:Play()
			end
		end
		if repairing and now >= fx.NextTool then
			fx.NextTool = now + 2.2 + math.random() * 1.5
			local s = sound(root, (symptom == "Tires" or symptom == "Suspension") and SoundIds.AirWrench or SoundIds.Ratchet, 0.5, false)
			s:Play()
			game:GetService("Debris"):AddItem(s, 4)
		end
		-- rodas: giram pela distância percorrida; pneu murcho / torto / fora do carro
		if #fx.Wheels > 0 then
			local front = frontWheel(fx)
			for _, g in ipairs(fx.Wheels) do
				local spin = forward / g.Radius -- cada roda gira pelo próprio raio (sentido corrigido: para frente)
				local axle = g.Axle
				local extra = CFrame.identity
				if g == front then
					if symptom == "Tires" and model:GetAttribute("Estacionado") == true then
						axle += Vector3.new(0, -0.3, 0) -- pneu murcho
					elseif symptom == "Suspension" and model:GetAttribute("Estacionado") == true then
						extra = CFrame.Angles(0, 0, math.rad(10) * g.Side) -- roda torta
					end
					if not model:GetAttribute("V2PilotId") and fx.Remove > 0.001 then
                        axle += Vector3.new(g.Side * 3 * fx.Remove, -0.4 * fx.Remove, 0)
                    end
				end
				local wheelId = "Wheel" .. (g.Front and "F" or "R") .. (g.Side < 0 and "L" or "R")
                local removed = model:GetAttribute("V2PilotId") ~= nil
                    and model:GetAttribute("V2State_" .. wheelId) == "Detached"
                g.V2Removed += ((removed and 1 or 0) - g.V2Removed) * math.min(1, dt * 5)
                if g.V2Removed > 0.001 then
                    axle += Vector3.new(g.Side * 3 * g.V2Removed, -0.4 * g.V2Removed, 0)
                end
                g.Spin = (g.Spin + spin) % (math.pi * 2)
				local axleWorld = root.CFrame * CFrame.new(axle) * extra * CFrame.Angles(g.Spin, 0, 0)
				for i, p in ipairs(g.Parts) do
					p.CFrame = axleWorld * g.Offsets[i]
				end
			end
		end
		-- capô
		local hood = fx.Hood
		if hood then
			local hinge = root.CFrame * CFrame.new(hood.Hinge) * CFrame.Angles(math.rad(55) * fx.HoodOpen, 0, 0)
			for i, p in ipairs(hood.Parts) do
				p.CFrame = hinge * hood.Offsets[i]
			end
		end
	end
end)
