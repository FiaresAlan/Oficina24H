--!strict
-- V2-11: um veículo Hatch PILOTO fisicamente dirigível associado à OS.
-- O carro original permanece reservado no box; seu clone física é
-- descartável, servidor dono da simulação, sem pagar, diagnosticar ou
-- completar OS por colisão/Touched/remoto.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local Rules=require(ReplicatedStorage.Shared.V2DriveRules)
local Safety=require(ReplicatedStorage.Shared.AssetSafetyRules)
local Catalog=require(ReplicatedStorage.Shared.Catalog)
local VehicleService=require(script.Parent.VehicleService)
local PlotService=require(script.Parent.PlotService)
local LotPath=require(script.Parent.LotPath)
local WorkshopLevels=require(ReplicatedStorage.Shared.WorkshopLevels)

local Service={}
local sessions: {[string]: any}={}
local byDriver: {[number]: string}={}
local heartbeat: RBXScriptConnection?=nil

local function part(parent: Instance,name: string,size: Vector3,cf: CFrame,
    color: Color3,collide: boolean,transparent: number?): Part
    local p=Instance.new("Part")
    p.Name=name
    p.Size=size
    p.CFrame=cf
    p.Color=color
    p.Material=Enum.Material.Metal
    p.Anchored=false
    p.CanCollide=collide
    p.CanQuery=collide
    p.CanTouch=false
    p.Transparency=transparent or 0
    p.Parent=parent
    return p
end

local function attachment(parent: BasePart,name: string,at: Vector3,
    axis: Vector3,secondary: Vector3): Attachment
    local a=Instance.new("Attachment")
    a.Name=name
    a.Position=at
    a.Axis=axis
    a.SecondaryAxis=secondary
    a.Parent=parent
    return a
end

local function weld(part0: BasePart,part1: BasePart)
    local w=Instance.new("WeldConstraint")
    w.Name="DriveWeld"
    w.Part0=part0
    w.Part1=part1
    w.Parent=part0
end

local function folder(): Folder
    local current=workspace:FindFirstChild("V2DriveCars")
    if current and current:IsA("Folder") then return current end
    local f=Instance.new("Folder")
    f.Name="V2DriveCars"
    f.Parent=workspace
    return f
end

local function visualShell(rig: Model,car: Model,chassis: BasePart)
    local assets=ServerStorage:FindFirstChild("Assets")
    local vehicles=assets and assets:FindFirstChild("Veiculos")
    local modelName=Catalog.VehicleModels[Rules.PilotVehicle]
    local template=vehicles and modelName and vehicles:FindFirstChild(modelName)
    local made=false
    if template and template:IsA("Model") and template.Archivable then
        local model=template:Clone()
        Safety.StripScripts(model)
        local parts={}
        for _,node in ipairs(model:GetDescendants()) do
            if node:IsA("BasePart") then
                table.insert(parts,node)
            elseif node:IsA("ProximityPrompt")
                or node:IsA("Seat") or node:IsA("VehicleSeat")
                or node:IsA("Constraint") or node:IsA("JointInstance") then
                node:Destroy()
            end
        end
        -- Limite físico mesmo diante de asset enorme do Creator Store:
        -- não gerar dezenas de massas/juntas no carro piloto.
        if #parts>0 and #parts<=95 then
            model.Name="VisualSanitizado"
            model:PivotTo(chassis.CFrame*CFrame.new(0,-3.3,0))
            for _,p in ipairs(parts) do
                if p.Parent and p:IsDescendantOf(model) then
                    p.Anchored=false
                    p.CanCollide=false
                    p.CanTouch=false
                    p.CanQuery=false
                    p.Massless=true
                    if p.Name=="Casco" then p.Transparency=1 end
                    weld(chassis,p)
                end
            end
            model.Parent=rig
            made=true
        else
            model:Destroy()
        end
    end
    if not made then
        local body=part(rig,"Carroceria",Vector3.new(6.5,2.3,12.5),
            chassis.CFrame*CFrame.new(0,0.5,0),Color3.fromRGB(245,178,52),false)
        body.Massless=true
        weld(chassis,body)
        local cabin=part(rig,"Cabine",Vector3.new(5.4,2,5.7),
            chassis.CFrame*CFrame.new(0,2.2,0.7),Color3.fromRGB(205,152,66),false)
        cabin.Massless=true
        weld(chassis,cabin)
        local wind=part(rig,"ParaBrisa",Vector3.new(5.5,1.4,.15),
            chassis.CFrame*CFrame.new(0,2.2,-2.2),Color3.fromRGB(115,185,225),false,0.3)
        wind.Massless=true
        wind.Material=Enum.Material.Glass
        weld(chassis,wind)
    end
