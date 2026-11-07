--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local VehicleService = require(script.Parent.VehicleService)
local EquipmentService = require(script.Parent.EquipmentService)
local WorkshopService = require(script.Parent.WorkshopService)
local StationService = require(script.Parent.StationService)
local RivalService = require(script.Parent.RivalService)

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "OficinaRemotes"
remotesFolder.Parent = ReplicatedStorage

local actionEvent = Instance.new("RemoteEvent")
actionEvent.Name = "Action"
actionEvent.Parent = remotesFolder

local snapshotFunction = Instance.new("RemoteFunction")
snapshotFunction.Name = "GetSnapshot"
snapshotFunction.Parent = remotesFolder

DataService.Start()
PlotService.Start()
StationService.Start() -- TV, prateleira, quadro, totem e elevadores em todos os lotes
PlotService.BeforeAssign = RivalService.MakeRoom
WorkshopService.Init(DataService)
WorkshopService.Start()
RivalService.Start() -- oficinas rivais (NPC) nos lotes livres

-- Gancho de QA: SÓ existe no Studio (nunca no jogo publicado). Permite simular jogador novo nos testes pelo comando.
if game:GetService("RunService"):IsStudio() then
    local qa = Instance.new("BindableFunction")
    qa.Name = "QA"
    qa.OnInvoke = function(command: any, player: any, arg: any): any
        if typeof(player) ~= "Instance" or not player:IsA("Player") then return "jogador inválido" end
        local profile = DataService.Get(player)
        if not profile then return "sem perfil" end
        if command == "NewPlayer" then
            profile.Onboarding = { Done = false }
            profile.Parts = { TirePatch = 3, Battery = 1, Fuse = 2 }
            return "ok"
        elseif command == "SetEarned" and type(arg) == "number" then
            profile.TotalEarned = arg
            WorkshopService.UpdateSkin(player)
            return "ok"
        elseif command == "Coins" and type(arg) == "number" then
            DataService.AddCoins(player, arg, "QA (Studio)")
            return profile.Coins
        elseif command == "AgeJobs" then
            return WorkshopService._ageJobsForTesting(player.UserId, 1000)
        elseif command == "Profile" then
            return { Coins = profile.Coins, Onboarding = profile.Onboarding.Done, TotalEarned = profile.TotalEarned }
        end
        return "comando desconhecido"
    end
    qa.Parent = game:GetService("ServerStorage")
end

-- Limitador por JOGADOR e por AÇÃO (uma ação rápida não descarta outra diferente). Só ações conhecidas entram na tabela.
local lastActionAt: {[number]: {[string]: number}} = {}
local KNOWN_ACTIONS: {[string]: boolean} = {}
for _, name in ipairs({ "ClaimWorkshop", "GenerateCustomer", "DeclineJob", "AcceptJob", "DiagnoseJob", "CompleteJob", "FinishRepair", "RepairPrefs", "CancelRepair", "SkipOnboarding", "BuyEquipment", "SetPrice", "BuyPart", "Checkout", "HireNpc", "InviteWorker", "CompleteCollaborativeJob", "RespondInvite", "MoveBag" }) do
    KNOWN_ACTIONS[name] = true
end

local function sendResult(player: Player, success: boolean, message: string, action: string?)
    actionEvent:FireClient(player, "Result", {
        Success = success,
        Message = message,
        Action = action, -- nome da ação que gerou o resultado (a interface limpa o carrinho só após "Checkout" bem-sucedido)
    })
end

VehicleService.PublishPreviews()
EquipmentService.PublishPreviews()

-- Loja de autopeças física: um prompt na fachada abre a Loja de Peças (o cliente escuta o prompt e abre o painel).
do
    local publicAreas = workspace:FindFirstChild("PublicAreas")
    local shopBuilding = publicAreas and publicAreas:FindFirstChild("LojaAutopecas")
    if shopBuilding and shopBuilding:IsA("BasePart") and not shopBuilding:FindFirstChild("ShopPrompt") then
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "ShopPrompt"
        prompt.ActionText = "Abrir loja"
        prompt.ObjectText = "Loja de Peças"
        prompt.HoldDuration = 0.3
        prompt.MaxActivationDistance = 28
        prompt.RequiresLineOfSight = false
        prompt.Style = Enum.ProximityPromptStyle.Custom
        prompt.Parent = shopBuilding
        prompt:SetAttribute("OpensPanel", "shop")
    end
