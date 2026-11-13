--!strict
-- V2-09/10: um carro em restauração e até dois carros de showroom, todos
-- decorativos e sem colisão, física, NPC, créditos ou ocupação de bays da V1.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Safety = require(ReplicatedStorage.Shared.AssetSafetyRules)
local UsedRules = require(ReplicatedStorage.Shared.V2UsedMarketRules)
local Visual = require(ReplicatedStorage.Shared.V2ShowroomVisual)
local PlotService = require(script.Parent.PlotService)
local StationService = require(script.Parent.StationService)

local Display = {}
local active: { [number]: Model } = {}
local showcases: { [number]: {Model} } = {}

local function shape(parent: Instance, name: string, size: Vector3,
    cf: CFrame, color: Color3): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = Enum.Material.Metal
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Parent = parent
    return p
end

local function showText(parent: Instance, labelText: string)
    local gui = Instance.new("BillboardGui")
    gui.Name = "UsedVehicleLabel"
    gui.Size = UDim2.fromOffset(350, 94)
    gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
    gui.AlwaysOnTop = false
    gui.MaxDistance = 70
    local label = Instance.new("TextLabel")
    label.Name = "Status"
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 17
    label.TextWrapped = true
    label.TextColor3 = Color3.fromRGB(246, 249, 252)
    label.BackgroundColor3 = Color3.fromRGB(21, 29, 41)
    label.BackgroundTransparency = 0.1
    label.Text = labelText
    label.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 9)
    corner.Parent = label
    gui.Parent = parent
end

local function createVehicle(parent: Model, offer: any, car: any,
    frame: CFrame, x: number, z: number): Model
    local item = Instance.new("Model")
    item.Name = "VeiculoDeRevenda"
    local assets = ServerStorage:FindFirstChild("Assets")
    local vehicles = assets and assets:FindFirstChild("Veiculos")
    local modelName = Catalog.VehicleModels[offer.VehicleName]
    local source = vehicles and modelName and vehicles:FindFirstChild(modelName)
    local displayFrame = frame * CFrame.new(x, 0.8, z) * CFrame.Angles(0, math.pi, 0)
    if source and source:IsA("Model") and source.Archivable
        and source:FindFirstChildWhichIsA("BasePart",true) then
        local clone = source:Clone()
        Safety.StripScripts(clone)
        for _, piece in ipairs(clone:GetDescendants()) do
            if piece:IsA("BasePart") then
                piece.Anchored = true
                piece.CanCollide = false
                piece.CanTouch = false
                piece.CanQuery = false
                piece.CastShadow = false
                if piece.Name == "Casco" then piece.Transparency = 1 end
            end
        end
        Visual.Apply(clone,car)
        local bounds,size = clone:GetBoundingBox()
        if size.X > 0 and size.Y > 0 and size.Z > 0 then
            local offset = clone:GetPivot():ToObjectSpace(bounds)
            clone:PivotTo(displayFrame*CFrame.new(0,size.Y/2,0)*offset:Inverse())
        end
        clone.Parent = item
    else
        -- Fallback não colidível caso o modelo 3D ainda não tenha sido importado.
        local tint = Color3.fromRGB(105, 93, 75)
        local body = shape(item,"Carroceria",Vector3.new(8,2.5,15),
            displayFrame*CFrame.new(0,2.4,0),tint)
        local cabin = shape(item,"Cabine",Vector3.new(7,2.7,7),
            displayFrame*CFrame.new(0,4.7,0.6),tint)
        for _, xx in ipairs({-3.9,3.9}) do
            for _, zz in ipairs({-4.3,4.3}) do
                local tire = shape(item,"Pneu",Vector3.new(1.5,2.8,2.8),
                    displayFrame*CFrame.new(xx,1.65,zz),Color3.fromRGB(27,28,30))
                tire.Shape=Enum.PartType.Cylinder
                local rim = shape(item,"Aro",Vector3.new(0.2,1.5,1.5),
                    displayFrame*CFrame.new(xx+(xx>0 and 0.82 or -0.82),1.65,zz),
                    Color3.fromRGB(155,160,170))
                rim.Shape=Enum.PartType.Cylinder
            end
        end
        -- Mesma transformação para fallback e asset real.
        local appearance = {Stage=car.Stage,Style=car.Style,
            Finish=car.Finish,Wheels=car.Wheels}
        local _ = {body,cabin}
        Visual.Apply(item,appearance)
    end
    item.Parent = parent
    return item
