--!strict
-- NpcKit: ferramentas comuns dos clientes NPC (modelo, posição, animação, caminhada, volante, sumir).
-- Modelos: avatares oficiais e gratuitos da Roblox em ServerStorage.Assets.Clientes, com atributo Genero ("M" ou "F").
-- O gênero vem da ordem (Catalog.PickCustomer), então o nome sempre combina com a aparência; a escolha dentro do gênero
-- é estável pelo nome (mesmo cliente = mesma aparência).
-- NPCs não colidem com ninguém (não empurram jogadores nem enroscam em placas) e o servidor decide o movimento.
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local NpcAnimations = require(game:GetService("ReplicatedStorage").Shared.NpcAnimations)

local NpcKit = {}

NpcKit.WalkSpeed = 10
NpcKit.SeatLift = 0.55 -- altura do HumanoidRootPart acima do ponto do banco (atributo Motorista): cabeça abaixo do teto

local function templates(gender: string?): { Model }
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Clientes")
	local list = {}
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") and child.PrimaryPart
				and (gender == nil or child:GetAttribute("Genero") == gender) then
				table.insert(list, child)
			end
		end
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
	end
	return list
end

-- Modelo do cliente: do gênero pedido (se houver), escolhido de forma estável pelo nome.
function NpcKit.Pick(gender: string?, customerName: string): Model?
	local list = templates(gender)
	if #list == 0 then
		list = templates(nil)
	end
	if #list == 0 then
		return nil
	end
	local sum = 0
	for i = 1, #customerName do
		sum += string.byte(customerName, i) * i
	end
	return list[(sum % #list) + 1]
end

-- Cópia pronta para o mundo (ainda sem Parent). Retorna nil se não houver modelo.
function NpcKit.Clone(gender: string?, customerName: string, name: string): Model?
	local template = NpcKit.Pick(gender, customerName)
	if not template then
		return nil
	end
	local npc = template:Clone()
	npc.Name = name
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false -- não atrapalha prompts nem raios
			d.CanTouch = false
			d.Massless = true
		end
	end
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.NameDisplayDistance = 0
		humanoid.HealthDisplayDistance = 0
		humanoid.WalkSpeed = NpcKit.WalkSpeed
		humanoid.AutoRotate = true
		humanoid.BreakJointsOnDeath = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	end
	npc:SetAttribute("Cliente", customerName)
	return npc
end

-- Coloca o NPC em pé com os pés em `feet`, de frente para `lookAt` (só gira no eixo vertical).
function NpcKit.Place(npc: Model, feet: Vector3, lookAt: Vector3?)
	local root = npc.PrimaryPart :: BasePart
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local hip = humanoid and humanoid.HipHeight or 2
	local standAt = feet + Vector3.new(0, hip + root.Size.Y / 2, 0)
	if lookAt and (Vector3.new(lookAt.X, 0, lookAt.Z) - Vector3.new(feet.X, 0, feet.Z)).Magnitude > 0.05 then
		npc:PivotTo(CFrame.lookAt(standAt, Vector3.new(lookAt.X, standAt.Y, lookAt.Z)))
	else
		npc:PivotTo(CFrame.new(standAt))
	end
end

-- Sem dono de rede: o servidor controla o movimento. Chamar DEPOIS de colocar no workspace.
function NpcKit.ServerOwned(npc: Model)
	local root = npc.PrimaryPart
	if root and root:IsDescendantOf(workspace) and not root.Anchored then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
end

export type NpcAnimator = { Idle: () -> (), Walk: () -> (), Sit: () -> (), Stop: () -> () }

-- Animações de espera, caminhada e volante; se um clipe não carregar, o NPC segue funcionando (sem animar).
function NpcKit.Animate(npc: Model): NpcAnimator
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local animator: Animator? = nil
	if humanoid then
		local found = humanoid:FindFirstChildOfClass("Animator")
		if found then
			animator = found
		else
			local created = Instance.new("Animator")
			created.Parent = humanoid
			animator = created
		end
	end
	local cache: { [string]: AnimationTrack } = {}
	local function track(key: string, priority: Enum.AnimationPriority): AnimationTrack?
		if cache[key] then
			return cache[key]
		end
		if not animator then
			return nil
		end
		local owner = animator
		local animation = Instance.new("Animation")
		animation.AnimationId = (NpcAnimations :: any)[key]
		local ok, loaded = pcall(function()
			return owner:LoadAnimation(animation)
		end)
		if not ok or not loaded then
			return nil
		end
		loaded.Looped = true
		loaded.Priority = priority
		cache[key] = loaded
		return loaded
	end
	local function only(key: string, priority: Enum.AnimationPriority)
		for name, t in pairs(cache) do
			if name ~= key and t.IsPlaying then
				t:Stop(0.2)
			end
		end
		local t = track(key, priority)
		if t and not t.IsPlaying then
			t:Play(0.2)
		end
	end
	local controller = {} :: NpcAnimator
	controller.Idle = function()
		only("Idle", Enum.AnimationPriority.Idle)
	end
	controller.Walk = function()
		only("Walk", Enum.AnimationPriority.Movement)
	end
	controller.Sit = function()
		only("Sit", Enum.AnimationPriority.Action)
	end
	controller.Stop = function()
		for _, t in pairs(cache) do
			t:Stop(0.1)
		end
	end
	return controller
end

-- Senta o NPC ao volante: solda o HumanoidRootPart na Raiz do carro, no ponto do banco do motorista (atributo
-- Motorista). Enquanto sentado ele faz parte do conjunto do carro (anda junto quando a Raiz se move).
function NpcKit.SeatIn(npc: Model, car: Model, animator: NpcAnimator?)
	local root = npc.PrimaryPart
	local carRoot = car.PrimaryPart
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not root or not carRoot then
		return
	end
	local old = root:FindFirstChild("Volante")
	if old then
		old:Destroy()
	end
	local seatPoint = car:GetAttribute("Motorista")
	local offset = typeof(seatPoint) == "Vector3" and seatPoint or Vector3.new(-1.5, 1.5, 0)
	if humanoid then
		humanoid:Move(Vector3.zero)
		humanoid.PlatformStand = true
	end
	npc:PivotTo(carRoot.CFrame * CFrame.new(offset + Vector3.new(0, NpcKit.SeatLift, 0)))
	local weld = Instance.new("Weld")
	weld.Name = "Volante"
	weld.Part0 = carRoot
	weld.Part1 = root
	weld.C0 = CFrame.new(offset + Vector3.new(0, NpcKit.SeatLift, 0))
	weld.Parent = root
	if animator then
		animator.Sit()
	end
end

-- Tira o NPC do carro e o põe em pé em `feet`, olhando para `lookAt`.
function NpcKit.Unseat(npc: Model, feet: Vector3, lookAt: Vector3?)
	local root = npc.PrimaryPart
	local weld = root and root:FindFirstChild("Volante")
	if weld then
		weld:Destroy()
	end
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end
	NpcKit.Place(npc, feet, lookAt)
	NpcKit.ServerOwned(npc)
end

-- Caminha até `target` (plano horizontal). Retorna true se chegou antes de `timeout`.
function NpcKit.WalkTo(npc: Model, target: Vector3, timeout: number): boolean
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc.PrimaryPart
	if not humanoid or not root then
		return false
	end
	local started = os.clock()
	local lastNudge = started
	humanoid:MoveTo(target)
	while os.clock() - started < timeout do
		if not npc.Parent then
			return false
		end
		local delta = (root.Position - target) * Vector3.new(1, 0, 1)
		if delta.Magnitude < 1.5 then
			return true
		end
		if os.clock() - lastNudge > 5 then
			lastNudge = os.clock()
			humanoid:MoveTo(target) -- MoveTo desiste sozinho depois de ~8 s
		end
		task.wait(0.1)
	end
	return false
end

-- Caminha por uma lista de pontos; se travar em algum, teletransporta para ele (nunca fica enroscado).
function NpcKit.WalkPath(npc: Model, points: { Vector3 }, animator: NpcAnimator?)
	if animator then
		animator.Walk()
	end
	for _, point in ipairs(points) do
		if not npc.Parent then
			return
		end
		local root = npc.PrimaryPart
		local distance = root and ((root.Position - point) * Vector3.new(1, 0, 1)).Magnitude or 0
		if not NpcKit.WalkTo(npc, point, distance / NpcKit.WalkSpeed + 2.5) and npc.Parent then
			NpcKit.Place(npc, point, nil)
			NpcKit.ServerOwned(npc)
		end
	end
	if animator then
		animator.Idle()
	end
end

-- Balão de fala sobre a cabeça (substitui o anterior). `seconds` nil = fica até ser trocado.
function NpcKit.Say(npc: Model, text: string, seconds: number?, accent: Color3?)
	local head = npc:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local old = head:FindFirstChild("Speech")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Speech"
	gui.Size = UDim2.fromOffset(260, 64)
	gui.StudsOffset = Vector3.new(0, 4.4, 0)
	gui.MaxDistance = 70
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	label.BackgroundTransparency = 0.05
	label.TextColor3 = Color3.fromRGB(20, 30, 50)
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	if accent then
		local stroke = Instance.new("UIStroke")
		stroke.Color = accent
		stroke.Thickness = 3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = label
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = head
	if seconds then
		task.delay(seconds, function()
			if gui.Parent then
				gui:Destroy()
			end
		end)
	end
end

-- Etiqueta com o nome do cliente (e coroa dourada quando é VIP), sempre visível de perto.
function NpcKit.NameTag(npc: Model, text: string, vip: boolean)
	local head = npc:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local old = head:FindFirstChild("NameTag")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(180, 26)
	gui.StudsOffset = Vector3.new(0, 1.5, 0)
	gui.MaxDistance = 45
	gui.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.Text = vip and ("★ VIP · " .. text) or text
	label.TextColor3 = vip and Color3.fromRGB(255, 205, 60) or Color3.fromRGB(255, 255, 255)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 20, 30)
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = head
end

-- Some suavemente e se destrói.
function NpcKit.FadeOut(npc: Model, seconds: number)
	for _, d in ipairs(npc:GetDescendants()) do
		if (d:IsA("BasePart") and d.Transparency < 1) or d:IsA("Decal") then
			TweenService:Create(d, TweenInfo.new(seconds), { Transparency = 1 }):Play()
		end
	end
	task.delay(seconds + 0.1, function()
		npc:Destroy()
	end)
end

return NpcKit