end

-- O módulo VehicleSeat produz ThrottleFloat/SteerFloat com teclado,
-- gamepad e direção de tela móvel. HingeConstraint real move rodas.
local function buildRig(car: Model,owner: Player,jobId: string): (Model,VehicleSeat,BasePart,{any},{any})
    local originalRoot=car.PrimaryPart :: BasePart
    local cf=originalRoot.CFrame*CFrame.new(0,3.3,0)
    local rig=Instance.new("Model")
    rig.Name="V2Drive_"..jobId
    rig:SetAttribute("V2Drive",true)
    rig:SetAttribute("OwnerUserId",owner.UserId)
    rig:SetAttribute("JobId",jobId)
    rig:SetAttribute("Checkpoints",0)
    rig:SetAttribute("MaxSeconds",Rules.MaximumSeconds)
    local chassis=part(rig,"DriveChassis",Vector3.new(6.1,1.3,10.8),
        cf,Color3.fromRGB(36,40,47),true)
    chassis.CustomPhysicalProperties=PhysicalProperties.new(1.2,1.1,0.1,100,100)
    rig.PrimaryPart=chassis
    local seat=Instance.new("VehicleSeat")
    seat.Name="PilotVehicleSeat"
    seat:SetAttribute("V2DriveSeat",true)
    seat.Size=Vector3.new(2,0.8,2)
    seat.CFrame=cf*CFrame.new(-1.2,1.45,0.45)
    seat.Transparency=0.35
    seat.Color=Color3.fromRGB(45,54,68)
    seat.MaxSpeed=Rules.MaxSpeed
    seat.Torque=0 -- os motores são controlados pelo SERVIDOR
    seat.TurnSpeed=0
    seat.Anchored=false
    seat.CanCollide=false
    seat.CanTouch=false
    seat.Parent=rig
    weld(chassis,seat)
    local motors={}
    local steering={}
    for _,side in ipairs({-1,1}) do
        for _,axle in ipairs({-1,1}) do
            -- Frente do carro: -Z em relação ao LookVector da Raiz.
            local x,z=side*3.1,axle*4.1
            local localPos=Vector3.new(x,-1.75,z)
            local knuckle=part(rig,
                "CubodeRoda_"..side.."_"..axle,
                Vector3.new(.35,.35,.35),cf*CFrame.new(localPos),
                Color3.fromRGB(65,65,65),false,1)
            knuckle.Massless=false
            knuckle.CustomPhysicalProperties=PhysicalProperties.new(0.25,0.8,0.1,100,100)
            if axle<0 then
                local frameAttachment=attachment(chassis,"ServoPivot",localPos,
                    Vector3.yAxis,Vector3.zAxis)
                local hubAttachment=attachment(knuckle,"ServoPivot",
                    Vector3.zero,Vector3.yAxis,Vector3.zAxis)
                local servo=Instance.new("HingeConstraint")
                servo.Name="Direcao"
                servo.Attachment0=frameAttachment
                servo.Attachment1=hubAttachment
                servo.ActuatorType=Enum.ActuatorType.Servo
                servo.LimitsEnabled=true
                servo.LowerAngle=-Rules.SteerAngle
                servo.UpperAngle=Rules.SteerAngle
                servo.TargetAngle=0
                servo.AngularSpeed=2.6
                servo.ServoMaxTorque=Rules.SteerTorque
                servo.Parent=rig
                table.insert(steering,servo)
            else
                weld(chassis,knuckle)
            end
            local wheel=part(rig,"RodaFisica_"..side.."_"..axle,
                Vector3.new(1.2,3.1,3.1),cf*CFrame.new(localPos),
                Color3.fromRGB(24,27,30),true)
            wheel.Shape=Enum.PartType.Cylinder
            wheel.CustomPhysicalProperties=PhysicalProperties.new(0.85,1.9,0,100,100)
            local shaft=attachment(knuckle,"Eixo",
                Vector3.zero,Vector3.xAxis,Vector3.yAxis)
            local rotor=attachment(wheel,"Eixo",
                Vector3.zero,Vector3.xAxis,Vector3.yAxis)
            local hinge=Instance.new("HingeConstraint")
            hinge.Name="MotorRoda"
            hinge.Attachment0=shaft
            hinge.Attachment1=rotor
            hinge.ActuatorType=Enum.ActuatorType.Motor
            hinge.MotorMaxTorque=Rules.MotorMaxTorque
            hinge.MotorMaxAcceleration=90
            hinge.AngularVelocity=0
            hinge.Parent=rig
            table.insert(motors,hinge)
        end
    end
    visualShell(rig,car,chassis)
    rig.Parent=folder()
    -- Nunca conceder network ownership ao motorista nem aos outros clientes.
    for _,node in ipairs(rig:GetDescendants()) do
        if node:IsA("BasePart") then
            pcall(function() node:SetNetworkOwner(nil) end)
        end
    end
    return rig,seat,chassis,motors,steering
