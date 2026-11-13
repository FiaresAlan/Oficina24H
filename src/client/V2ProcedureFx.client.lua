--!strict
-- V2-04: pista contextual de estado da peça, só no CLIENTE do dono/mecânico.
-- Antes do diagnóstico nenhum atributo V2Procedure* é criado no servidor.
-- Proxies abaixo não mexem na colisão, inventário, economia nem na OS.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local me = Players.LocalPlayer
local RANGE = 120
local COLORS = {
    Tires = Color3.fromRGB(229, 157, 64),
    Suspension = Color3.fromRGB(219, 170, 70),
    Electrical = Color3.fromRGB(75, 164, 241),
    Engine = Color3.fromRGB(228, 105, 76),
    Bodywork = Color3.fromRGB(161, 113, 237),
}
local OK_COLOR = Color3.fromRGB(89, 214, 150)

type Marker = {
    Gui: BillboardGui,
    Dot: Frame,
    Label: TextLabel,
    Light: PointLight,
    Parent: BasePart,
}
local tracked: { [Model]: Marker } = {}
local INTERVAL = 0.18
local elapsed = 0

local function available(car: Model): boolean
    if car:GetAttribute("OwnerUserId") == me.UserId then return true end
    local hired = me:GetAttribute("CollaborationJobId")
    return type(hired) == "string" and hired == car:GetAttribute("JobId")
end

local function create(point: BasePart): Marker
    local gui=Instance.new("BillboardGui")
    gui.Name="V2ProcedureHint"
    gui.AlwaysOnTop=false -- não atravessa o veículo ou o HUD
    gui.MaxDistance=RANGE
    gui.Size=UDim2.fromOffset(190,56)
    gui.StudsOffsetWorldSpace=Vector3.new(0,1.4,0)
    gui.Adornee=point
    gui.Parent=point
    local frame=Instance.new("Frame")
    frame.Name="MarkerBody"
    frame.BackgroundColor3=Color3.fromRGB(17,26,38)
    frame.BackgroundTransparency=0.1
    frame.Size=UDim2.fromScale(1,1)
    frame.BorderSizePixel=0
    frame.Parent=gui
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,8)
    corner.Parent=frame
    local dot=Instance.new("Frame")
    dot.Size=UDim2.fromOffset(8,36)
    dot.Position=UDim2.fromOffset(8,10)
    dot.BorderSizePixel=0
    dot.BackgroundColor3=OK_COLOR
    dot.Parent=frame
    local label=Instance.new("TextLabel")
    label.Name="Hint"
    label.BackgroundTransparency=1
    label.Size=UDim2.new(1,-30,1,-8)
    label.Position=UDim2.fromOffset(24,4)
    label.TextScaled=false
    label.TextSize=16
    label.Font=Enum.Font.GothamSemibold
    label.TextColor3=Color3.fromRGB(242,246,251)
    label.TextXAlignment=Enum.TextXAlignment.Left
    label.TextYAlignment=Enum.TextYAlignment.Center
    label.TextWrapped=true
    label.Text="PREPARE O COMPONENTE"
    label.Parent=frame
    local light=Instance.new("PointLight")
    light.Range=5
    light.Brightness=0.65
    light.Shadows=false
    light.Color=OK_COLOR
    light.Parent=point
    return {Gui=gui,Dot=dot,Label=label,Light=light,Parent=point}
end

local function clear(car: Model)
    local marker=tracked[car]
    if marker then
        marker.Gui:Destroy()
        marker.Light:Destroy()
        tracked[car]=nil
    end
end

local function locate(car: Model): BasePart?
    local folder=car:FindFirstChild("V2ProcedurePoints")
    if not folder then return nil end
    local id=car:GetAttribute("V2ProcedureStepId")
    if type(id)=="string" and id~="" then
        local point=folder:FindFirstChild("V2Step_"..id)
        if point and point:IsA("BasePart") then return point end
    end
    -- Ao terminar, ancora o antes/depois no último passo já concluído.
    if car:GetAttribute("V2RepairStage")=="After" then
        local final: BasePart?=nil
        for _,point in ipairs(folder:GetChildren()) do
            if point:IsA("BasePart") and point:GetAttribute("Completed")==true then
                final=point
            end
        end
        return final
    end
    return nil
end

local function update(car: Model, cameraPos: Vector3)
    if not car.Parent or not available(car) then clear(car) return end
    local root=car.PrimaryPart
    if not root or (root.Position-cameraPos).Magnitude>RANGE then clear(car) return end
    local stage=car:GetAttribute("V2RepairStage")
    if type(stage)~="string" then clear(car) return end
    if stage=="During" then clear(car) return end
    local point=locate(car)
    if not point then clear(car) return end
    local marker=tracked[car]
    if marker and marker.Parent~=point then
        clear(car)
        marker=nil
    end
    if not marker then
        marker=create(point)
        tracked[car]=marker
    end
    local after=stage=="After"
    local family=car:GetAttribute("V2ProcedureFamily")
    local color=after and OK_COLOR or COLORS[family] or OK_COLOR
    marker.Dot.BackgroundColor3=color
    marker.Light.Color=color
    marker.Label.Text=after and "REPARO CONCLUÍDO" or
        (stage=="Ready" and "PREPARAÇÃO CONCLUÍDA" or "EXECUTE A ETAPA AQUI")
    marker.Gui.Enabled=true
end

RunService.Heartbeat:Connect(function(dt: number)
    elapsed+=dt
    if elapsed<INTERVAL then return end
    elapsed=0
    local camera=workspace.CurrentCamera
    if not camera then return end
    for car in pairs(tracked) do
        if not car.Parent then clear(car) end
    end
    local folder=workspace:FindFirstChild("Vehicles")
    if not folder then return end
    for _,item in ipairs(folder:GetChildren()) do
        if item:IsA("Model") and item:GetAttribute("V2PilotId")~=nil then
            update(item,camera.CFrame.Position)
        end
    end
end)
