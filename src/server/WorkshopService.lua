--!strict
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local JobRules = require(ReplicatedStorage.Shared.JobRules)
local CustomerRules = require(ReplicatedStorage.Shared.CustomerRules)
local RepairRules = require(ReplicatedStorage.Shared.RepairRules)
local RepairSessionRules = require(ReplicatedStorage.Shared.RepairSessionRules)
local CollaborationRules = require(ReplicatedStorage.Shared.CollaborationRules)
local JobExitRules = require(ReplicatedStorage.Shared.JobExitRules)
local RepairCommitGuard = require(ReplicatedStorage.Shared.RepairCommitGuard)
local RepairOperations = require(ReplicatedStorage.Shared.RepairOperations)
local RepairActionRules = require(ReplicatedStorage.Shared.RepairActionRules)
local RepairReceiptRules = require(ReplicatedStorage.Shared.RepairReceiptRules)
local SettlementDeliveryRules = require(ReplicatedStorage.Shared.SettlementDeliveryRules)
local RepairPrepRules = require(ReplicatedStorage.Shared.RepairPrepRules)
local DiagnosisRules = require(ReplicatedStorage.Shared.DiagnosisRules)
local DiagnosisEvidence = require(ReplicatedStorage.Shared.DiagnosisEvidence)
local WorkshopLevels = require(ReplicatedStorage.Shared.WorkshopLevels)
local EquipmentUpgradeRules = require(ReplicatedStorage.Shared.EquipmentUpgradeRules)
local StaffAssignmentRules = require(ReplicatedStorage.Shared.StaffAssignmentRules)
local LocationRules = require(ReplicatedStorage.Shared.LocationRules)
local V2ReceptionRules = require(ReplicatedStorage.Shared.V2ReceptionRules)
local V2ComponentRules = require(ReplicatedStorage.Shared.V2ComponentRules)
local V2ManagementSummaryRules = require(ReplicatedStorage.Shared.V2ManagementSummaryRules)

local WorkshopService = {}

local PlotService = require(script.Parent.PlotService)
local VehicleService = require(script.Parent.VehicleService)
local CustomerArrivalService = require(script.Parent.CustomerArrivalService)
local EquipmentService = require(script.Parent.EquipmentService)
local EquipmentUpgradePads = require(script.Parent.EquipmentUpgradePads)
local StationService = require(script.Parent.StationService)
local CustomerNpcService = require(script.Parent.CustomerNpcService)
local RivalService = require(script.Parent.RivalService)
local NpcKit = require(script.Parent.NpcKit)
local ProgressService = require(script.Parent.ProgressService)
local ContractService = require(script.Parent.ContractService)
local ContractRules = require(ReplicatedStorage.Shared.ContractRules)
local ProgressRules = require(ReplicatedStorage.Shared.ProgressRules)

-- Loja de Autopeças do bairro: comprar só estando nela (prédio Workspace.PublicAreas.LojaAutopecas).
local function nearShop(player: Player): boolean
    local areas = workspace:FindFirstChild("PublicAreas")
    local shop = areas and areas:FindFirstChild("LojaAutopecas")
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not shop or not shop:IsA("BasePart") then
        -- Em produção, a falta da loja nunca autoriza uma compra.
        return LocationRules.MissingBlockAllowed(RunService:IsStudio())
    end
    if not hrp or not hrp:IsA("BasePart") then
        return false -- sem personagem (morto/respawn) não compra
    end
    return LocationRules.IsNearBlock(shop.CFrame, shop.Size, hrp.Position, Config.ShopDistance)
end
local SHOP_FAR = "Vá até a Loja de Autopeças do bairro para comprar."

local DataService: any
local updatePriceBoard: (Player) -> () -- definido adiante; declarado aqui porque ClaimWorkshop o usa
local syncStaffRef: (Player) -> () -- definido adiante (funcionários)
local refreshPlotDisplays: () -> () -- definido adiante (placa 3D e TV)
local rankingEntriesRef: () -> { any } -- definido adiante (ranking com rivais)
local upgradeInfoRef: (Player, any) -> any -- definido adiante (Construtora)
local createJobRef: (number, string?) -> any -- definido adiante (createJob)
local Workshops: {[number]: any} = {}
local Jobs: {[string]: any} = {}
local Invites: {[string]: any} = {}
local nextJobId = 0
local nextInviteId = 0
local ratingNotifier: ((Player, any) -> ())? = nil -- definido por Main (envia o evento "Rated" ao cliente)
local eventSender: ((Player, string, any) -> ())? = nil -- definido por Main (RepairStart / RepairDone)
local Repairs: { [number]: { JobId: string, Plan: any, StartedAt: number, Progress: any?, Token: string?, LastActionAt: number? } } = {} -- sessões do minijogo, por jogador
-- Comprovantes são privados do executor: últimos oito por jogador durante 15 minutos.
-- Só guardamos um resultado DEPOIS de aplicar consumo, dinheiro, XP e avaliação.
local RepairReceipts: { [number]: { any } } = {}
local SettlingRepairs: { [number]: any } = {} -- barreira de confirmação e retentativas por executor
local NpcPendingSaves: { [string]: boolean } = {} -- conclusão NPC: regrava sem reaplicar crédito
-- Funcionários por dono: NPCs, ordens em que estão trabalhando e próximo pagamento de salário.
local Staff: { [number]: { Npcs: { Model }, Busy: { [string]: boolean }, NextPay: number } } = {}
-- Uma ordem reservada para NPC não pode simultaneamente ser abandonada,
-- terceirizada ou iniciada manualmente. Reserva é por JobId e proprietário.
local function employeeReserved(job: any): boolean
    if type(job) ~= "table" then return false end
    local entry = Staff[job.OwnerUserId]
    return entry ~= nil and StaffAssignmentRules.IsReserved(entry.Busy, job.Id)
end
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

-- Funil do guia do 1º atendimento (Creator Dashboard > Analytics > Funnels). Só conta quem ainda está no guia.
local AnalyticsService = game:GetService("AnalyticsService")
local FUNNEL_STEPS = {
    Claimed = { 1, "Oficina registrada" }, Accepted = { 2, "Aceitou o 1º cliente" },
    Diagnosed = { 3, "Diagnosticou" }, Repaired = { 4, "Concluiu o 1º reparo" },
    FirstUpgrade = { 5, "Primeira ampliacao" }, FirstEmployee = { 6, "Primeiro mecanico" },
}
local function funnel(player: Player, key: string)
    local profile = DataService and DataService.Get(player)
    local step = FUNNEL_STEPS[key]
    if not profile or not step or (profile.Onboarding and profile.Onboarding.Done and key ~= "Repaired"
        and key ~= "FirstUpgrade" and key ~= "FirstEmployee") then
        return
    end
    pcall(function()
        AnalyticsService:LogOnboardingFunnelStepEvent(player, step[1], step[2])
    end)
end

-- Combo do turno: reparos seguidos com qualidade >= 70% aumentam o pagamento (+10% por reparo, até +50%).
-- Zera quando um cliente vai embora sem atendimento ou um serviço é abandonado. Só na sessão (não é salvo).
local Combo: { [number]: number } = {}
local COMBO_MIN_QUALITY = 70
local function comboMultiplier(userId: number): number
    return 1 + 0.1 * math.min(Combo[userId] or 0, 5)
end
local function breakCombo(userId: number)
    Combo[userId] = 0
end

-- Nível do prédio (shared/WorkshopLevels) e contagem de equipamentos do jogador.
local function workshopLevel(player: Player): number
    local profile = DataService and DataService.Get(player)
    return profile and profile.WorkshopLevel or 0
end
local function equipmentCount(owned: { [string]: boolean }?): number
    local n = 0
    for _, has in pairs(owned or {}) do
        if has then
            n += 1
        end
    end
    return n
end
local function skillTotal(player: Player): number
    local total = 0
    for _, specialization in ipairs(Catalog.Specializations) do
        total += DataService.GetSkillLevel(player, specialization)
    end
    return total
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
        PatienceSeconds = Config.CustomerPatienceSeconds * (job.Regular and Config.RegularPatienceMultiplier or 1),
        LevelMargin = margin,
        ByNpc = byNpc,
        Quality = quality,
    }
    local stars = CustomerRules.RateService(context, math.random)
    ProgressService.AddLeague(owner, ProgressRules.LeaguePoints(stars, quality, job.Vip == true)) -- liga semanal
    if job.Fleet then
        ContractService.FleetDone(owner, job.Fleet)
    end
    if stars == 5 and profile and job.CustomerName and job.CustomerGender and not job.Fleet then
        local found = nil
        for _, r in ipairs(profile.Regulars) do
            if r.Name == job.CustomerName and r.Gender == job.CustomerGender then
                found = r
            end
        end
        if found then
            found.Visits += 1
            found.Vehicle = job.VehicleName
            if found.Visits == Config.RegularReferralVisit then
                profile.PendingVipReferral = true
                if eventSender then
                    eventSender(owner, "Notice", { Message = "♥ " .. found.Name .. " adorou o serviço e vai indicar um cliente VIP para você!", Success = true })
                end
            end
        elseif #profile.Regulars < Config.RegularsMax and Catalog.VehicleModels[job.VehicleName] then
            table.insert(profile.Regulars, { Name = job.CustomerName, Gender = job.CustomerGender, Vehicle = job.VehicleName, Visits = 1 })
            if eventSender then
                eventSender(owner, "Notice", { Message = "♥ " .. job.CustomerName .. " virou freguês da sua oficina! Ele(a) vai voltar e pagar mais.", Success = true })
            end
        end
        DataService.MarkDirty(owner)
    end
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

-- Efeito visual do defeito no carro (VehicleFx no cliente): Tires, Engine, Electrical, Suspension, Bodywork.
local function defectSymptom(defectId: string?): string
    local defect = defectId and Catalog.Defects[defectId]
    return defect and defect.Specialization or ""
end