end
-- Painel "Melhores oficinas do servidor" na praça (Workspace.Bairro.Praca, ver tools/BuildPlaza.luau).
task.spawn(function()
    while true do
        local bairro = workspace:FindFirstChild("Bairro")
        local praca = bairro and bairro:FindFirstChild("Praca")
        local label = praca and praca:FindFirstChild("Lista", true)
        if label and label:IsA("TextLabel") then
            label.Text = WorkshopService.TopWorkshopsText(5)
        end
        task.wait(15)
    end
end)

WorkshopService.SetRatingNotifier(function(owner: Player, info: any)
    actionEvent:FireClient(owner, "Rated", info)
end)
WorkshopService.SetEventSender(function(player: Player, kind: string, payload: any)
    actionEvent:FireClient(player, kind, payload) -- "RepairStart" / "RepairDone"
end)

local snapshotCache: { [number]: { At: number, Value: any } } = {} -- ver GetSnapshot abaixo

-- Prompts "E" (carro e cliente) também passam por limite por jogador: sem ele dava para disparar Interact em rajada.
local lastInteractAt: {[number]: number} = {}
Players.PlayerRemoving:Connect(function(player)
    lastInteractAt[player.UserId] = nil
end)
local function onPrompt(player: Player, jobId: string, kind: string)
    local nowClock = os.clock()
    if nowClock - (lastInteractAt[player.UserId] or 0) < 0.5 then return end
    lastInteractAt[player.UserId] = nowClock
    snapshotCache[player.UserId] = nil
    local ok, message = WorkshopService.Interact(player, jobId, kind)
    sendResult(player, ok, message)
end
VehicleService.SetInteractionHandler(onPrompt)
-- Estações físicas do lote (StationService): contratar/demitir mecânico e expandir a oficina pelos prompts.
-- "Ver ordens" e "Abrir estoque" só abrem telas no cliente (o servidor valida a distância nas ações).
StationService.SetPromptHandler(function(player: Player, _plot: Instance, action: string)
    local nowClock = os.clock()
    if nowClock - (lastInteractAt[player.UserId] or 0) < 0.5 then return end
    lastInteractAt[player.UserId] = nowClock
    snapshotCache[player.UserId] = nil
    local ok, message
    if action == "Contratar" then
        ok, message = WorkshopService.HireEmployee(player)
    elseif action == "Demitir" then
        ok, message = WorkshopService.FireEmployee(player)
    elseif action == "Expandir" then
        ok, message = WorkshopService.BuyExpansion(player)
    else
        return
    end
    sendResult(player, ok, message)
end)

-- GetSnapshot custa CPU (percorre ordens e ranking): resposta em cache por 0,4 s por jogador contra laço de InvokeServer.
snapshotFunction.OnServerInvoke = function(player: Player)
    local profile = DataService.Get(player)
    if not profile then
        return { Ready = false }
    end
    local cached = snapshotCache[player.UserId]
    if cached and os.clock() - cached.At < 0.4 then
        return cached.Value
    end
    local value = WorkshopService.GetSnapshot(player)
    snapshotCache[player.UserId] = { At = os.clock(), Value = value }
    return value
end

