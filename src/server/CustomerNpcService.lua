--!strict
-- CustomerNpcService: cliente NPC ligado a uma ordem ACEITA. Depois de estacionar o carro na vaga (VehicleService), ele
-- desce e fica atrás do carro, perto do portão, conta o problema num balão e, enquanto o diagnóstico está pendente,
-- abre a conversa (diagnóstico) pelo prompt "Conversar". Quando a ordem acaba, Take() o devolve ao VehicleService, que o
-- põe de volta ao volante e tira o carro da vaga. Ferramentas comuns (modelo, animação, fala) ficam no NpcKit.
-- Servidor é a única autoridade; não existe NPC sem veículo, então não há duplicata ao entrar/sair.
local NpcKit = require(script.Parent.NpcKit)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local TALK_DISTANCE = Config.TalkDistance

local CustomerNpcService = {}

type Entry = { Npc: Model, Animator: NpcKit.NpcAnimator? }

local byJob: { [string]: Entry } = {}
local talkHandler: ((Player, string) -> ())? = nil

function CustomerNpcService.SetTalkHandler(handler: (Player, string) -> ())
	talkHandler = handler
end

-- Passa a cuidar de um cliente que já está em pé ao lado do carro estacionado.
function CustomerNpcService.Adopt(npc: Model, animator: NpcKit.NpcAnimator?, job: any, ownerUserId: number)
	if byJob[job.Id] then
		return
	end
	npc:SetAttribute("JobId", job.Id)
	npc:SetAttribute("OwnerUserId", ownerUserId)
	local anchor = npc:FindFirstChild("HumanoidRootPart")
	if anchor and anchor:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Talk"
		prompt.ActionText = "Conversar"
		prompt.ObjectText = job.Vip and "Cliente VIP" or "Cliente" -- o nome já aparece sobre a cabeça
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = TALK_DISTANCE -- só de perto (~3 m)
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Style = Enum.ProximityPromptStyle.Custom -- o HUD desenha o prompt (e só mostra para o dono)
		prompt:SetAttribute("OwnerUserId", ownerUserId)
		prompt.Enabled = not job.Diagnosed
		prompt.Parent = anchor
		prompt.Triggered:Connect(function(player: Player)
			if talkHandler and player.UserId == ownerUserId then
				talkHandler(player, job.Id)
			end
		end)
	end
	if animator then
		animator.Idle()
	end
	byJob[job.Id] = { Npc = npc, Animator = animator }
	NpcKit.Say(npc, tostring(job.Complaint or "Olá! Pode olhar meu carro?"), nil, job.Vip and Color3.fromRGB(255, 200, 40) or nil)
end

-- Diagnóstico concluído: o cliente para de pedir conversa e fala da próxima etapa.
function CustomerNpcService.SetDiagnosed(jobId: string, diagnosed: boolean)
	local entry = byJob[jobId]
	if not entry then
		return
	end
	local root = entry.Npc:FindFirstChild("HumanoidRootPart")
	local prompt = root and root:FindFirstChild("Talk")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = not diagnosed
	end
	if diagnosed then
		NpcKit.Say(entry.Npc, "Entendi! Pode consertar.", 6)
	end
end

-- Devolve o cliente (sem prompt) para quem vai levá-lo embora; nil se não houver.
function CustomerNpcService.Take(jobId: string): (Model?, NpcKit.NpcAnimator?)
	local entry = byJob[jobId]
	if not entry then
		return nil, nil
	end
	byJob[jobId] = nil
	local root = entry.Npc:FindFirstChild("HumanoidRootPart")
	local prompt = root and root:FindFirstChild("Talk")
	if prompt then
		prompt:Destroy()
	end
	return entry.Npc, entry.Animator
end

-- O cliente some sem animação (dono saiu).
function CustomerNpcService.Leave(jobId: string)
	local npc = CustomerNpcService.Take(jobId)
	if npc then
		npc:Destroy()
	end
end

-- O jogador está perto do cliente desta ordem (conversa/diagnóstico só de perto)? nil = sem NPC (então não restringe).
function CustomerNpcService.IsNear(player: Player, jobId: string, maxDistance: number): boolean?
	local entry = byJob[jobId]
	local root = entry and entry.Npc.PrimaryPart
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	if not hrp or not hrp:IsA("BasePart") then
		return false
	end
	return (hrp.Position - root.Position).Magnitude <= maxDistance
end

function CustomerNpcService.Count(): number
	local n = 0
	for _ in pairs(byJob) do
		n += 1
	end
	return n
end

return CustomerNpcService
