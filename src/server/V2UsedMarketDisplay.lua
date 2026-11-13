--!strict
-- V2-09: vitrine física do veículo de revenda, separada dos carros das OS.
-- Zero colisão/física, um carro por lote. Não interfere nos boxes/entrada.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Safety = require(ReplicatedStorage.Shared.AssetSafetyRules)
local UsedRules = require(ReplicatedStorage.Shared.V2UsedMarketRules)
local PlotService = require(script.Parent.PlotService)
local StationService = require(script.Parent.StationService)

local Display = {}
local active: { [number]: Model } = {}

local function showText(parent: Instance, text: string): BillboardGui
    local gui = Instance.new("BillboardGui")
    gui.Name = "UsedVehicleLabel"
    gui.Size = UDim2.fromOffset(350, 86)
    gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
    gui.AlwaysOnTop = false
    gui.MaxDistance = 75
    local label = Instance.new("TextLabel")
    label.Name = "Status"
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 18
    label.TextScaled = false
    label.TextWrapped = true
    label.TextColor3 = Color3.fromRGB(246, 249, 252)
    label.BackgroundColor3 = Color3.fromRGB(21, 29, 41)
    label.BackgroundTransparency = 0.1
    label.Text = text
    label.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 9)
    corner.Parent = label
    gui.Parent = parent
    return gui
end

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

local function createVehicle(root: Model, offer: any, car: any, frame: CFrame): Model
    local item = Instance.new("Model")
    item.Name = "VeiculoDeRevenda"
    local assets = ServerStorage:FindFirstChild("Assets")
    local vehicles = assets and assets:FindFirstChild("Veiculos")
    local modelName = Catalog.VehicleModels[offer.VehicleName]
    local source = vehicles and modelName and vehicles:FindFirstChild(modelName)
    local displayFrame = frame * CFrame.new(31, 0.8, -16) * CFrame.Angles(0, math.pi, 0)
    if source and source:IsA("Model") then
        local cloned = source:Clone()
        Safety.StripScripts(cloned)
        for _, descendant in ipairs(cloned:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.Anchored = true
                descendant.CanCollide = false
                descendant.CanTouch = false
                descendant.CanQuery = false
                descendant.CastShadow = false
                if descendant.Name == "Casco" then descendant.Transparency = 1 end
                if car.Stage ~= "Restored" and descendant.Transparency < 0.5
                    and descendant.Material ~= Enum.Material.Glass then
                    descendant.Color = descendant.Color:Lerp(Color3.fromRGB(95, 90, 82), 0.32)
                elseif car.Stage == "Restored" and car.Style ~= "Factory"
                    and descendant.Transparency < 0.5
                    and descendant.Material ~= Enum.Material.Glass then
                    local tint = car.Style == "Blue" and Color3.fromRGB(26, 100, 190)
                        or Color3.fromRGB(175, 38, 43)
                    descendant.Color = descendant.Color:Lerp(tint, 0.55)
                end
            end
        end
        -- Mantém o centro geométrico do modelo sobre o pedestal, mesmo
        -- quando o pivot original do asset não fica na origem.
        local bounding, size = cloned:GetBoundingBox()
        if size.X > 0 and size.Y > 0 and size.Z > 0 then
            local localOffset = cloned:GetPivot():ToObjectSpace(bounding)
            cloned:PivotTo(displayFrame * CFrame.new(0, size.Y / 2, 0) * localOffset:Inverse())
        end
        cloned.Parent = item
    else
        -- Sem asset 3D importado, a vitrine continua visível com carro leve
        -- de referência. Nunca instala scripts nem cria veículo de OS.
        local c = car.Stage == "Restored" and
            (car.Style == "Blue" and Color3.fromRGB(38, 102, 198)
            or car.Style == "Red" and Color3.fromRGB(185, 43, 48)
            or Color3.fromRGB(90, 145, 185)) or Color3.fromRGB(105, 93, 75)
        shape(item, "Chassi", Vector3.new(8, 2.5, 15),
            displayFrame * CFrame.new(0, 2.4, 0), c)
        shape(item, "Cabine", Vector3.new(7, 2.7, 7),
            displayFrame * CFrame.new(0, 4.7, 0.6), c)
        for _, xx in ipairs({-3.9, 3.9}) do
            for _, zz in ipairs({-4.3, 4.3}) do
                local tire = shape(item, "Roda", Vector3.new(1.7, 2.8, 2.8),
                    displayFrame * CFrame.new(xx, 1.65, zz), Color3.fromRGB(29, 30, 32))
                tire.Shape = Enum.PartType.Cylinder
            end
        end
    end
    item.Parent = root
    return item
end

function Display.Clear(playerId: number)
    local old = active[playerId]
    active[playerId] = nil
    if old and old.Parent then old:Destroy() end
end

-- callback recebe (jogador, operacao, UID). Validação e cobrança ficam
-- exclusivamente em WorkshopService/DataService, jamais no prompt.
function Display.Sync(player: Player, profile: any,
    callback: (Player, string, string) -> ()): boolean
    Display.Clear(player.UserId)
    local plot = PlotService.GetPlot(player)
    local frame = plot and StationService.FrameOf(plot)
    if not plot or not frame or plot:GetAttribute("OwnerUserId") ~= player.UserId then return false end
    local market = UsedRules.Sanitize(profile and profile.UsedMarket)
    local car = market.Owned[1]
    if not car then return true end
    local offer = UsedRules.Offers[car.Variant]
    if not offer then return false end
    local model = Instance.new("Model")
    model.Name = "V2UsedMarketDisplay"
    model:SetAttribute("OwnerUserId", player.UserId)
    model:SetAttribute("MarketUid", car.Uid)
    model:SetAttribute("MarketStage", car.Stage)
    local plate = shape(model, "PisoRevenda", Vector3.new(15, 0.3, 24),
        frame * CFrame.new(31, 0.18, -16), Color3.fromRGB(45, 50, 58))
    plate.Material = Enum.Material.Concrete
    local stand = shape(model, "PontoRevenda", Vector3.new(5, 2, 1),
        frame * CFrame.new(31, 1.2, -3), Color3.fromRGB(35, 47, 65))
    local stages = {
        Purchased = "INSPECIONAR", Inspected = "DESMONTAR",
        Stripped = "RESTAURAR", Restored = "VENDER",
    }
    local action = ({Purchased="Inspect",Inspected="Strip",
        Stripped="Restore",Restored="Sell"})[car.Stage]
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "PromptRevenda"
    prompt.ActionText = stages[car.Stage] or "VER DETALHES"
    prompt.ObjectText = offer.Name
    prompt.HoldDuration = 0.4
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Style = Enum.ProximityPromptStyle.Default
    prompt.Parent = stand
    prompt.Triggered:Connect(function(actor: Player)
        if actor.UserId ~= player.UserId or plot:GetAttribute("OwnerUserId") ~= player.UserId
            or not action then return end
        callback(actor, action, car.Uid)
    end)
    showText(stand, offer.Name .. "\n" .. car.Stage .. " · " .. (car.Style or "Factory"))
    createVehicle(model, offer, car, frame)
    model.Parent = plot
    active[player.UserId] = model
    return true
end

return Display