ContractService.SetOfferBuilder(function(player: Player)
    local profile = DataService.Get(player)
    if not profile or not getWorkshop(player) then
        return nil
    end
    local specs = {}
    for _, specialization in ipairs(Catalog.Specializations) do
        if JobRules.ServiceableCountIn(specialization, { [specialization] = DataService.GetSkillLevel(player, specialization) }, profile.Equipment) > 0 then
            table.insert(specs, specialization)
        end
    end
    return ContractRules.Offer(profile.WorkshopLevel or 0, specs, math.random)
end)

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
    -- Novato (guia ativo, menos de 2 serviços): o 1º e o 2º cliente têm defeitos que o estoque inicial resolve
    -- (pneu furado / bateria fraca), sem reclamação enganosa e sem VIP. O desafio entra depois.
    local rookie = profile ~= nil and not (profile.Onboarding and profile.Onboarding.Done) and (profile.RatingCount or 0) < 2
    if rookie then
        defectId = math.random(1, 2) == 1 and "FlatTire" or "WeakBattery"
    end
    -- Contrato de frota ativo: parte das chegadas são carros da frota com defeito da área do contrato.
    local fleet: any = nil
    if not rookie and owner then
        local inFlight = 0
        local active = ContractService.Active(ownerUserId)
        for _, other in pairs(Jobs) do
            if active and other.OwnerUserId == ownerUserId and other.Status ~= "Completed" and other.Fleet == active.Token then
                inFlight += 1
            end
        end
        fleet = ContractService.WantsFleet(ownerUserId, inFlight, math.random())
        if fleet then
            defectId = JobRules.PickDefectId(skillLevels, equipment, math.random, fleet.Offer.Spec)
        end
    end
    local defect = Catalog.Defects[defectId]
    -- O preço é fixado quando o cliente chega: mudar a tabela depois não altera ordens já abertas.
    -- Cliente VIP (esportivo) paga o dobro da tabela.
    local vip = not rookie and not fleet and math.random() < Catalog.VipChance
    local referral = false
    if not rookie and not fleet and profile and profile.PendingVipReferral then
        vip, referral = true, true -- indicação de um freguês: VIP garantido
        profile.PendingVipReferral = false
    end
    local regular: any = nil
    if not rookie and not vip and not fleet and profile and #profile.Regulars > 0 and math.random() < Config.RegularChance then
        regular = profile.Regulars[math.random(1, #profile.Regulars)]
        for _, other in pairs(Jobs) do
            if other.OwnerUserId == ownerUserId and other.Status ~= "Completed" and other.CustomerName == regular.Name then
                regular = nil -- já está na oficina
                break
            end
        end
    end
    local multiplier = profile and profile.PriceMultiplier or 1
    local rush = ProgressService.IsRush() -- Hora do Rush: o cliente aceita pagar mais
    local price = math.max(1, math.floor(Catalog.Services[defect.ServiceId].Reward * multiplier * (vip and Catalog.VipPayMultiplier or 1)
        * (rush and Config.RushPayMultiplier or 1) * (regular and Config.RegularPayMultiplier or 1) + 0.5))
    local gender, customerName = Catalog.PickCustomer()
    if regular then
        gender, customerName = regular.Gender, regular.Name
    end
    local vehicles = vip and Catalog.VipVehicleNames or Catalog.VehicleNames

    -- Nem toda reclamação corresponde ao defeito real: em ~35% dos casos o cliente descreve o sintoma de outro
    -- problema (de outra especialização). O jogador precisa diagnosticar para saber o que realmente está errado.
    local complaint = defect.Complaint
    local complaintDefectId = defectId
    if not rookie and math.random() < 0.35 then
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
        VehicleName = regular and regular.Vehicle or vehicles[math.random(1, #vehicles)],
        CustomerName = customerName,
        CustomerGender = gender,
        Vip = vip,
        Regular = regular ~= nil,
        Referral = referral,
        Fleet = fleet and fleet.Token or nil, -- contrato de frota ao qual este carro pertence
        FleetName = fleet and fleet.Offer.Name or nil,
        Rush = rush,
        Complaint = complaint,
        ComplaintDefectId = complaintDefectId,
        DefectId = defectId,
        ServiceId = defect.ServiceId,
        Price = price,
        PriceMultiplier = multiplier,
        Status = "Available",
        Priority = 0,
        ScheduledUntil = 0,
        ScheduleUsed = false,
        DiscountPercent = 0,
        OriginalPrice = price,
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
                local text = current.Vip
                    and ((current.Referral and "★ Indicação de freguês! " or "★ Cliente VIP! ") .. tostring(current.CustomerName) .. " chegou com um " .. tostring(current.VehicleName) .. " e paga o DOBRO. Aceite na TV de ordens!")
                    or current.Fleet and ("📋 Carro da frota " .. tostring(current.FleetName) .. " chegou (" .. tostring(current.VehicleName) .. "). Aceite na TV de ordens!")
                    or current.Regular and ("♥ Seu freguês " .. tostring(current.CustomerName) .. " voltou com o " .. tostring(current.VehicleName) .. " (paga +25%). Aceite na TV de ordens.")
                    or (tostring(current.CustomerName) .. " chegou com " .. tostring(current.VehicleName) .. ". Aceite na TV de ordens.")
                eventSender(ownerNow, "Notice", { Message = text, Success = true })
            end
        end)
    end
    return job
end

createJobRef = createJob

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

    if plot then
        StationService.ApplyLevel(plot, profile.WorkshopLevel or 0, player.DisplayName)
    end
    EquipmentService.Sync(player, profile.Equipment)
    EquipmentUpgradePads.Sync(player, profile.Equipment, profile.EquipmentLevels)
    funnel(player, "Claimed")
    if not (profile.Onboarding and profile.Onboarding.Done) then
        -- novato: o 1º cliente chega logo (sem esperar a leva do bairro)
        task.delay(3, function()
            if Workshops[player.UserId] and getOpenJobCount(player.UserId) == 0 then
                createJobRef(player.UserId)
            end
        end)
    end
    task.defer(function()
        syncStaffRef(player)
        refreshPlotDisplays()
    end)
    updatePriceBoard(player)
    return true, "Oficina registrada."
end

function WorkshopService.GetSnapshot(player: Player)
    local profile = DataService.Get(player)
    local workshop = getWorkshop(player)
    local jobs = {}

    if workshop then
        for _, job in pairs(Jobs) do
            if job.OwnerUserId == player.UserId and os.time() >= (job.ArrivesAt or 0)
                and not CustomerArrivalService.IsArriving(job.Id) then -- cliente ainda na rua: ordem fechada
                local entry: any = {
                    Id = job.Id,
                    VehicleName = job.VehicleName,
                    VehicleModel = VehicleService.GetModelName(job.VehicleName),
                    CustomerName = job.CustomerName,
                    Vip = job.Vip == true,
                    Regular = job.Regular == true,
                    Fleet = job.FleetName,
                    WaitSeconds = math.max(0, os.time() - job.CreatedAt), -- tempo de espera nunca fica negativo (a paciência acaba em PatienceSeconds)
                    PatienceSeconds = Config.CustomerPatienceSeconds * (job.Regular and Config.RegularPatienceMultiplier or 1),
                    Complaint = job.Complaint,
                    Status = job.Status,
                    Priority = job.Priority or 0,
                    ScheduledUntil = job.ScheduledUntil or 0,
                    ScheduleUsed = job.ScheduleUsed == true,
                    DiscountPercent = job.DiscountPercent or 0,
                    Diagnosed = job.Diagnosed,
                    Repairing = employeeReserved(job)
                        or (Repairs[job.OwnerUserId] ~= nil and Repairs[job.OwnerUserId].JobId == job.Id)
                        or (job.CollaboratorUserId ~= nil and Repairs[job.CollaboratorUserId] ~= nil
                            and Repairs[job.CollaboratorUserId].JobId == job.Id),
                    CollaboratorUserId = job.CollaboratorUserId,
                    ServiceName = job.Diagnosed and Catalog.Services[job.ServiceId].DisplayName or nil,
                }
                -- Requisitos e pagamento só são revelados após o diagnóstico (o defeito real fica no servidor).
                if job.Diagnosed then
                    entry.PrepRequired = RepairPrepRules.Requires(job.DefectId)
                    entry.PrepComplete = RepairPrepRules.Ready(job.DefectId, job.PreparationStep)
                    local defect = Catalog.Defects[job.DefectId]
                    local service = Catalog.Services[job.ServiceId]
                    local states, pilotId = VehicleService.ComponentStates(job.Id)
                    if pilotId then
                        local ready, instruction = V2ComponentRules.ReadyToRepair(job.DefectId, pilotId, states)
                        entry.Mechanics = {
                            PilotId = pilotId,
                            Hood = states.Hood,
                            WheelFL = states.WheelFL,
                            WheelFR = states.WheelFR,
                            WheelRL = states.WheelRL,
                            WheelRR = states.WheelRR,
                            Ready = ready,
                            Next = ready and "" or instruction,
                        }
                    end
                    entry.Requirement = {
                        Specialization = defect.Specialization,
                        Level = defect.RequiredLevel,
                        EquipmentId = defect.RequiredEquipment,
                        Reward = job.Price or service.Reward,
                        XP = service.XP,
                        Parts = defect.Parts or {},
                    }
                end
                entry.Reception = V2ReceptionRules.BuildVisible(entry, profile)
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

    for _, entry in ipairs(RivalService.RankEntries()) do
        table.insert(ranking, entry)
    end
    -- O perfil vivo contém chaves de liquidação: nunca replicar o ledger bruto
    -- com tokens da sessão para a UI. Mostrar somente dados financeiros saneados.
    local profileView = profile and table.clone(profile) or nil
    if profileView then
        profileView.RepairLedger = nil
        profileView.PendingClaims = nil -- tokens e referências financeiras nunca chegam ao cliente
        profileView.PendingClaimAudits = nil -- C25: casos privados de auditoria não são replicados
        profileView.OwnerSettlementProofs = nil -- arquivo de provas não replicado
        profileView.WorkerSettlementProofs = nil -- quitações privadas C23: não expor tokens
        profileView.WorkerPaidTombstones = nil -- C24: identificadores financeiros privados
    end
    return {
        Ranking = CustomerRules.Rank(ranking),
        Profile = profileView,
        RecentSettlements = DataService.RecentRepairSettlements(player, 12),
        PendingClaimSummary = DataService.PendingClaimSummary(player),
        HasWorkshop = workshop ~= nil,
        Workshop = (workshop and profile) and upgradeInfoRef(player, profile) or nil,
        Progress = profile and ProgressService.Snapshot(player, profile) or nil,
        Contract = ContractService.Snapshot(player.UserId),
        WorkshopName = workshop and workshop.Name or nil,
        Jobs = jobs,
        CollabJobs = collabJobs,
        SkillLevels = skillLevels,
        Management = V2ManagementSummaryRules.Build({
            HasWorkshop = workshop ~= nil,
            Profile = profileView,
            Jobs = jobs,
            FreeBays = workshop and PlotService.GetPlot(player) and VehicleService.GetFreeBayCount(PlotService.GetPlot(player)) or nil,
        }),
    }
end

-- Texto do painel "Melhores oficinas do servidor" da praça: as 5 oficinas online por reputação (mesma regra do ranking).
function WorkshopService.TopWorkshopsText(limit: number): string
    local ranked = rankingEntriesRef()
    if #ranked == 0 then
        return "Abra sua oficina e apareça aqui!"
    end
    local lines = {}
    for i, entry in ipairs(ranked) do
        if i > limit then
            break
        end
        table.insert(lines, string.format("%d. %s  ·  Nv %d  ·  %d rep  ·  %.1f★", i, entry.Name, entry.Level, entry.Reputation, entry.Rating))
    end
    return table.concat(lines, "\n")
end

function WorkshopService.GenerateCustomer(player: Player)
    local workshop = getWorkshop(player)
    if not workshop then return false, "Registre uma oficina primeiro." end
    if getOpenJobCount(player.UserId) >= WorkshopLevels.MaxOpenJobs(workshopLevel(player)) then
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
        if os.time() < (job.ArrivesAt or 0) or CustomerArrivalService.IsArriving(jobId) then
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
    if employeeReserved(job) then
        return false, "Seu mecânico já está atendendo este carro. Aguarde a conclusão."
    end
    local active = Repairs[player.UserId]
    if active and active.JobId == jobId then
        Repairs[player.UserId] = nil
        VehicleService.SetRepairing(jobId, false)
    end
    VehicleService.Despawn(job.Id)
    Jobs[jobId] = nil
    DataService.AddReputation(player, -1)
    breakCombo(player.UserId)
    return true, "Ordem abandonada. -1 de reputação."
end

-- V2-02: somente o dono na recepcao pode mudar a prioridade/agendamento/preco/pedido.
local function nearReception(player: Player): boolean
    local plot = PlotService.GetPlot(player)
    return plot ~= nil and plot:FindFirstChild("Estacoes") ~= nil
        and StationService.IsNear(player, plot, "Orders")
end

function WorkshopService.SetJobPriority(player: Player, jobId: string, value: any): (boolean, string)
    local job = Jobs[jobId]
    if not V2ReceptionRules.CanManage(player.UserId, job, "Available")
        or not V2ReceptionRules.ValidPriority(value) then
        return false, "Ordem ou prioridade inválida."
    end
    if not nearReception(player) then return false, "Use o balcão de recepção da sua oficina." end
    job.Priority = value
    return true, "Prioridade da fila atualizada."
end

function WorkshopService.ScheduleJob(player: Player, jobId: string, seconds: any): (boolean, string)
    local job = Jobs[jobId]
    if not V2ReceptionRules.CanManage(player.UserId, job, "Available")
        or not V2ReceptionRules.ValidAppointment(seconds) then
        return false, "Agendamento inválido."
    end
    if not nearReception(player) then return false, "Use o balcão de recepção da sua oficina." end
    if job.ScheduleUsed or CustomerArrivalService.IsArriving(jobId)
        or os.time() < (job.ArrivesAt or 0) then
        return false, "Este cliente já foi reagendado ou ainda está chegando."
    end
    job.ScheduleUsed = true -- apenas UMA remarcação por OS, sem farmar paciencia
    job.ScheduledUntil = os.time() + seconds
    job.CreatedAt += seconds -- concede o mesmo prazo que ficou reservado
    return true, "Atendimento reservado por " .. seconds .. " segundos. O cliente continua aguardando."
end

function WorkshopService.DiscountJob(player: Player, jobId: string, percent: any): (boolean, string)
    local job = Jobs[jobId]
    if not V2ReceptionRules.CanManage(player.UserId, job, "InProgress")
        or not job.Diagnosed or not V2ReceptionRules.ValidDiscount(percent) then
        return false, "Proposta inválida ou diagnóstico pendente."
    end
    if not nearReception(player) then return false, "Use o balcão de recepção da sua oficina." end
    if job.CollaboratorUserId or employeeReserved(job)
        or (Repairs[player.UserId] and Repairs[player.UserId].JobId == jobId) then
        return false, "Não é possível renegociar um reparo em execução ou delegado."
    end
    local original = job.OriginalPrice or job.Price
    local amount = V2ReceptionRules.PriceAfterDiscount(original, percent)
    if not amount then return false, "Valor inválido." end
    job.Price = amount
    job.DiscountPercent = percent
    job.PriceMultiplierOriginal = job.PriceMultiplierOriginal or job.PriceMultiplier or 1
    job.PriceMultiplier = job.PriceMultiplierOriginal * (100 - percent) / 100
    return true, "Proposta registrada: " .. tostring(amount) .. " moedas."
end

-- O jogador também pode descartar uma lista velha após cancelamento de OS.
function WorkshopService.ClearSupplyRequests(player: Player): (boolean, string)
    if not getWorkshop(player) then return false, "Registre a oficina primeiro." end
    if not nearReception(player) and not nearShop(player) then
        return false, "Acesse a recepção ou a Loja de Autopeças."
    end
    return DataService.ClearSupplyRequests(player)
end

function WorkshopService.RequestJobSupplies(player: Player, jobId: string): (boolean, string)
    local job = Jobs[jobId]
    if not V2ReceptionRules.CanManage(player.UserId, job, "InProgress") or not job.Diagnosed then
        return false, "Diagnostique a ordem antes de solicitar peças."
    end
    if not nearReception(player) then return false, "Use o balcão de recepção da sua oficina." end
    local profile = DataService.Get(player)
    if not profile then return false, "Perfil indisponível." end
    -- Não considerar apenas a OS clicada: duas ordens podem exigir a MESMA peça.
    local missing = V2ReceptionRules.AggregateMissing(Jobs, player.UserId, profile.Parts)
    if next(missing) == nil then return false, "Você já tem todas as peças necessárias." end
    return DataService.RequestSupply(player, missing)
end

function WorkshopService.AcceptJob(player: Player, jobId: string)
    local job = Jobs[jobId]
    if not job or job.OwnerUserId ~= player.UserId then
        return false, "Ordem não encontrada."
    end
    if job.Status ~= "Available" or (os.time() < (job.ArrivesAt or 0) and not CustomerArrivalService.IsWaiting(jobId)) then
        return false, "Esta ordem não está disponível."
    end
    if CustomerArrivalService.IsArriving(jobId) then
        return false, "O cliente ainda está estacionando."
    end
    if os.time() < (job.ScheduledUntil or 0) then
        return false, "O atendimento está agendado. Aguarde o horário reservado."
    end
    local plot = PlotService.GetPlot(player)
    if plot and plot:FindFirstChild("Estacoes") and not StationService.IsNear(player, plot, "Orders") then
        return false, "Aceite a ordem na TV de ordens, dentro da oficina."
    end
    -- O VehicleService assume o carro e o cliente da calçada (CustomerArrivalService.Claim) e entra na vaga.
    local placed, placeMessage = VehicleService.Spawn(player, job)
    if not placed then
        return false, placeMessage
    end
    job.Status = "InProgress"
    job.AcceptedAt = os.time()
    funnel(player, "Accepted")
    VehicleService.SetSymptom(job.Id, defectSymptom(job.Diagnosed and job.DefectId or job.ComplaintDefectId))
    job.AssignedWorkerUserId = player.UserId
    VehicleService.SetRepairActor(job.Id, player.UserId)
    return true, "Ordem aceita. " .. placeMessage
end

-- Exames e hipóteses formam a MESMA ordem: o servidor guarda o defeito verdadeiro.
local function ensureDiagnosisOptions(job: any)
    if not job.DiagnoseOptions then
        job.DiagnoseOptions = DiagnosisRules.BuildOptions(Catalog.Defects, job.DefectId, job.ComplaintDefectId, math.random)
        job.DiagnoseWrong = {}
        job.DiagnoseAttempts = 0
    end
end

local function sendDiagnosisOptions(player: Player, job: any)
    if not eventSender then return end
    local options = {}
    for _, id in ipairs(job.DiagnoseOptions) do
        table.insert(options, { Id = id, Name = Catalog.Defects[id].DisplayName, Wrong = job.DiagnoseWrong[id] == true })
    end
    eventSender(player, "DiagnoseStart", {
        JobId = job.Id, Vehicle = job.VehicleName, Customer = job.CustomerName, Complaint = job.Complaint,
        Options = options, Attempts = job.DiagnoseAttempts,
        Exams = DiagnosisEvidence.Exams,
        Findings = DiagnosisEvidence.Findings(job.DefectId, job.DiagnoseExams),
    })
end

-- Conversa com o cliente libera hipóteses. O diagnóstico real é sempre validado no servidor.
function WorkshopService.DiagnoseJob(player: Player, jobId: string, choice: any?)
    local job = Jobs[jobId]
    if not job or job.OwnerUserId ~= player.UserId then
        return false, "Ordem não encontrada."
    end
    if job.Status ~= "InProgress" or job.AssignedWorkerUserId ~= player.UserId then
        return false, "Você não está responsável por esta ordem."
    end
    local nearCustomer = CustomerNpcService.IsNear(player, job.Id, Config.TalkDistance)
    local nearVehicle = VehicleService.IsNear(player, job.Id, Config.InteractDistance)
    if choice ~= nil and job.DiagnoseOptions then
        -- Após a conversa, o mecânico pode analisar hipóteses perto do carro.
        if nearCustomer ~= true and not nearVehicle then
            return false, "Aproxime-se do carro ou do cliente para concluir o diagnóstico."
        end
    elseif nearCustomer == false then
        return false, "Chegue perto do cliente para conversar."
    elseif nearCustomer == nil and not nearVehicle then
        return false, "Aproxime-se do veículo para diagnosticar."
    end
    if job.Diagnosed then
        return true, Catalog.Defects[job.DefectId].DisplayName
    end

    ensureDiagnosisOptions(job)
    if choice == nil then
        VehicleService.EnableInspection(job.Id)
        sendDiagnosisOptions(player, job)
        return true, ""
    end

    -- Para os três casos-piloto, o cliente não pode resolver apenas escolhendo por sorte.
    if DiagnosisEvidence.RequiresExam(job.DefectId) and not DiagnosisEvidence.HasRelevantExam(job.DefectId, job.DiagnoseExams) then
        return false, "O laudo ainda é inconclusivo. Examine os pontos indicados no veículo."
    end
    local verdict = DiagnosisRules.Judge(job.DiagnoseOptions, job.DiagnoseWrong, job.DefectId, choice)
    if verdict == "invalid" then
        return false, "Opção de diagnóstico inválida."
    end
    job.DiagnoseAttempts += 1
    if verdict == "wrong" then
        job.DiagnoseWrong[choice] = true
        sendDiagnosisOptions(player, job)
        return false, "Não era isso: " .. Catalog.Defects[choice].DisplayName .. ". Cada palpite errado reduz a qualidade do reparo."
    end

    job.Diagnosed = true
    job.PreparationStep = 1
    -- Preparação fica visível apenas depois que o defeito foi diagnosticado.
    VehicleService.SetRepairPrepProgress(job.Id, job.DefectId, job.PreparationStep)
    funnel(player, "Diagnosed")
    VehicleService.SetStage(job.Id, "Repair")
    VehicleService.SetSymptom(job.Id, defectSymptom(job.DefectId))
    VehicleService.Flash(job.Id, Color3.fromRGB(80, 150, 255))
    if eventSender then
        eventSender(player, "DiagnoseDone", { JobId = job.Id, Attempts = job.DiagnoseAttempts })
    end
    local defect = Catalog.Defects[job.DefectId]
    return true, "Diagnóstico correto: " .. defect.DisplayName .. ". Serviço: " .. Catalog.Services[job.ServiceId].DisplayName .. "."
end

-- Exame explícito no veículo: não responde com o DefectId, somente com a leitura do instrumento.
-- Uma ação de exame não cobra peças nem altera dinheiro, XP ou condição de componentes.
function WorkshopService.ExamineJob(player: Player, jobId: string, examId: any)
    local job = Jobs[jobId]
    if not job or job.OwnerUserId ~= player.UserId then
        return false, "Ordem não encontrada."
    end
    if job.Status ~= "InProgress" or job.AssignedWorkerUserId ~= player.UserId or job.Diagnosed then
        return false, "Esta ordem não está aguardando inspeção."
    end
    if not job.DiagnoseOptions then
        return false, "Converse primeiro com o cliente para conhecer a reclamação."
    end
    if not DiagnosisEvidence.IsValidExam(examId) then
        return false, "Exame inválido."
    end
    if not VehicleService.IsNearInspectionPoint(player, job.Id, examId) then
        return false, "Vá até o ponto de inspeção correspondente no carro. Procure o marcador iluminado."
    end
    job.DiagnoseExams = job.DiagnoseExams or {}
    job.DiagnoseExams[examId] = true
    VehicleService.MarkInspected(job.Id, examId)
    sendDiagnosisOptions(player, job)
    return true, ""
end

-- Confere TUDO que o reparo exige (responsável, diagnóstico, distância, equipamento, nível, peças) SEM consumir nada.
-- Retorna (ok, mensagem, job, defect, service).
local function checkRepairable(player: Player, jobId: string): (boolean, string, any, any, any, Player?)
    local job = Jobs[jobId]
    if not CollaborationRules.IsAuthorized(job, player.UserId) then
        return false, "Você não está responsável por esta ordem.", nil, nil, nil, nil
    end
    if not job.Diagnosed then
        return false, "Faça o diagnóstico antes do reparo.", nil, nil, nil, nil
    end
    local owner: Player? = Players:GetPlayerByUserId(job.OwnerUserId)
    if not owner or not DataService.Get(owner) then
        return false, "O dono da oficina está desconectado.", nil, nil, nil, nil
    end
    local workshop = getWorkshop(owner)
    local defect = Catalog.Defects[job.DefectId]
    local service = Catalog.Services[job.ServiceId]
    if not workshop or not ownsEquipment(workshop, defect.RequiredEquipment) then
        local equipment = Catalog.Equipment[defect.RequiredEquipment]
        return false, "A oficina não possui o equipamento necessário: " .. (equipment and equipment.DisplayName or defect.RequiredEquipment), nil, nil, nil, nil
    end
    if not VehicleService.IsParked(job.Id) then
        return false, "Espere o carro estacionar no box.", nil, nil, nil, nil
    end
    -- Ferramenta: junto ao carro. Máquina: na sala de equipamentos da oficina DONA da OS.
    if defect.RequiredEquipment == "BasicToolset" then
        if not VehicleService.IsNear(player, job.Id, Config.InteractDistance) then
            return false, "Aproxime-se do veículo para reparar.", nil, nil, nil, nil
        end
    else
        local plot = PlotService.GetPlot(owner)
        local pos = plot and EquipmentService.Position(plot, defect.RequiredEquipment)
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not pos or not hrp or not hrp:IsA("BasePart") or (hrp.Position - pos).Magnitude > 12 then
            return false, "Use o equipamento " .. Catalog.Equipment[defect.RequiredEquipment].DisplayName .. " na sala dos fundos da oficina.", nil, nil, nil, nil
        end
    end
    local level = DataService.GetSkillLevel(player, defect.Specialization)
    if level < defect.RequiredLevel then
        return false, "Nível insuficiente em " .. defect.Specialization .. ". Requer nível " .. tostring(defect.RequiredLevel) .. ".", nil, nil, nil, nil
    end
    local missing = missingPartsMessage(owner, defect.Parts)
    if missing then
        return false, missing, nil, nil, nil, nil
    end
    return true, "", job, defect, service, owner
end

-- O jogador executa preparação no mundo físico ANTES de abrir o painel de reparo.
-- Não entrega moedas, peças, XP ou conclusão. Servidor controla sequência e proximidade.
function WorkshopService.PrepareRepairStep(player: Player, jobId: string, stepId: string)
    local job = Jobs[jobId]
    if not CollaborationRules.IsAuthorized(job, player.UserId) or not job.Diagnosed then
        return false, "Você não está autorizado a preparar esta ordem."
    end
    if employeeReserved(job) then
        return false, "Um funcionário já assumiu esta ordem."
    end
    if not RepairPrepRules.Requires(job.DefectId) then
        return false, "Esta ordem usa o procedimento tradicional."
    end
    if not VehicleService.IsParked(jobId) then
        return false, "Espere o carro estacionar."
    end
    local nextStep = RepairPrepRules.Advance(job.DefectId, job.PreparationStep, stepId)
    if not nextStep then
        return false, "Esta etapa não está liberada. Siga o marcador do carro."
    end
    if not VehicleService.IsNearRepairPrepPoint(player, jobId, stepId) then
        return false, "Aproxime-se do componente indicado para trabalhar."
    end
    job.PreparationStep = nextStep
    VehicleService.SetRepairPrepProgress(job.Id, job.DefectId, nextStep)
    if RepairPrepRules.Ready(job.DefectId, nextStep) then
        return true, "Preparação concluída. Use a ferramenta no carro ou a máquina da oficina."
    end
    return true, "Etapa concluída. Siga o próximo marcador no veículo."
end

-- Inicia o minijogo: o servidor sorteia o plano e guarda o instante de início. Nada é cobrado até o envio final.
-- `assist` (Reduzir movimento) deixa a barra mais lenta e a zona maior.
function WorkshopService.SetRepairAssist(player: Player, value: boolean)
    RepairAssist[player.UserId] = value == true
    return true, ""
end

function WorkshopService.StartRepair(player: Player, jobId: string, assist: boolean?)
    if SettlingRepairs[player.UserId] then
        return false, "Há um pagamento anterior aguardando confirmação. Aguarde antes de iniciar outra OS."
    end
    local ok, message, job, defect = checkRepairable(player, jobId)
    if not ok then
        return false, message
    end
    if employeeReserved(job) then
        return false, "Um funcionário já está executando esta ordem. Aguarde a conclusão."
    end
    if not RepairPrepRules.Ready(job.DefectId, job.PreparationStep) then
        return false, "Prepare primeiro o veículo: siga as etapas destacadas no carro."
    end
    local states, pilotId = VehicleService.ComponentStates(jobId)
    local componentReady, reason = V2ComponentRules.ReadyToRepair(job.DefectId, pilotId, states)
    if not componentReady then return false, reason end
    local previous = Repairs[player.UserId]
    if previous then
        if RepairSessionRules.IsActive(previous, os.clock(), RepairRules.MaxSessionSeconds) then
            return false, "Você já tem um reparo em andamento. Conclua ou cancele antes de iniciar outro."
        end
        -- Sessão abandonada/expirada: libere a animação antes de criar uma nova.
        Repairs[player.UserId] = nil
        VehicleService.SetRepairing(previous.JobId, false)
    end
    local margin = math.max(0, DataService.GetSkillLevel(player, defect.Specialization) - defect.RequiredLevel)
    local operation = RepairOperations.BuildPlan(job.DefectId, math.random(1, 2147483646))
    local plan = operation or RepairRules.BuildPlan(math.random(1, 2147483646), defect.RequiredLevel, margin, assist == true or RepairAssist[player.UserId] == true, EquipmentUpgradeRules.Efficiency(defect.RequiredEquipment,
        DataService.GetEquipmentLevel((Players:GetPlayerByUserId(job.OwnerUserId) or player), defect.RequiredEquipment)))
    Repairs[player.UserId] = {
        JobId = job.Id, Plan = plan, StartedAt = os.clock(),
        Progress = plan.Kind == "Operations" and RepairActionRules.New(plan) or nil,
        Token = game:GetService("HttpService"):GenerateGUID(false), -- timing e operações têm a mesma garantia de entrega
    }
    VehicleService.SetRepairing(job.Id, true) -- carro sobe no elevador / capô abre / pneu sai (efeitos no cliente)
    if eventSender then
        eventSender(player, "RepairStart", {
            JobId = job.Id,
            Vehicle = job.VehicleName,
            Service = Catalog.Services[job.ServiceId].DisplayName,
            Plan = operation and RepairOperations.PublicPlan(operation) or plan,
            Token = Repairs[player.UserId].Token,
        })
    end
    return true, ""
end

-- O servidor recebe cada interação do procedimento e confirma uma revisão antes de aceitar a próxima.
-- A UI não pode substituir ações ausentes por um formulário final fabricado.
function WorkshopService.RepairAction(player: Player, jobId: string, token: any, command: any): (boolean, string, number)
    local session = Repairs[player.UserId]
    if not session or session.JobId ~= jobId or session.Plan.Kind ~= "Operations" or not session.Progress
        or type(token) ~= "string" or token ~= session.Token then
        return false, "Não há um procedimento válido em andamento.", 0
    end
    local now = os.clock()
    if not RepairSessionRules.IsActive(session, now, RepairRules.MaxSessionSeconds) then
        Repairs[player.UserId] = nil
        VehicleService.SetRepairing(jobId, false)
        return false, "Sessão expirada. Inicie novamente.", 0
    end
    local ok, message = checkRepairable(player, jobId)
    if not ok then return false, message, session.Progress.Revision end
    -- Resposta idempotente ao mesmo comando após ACK perdido. Autoridade e
    -- proximidade são novamente verificadas antes de confirmar a retransmissão.
    if RepairActionRules.IsReplay(session.Progress, command) then
        return true, "", session.Progress.Revision
    end
    -- Limite curto para novos ajustes touch; retransmissões não gastam este intervalo.
    if session.LastActionAt and now - session.LastActionAt < 0.07 then
        return false, "Aguarde a confirmação do ajuste anterior.", session.Progress.Revision
    end
    local accepted, reason = RepairActionRules.Apply(session.Plan, session.Progress, command)
    if accepted then
        session.LastActionAt = now
        return true, "", session.Progress.Revision
    end
    return false, reason, session.Progress.Revision
end

-- Consulta sem efeitos colaterais: não reexecuta o serviço nem altera a economia.
function WorkshopService.CheckRepairOutcome(player: Player, jobId: any, token: any): any
    if not RepairReceiptRules.ValidRequest(jobId, token) then
        return { Status = "Unknown", JobId = "", Token = "" }
    end
    local userId = player.UserId
    local answer = { JobId = jobId, Token = token, Status = "Unknown" }
    -- Um recibo em memória não prova que as duas contas já foram gravadas.
    local settling = SettlingRepairs[userId]
    if SettlementDeliveryRules.Matches(settling, jobId, token) then
        answer.Status = "Processing"
        return answer
    end
    local receipt = RepairReceiptRules.Lookup(RepairReceipts[userId], jobId, token, os.clock())
        or DataService.GetRepairReceipt(player, jobId, token)
    if receipt then
        answer.Status = "Completed"
        answer.Result = receipt
        return answer
    end
    local current = Repairs[userId]
    if current and current.JobId == jobId and current.Token == token
        and RepairSessionRules.IsActive(current, os.clock(), RepairRules.MaxSessionSeconds) then
        answer.Status = "Active"
    end
    return answer
end

function WorkshopService.CancelRepair(player: Player, jobId: any?, token: any?)
    local session = Repairs[player.UserId]
    if not RepairSessionRules.CanCancel(session, jobId, token) then
        return false, "Cancelamento antigo ou de outra sessão ignorado."
    end
    if session then
        VehicleService.SetRepairing(session.JobId, false)
    end
    Repairs[player.UserId] = nil
    return true, ""
end

-- Confirma o pagamento somente depois de salvar os dois perfis, em ordem.
-- A confirmação de uma conta NÃO torna a outra atomicamente persistida.
local function confirmDelivery(entry: any)
    if SettlingRepairs[entry.WorkerUserId] ~= entry
        or not SettlementDeliveryRules.Ready(entry) then return false end
    SettlingRepairs[entry.WorkerUserId] = nil
    if entry.Delegated and entry.Worker.Parent == Players then
        -- Prova do proprietário só é dispensável após a claim sumir da conta
        -- do contratado em um Save CONFIRMADO, não após um descarte em memória.
        task.spawn(function()
            if not DataService.DiscardWorkerClaim(entry.Worker, entry.JobId, entry.Token) then
                return -- claim ausente: conservar prova até auditoria/recuperação
            end
            if not DataService.Save(entry.Worker) then
                warn("[WorkshopService] Remoção de claim não confirmada; prova do dono preservada:", entry.JobId)
                return
            end
            if entry.Owner.Parent == Players and DataService.DiscardConfirmedOwnerProof(
                entry.Owner, entry.JobId, entry.Token, entry.WorkerUserId) then
                if not DataService.Save(entry.Owner) then
                    warn("[WorkshopService] Limpeza da prova do proprietário pendente:", entry.JobId)
                end
            end
        end)
    end
    if eventSender and entry.Worker.Parent == Players then
        eventSender(entry.Worker, "RepairDone", entry.Receipt)
    end
    if entry.Delegated and eventSender and entry.Owner.Parent == Players then
        eventSender(entry.Owner, "Notice", { Message = entry.OwnerMessage, Success = true })
    end
    return true
end

local function persistDelivery(entry: any): boolean
    if SettlingRepairs[entry.WorkerUserId] ~= entry then return false end
    if not entry.OwnerSaved and entry.Owner.Parent == Players then
        SettlementDeliveryRules.MarkSaved(entry, "Owner", DataService.Save(entry.Owner))
    end
    if entry.OwnerSaved and not entry.WorkerSaved then
        -- Se o crédito do executor falhou temporariamente, a claim já está
        -- salva e a prova do dono agora está persistida. Retentar o mesmo
        -- token antes de confirmar a conta do executor; nunca inventar XP.
        if entry.Delegated then
            if not DataService.HasRepairCredit(entry.Worker, entry.JobId, entry.Token) then
                if not DataService.CreditRepairOnce(entry.Worker, entry.JobId, entry.Token,
                    entry.WorkerPay, "Worker", entry.ServiceName, entry.VehicleName) then
                    return false
                end
            end
            -- O crédito pode ter sido criado APÓS a montagem inicial do
            -- recibo, no caminho de retry. Anexá-lo antes do Save do worker.
            if not DataService.GetRepairReceipt(entry.Worker, entry.JobId, entry.Token) then
                DataService.AttachRepairReceipt(entry.Worker, entry.JobId, entry.Token, entry.Receipt)
            end
            if not entry.WorkerXpApplied then
                DataService.AddSkillXP(entry.Worker, entry.Spec, entry.XP)
                entry.WorkerXpApplied = true
            end
        end
        local workerSaved = entry.Worker == entry.Owner
            or (entry.Worker.Parent == Players and DataService.Save(entry.Worker))
        SettlementDeliveryRules.MarkSaved(entry, "Worker", workerSaved)
    end
    return confirmDelivery(entry)
end

local function retryDelivery(entry: any)
    task.spawn(function()
        -- Cada Save já faz retentativas com backoff; limitar a repetição externa.
        for attempt = 1, 6 do
            task.wait(math.min(8 + attempt * 4, 30))
            if SettlingRepairs[entry.WorkerUserId] ~= entry or entry.Worker.Parent ~= Players
                or (not entry.OwnerSaved and entry.Owner.Parent ~= Players) then return end
            if persistDelivery(entry) then return end
        end
        if SettlingRepairs[entry.WorkerUserId] == entry and eventSender
            and entry.Worker.Parent == Players then
            eventSender(entry.Worker, "Notice", {
                Message = "Pagamento ainda sem confirmação no DataStore. Evite sair e procure suporte se persistir.",
                Success = false,
            })
        end
    end)
end

-- Finaliza o minijogo: valida a sessão e os toques, recalcula a qualidade no servidor (6 fatores) e só então cobra peças e paga.
function WorkshopService.FinishRepair(player: Player, jobId: string, presses: any)
    local session = Repairs[player.UserId]
    if not session or session.JobId ~= jobId then
        -- A conclusão anterior pode ter sido paga, mas o ACK se perdeu.
        -- Reenvie o MESMO comprovante; jamais chame as rotinas financeiras outra vez.
        local token = type(presses) == "table" and presses.Token
        if SettlementDeliveryRules.Matches(SettlingRepairs[player.UserId], jobId, token) then
            return false, "Pagamento em processamento: aguardando salvamento dos perfis."
        end
        local receipt = RepairReceiptRules.Lookup(RepairReceipts[player.UserId], jobId, token, os.clock())
            or DataService.GetRepairReceipt(player, jobId, token)
        if receipt then
            if eventSender then eventSender(player, "RepairDone", receipt) end
            return true, "Entrega já concluída. Comprovante recuperado."
        end
        return false, "Nenhum reparo em andamento."
    end
    -- Todo reparo exige o seu token (inclusive o antigo minijogo de timing).
    -- Pacote atrasado de outro reparo jamais consome peças da sessão atual.
    if not RepairSessionRules.MatchesFinish(session, jobId, presses) then
        return false, "Identificador de sessão inválido."
    end
    Repairs[player.UserId] = nil -- sessão de uso único: reenviar não paga duas vezes
    local now = os.clock()
    SettlingRepairs[player.UserId] = { JobId = jobId, Token = session.Token, At = now }
    local function finishFailure(message: string): (boolean, string)
        SettlingRepairs[player.UserId] = nil
        VehicleService.SetRepairing(jobId, false)
        return false, message
    end
    if not RepairSessionRules.IsActive(session, now, RepairRules.MaxSessionSeconds) then
        return finishFailure("O reparo demorou demais e foi cancelado.")
    end
    local elapsed = now - session.StartedAt
    local ok, message, job, defect, service, owner = checkRepairable(player, jobId)
    if not ok then
        return finishFailure(message)
    end
    if not RepairPrepRules.Ready(job.DefectId, job.PreparationStep) then
        return finishFailure("A preparação do veículo não foi concluída.")
    end
    local mods: RepairRules.Mods = {
        Margin = math.max(0, DataService.GetSkillLevel(player, defect.Specialization) - defect.RequiredLevel),
        EquipmentEfficiency = EquipmentUpgradeRules.Efficiency(defect.RequiredEquipment,
            DataService.GetEquipmentLevel(owner :: Player, defect.RequiredEquipment)),
        PartReliability = Catalog.AveragePartReliability(defect.Parts),
        DiagnosisAttempts = job.DiagnoseAttempts or 1,
    }
    local result
    if session.Plan.Kind == "Operations" then
        local verifiedInput, reason = RepairActionRules.FinalInput(session.Plan, session.Progress)
        if not verifiedInput then
            return finishFailure(reason or "Ações do reparo incompletas.")
        end
        -- presses nunca é fonte de verdade em operações: só conta o estado observado no servidor.
        result = RepairOperations.Evaluate(session.Plan, verifiedInput, elapsed, mods)
    else
        result = RepairRules.Evaluate(session.Plan, presses, elapsed, mods)
    end
    VehicleService.SetRepairing(jobId, false)
    if not result.Valid then
        return finishFailure("Reparo inválido (" .. tostring(result.Reason) .. ").")
    end
    -- Evita reaplicar mesmo uma liquidação preservada de outra sessão de servidor.
    -- Essa checagem ocorre ANTES de retirar peças; cada token de operação é único.
    local workshopOwner = owner :: Player
    if type(session.Token) == "string"
        and (DataService.HasRepairCredit(player, jobId, session.Token)
            or DataService.HasRepairCredit(workshopOwner, jobId, session.Token)) then
        return finishFailure("Esta ordem já possui crédito registrado. Consulte o histórico.")
    end
    -- C12: persistir primeiro a reivindicação do executor. Uma queda após
    -- salvar o dono mas antes do executor poderá ser corrigida no próximo login.
    -- O preparo acontece ANTES do consumo de peças e de qualquer crédito.
    local delegated = CollaborationRules.IsWorker(job, player.UserId)
    local splitAtClaim = job.CollaborationSplitPercent
    local basePrice = job.Price or service.Reward
    local combo = delegated and 1 or comboMultiplier(player.UserId)
    local friend = delegated and 1 or ProgressService.FriendMultiplier(player)
    local ownerLevel = DataService.GetEquipmentLevel(owner :: Player, defect.RequiredEquipment)
    local price = math.floor(basePrice * RepairRules.PayMultiplier(result.Quality) * combo * friend
        * EquipmentUpgradeRules.RewardMultiplier(ownerLevel) + 0.5)
    local tip = RepairRules.Tip(basePrice, result.Quality)
    local xp = RepairRules.XPBonus(service.XP, result.Quality)
    local actorPay, ownerPay = price + tip, 0
    if delegated then
        ownerPay, actorPay = CollaborationRules.Split(price + tip, job.CollaborationSplitPercent or 25)
    end
    if not DataService.HasParts(workshopOwner, defect.Parts) then
        return finishFailure("Faltam peças na oficina.")
    end
    if delegated and workshopOwner ~= player and not DataService.HasOwnerProofCapacity(workshopOwner) then
        return finishFailure("Arquivo de repasses aguardando confirmação está cheio. Aguarde os pagamentos pendentes ou procure suporte.")
    end
    if delegated and workshopOwner ~= player and not DataService.HasWorkerProofCapacity(player) then
        return finishFailure("Arquivo privado do mecânico está cheio. Aguarde regularização antes de concluir outra OS colaborativa.")
    end
    if delegated and workshopOwner ~= player then
        local staged = DataService.StageWorkerClaim(player, workshopOwner.UserId,
            jobId, session.Token, ownerPay, actorPay, xp, result.Quality,
            service.DisplayName, job.VehicleName, defect.Specialization)
        if not staged then
            return finishFailure("Não foi possível reservar o pagamento do colaborador. Tente o reparo novamente.")
        end
        if not DataService.Save(player) then
            -- Save falhou ou lock foi perdido: não manter uma claim criada
            -- por este reparo como se a OS já tivesse crédito confirmado.
            if DataService.DiscardWorkerClaim(player, jobId, session.Token) then
                task.spawn(DataService.Save, player)
            end
            return finishFailure("Não foi possível salvar a reserva do colaborador. Tente o reparo novamente.")
        end
        -- Save(worker) pode ceder execução: PlayerLeft do proprietário
        -- remove a OS, ou outro caminho pode mudar quem é o responsável.
        -- Não debitar peças/pagar o dono usando referências capturadas
        -- antes desse yield. Se a limpeza falhar, a reivindicação antiga
        -- permanece auditável e NÃO prova crédito do dono (C25).
        local stillValid = RepairCommitGuard.CanSettle(job, Jobs[jobId],
            workshopOwner.UserId, player.UserId, delegated,
            workshopOwner.Parent == Players and DataService.Get(workshopOwner) ~= nil
                and getWorkshop(workshopOwner) ~= nil,
            player.Parent == Players and DataService.Get(player) ~= nil,
            splitAtClaim)
        if not stillValid then
            if DataService.DiscardWorkerClaim(player, jobId, session.Token) then
                task.spawn(DataService.Save, player)
            end
            return finishFailure("A oficina ou a ordem mudou durante a reserva. Nenhuma peça foi consumida.")
        end
    end
    -- A preparação da claim envolve Save(worker), portanto outra OS pode
    -- encher o arquivo de provas durante esse yield. Testar e mutar estoque
    -- + crédito do proprietário num único método sem yield, COM ROLLBACK.
    if not DataService.SettleRepairOwnerOnce(workshopOwner, jobId, session.Token,
        delegated and ownerPay or actorPay, defect.Parts, service.DisplayName, job.VehicleName,
        delegated and player.UserId or nil, delegated and actorPay or nil) then
        if delegated then
            DataService.DiscardWorkerClaim(player, jobId, session.Token)
            task.spawn(DataService.Save, player) -- limpeza da intenção antiga
        end
        return finishFailure("Não foi possível reservar peças e pagamento. Verifique estoque ou limite de repasses.")
    end
    -- A parcela do proprietário foi registrada; o contratado tem uma claim
    -- persistida que permite recuperação se o crédito dele falhar.
    local workerCredited = true
    if delegated then
        workerCredited = DataService.CreditRepairOnce(player, jobId, session.Token, actorPay,
            "Worker", service.DisplayName, job.VehicleName)
        if not workerCredited then
            warn("[WorkshopService] Crédito do contratado pendente de retentativa:", jobId, player.UserId)
        end
    end
    job.Status = "Completed"
    VehicleService.Flash(job.Id, Color3.fromRGB(90, 220, 130))
    VehicleService.Despawn(job.Id)
    if not delegated then
        if result.Quality >= COMBO_MIN_QUALITY then
            Combo[player.UserId] = (Combo[player.UserId] or 0) + 1
        else
            breakCombo(player.UserId)
        end
    end
    if delegated then
        player:SetAttribute("CollaborationOwnerUserId", nil)
        player:SetAttribute("CollaborationJobId", nil)
    end
    if workerCredited then
        DataService.AddSkillXP(player, defect.Specialization, xp)
    end
    DataService.AddReputation(workshopOwner, service.Reputation)
    local stars = rateService(workshopOwner, job, service, defect, player, false, result.Quality)
    ProgressService.Record(workshopOwner, {
        Kind = "RepairDone", Amount = delegated and ownerPay or actorPay, Spec = defect.Specialization,
        Quality = result.Quality, Stars = stars, Vip = job.Vip == true,
        FirstTry = (job.DiagnoseAttempts or 1) <= 1, Rush = job.Rush == true or ProgressService.IsRush(),
    })
    local bonus = DataService.CompleteOnboarding(workshopOwner, Config.OnboardingBonus)
    WorkshopService.UpdateSkin(workshopOwner)
    local receiptPayload = {
        JobId = jobId, Token = session.Token,
        Bonus = delegated and 0 or bonus,
        Quality = result.Quality, Perfect = result.Perfect, Good = result.Good, Miss = result.Miss,
        Corrected = result.Corrected, Uncorrected = result.Uncorrected, Breakdown = result.Breakdown,
        Tip = delegated and 0 or tip, Price = delegated and actorPay or price,
        XP = xp, Stars = stars, Combo = combo, NextCombo = delegated and 1 or comboMultiplier(player.UserId),
    }
    do
        -- Mesmo perfil DataStore: marca de crédito e recibo seguem a mesma gravação.
        DataService.AttachRepairReceipt(player, jobId, session.Token, receiptPayload)
        if delegated and workshopOwner ~= player then
            DataService.AttachRepairReceipt(workshopOwner, jobId, session.Token, {
                JobId = jobId, Token = session.Token,
                Quality = result.Quality, Price = ownerPay, Tip = 0, XP = 0,
                Stars = stars, Bonus = bonus,
            })
        end
        local receipts = RepairReceipts[player.UserId]
        if not receipts then
            receipts = {}
            RepairReceipts[player.UserId] = receipts
        end
        RepairReceiptRules.Remember(receipts, jobId, session.Token, receiptPayload, os.clock())
    end
    -- C10: nenhum RepairDone enquanto alguma parcela não tiver sido persistida.
    -- C11: salvamento com retentativa controlada; não reaplica saldo/peças/XP.
    funnel(workshopOwner, "Repaired")
    do
        local entry = SettlementDeliveryRules.New(jobId, session.Token,
            workshopOwner.UserId, player.UserId)
        if not entry then
            warn("[WorkshopService] Token de liquidação inválido, sem confirmação:", jobId)
            SettlingRepairs[player.UserId] = nil
            return false, "Não foi possível confirmar o identificador do pagamento."
        end
        entry.Worker, entry.Owner = player, workshopOwner
        entry.Delegated, entry.Receipt = delegated, receiptPayload
        entry.WorkerPay, entry.XP, entry.Spec = actorPay, xp, defect.Specialization
        entry.ServiceName, entry.VehicleName = service.DisplayName, job.VehicleName
        entry.WorkerXpApplied = workerCredited
        entry.OwnerMessage = string.format("%s concluiu %s com %d%% de qualidade: sua parte foi %d moedas.",
            player.DisplayName, service.DisplayName, result.Quality, ownerPay)
        entry.At = os.clock()
        SettlingRepairs[player.UserId] = entry
        if not persistDelivery(entry) then
            warn("[WorkshopService] Liquidação em memória, entrega pendente de DataStore:", jobId)
            if eventSender then
                eventSender(player, "Notice", {
                    Message = "Reparo executado; salvamento pendente. Aguarde a confirmação antes de sair.",
                    Success = false,
                })
            end
            retryDelivery(entry)
            return false, "Pagamento em processamento: aguardando confirmação do DataStore."
        end
    end
    if delegated then
        return true, "Serviço colaborativo concluído. Sua parte: +" .. tostring(actorPay)
            .. " moedas e +" .. tostring(xp) .. " XP. Nota: "
            .. CustomerRules.StarsText(stars)
    end
    return true, "Serviço concluído. +" .. tostring(actorPay) .. " moedas (qualidade " .. tostring(result.Quality) .. "%"
        .. (combo > 1 and string.format(", combo x%.1f", combo) or "")
        .. (friend > 1 and ", bônus de amigo" or "") .. "), +" .. tostring(xp)
        .. " XP. Avaliação: " .. CustomerRules.StarsText(stars) .. " (" .. tostring(stars) .. ")"
        .. (bonus > 0 and (" Bônus do primeiro serviço: +" .. tostring(bonus) .. ".") or "")
end

-- Atualiza a fachada conforme o total ganho; avisa o jogador quando a oficina evolui de tipo.
function WorkshopService.UpdateSkin(player: Player)
    local profile = DataService.Get(player)
    if not profile or not Workshops[player.UserId] then
        return
    end
    -- A aparência agora vem do nível comprado na Construtora (StationService.ApplyLevel); nada a fazer aqui.
end

function WorkshopService.SkipOnboarding(player: Player)
    DataService.CompleteOnboarding(player, 0)
    return true, ""
end

function WorkshopService.UpgradeOwnedEquipment(player: Player, equipmentId: string, sourcePlot: Instance): (boolean, string)
	local workshop = getWorkshop(player)
	if not workshop or PlotService.GetPlot(player) ~= sourcePlot
		or sourcePlot:GetAttribute("OwnerUserId") ~= player.UserId then
		return false, "Melhorias só podem ser compradas na sua oficina."
	end
	if workshop.Equipment[equipmentId] ~= true then return false, "Equipamento não instalado." end
	return DataService.UpgradeOwnedEquipment(player, equipmentId)
end

function WorkshopService.BuyEquipment(player: Player, equipmentId: string)
    if not nearShop(player) then return false, SHOP_FAR end
    local workshop = getWorkshop(player)
    local equipment = Catalog.Equipment[equipmentId]
    if not workshop or not equipment then return false, "Oficina ou equipamento inválido." end
    if ownsEquipment(workshop, equipmentId) then return false, "Você já possui este equipamento." end

    local profile = DataService.Get(player)
    if not profile or profile.Coins < equipment.Cost then
        return false, "Moedas insuficientes."
    end
    if equipmentCount(profile.Equipment) >= WorkshopLevels.MaxEquipment(profile.WorkshopLevel or 0) then
        return false, "Não cabe mais equipamento no seu prédio: amplie a oficina na Construtora."
    end

    DataService.AddCoins(player, -equipment.Cost, "Compra: " .. equipment.DisplayName)
    DataService.GrantEquipment(player, equipmentId)
    EquipmentService.Add(player, profile.Equipment, equipmentId)
    task.delay(0.7, function()
        if player.Parent == Players then EquipmentUpgradePads.Sync(player, profile.Equipment, profile.EquipmentLevels) end
    end)
    return true, equipment.DisplayName .. " comprado."
end

-- Loja de peças: compra em quantidade (1..MaxPartPurchase); o saldo e o estoque são decididos aqui.
function WorkshopService.BuyPart(player: Player, partId: string, quantity: number)
    if not nearShop(player) then return false, SHOP_FAR end
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
    DataService.FulfillSupplyRequest(player, partId, quantity)
    return true, string.format("%dx %s comprado(s).", quantity, part.DisplayName)
end

-- Carrinho da Loja de Peças: compra TODOS os itens ou nenhum. O servidor recalcula preços e valida saldo, limites e
-- posse; o cliente só envia { Kind = "Part" | "Equipment", Id, Quantity }.
local MAX_CART_LINES = 20
function WorkshopService.Checkout(player: Player, items: any)
    if type(items) ~= "table" or #items == 0 or #items > MAX_CART_LINES then
        return false, "Carrinho inválido."
    end
    if not nearShop(player) then return false, SHOP_FAR end
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
    local newCount = 0
    for _ in pairs(equipmentIds) do
        newCount += 1
    end
    if newCount > 0 and equipmentCount(profile.Equipment) + newCount > WorkshopLevels.MaxEquipment(profile.WorkshopLevel or 0) then
        return false, "Não cabe tanto equipamento no seu prédio: amplie a oficina na Construtora."
    end
    -- tudo validado: aplica sem yield entre a checagem e a gravação
    DataService.AddCoins(player, -total, "Loja de peças")
    for partId, quantity in pairs(partQuantities) do
        DataService.AddParts(player, partId, quantity)
        DataService.FulfillSupplyRequest(player, partId, quantity)
    end
    for equipmentId in pairs(equipmentIds) do
        DataService.GrantEquipment(player, equipmentId)
        EquipmentService.Add(player, profile.Equipment, equipmentId)
    end
    if next(equipmentIds) then
        task.delay(0.7, function()
            if player.Parent == Players then EquipmentUpgradePads.Sync(player, profile.Equipment, profile.EquipmentLevels) end
        end)
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
    if employeeReserved(job) then
        return false, "Um funcionário já está executando a ordem; não é possível convidar outro."
    end
    if Repairs[owner.UserId] and Repairs[owner.UserId].JobId == jobId then
        return false, "Termine ou cancele seu reparo antes de contratar um profissional."
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
    if not job or job.Status ~= "InProgress" or job.OwnerUserId ~= invite.OwnerUserId or not job.Diagnosed then
        invite.Status = "Expired"
        return false, "A ordem não está mais disponível."
    end
    if job.CollaboratorUserId then
        -- Outro profissional aceitou primeiro: não sobrescreve (o primeiro seria prejudicado).
        invite.Status = "Expired"
        return false, "A ordem já tem um colaborador."
    end
    if employeeReserved(job) then
        invite.Status = "Expired"
        return false, "Um funcionário já iniciou o atendimento; convite expirado."
    end

    for _, other in pairs(Jobs) do
        if other ~= job and CollaborationRules.IsWorker(other, worker.UserId) then
            return false, "Você já está contratado para outra ordem. Conclua-a primeiro."
        end
    end
    if Repairs[worker.UserId] then
        return false, "Conclua ou cancele seu reparo antes de aceitar o convite."
    end
    local defect = Catalog.Defects[job.DefectId]
    if DataService.GetSkillLevel(worker, defect.Specialization) < defect.RequiredLevel then
        return false, "Sua habilidade ainda não atende ao nível necessário deste serviço."
    end
    invite.Status = "Accepted"
    job.AssignedWorkerUserId = worker.UserId
    job.CollaboratorUserId = worker.UserId
    job.CollaborationSplitPercent = invite.SplitPercent
    job.CollabAt = os.time()
    VehicleService.SetRepairActor(job.Id, worker.UserId)
    worker:SetAttribute("CollaborationOwnerUserId", invite.OwnerUserId)
    worker:SetAttribute("CollaborationJobId", job.Id)
    return true, "Convite aceito. Vá até o carro ou a máquina da oficina contratante para reparar."
end

-- Compatibilidade com o botão legado: não paga instantaneamente; abre o mesmo minijogo do proprietário.
function WorkshopService.CompleteCollaborativeJob(worker: Player, jobId: string)
    return WorkshopService.StartRepair(worker, jobId, false)
end

-- A renda de um NPC não é anunciada como confirmada enquanto o perfil
-- proprietário não for salvo. Repetir Save NUNCA reaplica peças ou moedas.
local function confirmNpcSave(owner: Player, jobId: string, token: string, message: string, alreadyTried: boolean?)
    local key = tostring(owner.UserId) .. ":" .. jobId .. ":" .. token
    if NpcPendingSaves[key] then return end
    NpcPendingSaves[key] = true
    task.spawn(function()
        if alreadyTried and eventSender and owner.Parent == Players then
            eventSender(owner, "Notice", {
                Message = "Serviço realizado; pagamento aguardando DataStore. Não inicie cobrança novamente.",
                Success = false,
            })
        end
        for attempt = 1, 6 do
            if owner.Parent ~= Players or not DataService.Get(owner) then break end
            if DataService.Save(owner) then
                NpcPendingSaves[key] = nil
                if eventSender and owner.Parent == Players then
                    eventSender(owner, "Notice", { Message = message, Success = true })
                end
                return
            end
            task.wait(math.min(attempt * 4, 20))
        end
        NpcPendingSaves[key] = nil
        warn("[WorkshopService] NPC sem confirmação de persistência:", owner.UserId, jobId)
        if eventSender and owner.Parent == Players then
            eventSender(owner, "Notice", {
                Message = "Serviço NPC executado, mas o salvamento falhou. Evite sair; procure suporte.",
                Success = false,
            })
        end
    end)
end

function WorkshopService.HireNpc(player: Player, jobId: string)
    local job = Jobs[jobId]
    if not job or job.OwnerUserId ~= player.UserId or job.Status ~= "InProgress" then
        return false, "Ordem inválida."
    end
    if employeeReserved(job) or (Repairs[player.UserId] and Repairs[player.UserId].JobId == jobId) then
        return false, "Esta ordem já está sendo reparada. Aguarde a conclusão ou cancele o reparo manual."
    end
    if not job.Diagnosed then return false, "Faça o diagnóstico primeiro." end
    if job.CollaboratorUserId then
        return false, "Um profissional convidado já está nesta ordem."
    end
    local hirePlot = PlotService.GetPlot(player)
    if hirePlot and hirePlot:FindFirstChild("Estacoes") and not StationService.IsNear(player, hirePlot, "Orders") then
        return false, "Chame o mecânico avulso pela TV de ordens, dentro da oficina."
    end

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
    if missing then return false, missing end
    local token = game:GetService("HttpService"):GenerateGUID(false)
    if not DataService.SettleNpcRepairOnce(player, job.Id, token, price - npcCost,
        defect.Parts, "NPC avulso: " .. service.DisplayName, job.VehicleName) then
        return false, "Não foi possível registrar o custo e o pagamento deste serviço."
    end
    job.Status = "Completed"
    VehicleService.Despawn(job.Id)
    DataService.AddReputation(player, service.Reputation)
    local stars = rateService(player, job, service, defect, nil, true)
    DataService.AttachRepairReceipt(player, job.Id, token, {
        JobId = job.Id, Token = token, Price = price - npcCost, Stars = stars, Quality = Config.EmployeeQuality,
    })
    local message = "Mecânico NPC concluiu o serviço. Custo: " .. tostring(npcCost)
        .. " moedas. Você não recebeu XP. Avaliação: " .. CustomerRules.StarsText(stars) .. " (" .. tostring(stars) .. ")"
    if DataService.Save(player) then return true, message end
    confirmNpcSave(player, job.Id, token, message, true)
    return false, "Serviço realizado; aguarde a confirmação do pagamento no DataStore."
end

-- Interação física com o veículo (ProximityPrompt). O servidor decide o que o jogador pode fazer.
-- V2-03: controla mecanica pelo mesmo canal de ProximityPrompt da V1.
-- Não há RemoteEvent novo; todas as verificações são feitas no servidor, perto do carro.
function WorkshopService.ToggleVehicleComponent(player: Player, jobId: string, id: any): (boolean, string)
    local job = Jobs[jobId]
    if not job or job.Status ~= "InProgress" or type(id) ~= "string"
        or not V2ComponentRules.ById[id] then
        return false, "Ordem ou componente inválido."
    end
    local assigned = job.AssignedWorkerUserId == player.UserId
    if not assigned or not CollaborationRules.IsAuthorized(job, player.UserId) then
        return false, "Esta interação é exclusiva do mecânico responsável pela ordem."
    end
    local states, pilotId = VehicleService.ComponentStates(jobId)
    if not pilotId then return false, "Este carro não possui articulações V2." end
    local prepFolder = nil
    local supportReady = RepairPrepRules.IsDone(job.DefectId, job.PreparationStep, "JackSupport")
    local ctx: V2ComponentRules.Context = {
        Parked = VehicleService.IsParked(jobId),
        Assigned = assigned,
        InProgress = job.Status == "InProgress",
        Diagnosed = job.Diagnosed == true,
        Repairing = (Repairs[player.UserId] ~= nil and Repairs[player.UserId].JobId == jobId),
        WorkerBusy = employeeReserved(job),
        WheelSupportReady = supportReady,
        WheelSupportRequired = job.DefectId == "FlatTire",
        HoodLockedOpen = job.Diagnosed == true and
            (job.DefectId == "WeakBattery" or job.DefectId == "Overheating")
            and (job.PreparationStep or 1) > 1
            and not RepairPrepRules.Ready(job.DefectId, job.PreparationStep),
    }
    local _ = states
    local _2 = prepFolder
    return VehicleService.ToggleComponent(player, jobId, id, ctx)
end

function WorkshopService.Interact(player: Player, jobId: string, kind: string): (boolean, string)
    local job = Jobs[jobId]
    if kind == "Accept" then
        return WorkshopService.AcceptJob(player, jobId) -- valida dono, status e chegada
    end
    if not job or job.Status ~= "InProgress" then
        return false, "Ordem não está em andamento."
    end
    local componentId = V2ComponentRules.FromPrompt(kind)
    if componentId then return WorkshopService.ToggleVehicleComponent(player, jobId, componentId) end
    if kind == "Diagnose" then
        return WorkshopService.DiagnoseJob(player, jobId)
    elseif string.sub(kind, 1, 8) == "Inspect_" then
        return WorkshopService.ExamineJob(player, jobId, string.sub(kind, 9))
    elseif string.sub(kind, 1, 5) == "Prep_" then
        return WorkshopService.PrepareRepairStep(player, jobId, string.sub(kind, 6))
    elseif kind == "Repair" then
        if job.CollaboratorUserId == player.UserId then
            return WorkshopService.CompleteCollaborativeJob(player, jobId)
        elseif job.OwnerUserId == player.UserId then
            return WorkshopService.StartRepair(player, jobId, false)
        end
    end
    return false, "Você não participa desta ordem."
end

-- C26: dono saiu, a OS NÃO pode voltar a "Available" sem oficina/carros.
-- Todos os jobs do dono são removidos; eventos de reparo do contratado são cancelados.
function WorkshopService.PlayerLeft(userId: number)
    local ownSession = Repairs[userId]
    if ownSession then
        VehicleService.SetRepairing(ownSession.JobId, false)
    end
    Repairs[userId] = nil -- sessão de minijogo abandonada
    -- O save de saída do DataService continua sendo a última tentativa de preservar o crédito.
    -- Não enviar confirmação posterior a um executor desconectado.
    SettlingRepairs[userId] = nil
    Combo[userId] = nil
    CustomerArrivalService.Clear(userId) -- clientes que ainda esperavam na rua somem junto
    RepairAssist[userId] = nil
    for jobId, job in pairs(Jobs) do
        local action = JobExitRules.Action(job, userId)
        if action == "RemoveOwner" then
            if job.Status == "InProgress" and job.CollaboratorUserId then
                local worker = Players:GetPlayerByUserId(job.CollaboratorUserId)
                if worker then
                    if worker:GetAttribute("CollaborationJobId") == jobId then
                        worker:SetAttribute("CollaborationOwnerUserId", nil)
                        worker:SetAttribute("CollaborationJobId", nil)
                    end
                    -- Cancelar a sessão mesmo se os atributos do avatar já
                    -- tiverem sido limpos: não pode finalizar carro apagado.
                    local session = Repairs[worker.UserId]
                    if session and session.JobId == jobId then
                        Repairs[worker.UserId] = nil
                        VehicleService.SetRepairing(jobId, false)
                        if eventSender then
                            eventSender(worker, "Result", {
                                Action = "FinishRepair", Success = false,
                                Message = "O dono da oficina desconectou.",
                            })
                        end
                    end
                    if eventSender then
                        eventSender(worker, "Notice", {
                            Message = "O proprietário saiu: a ordem colaborativa foi cancelada.",
                            Success = false,
                        })
                    end
                end
            end
            -- Não converter InProgress em Available quando o carro some:
            -- descartar o job evita ordem fantasma após reentrada do dono.
            Jobs[jobId] = nil
        elseif action == "ReturnToOwner" then
            -- O colaborador saiu mas o dono continua ativo: manter a OS.
            job.CollaboratorUserId = nil
            job.CollaborationSplitPercent = nil
            job.CollabAt = nil
            job.AssignedWorkerUserId = job.OwnerUserId
            VehicleService.SetRepairActor(job.Id, job.OwnerUserId)
        end
    end
    for inviteId, invite in pairs(Invites) do
        if invite.WorkerUserId == userId or invite.OwnerUserId == userId then
            Invites[inviteId] = nil
        end
    end
    VehicleService.DespawnOwner(userId)
    local staff = Staff[userId]
    if staff then
        for _, npc in ipairs(staff.Npcs) do
            npc:Destroy()
        end
        Staff[userId] = nil
    end
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
    if not arrivals and ProgressService.IsRush() then
        count *= 2 -- Hora do Rush: clientes em dobro
    end
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
                Capacity = WorkshopLevels.MaxOpenJobs(e.Profile.WorkshopLevel or 0),
                Distance = e.Distance,
            }
        end
        -- Rivais disputam só parte do mercado (Config.RivalMarketShare): dão vida ao bairro sem deixar o jogador sem clientes.
        if rand() < Config.RivalMarketShare then
            for _, rc in ipairs(RivalService.Candidates()) do
                table.insert(candidates, rc)
            end
        end
        local choice = CustomerRules.Choose(candidates, rand)
        if choice and choice <= #entries then
            createJob(entries[choice].Owner.UserId, specialization)
            created += 1
        elseif choice then
            RivalService.Serve(candidates[choice].RivalId) -- o cliente preferiu a oficina rival
            lost += 1
        else
            lost += 1
        end
    end
    return created, lost
end

-- Mochila <-> prateleira (só perto da prateleira do estoque).
function WorkshopService.MoveBag(player: Player, partId: string, quantity: number, toBag: boolean)
    local plot = PlotService.GetPlot(player)
    if not getWorkshop(player) or not plot then
        return false, "Registre sua oficina primeiro."
    end
    if plot:FindFirstChild("Estacoes") and not StationService.IsNear(player, plot, "Stock") then
        return false, "Vá até a prateleira do estoque, dentro da oficina."
    end
    return DataService.MoveBag(player, partId, quantity, toBag)
end

-- Construtora do bairro: amplia o prédio para o próximo nível (WorkshopLevels.Check: moedas, nível, reputação, XP e
-- equipamentos). Só com os boxes vazios (a obra não derruba carro de cliente) e estando na Construtora.
function WorkshopService.UpgradeWorkshop(player: Player)
    local profile = DataService.Get(player)
    local plot = PlotService.GetPlot(player)
    if not profile or not plot or not getWorkshop(player) then
        return false, "Registre sua oficina primeiro."
    end
    if not StationService.NearConstrutora(player) then
        return false, "Vá até a Construtora do bairro para ampliar a oficina."
    end
    local level = profile.WorkshopLevel or 0
    if level >= WorkshopLevels.MaxLevel then
        return false, "Sua oficina já é a maior do bairro!"
    end
    local ok = WorkshopLevels.Check(level + 1, {
        Coins = profile.Coins,
        BusinessLevel = Catalog.BusinessLevel(profile.TotalEarned or 0),
        Reputation = profile.Reputation,
        SkillTotal = skillTotal(player),
        Equipment = equipmentCount(profile.Equipment),
    })
    if not ok then
        return false, "Ainda faltam requisitos para a ampliação (veja a lista na Construtora)."
    end
    for _, job in pairs(Jobs) do
        if job.OwnerUserId == player.UserId and job.Status == "InProgress" then
            return false, "Termine os serviços em andamento: a obra precisa dos boxes vazios."
        end
    end
    for _, child in ipairs(plot:GetChildren()) do
        if child:IsA("BasePart") and child.Name:match("^Bay%d+$") and child:GetAttribute("JobId") ~= nil then
            return false, "Espere o último carro sair do box para começar a obra."
        end
    end
    local next = WorkshopLevels.Levels[level + 1]
    DataService.AddCoins(player, -next.Cost, "Ampliação da oficina: " .. next.Name)
    DataService.SetWorkshopLevel(player, level + 1)
    if DataService.ClaimTelemetryMilestone(player, "FirstUpgrade") then funnel(player, "FirstUpgrade") end
    StationService.ApplyLevel(plot, level + 1, player.DisplayName)
    EquipmentService.Sync(player, profile.Equipment)
    EquipmentUpgradePads.Sync(player, profile.Equipment, profile.EquipmentLevels)
    syncStaffRef(player)
    refreshPlotDisplays()
    return true, string.format("Obra concluída! Agora você tem um %s com %d boxes.", next.Name, #next.Bays)
end

-- Situação da ampliação para a tela da Construtora (vai no snapshot).
local function upgradeInfo(player: Player, profile: any): any
    local level = profile.WorkshopLevel or 0
    local current = WorkshopLevels.Levels[level]
    local info: any = {
        Level = level,
        Name = current.Name,
        Bays = #current.Bays,
        MaxEquipment = WorkshopLevels.MaxEquipment(level),
        Equipment = equipmentCount(profile.Equipment),
        MaxEmployees = current.MaxEmployees,
    }
    local next = WorkshopLevels.Levels[level + 1]
    if next then
        local ok, rows = WorkshopLevels.Check(level + 1, {
            Coins = profile.Coins,
            BusinessLevel = Catalog.BusinessLevel(profile.TotalEarned or 0),
            Reputation = profile.Reputation,
            SkillTotal = skillTotal(player),
            Equipment = equipmentCount(profile.Equipment),
        })
        info.Next = { Level = level + 1, Name = next.Name, Bays = #next.Bays, Cost = next.Cost, CanBuy = ok, Rows = rows, MaxEmployees = next.MaxEmployees }
    end
    return info
end
WorkshopService._upgradeInfo = upgradeInfo
upgradeInfoRef = upgradeInfo

-- Funcionários ---------------------------------------------------------------------------------------------------

local function staffSpot(plot: Instance, index: number): Vector3?
    local root = StationService.FrameOf(plot)
    if not root then
        return nil
    end
    local L = WorkshopLevels.Levels[StationService.LevelOf(plot)] or WorkshopLevels.Levels[0]
    return (root * CFrame.new(L.X0 + 8 + index * 2.5, 0.4, 28)).Position -- corredor entre box e sala dos fundos
end

local function syncStaff(player: Player)
    local profile = DataService.Get(player)
    local plot = PlotService.GetPlot(player)
    local entry = Staff[player.UserId]
    if not entry then
        local saved = profile and tonumber(profile.NextPayAt) or 0
        local remaining = saved > os.time() and (saved - os.time()) or Config.PaydaySeconds
        if saved > 0 and saved <= os.time() and profile and (profile.Employees or 0) > 0 then
            remaining = 1 -- o pagamento venceu enquanto estava fora: cobra já
        end
        entry = { Npcs = {}, Busy = {}, NextPay = os.clock() + remaining }
        Staff[player.UserId] = entry
    end
    local want = profile and plot and (profile.Employees or 0) or 0
    while #entry.Npcs > want do
        local npc = table.remove(entry.Npcs)
        if npc then
            npc:Destroy()
        end
    end
    while #entry.Npcs < want and plot do
        local index = #entry.Npcs + 1
        local gender, name = Catalog.PickCustomer()
        local npc = NpcKit.Clone(gender, name, "Funcionario_" .. player.UserId .. "_" .. index)
        if not npc then
            break
        end
        npc:SetAttribute("Funcionario", true)
        local spot = staffSpot(plot, index)
        npc.Parent = plot
        if spot then
            NpcKit.Place(npc, spot, spot + Vector3.new(0, 0, 1))
        end
        NpcKit.ServerOwned(npc)
        NpcKit.Animate(npc).Idle()
        NpcKit.NameTag(npc, "Mecânico " .. name, false)
        table.insert(entry.Npcs, npc)
    end
end

function WorkshopService.HireEmployee(player: Player)
    local profile = DataService.Get(player)
    if not profile or not getWorkshop(player) then
        return false, "Registre sua oficina primeiro."
    end
    local maxEmployees = WorkshopLevels.Levels[profile.WorkshopLevel or 0].MaxEmployees
    if maxEmployees <= 0 then
        return false, "Funcionários a partir da Oficina (2 boxes). Amplie na Construtora."
    end
    if (profile.Employees or 0) >= maxEmployees then
        return false, string.format("Seu prédio comporta %d mecânico(s). Amplie para contratar mais.", maxEmployees)
    end
    if profile.Coins < Config.EmployeeHireCost then
        return false, string.format("Contratar custa %d moedas.", Config.EmployeeHireCost)
    end
    DataService.AddCoins(player, -Config.EmployeeHireCost, "Contratação de mecânico")
    if (profile.Employees or 0) == 0 then
        profile.NextPayAt = os.time() + Config.PaydaySeconds
    end
    DataService.SetEmployees(player, (profile.Employees or 0) + 1)
    if DataService.ClaimTelemetryMilestone(player, "FirstEmployee") then funnel(player, "FirstEmployee") end
    syncStaff(player)
    return true, string.format("Mecânico contratado! Salário: %d moedas a cada %d min. Ele atende sozinho os carros que estiverem no box.", Config.EmployeeSalary, Config.PaydaySeconds // 60)
end

function WorkshopService.FireEmployee(player: Player)
    local profile = DataService.Get(player)
    if not profile or (profile.Employees or 0) <= 0 then
        return false, "Você não tem funcionários."
    end
    DataService.SetEmployees(player, profile.Employees - 1)
    syncStaff(player)
    return true, "Mecânico demitido."
end

-- Tentativa de rota calculada pela navmesh; caso a cena ainda não permita
-- navegação (asset faltante), usa o destino direto com fallback do NpcKit.
local function walkEmployee(npc: Model, target: Vector3, animator: any)
    if not npc.Parent or not npc.PrimaryPart then return end
    local points = { target }
    local ok, path = pcall(function()
        local route = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false })
        route:ComputeAsync(npc.PrimaryPart.Position, target)
        return route
    end)
    if ok and path.Status == Enum.PathStatus.Success then
        points = {}
        for _, waypoint in ipairs(path:GetWaypoints()) do
            table.insert(points, waypoint.Position)
        end
    end
    NpcKit.WalkPath(npc, points, animator)
end

-- Ferramenta visível presa à mão durante o serviço (R15 e R6).
local function workWrench(npc: Model): (Part?, Weld?)
    local hand = npc:FindFirstChild("RightHand", true) or npc:FindFirstChild("Right Arm", true)
    if not hand or not hand:IsA("BasePart") then return nil, nil end
    local wrench = Instance.new("Part")
    wrench.Name = "ChaveEmUso"
    wrench.Size = Vector3.new(0.18, 0.18, 1.35)
    wrench.Material = Enum.Material.Metal
    wrench.Color = Color3.fromRGB(165, 175, 185)
    wrench.CanCollide, wrench.CanTouch, wrench.CanQuery = false, false, false
    wrench.Massless = true
    wrench.CFrame = hand.CFrame
    wrench.Parent = npc
    local joint = Instance.new("Weld")
    joint.Part0, joint.Part1 = hand, wrench
    joint.C0 = CFrame.new(0, -0.5, -0.55)
    joint.Parent = wrench
    return wrench, joint
end

-- Funcionário assume um carro em espera e mostra seu trabalho ao proprietário.
local function employeeWork(owner: Player, job: any, npc: Model)
    local entry = Staff[owner.UserId]
    if not entry or not StaffAssignmentRules.IsReserved(entry.Busy, job.Id) then return end
    local defect = Catalog.Defects[job.DefectId]
    local service = Catalog.Services[job.ServiceId]
    local workshop = getWorkshop(owner)
    local function release(message: string?)
        StaffAssignmentRules.Release(entry.Busy, job.Id)
        local plot = PlotService.GetPlot(owner)
        local spot = plot and staffSpot(plot, table.find(entry.Npcs, npc) or 1)
        if npc.Parent and spot then
            walkEmployee(npc, spot, NpcKit.Animate(npc))
            if npc.Parent then NpcKit.ServerOwned(npc) end
        end
        if message and eventSender then
            eventSender(owner, "Notice", { Message = message, Success = false })
        end
    end
    if not workshop or not ownsEquipment(workshop, defect.RequiredEquipment) then
        job.EmployeeRetryAt = os.time() + 60
        release("Seu mecânico não tem o equipamento para " .. service.DisplayName .. ".")
        return
    end
    if missingPartsMessage(owner, defect.Parts) then
        job.EmployeeRetryAt = os.time() + 60
        release("Seu mecânico precisa de peças para " .. service.DisplayName .. ". Compre na Loja de Autopeças.")
        return
    end
    -- vai até o carro
    local car = workspace:FindFirstChild("Vehicles") and workspace.Vehicles:FindFirstChild(job.Id)
    local carRoot = car and car:IsA("Model") and car.PrimaryPart
    if carRoot then
        local spot = carRoot.CFrame * Vector3.new(0, 0, -((tonumber(car:GetAttribute("Comprimento")) or 18) / 2 + 2))
        local plot = PlotService.GetPlot(owner)
        local frame = plot and StationService.FrameOf(plot)
        local groundY = frame and frame.Position.Y + 0.4 or (carRoot.Position.Y - 2.8)
        local target = Vector3.new(spot.X, groundY, spot.Z)
        walkEmployee(npc, target, NpcKit.Animate(npc))
        if npc.Parent then
            NpcKit.ServerOwned(npc)
            NpcKit.Say(npc, "Revisando " .. service.DisplayName, 6)
        end
    end
    if not npc.Parent then release(nil); return end
    job.Diagnosed = true
    -- Se o NPC não puder terminar, os sockets de preparo precisam existir para o jogador retomar.
    job.PreparationStep = job.PreparationStep or 1
    VehicleService.SetRepairPrepProgress(job.Id, job.DefectId, job.PreparationStep)
    VehicleService.SetStage(job.Id, "None")
    VehicleService.SetSymptom(job.Id, defectSymptom(job.DefectId))
    VehicleService.SetRepairing(job.Id, true)
    local level = DataService.GetEquipmentLevel(owner, defect.RequiredEquipment)
    local workSeconds = EquipmentUpgradeRules.EmployeeSeconds(Config.EmployeeWorkSeconds, level)
    local wrench, joint = workWrench(npc)
    local started = os.clock()
    local lastStage = -1
    while npc.Parent and job.Status == "InProgress" and os.clock() - started < workSeconds do
        local elapsed = os.clock() - started
        local percent = math.clamp(math.floor(100 * elapsed / workSeconds), 0, 100)
        npc:SetAttribute("RepairProgress", percent)
        local stage = math.floor(percent / 34)
        if stage ~= lastStage then
            lastStage = stage
            local phrases = { "Inspecionando...", "Substituindo peças...", "Testando o reparo..." }
            NpcKit.Say(npc, phrases[math.min(stage + 1, 3)], 5)
        end
        if joint then
            joint.C0 = CFrame.new(0, -0.5, -0.55)
                * CFrame.Angles(math.rad(16 * math.sin(elapsed * 5)), 0, 0)
        end
        task.wait(0.3)
    end
    if wrench then wrench:Destroy() end
    npc:SetAttribute("RepairProgress", nil)
    local current = Jobs[job.Id]
    if current ~= job or job.Status ~= "InProgress" or owner.Parent ~= Players
        or not npc.Parent or not table.find(entry.Npcs, npc) or Staff[owner.UserId] ~= entry
        or not StaffAssignmentRules.IsReserved(entry.Busy, job.Id)
        or job.CollaboratorUserId ~= nil
        or (Repairs[owner.UserId] and Repairs[owner.UserId].JobId == job.Id) then
        release(nil)
        return
    end
    local basePrice = job.Price or service.Reward
    local quality = EquipmentUpgradeRules.EmployeeQuality(Config.EmployeeQuality, level)
    local price = math.floor(basePrice * RepairRules.PayMultiplier(quality)
        * EquipmentUpgradeRules.RewardMultiplier(level) + 0.5)
    local token = game:GetService("HttpService"):GenerateGUID(false)
    if not DataService.SettleNpcRepairOnce(owner, job.Id, token, price, defect.Parts,
        "Funcionário NPC: " .. service.DisplayName, job.VehicleName) then
        VehicleService.SetRepairing(job.Id, false)
        VehicleService.SetStage(job.Id, "Repair")
        job.EmployeeRetryAt = os.time() + 60
        release("O mecânico não conseguiu reservar peças e pagamento de " .. service.DisplayName .. ".")
        return
    end
    job.Status = "Completed" -- nenhuma reexecução de pagamento/peças depois deste ponto
    VehicleService.SetRepairing(job.Id, false)
    VehicleService.Flash(job.Id, Color3.fromRGB(90, 220, 130))
    VehicleService.Despawn(job.Id)
    DataService.AddReputation(owner, service.Reputation)
    local stars = rateService(owner, job, service, defect, nil, true, quality)
    DataService.AttachRepairReceipt(owner, job.Id, token, {
        JobId = job.Id, Token = token, Price = price, Quality = quality, Stars = stars,
    })
    WorkshopService.UpdateSkin(owner)
    release(nil)
    confirmNpcSave(owner, job.Id, token, string.format(
        "Seu mecânico concluiu %s: +%d moedas (%s).",
        service.DisplayName, price, CustomerRules.StarsText(stars)))
end

local function staffTick()
    for userId, entry in pairs(Staff) do
        local owner = Players:GetPlayerByUserId(userId)
        local profile = owner and DataService.Get(owner)
        if not owner or not profile then
            for _, npc in ipairs(entry.Npcs) do
                npc:Destroy()
            end
            Staff[userId] = nil
        else
            -- salário (o relógio só corre com alguém contratado)
            if #entry.Npcs == 0 then
                entry.NextPay = os.clock() + Config.PaydaySeconds
                profile.NextPayAt = 0
            elseif os.clock() >= entry.NextPay then
                entry.NextPay = os.clock() + Config.PaydaySeconds
                profile.NextPayAt = os.time() + Config.PaydaySeconds
                local bill = #entry.Npcs * Config.EmployeeSalary
                if profile.Coins >= bill then
                    DataService.AddCoins(owner, -bill, "Salário dos funcionários")
                    if eventSender then
                        eventSender(owner, "Notice", { Message = string.format("Salários pagos: -%d moedas.", bill), Success = true })
                    end
                else
                    DataService.SetEmployees(owner, math.max(0, (profile.Employees or 0) - 1))
                    syncStaff(owner)
                    if eventSender then
                        eventSender(owner, "Notice", { Message = "Sem moedas para o salário: um mecânico pediu demissão.", Success = false })
                    end
                end
            end
            -- trabalho: cada funcionário livre pega um carro estacionado sem ninguém trabalhando
            local working = 0
            for _ in pairs(entry.Busy) do
                working += 1
            end
            -- O proprietário tem 25 s para assumir a primeira ordem; depois disso o
            -- funcionário pode trabalhar mesmo com apenas um cliente esperando.
            -- Isso permite automatizar enquanto o dono cuida de estoque e expansão.
            -- A renda ainda requer carros, peças e pagamento de salário.
            local waiting = 0
            local oldestWait = 0
            for jobId, job in pairs(Jobs) do
                if job.OwnerUserId == userId and job.Status == "InProgress" and not entry.Busy[jobId] and not job.CollaboratorUserId
                    and VehicleService.IsParked(jobId) and not (Repairs[userId] and Repairs[userId].JobId == jobId)
                    and not (RepairPrepRules.Requires(job.DefectId) and (job.PreparationStep or 1) > 1) then
                    waiting += 1
                    oldestWait = math.max(oldestWait, os.time() - (job.AcceptedAt or os.time()))
                end
            end
            if working < #entry.Npcs and StaffAssignmentRules.ShouldDispatch(waiting, oldestWait) then
                for jobId, job in pairs(Jobs) do
                    if working >= #entry.Npcs then
                        break
                    end
                    if job.OwnerUserId == userId and job.Status == "InProgress" and not entry.Busy[jobId]
                        and not job.CollaboratorUserId and VehicleService.IsParked(jobId)
                        and not (Repairs[userId] and Repairs[userId].JobId == jobId)
                        and not (RepairPrepRules.Requires(job.DefectId) and (job.PreparationStep or 1) > 1)
                        and os.time() >= (job.EmployeeRetryAt or 0)
                        and StaffAssignmentRules.EligibleJob(waiting, os.time() - (job.AcceptedAt or os.time())) then
                        local free: Model? = nil
                        for _, npc in ipairs(entry.Npcs) do
                            if not npc:GetAttribute("Trabalhando") then
                                free = npc
                                break
                            end
                        end
                        if free and StaffAssignmentRules.TryReserve(entry.Busy, jobId) then
                            working += 1
                            local worker = free :: Model
                            worker:SetAttribute("Trabalhando", true)
                            task.spawn(function()
                                local ok, err = xpcall(function()
                                    employeeWork(owner, job, worker)
                                end, debug.traceback)
                                if not ok then
                                    warn("[WorkshopService] Mecânico NPC falhou:", jobId, err)
                                    StaffAssignmentRules.Release(entry.Busy, jobId)
                                    if Jobs[jobId] == job and job.Status == "InProgress" then
                                        VehicleService.SetRepairing(jobId, false)
                                        VehicleService.SetStage(jobId, "Repair")
                                    end
                                end
                                worker:SetAttribute("Trabalhando", nil)
                            end)
                        end
                    end
                end
            end
        end
    end
end

-- "Usar <equipamento>" na sala dos fundos: começa o reparo da ordem do jogador que precisa desta máquina.
-- "Usar <equipamento>": trabalhador convidado só pode usar a máquina localizada
-- no MESMO lote do dono da ordem atribuída a ele.
function WorkshopService.UseEquipment(player: Player, equipmentId: string, sourcePlot: Instance?)
    local equipment = Catalog.Equipment[equipmentId]
    if not equipment or equipmentId == "BasicToolset" then
        return false, "Equipamento inválido."
    end
    if not sourcePlot then
        return false, "Use uma máquina instalada no local da oficina."
    end
    local chosen: any = nil
    for _, job in pairs(Jobs) do
        if CollaborationRules.IsAuthorized(job, player.UserId) and job.Diagnosed
            and Catalog.Defects[job.DefectId].RequiredEquipment == equipmentId then
            local owner = Players:GetPlayerByUserId(job.OwnerUserId)
            if owner and PlotService.GetPlot(owner) == sourcePlot then
                if not chosen or (job.AcceptedAt or 0) < (chosen.AcceptedAt or 0) then
                    chosen = job
                end
            end
        end
    end
    if not chosen then
        return false, "Nenhuma ordem atribuída a você usa esta máquina nesta oficina."
    end
    return WorkshopService.StartRepair(player, chosen.Id, false)
end

-- Placa 3D e TV de ordens de cada oficina (e dos rivais), com a posição no ranking geral.
local function rankingEntries(): { any }
    local list: { any } = {}
    for userId, shop in pairs(Workshops) do
        local owner = Players:GetPlayerByUserId(userId)
        local p = owner and DataService.Get(owner)
        if p then
            table.insert(list, {
                Name = shop.Name,
                Reputation = p.Reputation,
                TotalEarned = p.TotalEarned or 0,
                Price = p.PriceMultiplier or 1,
                Level = Catalog.BusinessLevel(p.TotalEarned or 0),
                Rating = CustomerRules.AverageRating(p.RatingSum or 0, p.RatingCount or 0),
                RatingCount = p.RatingCount or 0,
                UserId = userId,
            })
        end
    end
    for _, entry in ipairs(RivalService.RankEntries()) do
        table.insert(list, entry)
    end
    return CustomerRules.Rank(list)
end

function refreshPlotDisplays()
    local ranked = rankingEntries()
    local rankByName: { [string]: number } = {}
    for i, entry in ipairs(ranked) do
        rankByName[entry.Name] = rankByName[entry.Name] or i
    end
    for userId, shop in pairs(Workshops) do
        local owner = Players:GetPlayerByUserId(userId)
        local p = owner and DataService.Get(owner)
        local plot = owner and PlotService.GetPlot(owner)
        if owner and p and plot then
            local tier, tierName = Catalog.WorkshopTier(p.TotalEarned or 0)
            local rank = rankByName[shop.Name]
            local badge = ProgressService.LeagueBadge(owner)
            local rankLine = rank == 1 and "🏆 A MELHOR OFICINA DO SERVIDOR" or (rank and string.format("#%d no servidor  ·  faturou %d", rank, p.TotalEarned or 0) or "")
            StationService.SetSign(plot, {
                Title = string.upper(tierName),
                Name = string.upper(shop.Name),
                Line1 = string.format("Nível %d  ·  ★ %.1f (%d avaliações)", Catalog.BusinessLevel(p.TotalEarned or 0),
                    CustomerRules.AverageRating(p.RatingSum or 0, p.RatingCount or 0), p.RatingCount or 0),
                Line2 = string.format("Clientes atendidos: %d  ·  Rep. %d", p.RatingCount or 0, p.Reputation or 0),
                Line3 = badge ~= "" and (badge .. (rankLine ~= "" and ("  ·  " .. rankLine) or "")) or rankLine,
                Color = tier >= 3 and Color3.fromRGB(255, 196, 70) or tier == 2 and Color3.fromRGB(70, 190, 255) or Color3.fromRGB(255, 196, 40),
            })
            local lines = {}
            local queue = {}
            for _, job in pairs(Jobs) do
                if job.OwnerUserId == userId and job.Status == "Available" and not CustomerArrivalService.IsArriving(job.Id) and os.time() >= (job.ArrivesAt or 0) then
                    table.insert(queue, {
                        Id = job.Id, Priority = job.Priority or 0,
                        WaitSeconds = math.max(0, os.time() - job.CreatedAt),
                        Customer = tostring(job.CustomerName), Vehicle = tostring(job.VehicleName),
                        ScheduledUntil = job.ScheduledUntil or 0,
                    })
                end
            end
            table.sort(queue, V2ReceptionRules.QueueLess)
            for index, line in ipairs(queue) do
                if index > 3 then break end
                local priorityText = line.Priority == 1 and "↑ " or (line.Priority == -1 and "↓ " or "")
                local scheduled = line.ScheduledUntil > os.time() and " (agendado)" or ""
                table.insert(lines, priorityText .. line.Customer .. " · " .. line.Vehicle .. scheduled)
            end
            local contract = ContractService.Snapshot(userId)
            if contract.Active then
                table.insert(lines, 1, string.format("📋 CONTRATO %s: %d/%d · %d:%02d", string.upper(contract.Name), contract.Done, contract.Target,
                    math.floor(contract.EndsIn / 60), contract.EndsIn % 60))
            end
            StationService.SetOrdersScreen(plot, #lines > 0 and (table.concat(lines, "\n") .. "\n\nAperte E para aceitar") or "Nenhum cliente esperando.")
        end
    end
    RivalService.RefreshSigns(function(name: string): number?
        return rankByName[name]
    end)
end
WorkshopService.RefreshPlotDisplays = refreshPlotDisplays
syncStaffRef = syncStaff
rankingEntriesRef = rankingEntries

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
            local receiptNow = os.clock()
            for userId, receipts in pairs(RepairReceipts) do
                RepairReceiptRules.Prune(receipts, receiptNow)
                if #receipts == 0 then RepairReceipts[userId] = nil end
            end
            for userId, settling in pairs(SettlingRepairs) do
                if receiptNow - settling.At > 900 then
                    -- Bloqueia nova OS até desconectar: um pagamento não confirmado não vira sucesso silenciosamente.
                    warn("[WorkshopService] Liquidação pendente há mais de 15 minutos:", settling.JobId, userId)
                    settling.At = receiptNow
                end
            end
            for userId, session in pairs(Repairs) do
                if not RepairSessionRules.IsActive(session, os.clock(), RepairRules.MaxSessionSeconds + 5) then
                    Repairs[userId] = nil -- sessão esquecida não prende a ordem
                    VehicleService.SetRepairing(session.JobId, false)
                end
            end
            for jobId, job in pairs(Jobs) do
                -- Cliente que não foi atendido vai embora; ordens concluídas antigas saem da memória.
                local age = os.time() - job.CreatedAt
                local owner = Players:GetPlayerByUserId(job.OwnerUserId)
                if job.Status == "Available" and age > Config.CustomerPatienceSeconds * (job.Regular and Config.RegularPatienceMultiplier or 1) then
                    Jobs[jobId] = nil
                    CustomerArrivalService.Depart(jobId)
                    if owner and eventSender then
                        eventSender(owner, "Notice", { Message = tostring(job.CustomerName) .. " cansou de esperar e foi embora." .. ((Combo[job.OwnerUserId] or 0) > 0 and " Seu combo zerou!" or ""), Success = false })
                    end
                    if owner then
                        breakCombo(job.OwnerUserId)
                    end
                elseif job.Status == "InProgress" and job.CollaboratorUserId and os.time() - (job.CollabAt or os.time()) > Config.CollabMaxSeconds
                    and not (Repairs[job.CollaboratorUserId]
                        and Repairs[job.CollaboratorUserId].JobId == jobId
                        and RepairSessionRules.IsActive(Repairs[job.CollaboratorUserId], os.clock(), RepairRules.MaxSessionSeconds)) then
                    -- Não retirar o trabalho de alguém no meio de um reparo válido.
                    local oldWorker = Players:GetPlayerByUserId(job.CollaboratorUserId)
                    if oldWorker and oldWorker:GetAttribute("CollaborationJobId") == jobId then
                        oldWorker:SetAttribute("CollaborationOwnerUserId", nil)
                        oldWorker:SetAttribute("CollaborationJobId", nil)
                        if eventSender then
                            eventSender(oldWorker, "Notice", { Message = "Prazo do contrato encerrado: a OS voltou ao proprietário.", Success = false })
                        end
                    end
                    job.CollaboratorUserId = nil
                    job.CollaborationSplitPercent = nil
                    job.CollabAt = nil
                    job.AssignedWorkerUserId = job.OwnerUserId
                    VehicleService.SetRepairActor(job.Id, job.OwnerUserId)
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

    -- Funcionários (salário e trabalho) e placas/TVs das oficinas.
    task.spawn(function()
        local n = 0
        while true do
            task.wait(2)
            n += 1
            staffTick()
            if n % 3 == 0 then
                refreshPlotDisplays()
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