end

local function checkpointsOf(frame: CFrame,bay: BasePart): {Vector3}
    local localBay=frame:PointToObjectSpace(bay.Position)
    local points={
        Vector2.new(WorkshopLevels.GateOut,WorkshopLevels.ExitRowZ),
        Vector2.new(WorkshopLevels.GateOut+28,LotPath.LaneZ),
        Vector2.new(WorkshopLevels.GateIn,LotPath.CurbZ),
        Vector2.new(localBay.X,localBay.Z),
    }
    local out={}
    for _,p in ipairs(points) do
        table.insert(out,LotPath.Ground(frame,p.X,p.Y))
    end
    return out
end

local function marker(parent: Model,at: Vector3,index: number)
    local p=Instance.new("Part")
    p.Name="Checkpoint_"..index
    p.Shape=Enum.PartType.Cylinder
    p.Size=Vector3.new(.22,11,11)
    p.CFrame=CFrame.new(at+Vector3.new(0,.18,0))*CFrame.Angles(0,0,math.pi/2)
    p.Material=Enum.Material.Neon
    p.Color=Color3.fromRGB(73,187,235)
    p.Transparency=.65
    p.Anchored=true
    p.CanCollide=false
    p.CanTouch=false
    p.CanQuery=false
    p.Parent=parent
end

local function hideMarkers(session:any)
    if session.Markers then session.Markers:Destroy() end
    session.Markers=nil
end

local function clear(jobId: string,reason: string,notify: boolean)
    local s=sessions[jobId]
    if not s then return end
    sessions[jobId]=nil
    if byDriver[s.OwnerId]==jobId then byDriver[s.OwnerId]=nil end
    if s.Died then s.Died:Disconnect() end
    if s.OccupantChanged then s.OccupantChanged:Disconnect() end
    hideMarkers(s)
    for _,motor in ipairs(s.Motors) do motor.AngularVelocity=0 end
    if s.Seat.Parent then s.Seat.Disabled=true end
    local character=s.Player.Character
    local hum=character and character:FindFirstChildOfClass("Humanoid")
    if hum and s.Seat.Occupant==hum then
        hum.Sit=false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    if s.Rig.Parent then s.Rig:Destroy() end
    -- Restaurar o carro de OS sem alterar Job.Status, peças, danos ou pagamento.
    VehicleService.ResumeFromDrive(jobId)
    if character and character.Parent and s.OriginalRoot and s.OriginalRoot.Parent
        and character.PrimaryPart then
        character:PivotTo(s.OriginalRoot.CFrame*CFrame.new(-8,4,0))
    end
    if notify and s.Player.Parent==Players then
        local r=Service.Notify
        if r then r(s.Player,reason,false) end
    end
end

Service.Notify=nil :: ((Player,string,boolean)->())?

function Service.SetNotifier(callback: (Player,string,boolean)->())
    Service.Notify=callback
end

function Service.CancelJob(jobId: string,reason: string?)
    clear(jobId,reason or "Test-drive encerrado; veículo recolocado no box.",true)
end

function Service.CancelPlayer(userId: number)
    local jobId=byDriver[userId]
    if jobId then clear(jobId,"Sessão encerrada pela saída do motorista.",false) end
end

function Service.Status(jobId: string): any
    local s=sessions[jobId]
    if not s then return {Active=false,Available=true,Stage="Parado",Passed=0,Total=4} end
    return {Active=true,Available=false,Stage=s.Progress.Done and "Rota conferida" or "Dirigindo",
        Passed=s.Progress.Passed,Total=#s.Checkpoints,
        SecondsRemaining=math.max(0,math.floor(Rules.MaximumSeconds-(os.clock()-s.StartAt)))}
