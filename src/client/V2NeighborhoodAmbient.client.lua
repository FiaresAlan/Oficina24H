--!strict
-- V2-07: vida de bairro exclusivamente VISUAL e local.
-- Reaproveita carros 3D e avatares aprovados. Sem física, ordens, remotes,
-- estoque, saldo, pathfinding no servidor ou clones que bloqueiem o tráfego.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local Rules=require(ReplicatedStorage.Shared.V2NeighborhoodRules)
local Budget=require(ReplicatedStorage.Shared.V2VisualBudgetRules)
local Store=require(script.Parent.UI.Store)
local Animations=require(ReplicatedStorage.Shared.NpcAnimations)
local player=Players.LocalPlayer
local ambient=Instance.new("Folder")
ambient.Name="V2NeighborhoodAmbient"
ambient.Parent=Workspace

type Actor={
    Model: Model,
    Kind: string,
    FootHeight: number,
    Track: AnimationTrack?,
    Route: any,
    Offset: number,
    Started: number,
    LastProgress: number,
    LastGroundAt: number,
    GroundY: number,
    StalledUntil: number,
}
local live: {[string]: Actor}={}
local pool: {[string]: {Actor}}={Vehicle={},Pedestrian={}}
local cooldown: {[string]: number}={}
local templates: {[string]: {Model}}={Vehicle={},Pedestrian={}}
local fps=58
local tickAccumulator=0
local lastRefresh=-math.huge
local deliveryUntil=0
local courierStart=0
local deliveryNumber=0
local selectedRoutes: {[string]: any}={}
local frozen=false

local function safeTemplates()
    local previews=ReplicatedStorage:FindFirstChild("VehiclePreviews")
    local pedestrians=ReplicatedStorage:FindFirstChild("V2PedestrianPreviews")
    local vehicles={}
    if previews then
        for _,name in ipairs({
            "Veiculo_Hatch_MG3","Veiculo_Sedan_Civic","Veiculo_Picape_S10",
            "Veiculo_SUV_RAV4","Veiculo_Hatch_AE86",
        }) do
            local item=previews:FindFirstChild(name)
            if item and item:IsA("Model") and item.PrimaryPart then
                table.insert(vehicles,item)
            end
        end
    end
    local walkers={}
    for _,item in ipairs(pedestrians and pedestrians:GetChildren() or {}) do
        if item:IsA("Model") and item.PrimaryPart then table.insert(walkers,item) end
    end
    table.sort(walkers,function(a,b)return a.Name<b.Name end)
    templates.Vehicle=vehicles
    templates.Pedestrian=walkers
end

local function footprint(model: Model): number
    local box,size=model:GetBoundingBox()
    return math.clamp(model:GetPivot().Position.Y-(box.Position.Y-size.Y/2),0,12)
end

local function initModel(model: Model,kind: string)
    -- Ancoragem só no cliente; rig de caminhada continua podendo animar.
    local root=model.PrimaryPart
    for _,item in ipairs(model:GetDescendants()) do
        if item:IsA("ProximityPrompt") or item:IsA("ClickDetector") then
            item:Destroy()
        elseif item:IsA("BasePart") then
            item.CanCollide=false
            item.CanTouch=false
            item.CanQuery=false
            item.Massless=true
            item.CastShadow=false
            item.Anchored=(kind=="Vehicle" or item==root)
        elseif item:IsA("ParticleEmitter") or item:IsA("Trail")
            or item:IsA("Beam") then
            item.Enabled=false
        elseif item:IsA("PointLight") or item:IsA("SpotLight")
            or item:IsA("SurfaceLight") then
            item.Enabled=false
        end
    end
    model:SetAttribute("V2AmbientOnly",true)
    if root and root:IsA("BasePart") then root.Anchored=true end
end

local function animate(npc: Model): AnimationTrack?
    local humanoid=npc:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    local animator=humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator=Instance.new("Animator")
        animator.Parent=humanoid
    end
    local anim=Instance.new("Animation")
    anim.AnimationId=Animations.Walk
    local ok,track=pcall(function()
        return animator:LoadAnimation(anim)
    end)
    anim:Destroy()
    if ok and track then
        track.Looped=true
        track.Priority=Enum.AnimationPriority.Movement
        return track
    end
    return nil
end

