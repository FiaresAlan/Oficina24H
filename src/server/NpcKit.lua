--!strict
-- NpcKit: ferramentas comuns dos clientes NPC (modelo, posição, animação, caminhada, sumir). Os modelos vêm do assistente
-- 3D (ServerStorage.Assets.Customers) e a escolha é estável pelo nome do cliente (mesma pessoa = mesma aparência).
-- NPCs não colidem com ninguém (não empurram jogadores) e não têm dono de rede (o servidor decide tudo).
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local NpcAnimations = require(game:GetService("ReplicatedStorage").Shared.NpcAnimations)

local NpcKit = {}

NpcKit.WalkSpeed = 9

local function templates(): { Model }
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Customers")
	local list = {}
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") and child.PrimaryPart then
				table.insert(list, child)
			end
		end
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
	end
	return list
end

function NpcKit.Pick(customerName: string): Model?
	local list = templates()
	if #list == 0 then
		return nil
	end
	local sum = 0
	for i = 1, #customerName do
		sum += string.byte(customerName, i)
	end
	return list[(sum % #list) + 1]
end

-- Cópia pronta para o mundo (ainda sem Parent). Retorna nil se não houver modelo.
function NpcKit.Clone(customerName: string, name: string): Model?
	local template = NpcKit.Pick(customerName)
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
		end
	end
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.NameDisplayDistance = 0
		humanoid.HealthDisplayDistance = 0
		humanoid.WalkSpeed = NpcKit.WalkSpeed
		humanoid.AutoRotate = true
	end
	return npc
end

-- Coloca o NPC em pé com os pés em `feet`, de frente para `lookAt` (só gira no eixo vertical).
function NpcKit.Place(npc: Model, feet: Vector3, lookAt: Vector3?)
	local root = npc.PrimaryPart :: BasePart
	local boxCf, boxSize = npc:GetBoundingBox()
	local footOffset = root.Position.Y - (boxCf.Position.Y - boxSize.Y / 2)
	local standAt = feet + Vector3.new(0, footOffset, 0)
	if lookAt then
		npc:PivotTo(CFrame.lookAt(standAt, Vector3.new(lookAt.X, standAt.Y, lookAt.Z)))
	else
		npc:PivotTo(CFrame.new(standAt))
	end
end

-- Sem dono de rede: o servidor controla o movimento. Chamar DEPOIS de colocar no workspace.
function NpcKit.ServerOwned(npc: Model)
	local root = npc.PrimaryPart
	if root and root:IsDescendantOf(workspace) then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
end

export type NpcAnimator = { Idle: () -> (), Walk: () -> (), Stop: () -> () }

-- Animações de espera e de caminhada; se um clipe não carregar, o NPC segue funcionando (sem animar).
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
	local function load(id: string, priority: Enum.AnimationPriority): AnimationTrack?
		if not animator then
			return nil
		end
		local owner = animator
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return owner:LoadAnimation(animation)
		end)
		if not ok or not track then
			return nil
		end
		track.Looped = true
		track.Priority = priority
		return track
	end
	local idle = load(NpcAnimations.Idle, Enum.AnimationPriority.Idle)
	local walk = load(NpcAnimations.Walk, Enum.AnimationPriority.Movement)
	local controller = {} :: NpcAnimator
	controller.Idle = function()
		if walk then
			walk:Stop(0.2)
		end
		if idle and not idle.IsPlaying then
			idle:Play(0.2)
		end
	end
	controller.Walk = function()
		if idle then
			idle:Stop(0.2)
		end
		if walk and not walk.IsPlaying then
			walk:Play(0.2)
		end
	end
	controller.Stop = function()
		if idle then
			idle:Stop(0.1)
		end
		if walk then
			walk:Stop(0.1)
		end
	end
	return controller
end

-- Caminha até `target` (plano horizontal). Retorna true se chegou antes de `timeout`.
function NpcKit.WalkTo(npc: Model, target: Vector3, timeout: number): boolean
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc.PrimaryPart
	if not humanoid or not root then
		return false
	end
	local started = os.clock()
	humanoid:MoveTo(target)
	while os.clock() - started < timeout do
		if not npc.Parent then
			return false
		end
		local delta = (root.Position - target) * Vector3.new(1, 0, 1)
		if delta.Magnitude < 2 then
			return true
		end
		if (os.clock() - started) % 6 < 0.12 then
			humanoid:MoveTo(target) -- MoveTo desiste sozinho depois de ~8 s
		end
		task.wait(0.1)
	end
	return false
end

-- Balão de fala sobre a cabeça (substitui o anterior). `seconds` nil = fica até ser trocado.
function NpcKit.Say(npc: Model, text: string, seconds: number?)
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
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 60
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

-- Some suavemente e se destrói.
function NpcKit.FadeOut(npc: Model, seconds: number)
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			TweenService:Create(d, TweenInfo.new(seconds), { Transparency = 1 }):Play()
		end
	end
	task.delay(seconds + 0.1, function()
		npc:Destroy()
	end)
end

return NpcKit
