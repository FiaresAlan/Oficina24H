--!strict
local Catalog = {}

Catalog.Specializations = {
    "Tires",
    "Engine",
    "Electrical",
    "Suspension",
    "Bodywork",
}

Catalog.SkillXPPerLevel = 100

-- Nível empresarial derivado do total ganho (cresce devagar: raiz quadrada). Só leitura; usado para exibição e regras futuras.
function Catalog.BusinessLevel(totalEarned: number): number
    return math.floor(math.sqrt(math.max(0, totalEarned) / 100)) + 1
end

-- Progresso dentro do nível empresarial: (nível, total ganho, total do início do nível, total que leva ao próximo).
-- BusinessLevel(total) = floor(sqrt(total/100)) + 1, logo o nível N começa em (N-1)^2*100 e o próximo em N^2*100.
function Catalog.BusinessProgress(totalEarned: number): (number, number, number, number)
    local total = math.max(0, totalEarned)
    local level = Catalog.BusinessLevel(total)
    return level, total, (level - 1) ^ 2 * 100, level ^ 2 * 100
end

Catalog.Equipment = {
    BasicToolset = { DisplayName = "Kit de ferramentas", Cost = 0 },
    Jack = { DisplayName = "Macaco hidráulico", Cost = 100 },
    TireMachine = { DisplayName = "Desmontadora de pneus", Cost = 350 },
    Scanner = { DisplayName = "Scanner automotivo", Cost = 500 },
    EngineBench = { DisplayName = "Bancada de motor", Cost = 900 },
    ElectricalBench = { DisplayName = "Bancada elétrica", Cost = 650 },
    SuspensionLift = { DisplayName = "Elevador de suspensão", Cost = 750 },
    Balancer = { DisplayName = "Balanceadora de rodas", Cost = 450 },
    Compressor = { DisplayName = "Compressor de ar", Cost = 550 },
    BodyworkKit = { DisplayName = "Kit de funilaria", Cost = 600 },
    AlignmentRig = { DisplayName = "Equipamento de alinhamento", Cost = 800 },
}

Catalog.Defects = {
    FlatTire = {
        DisplayName = "Pneu furado",
        Specialization = "Tires",
        RequiredLevel = 1,
        RequiredEquipment = "BasicToolset",
        Complaint = "O pneu está perdendo pressão.",
        ServiceId = "RepairTire",
    },
    WornTire = {
        DisplayName = "Pneu desgastado",
        Specialization = "Tires",
        RequiredLevel = 2,
        RequiredEquipment = "TireMachine",
        Complaint = "O carro está vibrando em velocidade.",
        ServiceId = "ReplaceTire",
    },
    WeakBattery = {
        DisplayName = "Bateria fraca",
        Specialization = "Electrical",
        RequiredLevel = 1,
        RequiredEquipment = "BasicToolset",
        Complaint = "O veículo está demorando para ligar.",
        ServiceId = "ReplaceBattery",
    },
    LooseSuspension = {
        DisplayName = "Componente de suspensão solto",
        Specialization = "Suspension",
        RequiredLevel = 2,
        RequiredEquipment = "Jack",
        Complaint = "Há um ruído ao passar por irregularidades.",
        ServiceId = "RepairSuspension",
    },
    EngineMisfire = {
        DisplayName = "Falha de ignição",
        Specialization = "Engine",
        RequiredLevel = 3,
        RequiredEquipment = "Scanner",
        Complaint = "O motor está falhando.",
        ServiceId = "DiagnoseEngine",
    },
    ElectricalFault = {
        DisplayName = "Falha elétrica",
        Specialization = "Electrical",
        RequiredLevel = 4,
        RequiredEquipment = "ElectricalBench",
        Complaint = "Alguns componentes elétricos pararam.",
        ServiceId = "RepairElectrical",
    },
    Dent = {
        DisplayName = "Amassado na lataria",
        Specialization = "Bodywork",
        RequiredLevel = 1,
        RequiredEquipment = "BasicToolset",
        Complaint = "Há um amassado na porta.",
        ServiceId = "RepairDent",
    },
    BodyDamage = {
        DisplayName = "Colisão na carroceria",
        Specialization = "Bodywork",
        RequiredLevel = 3,
        RequiredEquipment = "BodyworkKit",
        Complaint = "O carro bateu e a lataria está torta.",
        ServiceId = "RepairBody",
    },
    PaintJob = {
        DisplayName = "Pintura danificada",
        Specialization = "Bodywork",
        RequiredLevel = 4,
        RequiredEquipment = "Compressor",
        Complaint = "A pintura está descascando.",
        ServiceId = "RepaintCar",
    },
    WheelImbalance = {
        DisplayName = "Rodas desbalanceadas",
        Specialization = "Tires",
        RequiredLevel = 3,
        RequiredEquipment = "Balancer",
        Complaint = "O volante treme em velocidade.",
        ServiceId = "BalanceWheels",
    },
    Misalignment = {
        DisplayName = "Alinhamento fora de ponto",
        Specialization = "Suspension",
        RequiredLevel = 3,
        RequiredEquipment = "AlignmentRig",
        Complaint = "O carro puxa para um lado.",
        ServiceId = "AlignWheels",
    },
    BrakeWear = {
        DisplayName = "Pastilhas de freio gastas",
        Specialization = "Suspension",
        RequiredLevel = 1,
        RequiredEquipment = "Jack",
        Complaint = "Os freios estão rangendo.",
        ServiceId = "ReplaceBrakes",
    },
    BrokenArm = {
        DisplayName = "Braço de suspensão quebrado",
        Specialization = "Suspension",
        RequiredLevel = 4,
        RequiredEquipment = "SuspensionLift",
        Complaint = "O carro está mais baixo de um lado.",
        ServiceId = "ReplaceArm",
    },
    EngineOverhaul = {
        DisplayName = "Retífica de motor",
        Specialization = "Engine",
        RequiredLevel = 5,
        RequiredEquipment = "EngineBench",
        Complaint = "Falta de força e fumaça escura.",
        ServiceId = "OverhaulEngine",
    },
    Overheating = {
        DisplayName = "Superaquecimento do motor",
        Specialization = "Engine",
        RequiredLevel = 1, -- rota inicial do Motor (sem serviço de nível 1 o XP da especialização nunca começaria)
        RequiredEquipment = "BasicToolset",
        Complaint = "O motor está esquentando demais.",
        ServiceId = "FixCooling",
    },
}

