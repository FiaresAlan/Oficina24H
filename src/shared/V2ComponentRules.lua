--!strict
-- V2-03: estados dos oito componentes físicos dos três veículos piloto.
-- Não carrega defeitos secretos, preços, estoque ou dados persistentes.
-- O servidor decide autorização, posição, transição e se o carro pode sair.
local Rules = {}

Rules.MaxDistance = 8
Rules.HoldSeconds = 0.45
Rules.Components = {
    { Id = "Hood", Pivot = "V2Pivot_Hood", Label = "Capô", Kind = "Panel" },
    { Id = "DoorLeft", Pivot = "V2Pivot_DoorLeft", Label = "Porta esquerda", Kind = "Panel" },
    { Id = "DoorRight", Pivot = "V2Pivot_DoorRight", Label = "Porta direita", Kind = "Panel" },
    { Id = "Trunk", Pivot = "V2Pivot_Trunk", Label = "Porta-malas", Kind = "Panel" },
    { Id = "WheelFL", Pivot = "V2Pivot_WheelFL", Label = "Roda dianteira esquerda", Kind = "Wheel" },
    { Id = "WheelFR", Pivot = "V2Pivot_WheelFR", Label = "Roda dianteira direita", Kind = "Wheel" },
    { Id = "WheelRL", Pivot = "V2Pivot_WheelRL", Label = "Roda traseira esquerda", Kind = "Wheel" },
    { Id = "WheelRR", Pivot = "V2Pivot_WheelRR", Label = "Roda traseira direita", Kind = "Wheel" },
}
Rules.ById = {}
for _, component in ipairs(Rules.Components) do
    Rules.ById[component.Id] = component
end

function Rules.Attribute(componentId: any): string?
    if type(componentId) ~= "string" or not Rules.ById[componentId] then return nil end
    return "V2State_" .. componentId
end

function Rules.FromPrompt(name: any): string?
    if type(name) ~= "string" or string.sub(name, 1, 3) ~= "V2_" then return nil end
    local id = string.sub(name, 4)
    return Rules.ById[id] and id or nil
end

function Rules.Closed(id: any): string?
    local part = type(id) == "string" and Rules.ById[id]
    if not part then return nil end
    return part.Kind == "Wheel" and "Mounted" or "Closed"
end

function Rules.Open(id: any): string?
    local part = type(id) == "string" and Rules.ById[id]
    if not part then return nil end
    return part.Kind == "Wheel" and "Detached" or "Open"
end

function Rules.IsOpen(id: any, state: any): boolean
    return Rules.Open(id) ~= nil and state == Rules.Open(id)
end

function Rules.Action(id: any, state: any): string
    local part = type(id) == "string" and Rules.ById[id]
    if not part then return "" end
    if part.Kind == "Wheel" then
        return Rules.IsOpen(id, state) and "Recolocar roda" or "Retirar roda"
    end
    return Rules.IsOpen(id, state) and "Fechar" or "Abrir"
end

function Rules.IsNear(pivot: any, position: any, distance: any): boolean
    return typeof(pivot) == "Vector3" and typeof(position) == "Vector3"
        and type(distance) == "number" and distance == distance and distance >= 0
        and distance <= Rules.MaxDistance
        and (pivot - position).Magnitude <= distance
end

-- ctx tem APENAS valores verificados no servidor. Nenhuma ação altera a OS monetariamente.
export type Context = {
    Parked: boolean, Assigned: boolean, InProgress: boolean,
    Diagnosed: boolean, Repairing: boolean, WorkerBusy: boolean,
    WheelSupportReady: boolean, WheelSupportRequired: boolean,
    HoodLockedOpen: boolean,
}

function Rules.Next(id: any, current: any, ctx: Context): (string?, string)
    local part = type(id) == "string" and Rules.ById[id]
    if not part then return nil, "Componente inválido." end
    if not ctx.Parked or not ctx.InProgress then
        return nil, "Espere o veículo estacionar na oficina."
    end
    if not ctx.Assigned then return nil, "Você não está designado para esta ordem." end
    if ctx.Repairing or ctx.WorkerBusy then
        return nil, "Aguarde o mecânico concluir a operação em andamento."
    end
    local opened = Rules.IsOpen(id, current)
    if part.Kind == "Wheel" then
        if not ctx.Diagnosed then
            return nil, "Diagnostique o veículo antes de retirar rodas."
        end
        if not opened and ctx.WheelSupportRequired and not ctx.WheelSupportReady then
            return nil, "Solte as porcas e apoie o veículo no elevador antes de retirar a roda."
        end
    end
    if id == "Hood" and opened and ctx.HoodLockedOpen then
        return nil, "Conclua a preparação sob o capô antes de fechá-lo."
    end
    if opened then return Rules.Closed(id), "Componente recolocado/fechado." end
    return Rules.Open(id), "Componente liberado/aberto."
end

function Rules.ReadyToRepair(defectId: any, pilotId: any, states: any): (boolean, string)
    if type(pilotId) ~= "string" or type(states) ~= "table" then return true, "" end
    if defectId == "FlatTire" then
        if states.WheelFL == "Detached" then return true, "" end
        return false, "Retire a roda dianteira esquerda depois de apoiar o carro."
    end
    if defectId == "WeakBattery" or defectId == "Overheating" then
        if states.Hood == "Open" then return true, "" end
        return false, "Abra o capô antes de iniciar este reparo."
    end
    return true, ""
end

function Rules.MayDrive(states: any): boolean
    if type(states) ~= "table" then return true end
    for _, component in ipairs(Rules.Components) do
        if Rules.IsOpen(component.Id, states[component.Id]) then
            return false
        end
    end
    return true
end

return Rules
