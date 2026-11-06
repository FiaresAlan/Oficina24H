--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local JobRules = require(ReplicatedStorage.Shared.JobRules)
local CustomerRules = require(ReplicatedStorage.Shared.CustomerRules)
local RepairRules = require(ReplicatedStorage.Shared.RepairRules)
local DiagnosisRules = require(ReplicatedStorage.Shared.DiagnosisRules)

local WorkshopService = {}

local PlotService = require(script.Parent.PlotService)
local VehicleService = require(script.Parent.VehicleService)
local CustomerArrivalService = require(script.Parent.CustomerArrivalService)
local WorkshopSkin = require(script.Parent.WorkshopSkin)
local EquipmentService = require(script.Parent.EquipmentService)

local DataService: any
local updatePriceBoard: (Player) -> () -- definido adiante; declarado aqui porque ClaimWorkshop o usa
local Workshops: {[number]: any} = {}
local Jobs: {[string]: any} = {}
local Invites: {[string]: any} = {}
local nextJobId = 0
local nextInviteId = 0
local ratingNotifier: ((Player, any) -> ())? = nil -- definido por Main (envia o evento "Rated" ao cliente)
local eventSender: ((Player, string, any) -> ())? = nil -- definido por Main (RepairStart / RepairDone)
local Repairs: { [number]: { JobId: string, Plan: any, StartedAt: number } } = {} -- sessões do minijogo, por jogador
local RepairAssist: { [number]: boolean } = {} -- preferência de acessibilidade (Reduzir movimento), por jogador

local function isFinite(value: any): boolean
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function newId(prefix: string, number: number): string
    return prefix .. "_" .. tostring(number)
end

local function getWorkshop(player: Player)
    return Workshops[player.UserId]
end

local function ownsEquipment(workshop: any, equipmentId: string): boolean
    return workshop.Equipment[equipmentId] == true
end

local function getOpenJobCount(ownerUserId: number): number
    local count = 0
    for _, job in pairs(Jobs) do
        if job.OwnerUserId == ownerUserId and job.Status ~= "Completed" then
            count += 1
        end
    end
    return count
end

-- Texto com as peças que faltam no estoque de `owner` para o serviço, ou nil se estiver tudo disponível.
local function missingPartsMessage(owner: Player, needed: { [string]: number }?): string?
    local missing = {}
    for partId, count in pairs(needed or {}) do
        local have = DataService.GetPartCount(owner, partId)
        if have < count then
            table.insert(missing, string.format("%s (%d/%d)", Catalog.Parts[partId].DisplayName, have, count))
        end
    end
    if #missing == 0 then
        return nil
    end
    table.sort(missing)
    return "Faltam peças: " .. table.concat(missing, ", ")
end

-- O cliente avalia o serviço (1 a 5 estrelas, ver CustomerRules.RateService): registra na oficina do dono e ajusta a reputação.
-- `executor`: quem fez o trabalho (para a sobra de nível); `byNpc`: mecânico NPC.
local function rateService(owner: Player, job: any, service: any, defect: any, executor: Player?, byNpc: boolean, quality: number?): number
    local profile = DataService.Get(owner)
    local margin = 0
    if executor and not byNpc then
        margin = math.max(0, DataService.GetSkillLevel(executor, defect.Specialization) - defect.RequiredLevel)
    end
    local context = {
        PriceMultiplier = job.PriceMultiplier or (profile and profile.PriceMultiplier) or 1,
        WaitSeconds = os.time() - job.CreatedAt,
        PatienceSeconds = Config.CustomerPatienceSeconds,
        LevelMargin = margin,
        ByNpc = byNpc,
        Quality = quality,
    }
    local stars = CustomerRules.RateService(context, math.random)
    local reputationDelta = CustomerRules.ReputationDelta(stars)
    local commentKey = CustomerRules.CommentKey(context, stars)
    DataService.AddRating(owner, stars, service.DisplayName, { CommentKey = commentKey, Customer = job.CustomerName })
    DataService.AddOrderHistory(owner, {
        Vehicle = job.VehicleName,
        Customer = job.CustomerName or "?",
        Service = service.DisplayName,
        Price = job.Price or service.Reward,
        Stars = stars,
    })
    DataService.AddReputation(owner, reputationDelta) -- negativo reduz (piso em 0)
    if ratingNotifier then
        -- Só o dono da oficina é avisado (a nota vale para a oficina dele, mesmo quando um colaborador executa).
        ratingNotifier(owner, {
            Stars = stars,
            CommentKey = commentKey,
            ReputationDelta = reputationDelta,
            Service = service.DisplayName,
            Quality = quality,
        })
    end
    return stars
end

function WorkshopService.SetRatingNotifier(callback: ((Player, any) -> ())?)
    ratingNotifier = callback
end

function WorkshopService.SetEventSender(callback: ((Player, string, any) -> ())?)
    eventSender = callback
end

