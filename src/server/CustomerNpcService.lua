--!strict
-- CustomerNpcService: cliente NPC físico ligado a uma ordem ACEITA. Fica ao lado do veículo na vaga (modelos do assistente 3D),
-- conta o problema num balão e, enquanto o diagnóstico está pendente, abre a conversa (diagnóstico) pelo prompt "Conversar".
-- Some quando a ordem acaba (concluída, dispensada, abandonada, expirada, dono saiu). A chegada pela rua é do
-- CustomerArrivalService; ferramentas comuns (modelo, animação, fala) ficam no NpcKit. Servidor é a única autoridade;
-- não existe NPC sem veículo, então não há duplicata ao entrar/sair.
local NpcKit = require(script.Parent.NpcKit)

local CustomerNpcService = {}

local byJob: { [string]: Model } = {}
local talkHandler: ((Player, string) -> ())? = nil

function CustomerNpcService.SetTalkHandler(handler: (Player, string) -> ())
	talkHandler = handler
end

-- Cliente aparece ao lado do carro, de frente para ele.
function CustomerNpcService.Spawn(car: Model, job: any, ownerUserId: number)
	if byJob[job.Id] then
		return
	end
	local npc = NpcKit.Clone(tostring(job.CustomerName or job.Id), "Cliente_" .. job.Id)
	if not npc then
		return -- sem modelo: o jogo segue sem o NPC (a interface continua funcionando)
	end
	local carCf, carSize = car:GetBoundingBox()
	local floorY = carCf.Position.Y - carSize.Y / 2
	local side = carCf.RightVector
	side = Vector3.new(side.X, 0, side.Z).Unit
	local carHalfWidth = math.min(carSize.X, carSize.Z) / 2
	local feet = Vector3.new(carCf.Position.X, floorY, carCf.Position.Z) + side * (carHalfWidth + 3.2)
	NpcKit.Place(npc, feet, Vector3.new(carCf.Position.X, floorY, carCf.Position.Z))
	npc:SetAttribute("JobId", job.Id)
	npc:SetAttribute("OwnerUserId", ownerUserId)

	local anchor = npc:FindFirstChild("HumanoidRootPart")
	if anchor and anchor:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Talk"
		prompt.ActionText = "Conversar"
		prompt.ObjectText = tostring(job.CustomerName or "Cliente")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Style = Enum.ProximityPromptStyle.Custom -- o HUD desenha o prompt (e só mostra para o dono)
		prompt.Enabled = not job.Diagnosed
		prompt.Parent = anchor
		prompt.Triggered:Connect(function(player: Player)
			if talkHandler and player.UserId == ownerUserId then
				talkHandler(player, job.Id)
			end
		end)
	end
	npc.Parent = workspace:FindFirstChild("Vehicles") or workspace
	NpcKit.ServerOwned(npc)
	NpcKit.Animate(npc).Idle()
	byJob[job.Id] = npc
	NpcKit.Say(npc, tostring(job.Complaint or "Olá! Pode olhar meu carro?"), nil)
end

-- Diagnóstico concluído: o cliente para de pedir conversa e fala da próxima etapa.
function CustomerNpcService.SetDiagnosed(jobId: string, diagnosed: boolean)
	local npc = byJob[jobId]
	if not npc then
		return
	end
	local root = npc:FindFirstChild("HumanoidRootPart")
	local prompt = root and root:FindFirstChild("Talk")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = not diagnosed
	end
	if diagnosed then
		NpcKit.Say(npc, "Entendi! Pode consertar.", 6)
	end
end

-- O cliente vai embora: despede-se e desaparece suavemente (sem rastro; sem NPC órfão).
function CustomerNpcService.Leave(jobId: string)
	local npc = byJob[jobId]
	if not npc then
		return
	end
	byJob[jobId] = nil
	local root = npc:FindFirstChild("HumanoidRootPart")
	local prompt = root and root:FindFirstChild("Talk")
	if prompt then
		prompt:Destroy()
	end
	NpcKit.Say(npc, "Até mais!", nil)
	task.delay(1.2, function()
		if npc.Parent then
			NpcKit.FadeOut(npc, 0.8)
		end
	end)
end

function CustomerNpcService.Count(): number
	local n = 0
	for _ in pairs(byJob) do
		n += 1
	end
	return n
end

return CustomerNpcService
