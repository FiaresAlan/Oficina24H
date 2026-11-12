--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local JobRules = require(ReplicatedStorage.Shared.JobRules)
local CustomerRules = require(ReplicatedStorage.Shared.CustomerRules)
local RepairRules = require(ReplicatedStorage.Shared.RepairRules)
local DiagnosisRules = require(ReplicatedStorage.Shared.DiagnosisRules)
local DiagnosisEvidence = require(ReplicatedStorage.Shared.DiagnosisEvidence)
local WorkshopLevels = require(ReplicatedStorage.Shared.WorkshopLevels)

local WorkshopService = {}

local PlotService = require(script.Parent.PlotService)
local VehicleService = require(script.Parent.VehicleService)
local CustomerArrivalService = require(script.Parent.CustomerArrivalService)
local EquipmentService = require(script.Parent.EquipmentService)
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
        return true -- sem o prédio (ex.: testes no Edit) não bloqueia
    end
    if not hrp or not hrp:IsA("BasePart") then
        return false -- sem personagem (morto/respawn) não compra
    end
    local rel = shop.CFrame:PointToObjectSpace(hrp.Position)
    local half = shop.Size / 2
    local dx = math.max(math.abs(rel.X) - half.X, 0)
    local dz = math.max(math.abs(rel.Z) - half.Z, 0)
    return math.sqrt(dx * dx + dz * dz) <= Config.ShopDistance
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
local Repairs: { [number]: { JobId: string, Plan: any, StartedAt: number } } = {} -- sessões do minijogo, por jogador
-- Funcionários por dono: NPCs, ordens em que estão trabalhando e próximo pagamento de salário.
local Staff: { [number]: { Npcs: { Model }, Busy: { [string]: boolean }, NextPay: number } } = {}
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
local FUNNEL_STEPS = { Claimed = { 1, "Oficina registrada" }, Accepted = { 2, "Aceitou o 1º cliente" }, Diagnosed = { 3, "Diagnosticou" }, Repaired = { 4, "Concluiu o 1º reparo" } }
local function funnel(player: Player, key: string)
    local profile = DataService and DataService.Get(player)
    local step = FUNNEL_STEPS[key]
    if not profile or not step or (profile.Onboarding and profile.Onboarding.Done and key ~= "Repaired") then
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
                    WaitSeconds = os.time() - job.CreatedAt, -- tempo desde a chegada (a paciência acaba em PatienceSeconds)
                    PatienceSeconds = Config.CustomerPatienceSeconds * (job.Regular and Config.RegularPatienceMultiplier or 1),
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

    for _, entry in ipairs(RivalService.RankEntries()) do
        table.insert(ranking, entry)
    end
    return {
        Ranking = CustomerRules.Rank(ranking),
        Profile = profile,
        HasWorkshop = workshop ~= nil,
        Workshop = (workshop and profile) and upgradeInfoRef(player, profile) or nil,
        Progress = profile and ProgressService.Snapshot(player, profile) or nil,
        Contract = ContractService.Snapshot(player.UserId),
        WorkshopName = workshop and workshop.Name or nil,
        Jobs = jobs,
        CollabJobs = collabJobs,
        SkillLevels = skillLevels,
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
    VehicleService.Despawn(job.Id)
    Jobs[jobId] = nil
    DataService.AddReputation(player, -1)
    breakCombo(player.UserId)
    return true, "Ordem abandonada. -1 de reputação."
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
        sendDiagnosisOptions(player, job)
        return true, ""
    end

    -- Para os três casos-piloto, o cliente não pode resolver apenas escolhendo por sorte.
    if DiagnosisEvidence.RequiresExam(job.DefectId) and not DiagnosisEvidence.HasAnyExam(job.DiagnoseExams) then
        return false, "Faça pelo menos uma inspeção no carro antes de confirmar o diagnóstico."
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
    if not VehicleService.IsNear(player, job.Id, Config.InteractDistance) then
        return false, "Aproxime-se do carro para realizar a inspeção."
    end
    job.DiagnoseExams = job.DiagnoseExams or {}
    job.DiagnoseExams[examId] = true
    sendDiagnosisOptions(player, job)
    return true, ""
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
    local workshop = getWorkshop(player)
    local defect = Catalog.Defects[job.DefectId]
    local service = Catalog.Services[job.ServiceId]
    if not workshop or not ownsEquipment(workshop, defect.RequiredEquipment) then
        local equipment = Catalog.Equipment[defect.RequiredEquipment]
        return false, "Sua oficina não possui o equipamento necessário: " .. (equipment and equipment.DisplayName or defect.RequiredEquipment), nil, nil, nil
    end
    if not VehicleService.IsParked(job.Id) then
        return false, "Espere o carro estacionar no box.", nil, nil, nil
    end
    -- Ferramenta de mão: reparo no carro. Máquina: o jogador usa a máquina na sala dos fundos (prompt "Usar").
    if defect.RequiredEquipment == "BasicToolset" then
        if not VehicleService.IsNear(player, job.Id, Config.InteractDistance) then
            return false, "Aproxime-se do veículo para reparar.", nil, nil, nil
        end
    else
        local plot = PlotService.GetPlot(player)
        local pos = plot and EquipmentService.Position(plot, defect.RequiredEquipment)
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not pos or not hrp or not hrp:IsA("BasePart") or (hrp.Position - pos).Magnitude > 12 then
            return false, "Use o equipamento " .. Catalog.Equipment[defect.RequiredEquipment].DisplayName .. " na sala dos fundos da oficina.", nil, nil, nil
        end
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
    VehicleService.SetRepairing(job.Id, true) -- carro sobe no elevador / capô abre / pneu sai (efeitos no cliente)
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
    local session = Repairs[player.UserId]
    if session then
        VehicleService.SetRepairing(session.JobId, false)
    end
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
    VehicleService.SetRepairing(jobId, false)
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
    local combo = comboMultiplier(player.UserId)
    local friend = ProgressService.FriendMultiplier(player) -- jogando com amigo: +10%
    local price = math.floor(basePrice * RepairRules.PayMultiplier(result.Quality) * combo * friend + 0.5)
    if result.Quality >= COMBO_MIN_QUALITY then
        Combo[player.UserId] = (Combo[player.UserId] or 0) + 1
    else
        breakCombo(player.UserId)
    end
    local tip = RepairRules.Tip(basePrice, result.Quality)
    local xp = RepairRules.XPBonus(service.XP, result.Quality)
    DataService.AddCoins(player, price + tip, "Serviço: " .. service.DisplayName .. (tip > 0 and " (+gorjeta)" or ""))
    DataService.AddSkillXP(player, defect.Specialization, xp)
    DataService.AddReputation(player, service.Reputation)
    local stars = rateService(player, job, service, defect, player, false, result.Quality)
    ProgressService.Record(player, {
        Kind = "RepairDone", Amount = price + tip, Spec = defect.Specialization, Quality = result.Quality, Stars = stars,
        Vip = job.Vip == true, FirstTry = (job.DiagnoseAttempts or 1) <= 1, Rush = job.Rush == true or ProgressService.IsRush(),
    })
    local bonus = DataService.CompleteOnboarding(player, Config.OnboardingBonus)
    WorkshopService.UpdateSkin(player)
    if eventSender then
        eventSender(player, "RepairDone", {
            Bonus = bonus,
            Quality = result.Quality, Perfect = result.Perfect, Good = result.Good, Miss = result.Miss,
            Corrected = result.Corrected, Uncorrected = result.Uncorrected, Breakdown = result.Breakdown,
            Tip = tip, Price = price, XP = xp, Stars = stars, Combo = combo, NextCombo = comboMultiplier(player.UserId),
        })
    end
    funnel(player, "Repaired")
    return true, "Serviço concluído. +" .. tostring(price + tip) .. " moedas (qualidade " .. tostring(result.Quality) .. "%"
        .. (combo > 1 and string.format(", combo x%.1f", combo) or "") .. (friend > 1 and ", bônus de amigo" or "") .. "), +" .. tostring(xp)
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
    end
    for equipmentId in pairs(equipmentIds) do
        DataService.GrantEquipment(player, equipmentId)
        EquipmentService.Add(player, profile.Equipment, equipmentId)
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
    if not VehicleService.IsParked(job.Id) then
        return false, "Espere o carro estacionar no box."
    end
    -- reparo de máquina: o colaborador também precisa estar na máquina da sala dos fundos
    if defect.RequiredEquipment ~= "BasicToolset" then
        local plot = PlotService.GetPlot(owner)
        local pos = plot and EquipmentService.Position(plot, defect.RequiredEquipment)
        local character = worker.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not pos or not hrp or not hrp:IsA("BasePart") or (hrp.Position - pos).Magnitude > 12 then
            return false, "Use o equipamento " .. Catalog.Equipment[defect.RequiredEquipment].DisplayName .. " na sala dos fundos da oficina."
        end
    end

    local workerPercent = job.CollaborationSplitPercent or 25
    -- sem o minijogo, o serviço do colaborador vale como qualidade padrão (85%) e rende metade do XP
    local price = math.floor((job.Price or service.Reward) * RepairRules.PayMultiplier(85) + 0.5)
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
    DataService.AddSkillXP(worker, defect.Specialization, math.floor(service.XP / 2))
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
    if kind == "Accept" then
        return WorkshopService.AcceptJob(player, jobId) -- valida dono, status e chegada
    end
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
    Combo[userId] = nil
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
    StationService.ApplyLevel(plot, level + 1, player.DisplayName)
    EquipmentService.Sync(player, profile.Equipment)
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
    return (root * CFrame.new(-8 - index * 2.5, 0.4, 12)).Position -- área livre perto da prateleira, longe dos boxes
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
        return false, "Funcionários só a partir do Centro automotivo (4 boxes). Amplie na Construtora."
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

-- O funcionário pega um carro estacionado ainda não atendido: diagnostica, sobe no elevador e conserta sozinho.
local function employeeWork(owner: Player, job: any, npc: Model)
    local entry = Staff[owner.UserId]
    entry.Busy[job.Id] = true
    local defect = Catalog.Defects[job.DefectId]
    local service = Catalog.Services[job.ServiceId]
    local workshop = getWorkshop(owner)
    local function release(message: string?)
        entry.Busy[job.Id] = nil
        local plot = PlotService.GetPlot(owner)
        local spot = plot and staffSpot(plot, table.find(entry.Npcs, npc) or 1)
        if npc.Parent and spot then
            NpcKit.Place(npc, spot, spot + Vector3.new(0, 0, 1))
            NpcKit.ServerOwned(npc)
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
        NpcKit.Place(npc, Vector3.new(spot.X, carRoot.Position.Y, spot.Z), carRoot.Position)
        NpcKit.ServerOwned(npc)
    end
    job.Diagnosed = true
    VehicleService.SetStage(job.Id, "None")
    VehicleService.SetSymptom(job.Id, defectSymptom(job.DefectId))
    VehicleService.SetRepairing(job.Id, true)
    task.wait(Config.EmployeeWorkSeconds)
    local current = Jobs[job.Id]
    if current ~= job or job.Status ~= "InProgress" or not owner.Parent then
        release(nil)
        return
    end
    if not DataService.TakeParts(owner, defect.Parts) then
        VehicleService.SetRepairing(job.Id, false)
        VehicleService.SetStage(job.Id, "Repair")
        job.EmployeeRetryAt = os.time() + 60
        release("Faltaram peças para o mecânico terminar " .. service.DisplayName .. ".")
        return
    end
    job.Status = "Completed"
    VehicleService.SetRepairing(job.Id, false)
    VehicleService.Flash(job.Id, Color3.fromRGB(90, 220, 130))
    VehicleService.Despawn(job.Id)
    local basePrice = job.Price or service.Reward
    local price = math.floor(basePrice * RepairRules.PayMultiplier(Config.EmployeeQuality) + 0.5)
    DataService.AddCoins(owner, price, "Serviço do funcionário: " .. service.DisplayName)
    DataService.AddReputation(owner, service.Reputation)
    local stars = rateService(owner, job, service, defect, nil, true, Config.EmployeeQuality)
    WorkshopService.UpdateSkin(owner)
    release(nil)
    if eventSender then
        eventSender(owner, "Notice", { Message = string.format("Seu mecânico concluiu %s: +%d moedas (%s).", service.DisplayName, price, CustomerRules.StarsText(stars)), Success = true })
    end
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
            -- Equilíbrio: o funcionário só pega um carro quando há pelo menos 2 esperando atendimento (sobra um para o
            -- jogador). Assim a equipe ajuda a dar conta do movimento, mas não joga sozinha.
            local waiting = 0
            for jobId, job in pairs(Jobs) do
                if job.OwnerUserId == userId and job.Status == "InProgress" and not entry.Busy[jobId] and not job.CollaboratorUserId
                    and VehicleService.IsParked(jobId) and not (Repairs[userId] and Repairs[userId].JobId == jobId) then
                    waiting += 1
                end
            end
            if working < #entry.Npcs and waiting >= 2 then
                for jobId, job in pairs(Jobs) do
                    if working >= #entry.Npcs then
                        break
                    end
                    if job.OwnerUserId == userId and job.Status == "InProgress" and not entry.Busy[jobId]
                        and not job.CollaboratorUserId and VehicleService.IsParked(jobId)
                        and not (Repairs[userId] and Repairs[userId].JobId == jobId)
                        and os.time() >= (job.EmployeeRetryAt or 0) then
                        local free: Model? = nil
                        for _, npc in ipairs(entry.Npcs) do
                            if not npc:GetAttribute("Trabalhando") then
                                free = npc
                                break
                            end
                        end
                        if free then
                            working += 1
                            local worker = free :: Model
                            worker:SetAttribute("Trabalhando", true)
                            task.spawn(function()
                                employeeWork(owner, job, worker)
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
function WorkshopService.UseEquipment(player: Player, equipmentId: string)
    local chosen: any = nil
    for _, job in pairs(Jobs) do
        if job.OwnerUserId == player.UserId and job.Status == "InProgress" and job.AssignedWorkerUserId == player.UserId
            and Catalog.Defects[job.DefectId].RequiredEquipment == equipmentId then
            if job.Diagnosed and (not chosen or (job.AcceptedAt or 0) < (chosen.AcceptedAt or 0)) then
                chosen = job
            end
        end
    end
    if not chosen then
        return false, "Nenhum carro diagnosticado precisa de " .. Catalog.Equipment[equipmentId].DisplayName .. " agora."
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
            for _, job in pairs(Jobs) do
                if job.OwnerUserId == userId and job.Status == "Available" and not CustomerArrivalService.IsArriving(job.Id) and os.time() >= (job.ArrivesAt or 0) then
                    table.insert(lines, string.format("%s%s · %s", job.Vip and "★ " or (job.Fleet and "📋 " or ""), tostring(job.CustomerName), tostring(job.VehicleName)))
                end
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
            for userId, session in pairs(Repairs) do
                if os.clock() - session.StartedAt > RepairRules.MaxSessionSeconds + 5 then
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
