--!strict
-- V2-06: stands físicos de melhoria. PISAR NUNCA COMPRA.
-- Confirmar explicitamente duas vezes no ProximityPrompt, com preço/tier
-- computados pelo servidor e distância revalidada em cada interação.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Levels=require(ReplicatedStorage.Shared.WorkshopLevels)
local Rules=require(ReplicatedStorage.Shared.EquipmentUpgradeRules)
local Quotes=require(ReplicatedStorage.Shared.V2UpgradePurchaseRules)
local Catalog=require(ReplicatedStorage.Shared.Catalog)
local EquipmentService=require(script.Parent.EquipmentService)
local PlotService=require(script.Parent.PlotService)
local StationService=require(script.Parent.StationService)

local Pads={}
local live: {[number]: any}={}
local onPurchase: ((Player,string,Instance)->())?=nil
local onNotice: ((Player,string,boolean)->())?=nil

function Pads.SetPurchaseHandler(callback: (Player,string,Instance)->())
    onPurchase=callback
end
function Pads.SetNoticeHandler(callback: (Player,string,boolean)->())
    onNotice=callback
end

local function create(plot: Instance,id: string): BasePart
    local folder=plot:FindFirstChild("UpgradePads")
    if not folder then
        folder=Instance.new("Folder")
        folder.Name="UpgradePads"
        folder.Parent=plot
    end
    local pad=Instance.new("Part")
    pad.Name="Upgrade_"..id
    pad.Size=Vector3.new(3.7,0.16,3)
    pad.Anchored=true
    pad.CanCollide=false
    pad.CanTouch=false
    pad.CanQuery=false
    pad.Material=Enum.Material.DiamondPlate
    pad.Color=Color3.fromRGB(54,101,138)
    pad.Transparency=0.2
    pad.Parent=folder
    local billboard=Instance.new("BillboardGui")
    billboard.Name="Price"
    billboard.Size=UDim2.fromOffset(235,100)
    billboard.StudsOffsetWorldSpace=Vector3.new(0,2.9,0)
    billboard.MaxDistance=35
    billboard.Parent=pad
    local label=Instance.new("TextLabel")
    label.Name="Label"
    label.Size=UDim2.fromScale(1,1)
    label.BackgroundColor3=Color3.fromRGB(24,34,47)
    label.BackgroundTransparency=0.08
    label.TextColor3=Color3.fromRGB(215,236,248)
    label.TextScaled=true
    label.TextWrapped=true
    label.Font=Enum.Font.GothamBold
    label.Parent=billboard
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,8)
    corner.Parent=label
    local prompt=Instance.new("ProximityPrompt")
    prompt.Name="UpgradeConfirm_"..id
    prompt.ActionText="Ver investimento"
    prompt.ObjectText="Melhorar equipamento"
    prompt.HoldDuration=0.5
    prompt.MaxActivationDistance=7.5
    prompt.RequiresLineOfSight=false
    prompt.KeyboardKeyCode=Enum.KeyCode.E
    prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
    prompt.Style=Enum.ProximityPromptStyle.Custom
    prompt.Parent=pad
    prompt.Triggered:Connect(function(player: Player)
        Pads.Interact(player,id,plot)
    end)
    return pad
end

function Pads.Interact(player: Player,id: string,plot: Instance)
    local state=live[player.UserId]
    local entry=state and state.Entries[id]
    if not entry or state.Plot~=plot or PlotService.GetPlot(player)~=plot
        or plot:GetAttribute("OwnerUserId")~=player.UserId
        or entry.Pad.Parent==nil or entry.Pad:GetAttribute("OwnerUserId")~=player.UserId then
        return
    end
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health<=0
        or (root.Position-entry.Pad.Position).Magnitude>7.5 then return end
    local target=entry.Level+1
    local price=Rules.NextCost(id,entry.Level)
    if not price or price~=entry.Cost or target>Rules.MaxLevel then
        entry.Pending=nil
        if onNotice then onNotice(player,"Melhoria desatualizada. Reabra a oferta.",false) end
        return
    end
    local quote={
        Kind="Equipment", Id=id, Source=tostring(plot:GetAttribute("PlotId") or plot.Name),
        Target=target, Cost=price,
    }
    local execute,nextPending,message=Quotes.Step(entry.Pending,quote,os.clock())
    entry.Pending=nextPending -- consumido ANTES de chamar a transação
    if not execute then
        if onNotice then
            onNotice(player,message..string.format(
                " Nível %d: produtividade +3%% por nível, funcionário até 8%% mais rápido.",
                target),false)
        end
        return
    end
    if onPurchase then onPurchase(player,id,plot) end