end

function Service.BusyFor(userId: number): boolean
    return byDriver[userId]~=nil
end
function Service.BusyJob(jobId: string): boolean
    return sessions[jobId]~=nil
end

function Service.Start(player: Player,jobId: string): (boolean,string)
    if sessions[jobId] or byDriver[player.UserId] then
        return false,"Já há uma sessão de direção ativa."
    end
    local car,bay=VehicleService.DriveInfo(jobId)
    if not car or not bay or not Rules.PilotEligible(Rules.PilotVehicle,
        car:GetAttribute("V2PilotId")) then
        return false,"O carro piloto não está estacionado para dirigir."
    end
    local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health<=0 or humanoid.Sit then
        return false,"Seu personagem não está livre para assumir o volante."
    end
    local plot=PlotService.GetPlot(player)
    local frame=plot and LotPath.Frame(plot)
    if not frame or not plot or plot:GetAttribute("OwnerUserId")~=player.UserId
        or car:GetAttribute("OwnerUserId")~=player.UserId then
        return false,"Carro/terreno de outro jogador."
    end
    local source,realBay,message=VehicleService.SuspendForDrive(jobId,player.UserId)
    if not source or not realBay then return false,message end
    local ok,rig,seat,chassis,motors,steering=pcall(buildRig,source,player,jobId)
    if not ok then
        VehicleService.ResumeFromDrive(jobId)
        warn("[V2DriveService] Falha na montagem física:",rig)
        return false,"Falha na montagem do carro; box restaurado."
    end
    local activeRig=rig :: Model
    local activeSeat=seat :: VehicleSeat
    local main=chassis :: BasePart
    local route=checkpointsOf(frame,realBay)
    local markers=Instance.new("Model")
    markers.Name="V2DriveCheckpoints_"..jobId
    for i,p in ipairs(route) do marker(markers,p,i) end
    markers.Parent=folder()
    local session={
        Rig=activeRig,Seat=activeSeat,Chassis=main,Player=player,
        OwnerId=player.UserId,JobId=jobId,OriginalRoot=source.PrimaryPart,
        Motors=motors,Steering=steering,Markers=markers,
        StartAt=os.clock(),LastAt=os.clock(),Previous=main.Position,
        Origin=main.Position,Checkpoints=route,Progress=Rules.CheckpointState(),
        SeatLostAt=nil,SeatAcquired=false,Accum=0,DriverHumanoid=humanoid,
        InputAt=-math.huge,InputThrottle=0,InputSteer=0,LastInputRequest=-math.huge,
    }
    sessions[jobId]=session
    byDriver[player.UserId]=jobId
    -- Qualquer pessoa que consiga tocar no VehicleSeat alheio será expulsa.
    session.OccupantChanged=activeSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
        local current=activeSeat.Occupant
        if current then
            local character=current.Parent
            local seatedPlayer=character and Players:GetPlayerFromCharacter(character)
            if not Rules.PermittedOccupant(player.UserId,seatedPlayer and seatedPlayer.UserId) then
                current.Sit=false
                current:ChangeState(Enum.HumanoidStateType.GettingUp)
                return
            end
            session.SeatAcquired=true
            session.SeatLostAt=nil
        elseif session.SeatAcquired then
            session.SeatLostAt=os.clock()
        end
    end)
    session.Died=humanoid.Died:Connect(function()
        clear(jobId,"Motorista caiu ou morreu. Veículo devolvido ao box.",true)
    end)
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        root.CFrame=activeSeat.CFrame*CFrame.new(0,3,0)
    end
    activeSeat:Sit(humanoid)
    return true,"Test-drive iniciado. WASD/setas, controle ou toque: dirija; Backspace/B para voltar ao box. Sem recompensa na V2-11."
end

-- Somente intenção de aceleração/direção chega do cliente: não há
-- posição, velocidade, recompensa ou autoridade de checkpoint no remoto.
function Service.Input(player: Player,jobId: any,throttle: any,steer: any)
    if type(jobId)~="string" or #jobId>80 then return end
    local s=sessions[jobId]
    if not s or s.OwnerId~=player.UserId or s.Seat.Occupant~=s.DriverHumanoid then return end
    local now=os.clock()
    if now-s.LastInputRequest<0.07 then return end -- limite 14 Hz
    s.LastInputRequest=now
    if type(throttle)~="number" or type(steer)~="number"
        or throttle~=throttle or steer~=steer
        or throttle==math.huge or steer==math.huge
        or throttle==-math.huge or steer==-math.huge
        or math.abs(throttle)>1.001 or math.abs(steer)>1.001 then return end
    s.InputThrottle=throttle
    s.InputSteer=steer
    s.InputAt=now
