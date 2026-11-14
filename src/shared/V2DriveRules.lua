--!strict
-- V2-11: contrato puro de test-drive PILOTO sem recompensas, sem Touched
-- do cliente, sem payload de steering/velocidade/posição.
local R = {}
R.PilotVehicle = "Hatch amarelo"
R.MaximumSeconds = 150
R.SeatGraceSeconds = 7
R.OutOfSeatGraceSeconds = 4
R.MaxSpeed = 54 -- studs/s; física é propriedade do servidor
R.MaxRadius = 260
R.MinHeight = -25
R.MaxHeight = 65
R.MaxTeleportSlack = 14
R.CrashSpeed = 16
R.CrashRayLength = 6
R.MaxDriveSessionsPerUser = 1
R.CheckpointRadius = 15
R.CheckpointMinInterval = 1.5
R.MotorAngularSpeed = 19 -- rad/s; raio da roda ~1.55 studs
R.MotorMaxTorque = 180000
R.SteerAngle = 27
R.SteerTorque = 90000

local function finite(v: any): boolean
    return type(v) == "number" and v == v
        and v ~= math.huge and v ~= -math.huge
end

function R.PilotEligible(vehicleName: any, pilotId: any): boolean
    return vehicleName == R.PilotVehicle and pilotId == "Hatch"
end

function R.CanLaunch(ctx: any): (boolean, string)
    if type(ctx) ~= "table" or ctx.Owner ~= true or ctx.Active ~= true then
        return false, "Somente o dono de uma OS em andamento pode dirigir este carro."
    end
    if not R.PilotEligible(ctx.VehicleName, ctx.PilotId) then
        return false, "V2-11: somente o Hatch piloto está liberado para condução."
    end
    if not ctx.Parked then return false, "Aguarde o cliente estacionar no box." end
    if ctx.Repairing or ctx.Delegated or ctx.EmployeeBusy then
        return false, "Encerre o trabalho ou a atribuição do mecânico antes de sair com o carro."
    end
    if not ctx.ComponentsClosed or ctx.SupportRaised then
        return false, "Feche portas e capô, recoloque todas as rodas e desça o elevador."
    end
    if not ctx.Near or not ctx.CharacterReady then
        return false, "Fique perto do veículo, com personagem ativo, para iniciar o test-drive."
    end
    if ctx.OtherSession or ctx.JobSession then
        return false, "Já existe um test-drive em andamento para esta OS ou jogador."
    end
    return true, ""
end

function R.PermittedOccupant(driverId: any, occupantPlayerId: any): boolean
    return type(driverId) == "number" and driverId > 0
        and occupantPlayerId == driverId
end

-- Aceita exclusivamente posição/velocidade OBSERVADAS no servidor.
-- prev/pos têm Vector3; elapsed medido com os.clock no Heartbeat.
function R.AssessMotion(origin: any, previous: any, position: any,
    velocity: any, elapsed: any): (boolean, string)
    if typeof(origin) ~= "Vector3" or typeof(previous) ~= "Vector3"
        or typeof(position) ~= "Vector3" or typeof(velocity) ~= "Vector3"
        or not finite(elapsed) or elapsed <= 0 then
        return false, "Telemetria inválida."
    end
    for _, v in ipairs({position.X,position.Y,position.Z,
        velocity.X,velocity.Y,velocity.Z}) do
        if not finite(v) then return false, "Posição/velocidade não finita." end
    end
    local horizontal=(Vector2.new(position.X-origin.X,position.Z-origin.Z)).Magnitude
    if horizontal > R.MaxRadius then return false, "Distância máxima da oficina excedida." end
    if position.Y < origin.Y + R.MinHeight or position.Y > origin.Y + R.MaxHeight then
        return false, "Desnível de condução inseguro."
    end
    if velocity.Magnitude > R.MaxSpeed then return false, "Velocidade fora do limite." end
    local moved=(position-previous).Magnitude
    if moved > elapsed * R.MaxSpeed + R.MaxTeleportSlack then
        return false, "Deslocamento instantâneo fora do limite."
    end
    return true, ""
end

function R.Controls(throttle: any, steer: any): (number, number)
    local gas=finite(throttle) and math.clamp(throttle,-1,1) or 0
    local turn=finite(steer) and math.clamp(steer,-1,1) or 0
    -- Ré limitada para manter controle, tecla S = freio antes de engatar ré.
    -- Pivô da roda no eixo +X: ω positivo deslocaria o carro em +Z,
    -- mas LookVector/frente é -Z. Inverter ambos motor e direção.
    return -(gas<0 and gas*0.45 or gas)*R.MotorAngularSpeed,
        -turn*R.SteerAngle
end

function R.CheckpointState(): any
    return {Index=1,Passed=0,LastAt=-math.huge,Done=false}
end

-- Marcadores 100% consultivos na V2-11. Em nenhuma fase esta função
-- retorna moedas/XP/prova de pagamento de reparo.
function R.Advance(state: any, checkpoints: any, at: any, position: any): (boolean, string)
    if type(state)~="table" or type(checkpoints)~="table"
        or not finite(at) or typeof(position)~="Vector3" then
        return false, "Amostra inválida."
    end
    if state.Done then return false, "Rota já verificada." end
    local target=checkpoints[state.Index]
    if typeof(target)~="Vector3" then return false, "Checkpoint ausente." end
    if at - (state.LastAt or 0) < R.CheckpointMinInterval then
        return false, "Aguarde passagem real entre checkpoints."
    end
    if (Vector2.new(target.X-position.X,target.Z-position.Z)).Magnitude
        > R.CheckpointRadius or math.abs(target.Y-position.Y)>12 then
        return false, "Fora da área do checkpoint."
    end
    state.Passed+=1
    state.Index+=1
    state.LastAt=at
    state.Done=state.Index>#checkpoints
    return true, state.Done and "Rota validada pelo servidor; sem recompensa nesta fase."
        or "Checkpoint validado pelo servidor."
end

return R