Catalog.Services = {
    RepairTire = {
        DisplayName = "Reparar pneu",
        DefectId = "FlatTire",
        Reward = 90,
        XP = 25,
        Reputation = 2,
    },
    ReplaceTire = {
        DisplayName = "Trocar pneus",
        DefectId = "WornTire",
        Reward = 180,
        XP = 40,
        Reputation = 3,
    },
    ReplaceBattery = {
        DisplayName = "Substituir bateria",
        DefectId = "WeakBattery",
        Reward = 120,
        XP = 30,
        Reputation = 2,
    },
    RepairSuspension = {
        DisplayName = "Reparar suspensão",
        DefectId = "LooseSuspension",
        Reward = 220,
        XP = 50,
        Reputation = 4,
    },
    DiagnoseEngine = {
        DisplayName = "Diagnosticar motor",
        DefectId = "EngineMisfire",
        Reward = 300,
        XP = 65,
        Reputation = 5,
    },
    RepairElectrical = {
        DisplayName = "Reparar sistema elétrico",
        DefectId = "ElectricalFault",
        Reward = 260,
        XP = 55,
        Reputation = 4,
    },
    RepairDent = { DisplayName = "Reparar amassado", DefectId = "Dent", Reward = 80, XP = 22, Reputation = 1 },
    RepairBody = { DisplayName = "Reparar carroceria", DefectId = "BodyDamage", Reward = 280, XP = 60, Reputation = 4 },
    RepaintCar = { DisplayName = "Repintar veículo", DefectId = "PaintJob", Reward = 340, XP = 70, Reputation = 5 },
    BalanceWheels = { DisplayName = "Balancear rodas", DefectId = "WheelImbalance", Reward = 160, XP = 38, Reputation = 2 },
    AlignWheels = { DisplayName = "Alinhar direção", DefectId = "Misalignment", Reward = 210, XP = 48, Reputation = 3 },
    ReplaceBrakes = { DisplayName = "Trocar pastilhas de freio", DefectId = "BrakeWear", Reward = 150, XP = 34, Reputation = 2 },
    ReplaceArm = { DisplayName = "Trocar braço de suspensão", DefectId = "BrokenArm", Reward = 320, XP = 62, Reputation = 4 },
    OverhaulEngine = { DisplayName = "Retificar motor", DefectId = "EngineOverhaul", Reward = 460, XP = 90, Reputation = 6 },
    FixCooling = { DisplayName = "Reparar arrefecimento", DefectId = "Overheating", Reward = 190, XP = 42, Reputation = 3 },
}

-- Peças consumíveis: cada serviço gasta peças do estoque da oficina (comprado na loja de peças).
Catalog.Parts = {
    TirePatch = { DisplayName = "Remendo de pneu", Cost = 10 },
    Tire = { DisplayName = "Pneu novo", Cost = 30 },
    Battery = { DisplayName = "Bateria", Cost = 55 },
    SuspensionKit = { DisplayName = "Kit de suspensão", Cost = 35 },
    SparkPlug = { DisplayName = "Vela de ignição", Cost = 15 },
    Fuse = { DisplayName = "Fusível", Cost = 8 },
    FillerPutty = { DisplayName = "Massa de funilaria", Cost = 10 },
    BodyPanel = { DisplayName = "Painel de lataria", Cost = 80 },
    PaintCan = { DisplayName = "Lata de tinta", Cost = 45 },
    WheelWeight = { DisplayName = "Peso de balanceamento", Cost = 6 },
    BrakePad = { DisplayName = "Pastilha de freio", Cost = 25 },
    Coolant = { DisplayName = "Fluido de arrefecimento", Cost = 12 },
    SuspensionArm = { DisplayName = "Braço de suspensão", Cost = 70 },
    EngineKit = { DisplayName = "Kit de retífica", Cost = 150 },
}
Catalog.MaxPartPurchase = 20 -- por compra