end

local function createDisplay(player: Player, plot: Instance, frame: CFrame,
    car: any, x: number, z: number, exhibit: boolean, slot: number,
    callback: (Player,string,string)->()): Model
    local offer = UsedRules.Offers[car.Variant]
    local model = Instance.new("Model")
    model.Name = exhibit and ("V2ShowroomBay"..tostring(slot)) or "V2UsedMarketDisplay"
    model:SetAttribute("OwnerUserId",player.UserId)
    model:SetAttribute("MarketUid",car.Uid)
    model:SetAttribute("MarketStage",car.Stage)
    model:SetAttribute("Exhibit",exhibit)
    model:SetAttribute("ShowroomSlot",exhibit and slot or 0)
    local plate = shape(model,"PisoRevenda",
        Vector3.new(15,0.3,exhibit and 17 or 24),
        frame*CFrame.new(x,0.18,z),Color3.fromRGB(45,50,58))
    plate.Material = Enum.Material.Concrete
    local stand = shape(model,"PontoRevenda",Vector3.new(5,2,1),
        frame*CFrame.new(x,1.2,z+(exhibit and 9 or 13)),
        Color3.fromRGB(35,47,65))
    local stages = {
        Purchased = "INSPECIONAR", Inspected = "DESMONTAR",
        Stripped = "RESTAURAR", Restored = "VENDER",
    }
    local operation = exhibit and "Recall"
        or ({Purchased="Inspect",Inspected="Strip",
            Stripped="Restore",Restored="Sell"})[car.Stage]
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "PromptRevenda"
    prompt.ActionText = exhibit and "RETIRAR DA EXPOSIÇÃO" or (stages[car.Stage] or "VER DETALHES")
    prompt.ObjectText = offer.Name
    prompt.HoldDuration = 0.45
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Style = Enum.ProximityPromptStyle.Default
    prompt.Parent = stand
    prompt.Triggered:Connect(function(actor: Player)
        if actor.UserId ~= player.UserId or plot:GetAttribute("OwnerUserId") ~= player.UserId
            or not operation then return end
        callback(actor,operation,car.Uid)
    end)
    local text = exhibit and "SHOWROOM "..tostring(slot) or "RESTAURAÇÃO"
    showText(stand,text.."\n"..offer.Name.." · "..car.Stage)
    createVehicle(model,offer,car,frame,x,z)
    model.Parent=plot
    return model
end

function Display.Clear(playerId: number)
    local old=active[playerId]
    active[playerId]=nil
    if old then old:Destroy() end
    local list=showcases[playerId]
    showcases[playerId]=nil
    for _, model in ipairs(list or {}) do model:Destroy() end
end

-- Sync recria somente as três posições permitidas, sem afetar o carro das OS.
function Display.Sync(player: Player,profile: any,
    callback: (Player,string,string)->()): boolean
    Display.Clear(player.UserId)
    local plot=PlotService.GetPlot(player)
    local frame=plot and StationService.FrameOf(plot)
    if not plot or not frame or plot:GetAttribute("OwnerUserId")~=player.UserId then return false end
    local market=UsedRules.Sanitize(profile and profile.UsedMarket)
    local car=market.Owned[1]
    if car then
        active[player.UserId]=createDisplay(player,plot,frame,car,31,-16,false,0,callback)
    end
    local displays={}
    -- Área lateral frontal do lote, fora dos boxes, corredor e máquinas.
    local positions={{-32,-36},{31,-36}}
    for i,exhibit in ipairs(market.Showroom) do
        local spot=positions[i]
        if spot then
            table.insert(displays,createDisplay(player,plot,frame,
                exhibit,spot[1],spot[2],true,i,callback))
        end
    end
    showcases[player.UserId]=displays
    return true
end

return Display