-- `specialization` (opcional): o cliente procurou um especialista nessa área (escolha de mercado, ver DispatchCustomers).
local function createJob(ownerUserId: number, specialization: string?)
    -- O defeito depende da capacidade da oficina (nível e equipamento), ver shared/JobRules.
    local owner = Players:GetPlayerByUserId(ownerUserId)
    local profile = owner and DataService.Get(owner)
    local skillLevels, equipment = {}, {}
    if owner and profile then
        for _, specialization in ipairs(Catalog.Specializations) do
            skillLevels[specialization] = DataService.GetSkillLevel(owner, specialization)
        end
        equipment = profile.Equipment
    end
    local defectId = JobRules.PickDefectId(skillLevels, equipment, math.random, specialization)
    local defect = Catalog.Defects[defectId]
    -- O preço é fixado quando o cliente chega: mudar a tabela depois não altera ordens já abertas.
    local multiplier = profile and profile.PriceMultiplier or 1
    local price = math.max(1, math.floor(Catalog.Services[defect.ServiceId].Reward * multiplier + 0.5))

    -- Nem toda reclamação corresponde ao defeito real: em ~35% dos casos o cliente descreve o sintoma de outro
    -- problema (de outra especialização). O jogador precisa diagnosticar para saber o que realmente está errado.
    local complaint = defect.Complaint
    local complaintDefectId = defectId
    if math.random() < 0.35 then
        local others = {}
        for otherId, other in pairs(Catalog.Defects) do
            if otherId ~= defectId and other.Specialization ~= defect.Specialization then
                table.insert(others, otherId)
            end
        end
        table.sort(others)
        if #others > 0 then
            complaintDefectId = others[math.random(1, #others)]
            complaint = Catalog.Defects[complaintDefectId].Complaint
        end
    end

    nextJobId += 1
    local id = newId("job", nextJobId)
    Jobs[id] = {
        Id = id,
        OwnerUserId = ownerUserId,
        VehicleName = Catalog.VehicleNames[math.random(1, #Catalog.VehicleNames)],
        CustomerName = Catalog.CustomerNames[math.random(1, #Catalog.CustomerNames)],
        Complaint = complaint,
        ComplaintDefectId = complaintDefectId,
        DefectId = defectId,
        ServiceId = defect.ServiceId,
        Price = price,
        PriceMultiplier = multiplier,
        Status = "Available",
        AssignedWorkerUserId = nil,
        Diagnosed = false,
        CreatedAt = os.time(),
    }
    local job = Jobs[id]
    local eta = math.ceil(CustomerArrivalService.Arrive(job))
    job.ArrivesAt = os.time() + eta
    job.CreatedAt = job.ArrivesAt
    if eta > 0 and eventSender then
        task.delay(eta, function()
            local current = Jobs[id]
            local ownerNow = Players:GetPlayerByUserId(ownerUserId)
            if current and current.Status == "Available" and ownerNow and eventSender then
                eventSender(ownerNow, "Notice", { Message = tostring(current.CustomerName) .. " chegou com " .. tostring(current.VehicleName) .. ".", Success = true })
            end
        end)
    end
    return job
end

function WorkshopService.Init(dataService: any)
    DataService = dataService
end

function WorkshopService.ClaimWorkshop(player: Player)
    if Workshops[player.UserId] then
        return false, "Você já possui uma oficina."
    end

    local plot = PlotService.GetPlot(player)
    if not plot then
        local ok, message = PlotService.Assign(player)
        if not ok then
            return false, message
        end
        plot = PlotService.GetPlot(player)
    end

    local profile = DataService.Get(player)
    if not profile then
        return false, "Seus dados ainda estão carregando."
    end

    Workshops[player.UserId] = {
        OwnerUserId = player.UserId,
        PlotId = plot and plot:GetAttribute("PlotId") or nil,
        Name = "Oficina de " .. player.DisplayName,
        Equipment = profile.Equipment, -- mesma tabela do perfil: compras são persistidas pelo DataService
        CreatedAt = os.time(),
    }

    EquipmentService.Sync(player, profile.Equipment)
    WorkshopSkin.Update(player, profile.TotalEarned or 0)
    updatePriceBoard(player)
    return true, "Oficina registrada."
end

function WorkshopService.GetSnapshot(player: Player)
    local profile = DataService.Get(player)
    local workshop = getWorkshop(player)
    local jobs = {}

    if workshop then
        for _, job in pairs(Jobs) do
            if job.OwnerUserId == player.UserId and os.time() >= (job.ArrivesAt or 0) then -- cliente ainda na rua: ordem fechada
                local entry: any = {
                    Id = job.Id,
                    VehicleName = job.VehicleName,
                    VehicleModel = VehicleService.GetModelName(job.VehicleName),
                    CustomerName = job.CustomerName,
                    WaitSeconds = os.time() - job.CreatedAt, -- tempo desde a chegada (a paciência acaba em PatienceSeconds)
                    PatienceSeconds = Config.CustomerPatienceSeconds,
                    Complaint = job.Complaint,
                    Status = job.Status,
                    Diagnosed = job.Diagnosed,
                    CollaboratorUserId = job.CollaboratorUserId,
                    ServiceName = job.Diagnosed and Catalog.Services[job.ServiceId].DisplayName or nil,
                }
                -- Requisitos e pagamento só são revelados após o diagnóstico (o defeito real fica no servidor).
                if job.Diagnosed then
                    local defect = Catalog.Defects[job.DefectId]
                    local service = Catalog.Services[job.ServiceId]
                    entry.Requirement = {
                        Specialization = defect.Specialization,
                        Level = defect.RequiredLevel,
                        EquipmentId = defect.RequiredEquipment,
                        Reward = job.Price or service.Reward,
                        XP = service.XP,
                        Parts = defect.Parts or {},
                    }
                end
                table.insert(jobs, entry)
            end
        end
    end

    -- Ordens de outras oficinas em que este jogador colabora.
    local collabJobs = {}
    for _, job in pairs(Jobs) do
        if job.CollaboratorUserId == player.UserId and job.Status == "InProgress" then
            local owner = Players:GetPlayerByUserId(job.OwnerUserId)
            table.insert(collabJobs, {
                Id = job.Id,
                VehicleName = job.VehicleName,
                OwnerName = owner and owner.DisplayName or "?",
                SplitPercent = job.CollaborationSplitPercent or 25,
                Diagnosed = job.Diagnosed,
            })
        end
    end

    local skillLevels = {}
    for _, specialization in ipairs(Catalog.Specializations) do
        skillLevels[specialization] = DataService.GetSkillLevel(player, specialization)
    end

    -- Ranking das oficinas online (reputação, total ganho, nome).
    local ranking: { any } = {}
    for userId, shop in pairs(Workshops) do
        local owner = Players:GetPlayerByUserId(userId)
        local p = owner and DataService.Get(owner)
        if p then
            table.insert(ranking, {
                Name = shop.Name,
                Reputation = p.Reputation,
                TotalEarned = p.TotalEarned or 0,
                Price = p.PriceMultiplier or 1,
                Level = Catalog.BusinessLevel(p.TotalEarned or 0),
                Rating = CustomerRules.AverageRating(p.RatingSum or 0, p.RatingCount or 0),
                RatingCount = p.RatingCount or 0,
                IsMe = userId == player.UserId,
            })
        end
    end

    return {
        Ranking = CustomerRules.Rank(ranking),
        Profile = profile,
        HasWorkshop = workshop ~= nil,
        WorkshopName = workshop and workshop.Name or nil,
        Jobs = jobs,
        CollabJobs = collabJobs,
        SkillLevels = skillLevels,
    }
end

function WorkshopService.GenerateCustomer(player: Player)
    local workshop = getWorkshop(player)
    if not workshop then return false, "Registre uma oficina primeiro." end
    if getOpenJobCount(player.UserId) >= Config.MaxOpenJobsPerWorkshop then
        return false, "Sua oficina já atingiu o limite de ordens abertas."
    end
    -- Sem isso o botão permitiria farmar dinheiro sem limite; clientes também chegam sozinhos (Start).
    local now = os.clock()
    local wait = (workshop.LastManualCustomerAt or -math.huge) + Config.ManualCustomerCooldownSeconds - now
    if wait > 0 then
        return false, string.format("Aguarde %d s para chamar outro cliente.", math.ceil(wait))
    end
    -- Panfletos custam moedas: o botão deixa de ser dinheiro grátis e vira investimento em publicidade.
    local profile = DataService.Get(player)
    if not profile or profile.Coins < Config.AdvertisingCost then
        return false, string.format("Panfletos custam %d moedas.", Config.AdvertisingCost)
    end
    workshop.LastManualCustomerAt = now
    DataService.AddCoins(player, -Config.AdvertisingCost, "Publicidade: panfletos")
    local job = createJob(player.UserId)
    return true, "Panfletos distribuídos! Um cliente está chegando com " .. job.VehicleName .. "."
end

-- Texto do quadro de preços na fachada (SurfaceGui "PriceText" criado por tools/WorkshopBuilding).
function updatePriceBoard(player: Player)
    local plot = PlotService.GetPlot(player)
    local profile = DataService.Get(player)
    local label = plot and plot:FindFirstChild("PriceText", true)
    if label and label:IsA("TextLabel") and profile then
        label.Text = string.format("%s\nPREÇO %d%%", string.upper(player.DisplayName), math.floor((profile.PriceMultiplier or 1) * 100 + 0.5))
    end
end

-- Preço da oficina (0.7x a 1.5x da tabela). Vale para clientes que chegarem DEPOIS: ordens abertas mantêm o preço combinado.
function WorkshopService.SetPrice(player: Player, multiplier: number)
    if not getWorkshop(player) then
        return false, "Registre sua oficina primeiro."
    end
    local applied = DataService.SetPriceMultiplier(player, multiplier)
    if not applied then
        return false, "Seus dados ainda estão carregando."
    end
    updatePriceBoard(player)
    return true, string.format("Preço da oficina: %d%% da tabela.", math.floor(applied * 100 + 0.5))
end

-- Recusar uma ordem disponível (sem custo) ou abandonar uma em andamento (-1 de reputação).
-- Sem isso, uma ordem impossível (falta de nível/equipamento) prenderia a vaga para sempre.
function WorkshopService.DeclineJob(player: Player, jobId: string)
    local job = Jobs[jobId]
    if not job or job.OwnerUserId ~= player.UserId then
        return false, "Ordem não encontrada."
    end
    if job.Status == "Available" then
        if os.time() < (job.ArrivesAt or 0) then
            return false, "O cliente ainda está chegando."
        end
        Jobs[jobId] = nil
        CustomerArrivalService.Depart(jobId)
        return true, "Cliente dispensado."
    end
    if job.Status ~= "InProgress" then
        return false, "Esta ordem não pode ser abandonada."
    end
    if job.CollaboratorUserId then
        return false, "Há um colaborador nesta ordem; aguarde ele concluir ou sair."
    end
    VehicleService.Despawn(job.Id)
    Jobs[jobId] = nil
    DataService.AddReputation(player, -1)
    return true, "Ordem abandonada. -1 de reputação."
end

function WorkshopService.AcceptJob(player: Player, jobId: string)
    local job = Jobs[jobId]
    if not job or job.OwnerUserId ~= player.UserId then
        return false, "Ordem não encontrada."
    end
    if job.Status ~= "Available" or os.time() < (job.ArrivesAt or 0) then
        return false, "Esta ordem não está disponível."
    end
    local placed, placeMessage = VehicleService.Spawn(player, job)
    if not placed then
        return false, placeMessage
    end
    CustomerArrivalService.Claim(jobId)
    job.Status = "InProgress"
    job.AcceptedAt = os.time()
    job.AssignedWorkerUserId = player.UserId
    return true, "Ordem aceita. " .. placeMessage
end

-- Diagnóstico por escolha: sem escolha abre a tela com 3 candidatos; com escolha, o servidor valida. Palpite errado bloqueia a
-- opção e reduz a qualidade do reparo; acertar revela o defeito (e só então o serviço pode começar).
function WorkshopService.DiagnoseJob(player: Player, jobId: string, choice: any?)
    local job = Jobs[jobId]
    if not job or job.OwnerUserId ~= player.UserId then
        return false, "Ordem não encontrada."
    end
    if job.Status ~= "InProgress" or job.AssignedWorkerUserId ~= player.UserId then
        return false, "Você não está responsável por esta ordem."
    end
    if not VehicleService.IsNear(player, job.Id, Config.InteractDistance) then
        return false, "Aproxime-se do veículo para diagnosticar."
    end
    if job.Diagnosed then
        return true, Catalog.Defects[job.DefectId].DisplayName
    end

    if not job.DiagnoseOptions then
        job.DiagnoseOptions = DiagnosisRules.BuildOptions(Catalog.Defects, job.DefectId, job.ComplaintDefectId, math.random)
        job.DiagnoseWrong = {}
        job.DiagnoseAttempts = 0
    end
    local function sendOptions()
        if eventSender then
            local options = {}
            for _, id in ipairs(job.DiagnoseOptions) do
                table.insert(options, { Id = id, Name = Catalog.Defects[id].DisplayName, Wrong = job.DiagnoseWrong[id] == true })
            end
            eventSender(player, "DiagnoseStart", {
                JobId = job.Id, Vehicle = job.VehicleName, Customer = job.CustomerName, Complaint = job.Complaint,
                Options = options, Attempts = job.DiagnoseAttempts,
            })
        end
    end

    if choice == nil then
        sendOptions()
        return true, ""
    end
    local verdict = DiagnosisRules.Judge(job.DiagnoseOptions, job.DiagnoseWrong, job.DefectId, choice)
    if verdict == "invalid" then
        return false, "Opção de diagnóstico inválida."
    end
    job.DiagnoseAttempts += 1
    if verdict == "wrong" then
        job.DiagnoseWrong[choice] = true
        sendOptions()
        return false, "Não era isso: " .. Catalog.Defects[choice].DisplayName .. ". Cada palpite errado reduz a qualidade do reparo."
    end

    job.Diagnosed = true
    VehicleService.SetStage(job.Id, "Repair")
    VehicleService.Flash(job.Id, Color3.fromRGB(80, 150, 255))
    if eventSender then
        eventSender(player, "DiagnoseDone", { JobId = job.Id, Attempts = job.DiagnoseAttempts })
    end
    local defect = Catalog.Defects[job.DefectId]
    return true, "Diagnóstico correto: " .. defect.DisplayName .. ". Serviço: " .. Catalog.Services[job.ServiceId].DisplayName .. "."
end

-- Confere TUDO que o reparo exige (responsável, diagnóstico, distância, equipamento, nível, peças) SEM consumir nada.
-- Retorna (ok, mensagem, job, defect, service).
local function checkRepairable(player: Player, jobId: string): (boolean, string, any, any, any)
    local job = Jobs[jobId]
    if not job or job.OwnerUserId ~= player.UserId then
        return false, "Ordem não encontrada.", nil, nil, nil
    end
    if job.Status ~= "InProgress" or job.AssignedWorkerUserId ~= player.UserId then
        return false, "Você não está responsável por esta ordem.", nil, nil, nil
    end
    if not job.Diagnosed then
        return false, "Faça o diagnóstico antes do reparo.", nil, nil, nil
    end
    if not VehicleService.IsNear(player, job.Id, Config.InteractDistance) then
        return false, "Aproxime-se do veículo para reparar.", nil, nil, nil
    end
    local workshop = getWorkshop(player)
    local defect = Catalog.Defects[job.DefectId]
    local service = Catalog.Services[job.ServiceId]
    if not workshop or not ownsEquipment(workshop, defect.RequiredEquipment) then
        return false, "Sua oficina não possui o equipamento necessário: " .. defect.RequiredEquipment, nil, nil, nil
    end
    local level = DataService.GetSkillLevel(player, defect.Specialization)
    if level < defect.RequiredLevel then
        return false, "Nível insuficiente em " .. defect.Specialization .. ". Requer nível " .. tostring(defect.RequiredLevel) .. ".", nil, nil, nil
    end
    local missing = missingPartsMessage(player, defect.Parts)
    if missing then
        return false, missing, nil, nil, nil
    end
    return true, "", job, defect, service
end

-- Inicia o minijogo: o servidor sorteia o plano e guarda o instante de início. Nada é cobrado até o envio final.
-- `assist` (Reduzir movimento) deixa a barra mais lenta e a zona maior.
function WorkshopService.SetRepairAssist(player: Player, value: boolean)
    RepairAssist[player.UserId] = value == true
    return true, ""
end

function WorkshopService.StartRepair(player: Player, jobId: string, assist: boolean?)
    local ok, message, job, defect = checkRepairable(player, jobId)
    if not ok then
        return false, message
    end
    local margin = math.max(0, DataService.GetSkillLevel(player, defect.Specialization) - defect.RequiredLevel)
    local plan = RepairRules.BuildPlan(math.random(1, 2147483646), defect.RequiredLevel, margin, assist == true or RepairAssist[player.UserId] == true, Catalog.EquipmentEfficiency[defect.RequiredEquipment])
    Repairs[player.UserId] = { JobId = job.Id, Plan = plan, StartedAt = os.clock() }
    if eventSender then
        eventSender(player, "RepairStart", {
            JobId = job.Id,
            Vehicle = job.VehicleName,
            Service = Catalog.Services[job.ServiceId].DisplayName,
            Plan = plan,
        })
    end
    return true, ""
end

function WorkshopService.CancelRepair(player: Player)
    Repairs[player.UserId] = nil
    return true, ""
end

-- Finaliza o minijogo: valida a sessão e os toques, recalcula a qualidade no servidor (6 fatores) e só então cobra peças e paga.
function WorkshopService.FinishRepair(player: Player, jobId: string, presses: any)
    local session = Repairs[player.UserId]
    if not session or session.JobId ~= jobId then
        return false, "Nenhum reparo em andamento."
    end
    Repairs[player.UserId] = nil -- sessão de uso único: reenviar não paga duas vezes
    local elapsed = os.clock() - session.StartedAt
    if elapsed > RepairRules.MaxSessionSeconds then
        return false, "O reparo demorou demais e foi cancelado."
    end
    local ok, message, job, defect, service = checkRepairable(player, jobId)
    if not ok then
        return false, message
    end
    local mods: RepairRules.Mods = {
        Margin = math.max(0, DataService.GetSkillLevel(player, defect.Specialization) - defect.RequiredLevel),
        EquipmentEfficiency = Catalog.EquipmentEfficiency[defect.RequiredEquipment] or 0,
        PartReliability = Catalog.AveragePartReliability(defect.Parts),
        DiagnosisAttempts = job.DiagnoseAttempts or 1,
    }
    local result = RepairRules.Evaluate(session.Plan, presses, elapsed, mods)
    if not result.Valid then
        return false, "Reparo inválido (" .. tostring(result.Reason) .. ")."
    end
    if not DataService.TakeParts(player, defect.Parts) then
        return false, "Faltam peças."
    end

    job.Status = "Completed"
    VehicleService.Flash(job.Id, Color3.fromRGB(90, 220, 130))
    VehicleService.Despawn(job.Id)
    local basePrice = job.Price or service.Reward
    local price = math.floor(basePrice * RepairRules.PayMultiplier(result.Quality) + 0.5)
    local tip = RepairRules.Tip(basePrice, result.Quality)
    local xp = RepairRules.XPBonus(service.XP, result.Quality)
    DataService.AddCoins(player, price + tip, "Serviço: " .. service.DisplayName .. (tip > 0 and " (+gorjeta)" or ""))
    DataService.AddSkillXP(player, defect.Specialization, xp)
    DataService.AddReputation(player, service.Reputation)
    local stars = rateService(player, job, service, defect, player, false, result.Quality)
    local bonus = DataService.CompleteOnboarding(player, Config.OnboardingBonus)
    WorkshopService.UpdateSkin(player)
    if eventSender then
        eventSender(player, "RepairDone", {
            Bonus = bonus,
            Quality = result.Quality, Perfect = result.Perfect, Good = result.Good, Miss = result.Miss,
            Corrected = result.Corrected, Uncorrected = result.Uncorrected, Breakdown = result.Breakdown,
            Tip = tip, Price = price, XP = xp, Stars = stars,
        })
    end
    return true, "Serviço concluído. +" .. tostring(price + tip) .. " moedas (qualidade " .. tostring(result.Quality) .. "%), +" .. tostring(xp)
        .. " XP. Avaliação: " .. CustomerRules.StarsText(stars) .. " (" .. tostring(stars) .. ")"
        .. (bonus > 0 and (" Bônus do primeiro serviço: +" .. tostring(bonus) .. ".") or "")
end

-- Atualiza a fachada conforme o total ganho; avisa o jogador quando a oficina evolui de tipo.
function WorkshopService.UpdateSkin(player: Player)
    local profile = DataService.Get(player)
    if not profile or not Workshops[player.UserId] then
        return
    end
    local changed, name = WorkshopSkin.Update(player, profile.TotalEarned or 0)
    if changed and eventSender then
        eventSender(player, "Notice", { Message = "Sua oficina evoluiu: agora é " .. name .. "!", Success = true })
    end
end

function WorkshopService.SkipOnboarding(player: Player)
    DataService.CompleteOnboarding(player, 0)
    return true, ""
end

function WorkshopService.BuyEquipment(player: Player, equipmentId: string)
    local workshop = getWorkshop(player)
    local equipment = Catalog.Equipment[equipmentId]
    if not workshop or not equipment then return false, "Oficina ou equipamento inválido." end
    if ownsEquipment(workshop, equipmentId) then return false, "Você já possui este equipamento." end

    local profile = DataService.Get(player)
    if not profile or profile.Coins < equipment.Cost then
        return false, "Moedas insuficientes."
    end

    DataService.AddCoins(player, -equipment.Cost, "Compra: " .. equipment.DisplayName)
    DataService.GrantEquipment(player, equipmentId)
    EquipmentService.Add(player, equipmentId)
    return true, equipment.DisplayName .. " comprado."
end

-- Loja de peças: compra em quantidade (1..MaxPartPurchase); o saldo e o estoque são decididos aqui.
function WorkshopService.BuyPart(player: Player, partId: string, quantity: number)
    local part = Catalog.Parts[partId]
    if not part then
        return false, "Peça inválida."
    end
    if quantity ~= quantity or quantity < 1 or quantity > Catalog.MaxPartPurchase or math.floor(quantity) ~= quantity then
        return false, "Quantidade inválida."
    end
    local profile = DataService.Get(player)
    if not profile or not getWorkshop(player) then
        return false, "Registre sua oficina primeiro."
    end
    local cost = part.Cost * quantity
    if profile.Coins < cost then
        return false, "Moedas insuficientes."
    end
    DataService.AddCoins(player, -cost, string.format("Peças: %dx %s", quantity, part.DisplayName))
    DataService.AddParts(player, partId, quantity)
    return true, string.format("%dx %s comprado(s).", quantity, part.DisplayName)
end

-- Carrinho da Loja de Peças: compra TODOS os itens ou nenhum. O servidor recalcula preços e valida saldo, limites e
-- posse; o cliente só envia { Kind = "Part" | "Equipment", Id, Quantity }.
local MAX_CART_LINES = 20
function WorkshopService.Checkout(player: Player, items: any)
    if type(items) ~= "table" or #items == 0 or #items > MAX_CART_LINES then
        return false, "Carrinho inválido."
    end
    local profile = DataService.Get(player)
    local workshop = getWorkshop(player)
    if not profile or not workshop then
        return false, "Registre sua oficina primeiro."
    end
    local total = 0
    local partQuantities: { [string]: number } = {}
    local equipmentIds: { [string]: boolean } = {}
    for _, line in ipairs(items) do
        if type(line) ~= "table" or type(line.Id) ~= "string" or type(line.Quantity) ~= "number" then
            return false, "Carrinho inválido."
        end
        local quantity = line.Quantity
        if quantity ~= quantity or quantity < 1 or math.floor(quantity) ~= quantity then
            return false, "Quantidade inválida."
        end
        if line.Kind == "Part" then
            local part = Catalog.Parts[line.Id]
            if not part then
                return false, "Peça inválida."
            end
            partQuantities[line.Id] = (partQuantities[line.Id] or 0) + quantity
            if partQuantities[line.Id] > Catalog.MaxPartPurchase then
                return false, "Quantidade acima do limite por compra."
            end
            total += part.Cost * quantity
        elseif line.Kind == "Equipment" then
            local equipment = Catalog.Equipment[line.Id]
            if not equipment or quantity ~= 1 or equipmentIds[line.Id] or ownsEquipment(workshop, line.Id) then
                return false, "Equipamento inválido ou já instalado."
            end
            equipmentIds[line.Id] = true
            total += equipment.Cost
        else
            return false, "Item inválido."
        end
    end
    if profile.Coins < total then
        return false, "Moedas insuficientes."
    end
    -- tudo validado: aplica sem yield entre a checagem e a gravação
    DataService.AddCoins(player, -total, "Loja de peças")
    for partId, quantity in pairs(partQuantities) do
        DataService.AddParts(player, partId, quantity)
    end
    for equipmentId in pairs(equipmentIds) do
        DataService.GrantEquipment(player, equipmentId)
        EquipmentService.Add(player, equipmentId)
    end
    return true, string.format("Compra concluída: %d moedas.", total)
end

function WorkshopService.InviteWorker(owner: Player, workerUserId: number, jobId: string, splitPercent: number)
    local job = Jobs[jobId]
    if not job or job.OwnerUserId ~= owner.UserId or job.Status ~= "InProgress" then
        return false, "Ordem inválida para contratação."
    end
    if job.CollaboratorUserId then
        return false, "Esta ordem já tem um colaborador."
    end
    if not isFinite(workerUserId) or not isFinite(splitPercent) then return false, "Convite inválido." end
    if workerUserId == owner.UserId then return false, "Você não pode convidar a si mesmo." end
    if not job.Diagnosed then return false, "Faça o diagnóstico antes de chamar um colaborador." end
    for _, other in pairs(Invites) do
        if other.JobId == jobId and other.Status == "Pending" and os.time() <= other.ExpiresAt then
            return false, "Já existe um convite pendente para esta ordem."
        end
    end

    local worker = Players:GetPlayerByUserId(workerUserId)
    if not worker then return false, "O profissional não está online." end

    splitPercent = math.clamp(math.floor(splitPercent), 1, Config.MaxServiceSplitPercent)
    nextInviteId += 1
    local inviteId = newId("invite", nextInviteId)
    Invites[inviteId] = {
        Id = inviteId,
        OwnerUserId = owner.UserId,
        WorkerUserId = workerUserId,
        JobId = jobId,
        SplitPercent = splitPercent,
        ExpiresAt = os.time() + Config.InviteTimeoutSeconds,
        Status = "Pending",
    }

    return true, "Convite criado: " .. inviteId
end

function WorkshopService.RespondInvite(worker: Player, inviteId: string, accepted: boolean)
    local invite = Invites[inviteId]
    if not invite or invite.WorkerUserId ~= worker.UserId or invite.Status ~= "Pending" then
        return false, "Convite inválido."
    end
    if os.time() > invite.ExpiresAt then
        invite.Status = "Expired"
        return false, "Convite expirado."
    end
    if not accepted then
        invite.Status = "Declined"
        return true, "Convite recusado."
    end

    local job = Jobs[invite.JobId]
    if not job or job.Status ~= "InProgress" then
        invite.Status = "Expired"
        return false, "A ordem não está mais disponível."
    end
    if job.CollaboratorUserId then
        -- Outro profissional aceitou primeiro: não sobrescreve (o primeiro seria prejudicado).
        invite.Status = "Expired"
        return false, "A ordem já tem um colaborador."
    end

    invite.Status = "Accepted"
    job.AssignedWorkerUserId = worker.UserId
    job.CollaboratorUserId = worker.UserId
    job.CollaborationSplitPercent = invite.SplitPercent
    job.CollabAt = os.time()
    return true, "Convite aceito. Você agora participa da ordem."
end

function WorkshopService.CompleteCollaborativeJob(worker: Player, jobId: string)
    local job = Jobs[jobId]
    if not job or job.Status ~= "InProgress" or job.AssignedWorkerUserId ~= worker.UserId
        or job.CollaboratorUserId ~= worker.UserId or worker.UserId == job.OwnerUserId then
        return false, "Você não está responsável por esta ordem."
    end
    if not job.Diagnosed then return false, "O diagnóstico ainda não foi feito." end
    if not VehicleService.IsNear(worker, job.Id, Config.InteractDistance) then
        return false, "Aproxime-se do veículo para reparar."
    end

    local defect = Catalog.Defects[job.DefectId]
    local service = Catalog.Services[job.ServiceId]
    local owner = Players:GetPlayerByUserId(job.OwnerUserId)
    if not owner then return false, "O proprietário saiu do servidor; a ordem foi cancelada." end

    local ownerWorkshop = getWorkshop(owner)
    if not ownerWorkshop or not ownsEquipment(ownerWorkshop, defect.RequiredEquipment) then
        return false, "A oficina não possui o equipamento necessário."
    end

    local level = DataService.GetSkillLevel(worker, defect.Specialization)
    if level < defect.RequiredLevel then
        return false, "Seu nível de habilidade é insuficiente."
    end

    local workerPercent = job.CollaborationSplitPercent or 25
    local price = job.Price or service.Reward
    local workerPay = math.floor(price * workerPercent / 100)
    local ownerPay = price - workerPay

    -- As peças saem do estoque do dono da oficina (o colaborador trabalha com o material dela).
    local missing = missingPartsMessage(owner, defect.Parts)
    if missing or not DataService.TakeParts(owner, defect.Parts) then
        return false, missing or "Faltam peças na oficina."
    end

    job.Status = "Completed"
    VehicleService.Flash(job.Id, Color3.fromRGB(90, 220, 130))
    VehicleService.Despawn(job.Id)
    DataService.AddCoins(worker, workerPay, "Trabalho em oficina alheia: " .. service.DisplayName)
    DataService.AddSkillXP(worker, defect.Specialization, service.XP)
    DataService.AddCoins(owner, ownerPay, "Serviço (parte do dono): " .. service.DisplayName)
    DataService.AddReputation(owner, service.Reputation)
    local stars = rateService(owner, job, service, defect, worker, false)

    return true, "Serviço concluído. Sua parte: " .. tostring(workerPay) .. " moedas e XP. Avaliação do cliente: "
        .. CustomerRules.StarsText(stars) .. " (" .. tostring(stars) .. ")"
end

function WorkshopService.HireNpc(player: Player, jobId: string)
    local job = Jobs[jobId]
    if not job or job.OwnerUserId ~= player.UserId or job.Status ~= "InProgress" then
        return false, "Ordem inválida."
    end
    if not job.Diagnosed then return false, "Faça o diagnóstico primeiro." end

    local defect = Catalog.Defects[job.DefectId]
    local service = Catalog.Services[job.ServiceId]
    local workshop = getWorkshop(player)
    if not workshop or not ownsEquipment(workshop, defect.RequiredEquipment) then
        return false, "Equipamento necessário não instalado."
    end

    local price = job.Price or service.Reward
    local npcCost = math.floor(price * 0.55)
    local profile = DataService.Get(player)
    if not profile or profile.Coins < npcCost then
        return false, "Moedas insuficientes para contratar o mecânico NPC."
    end

    local missing = missingPartsMessage(player, defect.Parts)
    if missing or not DataService.TakeParts(player, defect.Parts) then
        return false, missing or "Faltam peças."
    end
    DataService.AddCoins(player, price - npcCost, "Serviço por mecânico NPC: " .. service.DisplayName)
    DataService.AddReputation(player, service.Reputation)
    local stars = rateService(player, job, service, defect, nil, true)
    job.Status = "Completed"
    VehicleService.Despawn(job.Id)
    return true, "Mecânico NPC concluiu o serviço. Custo: " .. tostring(npcCost) .. " moedas. Você não recebeu XP. Avaliação: "
        .. CustomerRules.StarsText(stars) .. " (" .. tostring(stars) .. ")"
end

-- Interação física com o veículo (ProximityPrompt). O servidor decide o que o jogador pode fazer.
function WorkshopService.Interact(player: Player, jobId: string, kind: string): (boolean, string)
    local job = Jobs[jobId]
    if not job or job.Status ~= "InProgress" then
        return false, "Ordem não está em andamento."
    end
    if kind == "Diagnose" then
        return WorkshopService.DiagnoseJob(player, jobId)
    elseif kind == "Repair" then
        if job.CollaboratorUserId == player.UserId then
            return WorkshopService.CompleteCollaborativeJob(player, jobId)
        elseif job.OwnerUserId == player.UserId then
            return WorkshopService.StartRepair(player, jobId, false)
        end
    end
    return false, "Você não participa desta ordem."
end

-- Dono saiu: devolve ordens em andamento para "Available" e remove os veículos físicos do lote.
function WorkshopService.PlayerLeft(userId: number)
    Repairs[userId] = nil -- sessão de minijogo abandonada
    CustomerArrivalService.Clear(userId) -- clientes que ainda esperavam na rua somem junto
    RepairAssist[userId] = nil
    for jobId, job in pairs(Jobs) do
        if job.OwnerUserId == userId and job.Status ~= "InProgress" then
            Jobs[jobId] = nil -- cliente que esperava vai embora com o dono; não fica ordem fantasma para a reentrada
        elseif job.OwnerUserId == userId and job.Status == "InProgress" then
            job.Status = "Available"
            job.AssignedWorkerUserId = nil
            job.CollaboratorUserId = nil
        elseif job.CollaboratorUserId == userId and job.Status == "InProgress" then
            -- O colaborador pode sair a qualquer momento: a ordem volta ao dono, sem prendê-lo ao trabalho.
            job.CollaboratorUserId = nil
            job.CollaborationSplitPercent = nil
            job.AssignedWorkerUserId = job.OwnerUserId
        end
    end
    for inviteId, invite in pairs(Invites) do
        if invite.WorkerUserId == userId or invite.OwnerUserId == userId then
            Invites[inviteId] = nil
        end
    end
    VehicleService.DespawnOwner(userId)
    -- A oficina referencia tabelas do perfil carregado; ao sair, descarta para não usar dados velhos na reentrada.
    Workshops[userId] = nil
end

-- Mercado: chegam clientes e cada um ESCOLHE a oficina (preço, reputação, especialização, distância, fila).
-- Retorna quantos clientes viraram ordens e quantos foram embora (nenhuma oficina serviu ou desistiram).
function WorkshopService.DispatchCustomers(arrivals: number?, rand: (() -> number)?): (number, number)
    rand = rand or math.random
    local entries = {}
    for userId, workshop in pairs(Workshops) do
        local owner = Players:GetPlayerByUserId(userId)
        local profile = owner and DataService.Get(owner)
        if owner and profile then
            local plot = PlotService.GetPlot(owner)
            local entry = plot and plot:FindFirstChild("Entry")
            local levels = {}
            for _, specialization in ipairs(Catalog.Specializations) do
                levels[specialization] = DataService.GetSkillLevel(owner, specialization)
            end
            table.insert(entries, {
                Owner = owner,
                Profile = profile,
                Levels = levels,
                Distance = entry and entry:IsA("BasePart") and (entry.Position - Config.CustomerArrivalPoint).Magnitude or 300,
            })
            local _ = workshop
        end
    end
    if #entries == 0 then
        return 0, 0
    end

    local count = arrivals or math.max(1, math.ceil(#entries * Config.CustomersPerWorkshopPerTick))
    local created, lost = 0, 0
    for _ = 1, count do
        -- Cada cliente precisa de uma área; os candidatos são julgados por ela.
        local specialization = Catalog.Specializations[math.floor(rand() * #Catalog.Specializations) + 1]
        local candidates = {}
        for i, e in ipairs(entries) do
            candidates[i] = {
                Price = e.Profile.PriceMultiplier or 1,
                Reputation = e.Profile.Reputation,
                SpecLevel = e.Levels[specialization] or 1,
                ServiceableCount = JobRules.ServiceableCountIn(specialization, e.Levels, e.Profile.Equipment),
                Rating = CustomerRules.AverageRating(e.Profile.RatingSum or 0, e.Profile.RatingCount or 0),
                OpenJobs = getOpenJobCount(e.Owner.UserId),
                Capacity = Config.MaxOpenJobsPerWorkshop,
                Distance = e.Distance,
            }
        end
        local choice = CustomerRules.Choose(candidates, rand)
        if choice then
            createJob(entries[choice].Owner.UserId, specialization)
            created += 1
        else
            lost += 1
        end
    end
    return created, lost
end

-- Somente QA no Studio (Main expõe via ServerStorage.QA): envelhece as ordens abertas do jogador para testar a expiração.
function WorkshopService._ageJobsForTesting(userId: number, seconds: number): number
    local n = 0
    for _, job in pairs(Jobs) do
        if job.OwnerUserId == userId then
            job.CreatedAt -= seconds
            if job.AcceptedAt then job.AcceptedAt -= seconds end
            n += 1
        end
    end
    return n
end

function WorkshopService.Start()
    task.spawn(function()
        while true do
            task.wait(Config.JobRefreshSeconds)
            for userId in pairs(Workshops) do
                local ownerNow = Players:GetPlayerByUserId(userId)
                if ownerNow then
                    WorkshopService.UpdateSkin(ownerNow) -- ganhos de colaboração e mecânico NPC também contam
                end
            end
            for userId, session in pairs(Repairs) do
                if os.clock() - session.StartedAt > RepairRules.MaxSessionSeconds + 5 then
                    Repairs[userId] = nil -- sessão esquecida não prende a ordem
                end
            end
            for jobId, job in pairs(Jobs) do
                -- Cliente que não foi atendido vai embora; ordens concluídas antigas saem da memória.
                local age = os.time() - job.CreatedAt
                local owner = Players:GetPlayerByUserId(job.OwnerUserId)
                if job.Status == "Available" and age > Config.CustomerPatienceSeconds then
                    Jobs[jobId] = nil
                    CustomerArrivalService.Depart(jobId)
                    if owner and eventSender then
                        eventSender(owner, "Notice", { Message = tostring(job.CustomerName) .. " cansou de esperar e foi embora.", Success = false })
                    end
                elseif job.Status == "InProgress" and job.CollaboratorUserId and os.time() - (job.CollabAt or os.time()) > Config.CollabMaxSeconds then
                    -- colaborador que não conclui não prende a vaga: a ordem volta ao dono
                    job.CollaboratorUserId = nil
                    job.CollaborationSplitPercent = nil
                    job.CollabAt = nil
                    job.AssignedWorkerUserId = job.OwnerUserId
                    if owner and eventSender then
                        eventSender(owner, "Notice", { Message = "O colaborador demorou demais: a ordem voltou para você.", Success = false })
                    end
                elseif job.Status == "InProgress" and not job.CollaboratorUserId and os.time() - (job.AcceptedAt or job.CreatedAt) > Config.InProgressMaxSeconds
                    and not (Repairs[job.OwnerUserId] and Repairs[job.OwnerUserId].JobId == jobId) then
                    -- aceita e esquecida: o cliente leva o carro embora e a vaga é liberada (-1 de reputação, como abandonar)
                    VehicleService.Despawn(job.Id)
                    Jobs[jobId] = nil
                    if owner then
                        DataService.AddReputation(owner, -1)
                        if eventSender then
                            eventSender(owner, "Notice", { Message = tostring(job.CustomerName) .. " cansou de esperar o reparo e levou o carro. -1 de reputação.", Success = false })
                        end
                    end
                elseif job.Status == "Completed" and age > 600 then
                    Jobs[jobId] = nil
                end
            end
            for inviteId, invite in pairs(Invites) do
                -- Convites encerrados ou vencidos há mais de 2 minutos não precisam ficar na memória.
                if invite.Status ~= "Pending" or os.time() > invite.ExpiresAt + 120 then
                    Invites[inviteId] = nil
                end
            end
        end
    end)

    -- Chegada de clientes: cada cliente escolhe a oficina (ver DispatchCustomers).
    task.spawn(function()
        while true do
            task.wait(Config.CustomerArrivalSeconds)
            WorkshopService.DispatchCustomers()
        end
    end)
end

return WorkshopService