-- Peças consumidas por defeito (a cobrança vem do estoque do dono da oficina). Alinhamento não gasta peças.
local defectParts = {
    FlatTire = { TirePatch = 1 },
    WornTire = { Tire = 2 },
    WeakBattery = { Battery = 1 },
    LooseSuspension = { SuspensionKit = 1 },
    EngineMisfire = { SparkPlug = 2 },
    ElectricalFault = { Fuse = 2 },
    Dent = { FillerPutty = 1 },
    BodyDamage = { BodyPanel = 1 },
    PaintJob = { PaintCan = 2 },
    WheelImbalance = { WheelWeight = 1 },
    BrakeWear = { BrakePad = 1 },
    Overheating = { Coolant = 1 },
    BrokenArm = { SuspensionArm = 1 },
    EngineOverhaul = { EngineKit = 1 },
}
for defectId, parts in pairs(defectParts) do
    if Catalog.Defects[defectId] then
        Catalog.Defects[defectId].Parts = parts
    end
end

-- Categorias de produto DERIVADAS do catálogo (nada cadastrado à mão): uma peça pertence à especialização dos serviços
-- que a consomem; um equipamento, à especialização dos serviços que o exigem (mais de uma = "Misc").
Catalog.CategoryOrder = { "Engine", "Suspension", "Electrical", "Tires", "Bodywork", "Misc" }
Catalog.PartCategory = {} :: { [string]: string }
Catalog.EquipmentCategory = {} :: { [string]: string }
do
    local function assign(target: { [string]: string }, id: string, specialization: string)
        local current = target[id]
        if current == nil then
            target[id] = specialization
        elseif current ~= specialization then
            target[id] = "Misc"
        end
    end
    for _, defect in pairs(Catalog.Defects) do
        for partId in pairs(defect.Parts or {}) do
            assign(Catalog.PartCategory, partId, defect.Specialization)
        end
        if defect.RequiredEquipment then
            assign(Catalog.EquipmentCategory, defect.RequiredEquipment, defect.Specialization)
        end
    end
    for partId in pairs(Catalog.Parts) do
        Catalog.PartCategory[partId] = Catalog.PartCategory[partId] or "Misc"
    end
    for equipmentId in pairs(Catalog.Equipment) do
        Catalog.EquipmentCategory[equipmentId] = Catalog.EquipmentCategory[equipmentId] or "Misc"
    end
end

-- Fatores de qualidade do reparo (ver shared/RepairRules): eficiência do equipamento (0 a 4) e confiabilidade da peça
-- (1 = neutra; remendo e massa < 1; kits e braço novos > 1). Faixas de peça (Econômica/Padrão/Premium) ficam para depois.
Catalog.EquipmentEfficiency = {
    BasicToolset = 0, Jack = 1, TireMachine = 2, Scanner = 2, Balancer = 2, Compressor = 2, BodyworkKit = 2,
    EngineBench = 3, ElectricalBench = 3, SuspensionLift = 3, AlignmentRig = 4,
} :: { [string]: number }
Catalog.PartReliability = {
    TirePatch = 0.90, FillerPutty = 0.92, Fuse = 0.97, WheelWeight = 0.97, BodyPanel = 1.03, SuspensionArm = 1.04, EngineKit = 1.05,
} :: { [string]: number }

-- Média da confiabilidade das peças que um defeito consome (peças sem valor contam como 1).
function Catalog.AveragePartReliability(parts: { [string]: number }?): number
    local sum, count = 0, 0
    for partId in pairs(parts or {}) do
        sum += Catalog.PartReliability[partId] or 1
        count += 1
    end
    return count > 0 and sum / count or 1
end

Catalog.CustomerNames = { "Marcos", "Ana", "Carlos", "Beatriz", "João", "Luiza", "Pedro", "Camila", "Rafael", "Fernanda", "Tiago", "Juliana" }

-- Nome exibido do veículo -> modelo em ServerStorage.Assets.Veiculos (usado pelo VehicleService e pelas miniaturas 3D).
-- Não há picape nos assets disponíveis; o compacto serve de substituto (limitação registrada em docs/PROGRESSO.md).
Catalog.VehicleModels = {
    ["Hatch compacto"] = "Veiculo_Hatch",
    ["Sedã urbano"] = "Veiculo_Sedan",
    ["Picape leve"] = "Veiculo_Compacto",
} :: { [string]: string }

Catalog.VehicleNames = {
    "Hatch compacto",
    "Sedã urbano",
    "Picape leve",
}

return Catalog