local function create(kind: string,seed: number): Actor?
    safeTemplates()
    local list=templates[kind]
    if not list or #list==0 then return nil end
    local source=list[(seed%#list)+1]
    if not Budget.PreflightTemplate(source,"Ambient") then return nil end
    local model=source:Clone()
    model.Name="V2Ambient_"..kind
    local root=model.PrimaryPart
    if not root then model:Destroy();return nil end
    initModel(model,kind)
    local actor: Actor={
        Model=model,Kind=kind,FootHeight=footprint(model),
        Track=kind=="Pedestrian" and animate(model) or nil,
        Route=nil,Offset=0,Started=0,LastProgress=0,LastGroundAt=-math.huge,
        GroundY=0.6,StalledUntil=0,
    }
    return actor
end

local function acquire(kind: string,seed: number): Actor?
    local reserve=pool[kind]
    local actor=reserve and table.remove(reserve)
    if not actor then actor=create(kind,seed) end
    if actor then actor.Model.Parent=ambient end
    return actor
end

local function totalPooled(): number
    local total=0
    for _,reserve in pairs(pool) do total+=#reserve end
    return total
end

local function release(id: string,untilAt: number?)
    local actor=live[id]
    if not actor then return end
    live[id]=nil
    if untilAt then cooldown[id]=untilAt end
    if actor.Track then pcall(function() actor.Track:Stop(0.12) end) end
    actor.Model.Parent=nil
    local reserve=pool[actor.Kind]
    if reserve and totalPooled()<Rules.MaxPooled then
        table.insert(reserve,actor)
    else
        actor.Model:Destroy()
    end
end

local function findRoot(): Vector3?
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then return root.Position end
    return nil
end

local function ground(position: Vector3,model: Model): number
    local ignored={ambient}
    local list={"Vehicles","Arrivals","RivalVehicles"}
    for _,name in ipairs(list) do
        local f=Workspace:FindFirstChild(name)
        if f then table.insert(ignored,f) end
    end
    if player.Character then table.insert(ignored,player.Character) end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=ignored
    params.IgnoreWater=true
    local hit=Workspace:Raycast(
        Vector3.new(position.X,15,position.Z),
        Vector3.new(0,-38,0),params)
    if hit then return math.clamp(hit.Position.Y,-5,8) end
    return 0.8
end

local function vehicleConflict(point: Vector3): boolean
    -- Não copiar as rotas reais de atendimento da V1 nem sobrepor carros
    -- estacionados em vagas do meio-fio; ambiente cede a preferência.
    for _,name in ipairs({"Vehicles","Arrivals","RivalVehicles"}) do
        local f=Workspace:FindFirstChild(name)
        if f then
            for _,m in ipairs(f:GetChildren()) do
                if m:IsA("Model") and m.PrimaryPart then
                    local p=m.PrimaryPart.Position
                    local d=Vector3.new(p.X-point.X,0,p.Z-point.Z).Magnitude
                    if d<17 then return true end
                end
            end
        end
    end
    return false
end

local function routeOffset(route: any,focus: Vector3,now: number): number
    local start,finish=route.From,route.To
    local length=Rules.Length(route)
    local tangent=(finish-start)/length
    local projection=math.clamp(
        (Vector3.new(focus.X,0,focus.Z)-start):Dot(tangent),0,length)
    local behind=route.Kind=="Vehicle" and 46 or 24
    return math.clamp(projection-behind,0,math.max(0,length-4))
end

local function spawn(route: any,focus: Vector3,now: number)
    if live[route.Id] or now<(cooldown[route.Id] or 0) then return end
    local kind=route.Kind=="Courier" and "Pedestrian" or route.Kind
    local count=0
    for _ in pairs(live) do count+=1 end
    if count>=Rules.MaxActive then return end
    local actor=acquire(kind,#route.Id+math.floor(now/27))
    if not actor then
        cooldown[route.Id]=now+12
        return
    end
    actor.Route=route
    actor.Offset=route.Kind=="Courier" and 0 or routeOffset(route,focus,now)
    actor.Started=now
    actor.LastGroundAt=-math.huge
    actor.LastProgress=actor.Offset
    live[route.Id]=actor
    if actor.Track then pcall(function() actor.Track:Play(0.15) end) end
end

local function setFrame(actor: Actor,now: number,focus: Vector3,range: number)
    local route=actor.Route
    local elapsed=math.max(0,now-actor.Started)
    local progress=elapsed*route.Speed+actor.Offset
    local length=Rules.Length(route)
    if progress>=length then
        release(route.Id,now+9)
        return
    end
    local point,forward=Rules.Position(route,elapsed,actor.Offset)
    if not point or not forward then release(route.Id,now+8);return end
    local dis=Vector3.new(focus.X-point.X,0,focus.Z-point.Z).Magnitude
    if dis>range+42 then release(route.Id,now+5);return end
    if now-actor.LastGroundAt>2 then
        actor.GroundY=ground(point,actor.Model)
        actor.LastGroundAt=now
    end
    -- Via pública apenas visual, sem colisão; se houver um carro V1,
    -- o ator ambiente desaparece em vez de atravessar a OS verdadeira.
    local model=actor.Model
    if actor.Kind=="Vehicle" and vehicleConflict(point) then
        if model.Parent then model.Parent=nil end
        return
    end
    if not model.Parent then model.Parent=ambient end
    local pivotPos=Vector3.new(point.X,actor.GroundY+actor.FootHeight,point.Z)
    model:PivotTo(CFrame.lookAt(pivotPos,pivotPos+forward))
end

local function refresh(now: number,focus: Vector3,budget: any)
    local routes=Rules.Select(focus,budget)
    selectedRoutes={}
    for _,route in ipairs(routes) do selectedRoutes[route.Id]=route end
    local courierActive=now<deliveryUntil and Rules.Distance(Rules.Courier,focus)<budget.Range
    if courierActive then selectedRoutes[Rules.Courier.Id]=Rules.Courier end
    for id in pairs(live) do
        if selectedRoutes[id]==nil then release(id,now+3) end
    end
    if courierActive and live[Rules.Courier.Id]==nil then
        -- Um evento confirmado (compra REAL de peças) tem preferência sobre
        -- qualquer figurante. Nunca ultrapassa o teto global de malhas.
        local count,worstId,farthest=0,nil,-1
        for id,actor in pairs(live) do
            count+=1
            if id~=Rules.Courier.Id then
                local distance=Rules.Distance(actor.Route,focus)
                if distance>farthest then farthest=distance;worstId=id end
            end
        end
        if count>=Rules.MaxActive and worstId then
            release(worstId,now+4)
        end
        spawn(Rules.Courier,focus,now)
    end
    for _,route in ipairs(routes) do spawn(route,focus,now) end
    -- Métricas só no clone local (QA mobile/streaming, sem remotes ou dados
    -- pessoais). Não medem FPS de GPU, mas permitem conferir o orçamento.
    local pedestrians,vehicles=0,0
    for _,actor in pairs(live) do
        if actor.Kind=="Pedestrian" then pedestrians+=1 else vehicles+=1 end
    end
    ambient:SetAttribute("V2ActivePedestrians",pedestrians)
    ambient:SetAttribute("V2ActiveVehicles",vehicles)
    ambient:SetAttribute("V2PooledModels",totalPooled())
    ambient:SetAttribute("V2EstimatedFps",math.floor(fps+0.5))
    ambient:SetAttribute("V2DrawDistance",budget.Range)
end

local actionEvent=ReplicatedStorage:WaitForChild("OficinaRemotes",30)
actionEvent=actionEvent and actionEvent:WaitForChild("Action",10)
if actionEvent and actionEvent:IsA("RemoteEvent") then
    actionEvent.OnClientEvent:Connect(function(kind: any,payload: any)
        if kind~="V2NeighborhoodCourier" or type(payload)~="table"
            or type(payload.PartCount)~="number" or payload.PartCount<=0 then return end
        local now=os.clock()
        deliveryUntil=now+Rules.DeliverySeconds
        courierStart=now
        deliveryNumber+=1
        if live[Rules.Courier.Id] then release(Rules.Courier.Id) end
        cooldown[Rules.Courier.Id]=nil
    end)
end

RunService.Heartbeat:Connect(function(dt: number)
    if frozen then return end
    if dt>0 and dt<2 then fps=fps*0.94+(1/dt)*0.06 end
    local userProfile=Store.Snapshot and Store.Snapshot.Profile
    local preferences=userProfile and userProfile.Accessibility
    local lowDetail=type(preferences)=="table" and preferences.LowDetail==true
    local budget=Rules.Budget(UserInputService.TouchEnabled,fps,
        #Players:GetPlayers(),lowDetail)
    tickAccumulator+=math.clamp(dt,0,0.25)
    if tickAccumulator<budget.Tick then return end
    tickAccumulator=0
    local camera=Workspace.CurrentCamera
    local focus=camera and camera.CFrame.Position or findRoot()
    if not focus then return end
    local now=os.clock()
    if now-lastRefresh>=Rules.RefreshSeconds then
        lastRefresh=now
        refresh(now,focus,budget)
    end
    for _,actor in pairs(live) do
        setFrame(actor,now,focus,budget.Range)
    end
end)

player.AncestryChanged:Connect(function(_,parent: Instance?)
    if parent~=nil then return end
    frozen=true
    for id in pairs(live) do release(id) end
    for _,reserve in pairs(pool) do
        for _,actor in ipairs(reserve) do actor.Model:Destroy() end
        table.clear(reserve)
    end
    ambient:Destroy()
end)