end

function Service.End(player: Player,jobId: string): (boolean,string)
    local session=sessions[jobId]
    if not session or session.OwnerId~=player.UserId then
        return false,"Sessão inexistente ou pertencente a outro motorista."
    end
    local passed=session.Progress.Passed
    clear(jobId,"",false)
    return true,string.format("Carro devolvido ao box. Checkpoints verificados pelo servidor: %d/4. Sem pagamento nesta fase.",passed)
end

local function sample(s: any,now: number): string?
    local root=s.Chassis
    if not root.Parent or not s.Rig.Parent then return "Veículo removido." end
    local t=now-s.LastAt
    local position=root.Position
    local velocity=root.AssemblyLinearVelocity
    local legal,why=Rules.AssessMotion(s.Origin,s.Previous,position,velocity,t)
    if not legal then return why end
    s.LastAt=now
    s.Previous=position
    local got,message=Rules.Advance(s.Progress,s.Checkpoints,now,position)
    if got then
        s.Rig:SetAttribute("Checkpoints",s.Progress.Passed)
        if s.Progress.Done then
            s.Rig:SetAttribute("RouteDone",true)
        end
    end
    -- Colisão apenas de geometria sólida observada pelo servidor.
    -- Ignore NPC/pessoas e a própria carcaça; nunca usar Touched para pagar.
    if now-s.StartAt>3 and velocity.Magnitude>Rules.CrashSpeed then
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        local excluded={s.Rig}
        local original=s.OriginalRoot and s.OriginalRoot.Parent
        if original then table.insert(excluded,original) end
        if s.Player.Character then table.insert(excluded,s.Player.Character) end
        params.FilterDescendantsInstances=excluded
        params.IgnoreWater=true
        local direction=root.CFrame.LookVector*Rules.CrashRayLength
        local hit=workspace:Raycast(root.Position+root.CFrame.LookVector*5,direction,params)
        if hit and hit.Instance and hit.Instance.CanCollide then
            return "Obstáculo à frente: veículo recolhido por segurança."
        end
    end
    if now-s.StartAt>3 and root.CFrame.UpVector.Y<0.2 then
        return "Carro capotado: retorno de segurança ao box."
    end
    return nil
end

function Service.StartHeartbeat()
    if heartbeat then return end
    heartbeat=RunService.Heartbeat:Connect(function(dt)
        local now=os.clock()
        for jobId,s in pairs(sessions) do
            local invalid: string?=nil
            if s.Player.Parent~=Players or not s.DriverHumanoid.Parent
                or s.DriverHumanoid.Health<=0 then
                invalid="Motorista indisponível."
            elseif now-s.StartAt>Rules.MaximumSeconds then
                invalid="Limite do test-drive atingido."
            else
                local occupant=s.Seat.Occupant
                if occupant and occupant~=s.DriverHumanoid then
                    occupant.Sit=false
                elseif occupant~=s.DriverHumanoid then
                    if (not s.SeatAcquired and now-s.StartAt>Rules.SeatGraceSeconds)
                        or (s.SeatLostAt and now-s.SeatLostAt>Rules.OutOfSeatGraceSeconds) then
                        invalid="Motorista saiu do assento ou não conseguiu sentar."
                    end
                end
            end
            if invalid then
                clear(jobId,invalid,true)
            else
                local occupant=s.Seat.Occupant
                local speed,angle=0,0
                if occupant==s.DriverHumanoid and now-s.InputAt<0.35 then
                    speed,angle=Rules.Controls(s.InputThrottle,s.InputSteer)
                end
                for _,motor in ipairs(s.Motors) do motor.AngularVelocity=speed end
                for _,servo in ipairs(s.Steering) do servo.TargetAngle=angle end
                s.Accum+=dt
                if s.Accum>=0.10 then
                    s.Accum=0
                    local problem=sample(s,now)
                    if problem then clear(jobId,problem,true) end
                end
            end
        end
    end)
end

function Service._buildRigForTesting(car: Model,owner: any,jobId: string)
    if not RunService:IsStudio() then return nil end
    return buildRig(car,owner,jobId)
end

return Service