actionEvent.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
    if type(action) ~= "string" or type(payload) ~= "table" then return end

    if not KNOWN_ACTIONS[action] then return end
    local now = os.clock()
    local perPlayer = lastActionAt[player.UserId]
    if not perPlayer then
        perPlayer = {}
        lastActionAt[player.UserId] = perPlayer
    end
    if now - (perPlayer[action] or 0) < 0.25 then return end
    perPlayer[action] = now
    snapshotCache[player.UserId] = nil -- a ação vai mudar o estado: o próximo snapshot não pode vir do cache

    local success = false
    local message = "Ação desconhecida."

    if action == "ClaimWorkshop" then
        success, message = WorkshopService.ClaimWorkshop(player)
    elseif action == "GenerateCustomer" then
        success, message = WorkshopService.GenerateCustomer(player)
    elseif action == "DeclineJob" and type(payload.JobId) == "string" then
        success, message = WorkshopService.DeclineJob(player, payload.JobId)
    elseif action == "AcceptJob" and type(payload.JobId) == "string" then
        success, message = WorkshopService.AcceptJob(player, payload.JobId)
    elseif action == "DiagnoseJob" and type(payload.JobId) == "string" then
        success, message = WorkshopService.DiagnoseJob(player, payload.JobId, payload.Choice)
    elseif action == "CompleteJob" and type(payload.JobId) == "string" then
        -- Não existe mais conclusão direta: todo reparo passa pelo minijogo (sessão sorteada e cronometrada no servidor).
        success, message = WorkshopService.StartRepair(player, payload.JobId, payload.Assist == true)
    elseif action == "FinishRepair" and type(payload.JobId) == "string" and type(payload.Presses) == "table" then
        success, message = WorkshopService.FinishRepair(player, payload.JobId, payload.Presses)
    elseif action == "RepairPrefs" and type(payload.Assist) == "boolean" then
        success, message = WorkshopService.SetRepairAssist(player, payload.Assist)
    elseif action == "CancelRepair" then
        success, message = WorkshopService.CancelRepair(player)
    elseif action == "SkipOnboarding" then
        success, message = WorkshopService.SkipOnboarding(player)
    elseif action == "BuyEquipment" and type(payload.EquipmentId) == "string" then
        success, message = WorkshopService.BuyEquipment(player, payload.EquipmentId)
    elseif action == "SetPrice" and type(payload.Multiplier) == "number" then
        success, message = WorkshopService.SetPrice(player, payload.Multiplier)
    elseif action == "BuyPart" and type(payload.PartId) == "string" and type(payload.Quantity) == "number" then
        success, message = WorkshopService.BuyPart(player, payload.PartId, payload.Quantity)
    elseif action == "MoveBag" and type(payload.PartId) == "string" and type(payload.Quantity) == "number" and type(payload.ToBag) == "boolean" then
        success, message = WorkshopService.MoveBag(player, payload.PartId, payload.Quantity, payload.ToBag)
    elseif action == "Checkout" and type(payload.Items) == "table" then
        success, message = WorkshopService.Checkout(player, payload.Items)
    elseif action == "HireNpc" and type(payload.JobId) == "string" then
        success, message = WorkshopService.HireNpc(player, payload.JobId)
    elseif action == "InviteWorker"
        and type(payload.WorkerUserId) == "number"
        and type(payload.JobId) == "string"
        and type(payload.SplitPercent) == "number" then
        success, message = WorkshopService.InviteWorker(
            player,
            payload.WorkerUserId,
            payload.JobId,
            payload.SplitPercent
        )
        if success then
            -- O ID do convite é devolvido na mensagem para o proprietário.
            local inviteId = string.match(message, "Convite criado: (.+)")
            local worker = Players:GetPlayerByUserId(payload.WorkerUserId)
            if worker and inviteId then
                actionEvent:FireClient(worker, "WorkInvite", {
                    InviteId = inviteId,
                    OwnerName = player.DisplayName,
                    JobId = payload.JobId,
                    SplitPercent = math.clamp(math.floor(payload.SplitPercent), 1, 80),
                })
            end
        end
    elseif action == "CompleteCollaborativeJob" and type(payload.JobId) == "string" then
        success, message = WorkshopService.CompleteCollaborativeJob(player, payload.JobId)
    elseif action == "RespondInvite" and type(payload.InviteId) == "string" and type(payload.Accepted) == "boolean" then
        success, message = WorkshopService.RespondInvite(player, payload.InviteId, payload.Accepted)
    end

    sendResult(player, success, message, action)
end)

-- Registro automático da oficina assim que os dados carregam (o botão da UI continua como alternativa).
local function autoClaim(player: Player)
    local waited = 0
    while player.Parent == Players and not DataService.Get(player) and waited < 60 do
        task.wait(0.5)
        waited += 0.5
    end
    if player.Parent == Players and DataService.Get(player) then
        WorkshopService.ClaimWorkshop(player)
    end
end
Players.PlayerAdded:Connect(autoClaim)
for _, existing in ipairs(Players:GetPlayers()) do
    task.spawn(autoClaim, existing)
end

Players.PlayerRemoving:Connect(function(player)
    lastActionAt[player.UserId] = nil
    snapshotCache[player.UserId] = nil
    WorkshopService.PlayerLeft(player.UserId)
end)