end

function Pads.Sync(player: Player,owned: any,upgrades: any)
    local plot=PlotService.GetPlot(player)
    local origin=plot and StationService.FrameOf(plot)
    if not plot or not origin then return end
    local state=live[player.UserId]
    if state and state.Plot~=plot then
        local old=state.Plot:FindFirstChild("UpgradePads")
        if old then old:Destroy() end
        state=nil
    end
    state=state or { Plot=plot,Entries={} }
    live[player.UserId]=state
    local slots=Levels.EquipmentSlots(StationService.LevelOf(plot))
    local index,keep=0,{}
    for _,id in ipairs(EquipmentService.Order) do
        if owned[id]==true then
            index+=1
            local level=Rules.Level(upgrades,owned,id)
            local models=plot:FindFirstChild("Equipment")
            local model=models and models:FindFirstChild("Eq_"..id)
            if model and model:IsA("Model") then
                model:SetAttribute("UpgradeLevel",level)
                local anchor=model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
                if anchor then
                    local badge=anchor:FindFirstChild("UpgradeTier")
                    if level>=2 then
                        if not badge then
                            badge=Instance.new("BillboardGui")
                            badge.Name="UpgradeTier"
                            badge.Size=UDim2.fromOffset(110,28)
                            badge.StudsOffsetWorldSpace=Vector3.new(0,3.5,0)
                            badge.MaxDistance=35
                            badge.Parent=anchor
                            local lbl=Instance.new("TextLabel")
                            lbl.Name="Tier"
                            lbl.Size=UDim2.fromScale(1,1)
                            lbl.Font=Enum.Font.GothamBold
                            lbl.TextScaled=true
                            lbl.BackgroundColor3=Color3.fromRGB(28,34,40)
                            lbl.TextColor3=Color3.fromRGB(245,205,95)
                            lbl.Parent=badge
                        end
                        local lbl=badge:FindFirstChild("Tier")
                        if lbl and lbl:IsA("TextLabel") then lbl.Text="MÁQUINA NÍVEL "..level end
                    elseif badge then
                        badge:Destroy()
                    end
                end
            end
            local cost=Rules.NextCost(id,level)
            if slots[index] and cost then
                keep[id]=true
                local entry=state.Entries[id]
                local pad=entry and entry.Pad or create(plot,id)
                pad.CFrame=origin*CFrame.new(slots[index].X,0.2,slots[index].Y-5.5)
                pad:SetAttribute("EquipmentId",id)
                pad:SetAttribute("OwnerUserId",player.UserId)
                local prompt=pad:FindFirstChildWhichIsA("ProximityPrompt")
                if prompt then prompt:SetAttribute("OwnerUserId",player.UserId) end
                local gui=pad:FindFirstChild("Price")
                local label=gui and gui:FindFirstChild("Label")
                if label and label:IsA("TextLabel") then
                    label.Text=string.format(
                        "MELHORAR · %s\nN%d · %d moedas\nINTERAJA 2 VEZES · NÃO PISE",
                        Catalog.Equipment[id].DisplayName,level+1,cost)
                end
                if not entry then
                    entry={Pad=pad,Level=level,Cost=cost,Pending=nil}
                    state.Entries[id]=entry
                elseif entry.Level~=level or entry.Cost~=cost then
                    entry.Pending=nil
                end
                entry.Level=level
                entry.Cost=cost
            end
        end
    end
    for id,entry in pairs(state.Entries) do
        if not keep[id] then entry.Pad:Destroy();state.Entries[id]=nil end
    end
end

function Pads.Clear(player: Player)
    local state=live[player.UserId]
    if state then
        local folder=state.Plot:FindFirstChild("UpgradePads")
        if folder then folder:Destroy() end
    end
    live[player.UserId]=nil
end

function Pads.Start()
    Players.PlayerRemoving:Connect(Pads.Clear)
    -- SEM laço de Touched/Heartbeat: presença em qualquer pad jamais cobra.
end
return Pads
