--!strict
-- V2-10: comparação ANTES / DEPOIS só no cliente, sem modificar o perfil.
-- Sem sobreposição escura; viewport usa assets já sanitizados pela V1.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Appearance=require(ReplicatedStorage.Shared.V2ShowroomRules)
local Visual=require(ReplicatedStorage.Shared.V2ShowroomVisual)

local Preview={}

local function fallback(): Model
    local root=Instance.new("Model")
    root.Name="PreviewSimples"
    local function box(name: string,size: Vector3,cf: CFrame,color: Color3)
        local p=Instance.new("Part")
        p.Name=name
        p.Size=size
        p.CFrame=cf
        p.Color=color
        p.Anchored=true
        p.CanCollide=false
        p.CanTouch=false
        p.CanQuery=false
        p.Parent=root
    end
    box("Carroceria",Vector3.new(6,1.8,12),CFrame.new(0,1.8,0),Color3.fromRGB(115,160,190))
    box("Cabine",Vector3.new(5,2.2,5.7),CFrame.new(0,3.8,0.4),Color3.fromRGB(115,160,190))
    for _, x in ipairs({-3,3}) do
        for _, z in ipairs({-3.7,3.7}) do
            box("Pneu",Vector3.new(1,2.1,2.1),CFrame.new(x,1.2,z),Color3.fromRGB(25,28,31))
            box("Aro",Vector3.new(.2,1.4,1.4),
                CFrame.new(x+(x>0 and 0.6 or -0.6),1.2,z),
                Color3.fromRGB(160,170,178))
        end
    end
    return root
end

local function thumbnail(parent: Instance,title: string,
    modelName: string?,car: any,widthScale: number)
    local container=Instance.new("Frame")
    container.Name="Visual_"..title
    container.Size=UDim2.new(widthScale,-8,1,0)
    container.BackgroundColor3=Color3.fromRGB(26,39,60)
    container.BorderSizePixel=0
    container.Parent=parent
    local round=Instance.new("UICorner")
    round.CornerRadius=UDim.new(0,10)
    round.Parent=container
    local caption=Instance.new("TextLabel")
    caption.Name="StageLabel"
    caption.Size=UDim2.new(1,-12,0,26)
    caption.Position=UDim2.fromOffset(6,5)
    caption.BackgroundTransparency=1
    caption.Font=Enum.Font.GothamBold
    caption.TextSize=17
    caption.TextColor3=Color3.fromRGB(234,240,250)
    caption.Text=title
    caption.Parent=container
    local viewport=Instance.new("ViewportFrame")
    viewport.Name="CarPreview"
    viewport.Size=UDim2.new(1,-6,1,-37)
    viewport.Position=UDim2.fromOffset(3,33)
    viewport.BackgroundTransparency=1
    viewport.Ambient=Color3.fromRGB(185,195,210)
    viewport.LightColor=Color3.fromRGB(255,245,230)
    viewport.LightDirection=Vector3.new(-1,-1,-1)
    viewport.Parent=container
    local camera=Instance.new("Camera")
    camera.FieldOfView=32
    camera.Parent=viewport
    viewport.CurrentCamera=camera
    local folder=ReplicatedStorage:FindFirstChild("VehiclePreviews")
    local template=modelName and folder and folder:FindFirstChild(modelName)
    local carModel: Model
    if template and template:IsA("Model") and template.Archivable
        and template:FindFirstChildWhichIsA("BasePart",true) then
        carModel=template:Clone()
    else
        carModel=fallback()
    end
    Visual.Apply(carModel,car)
    carModel.Parent=viewport
    local cf,size=carModel:GetBoundingBox()
    local distance=math.max(size.X,size.Y,size.Z)*2.0
    distance=math.max(distance,15)
    camera.CFrame=CFrame.lookAt(cf.Position+
        Vector3.new(0.76,0.42,1).Unit*distance,cf.Position)
    return container
end

function Preview.Pair(parent: Instance,modelName: string?,raw: any,proposal: string): Frame
    local before=Appearance.Appearance(raw)
    local after={
        Stage="Restored",Style=before.Paint,
        Finish=before.Finish,Wheels=before.Wheels,
    }
    local category,choice=Appearance.Parse(proposal)
    if category=="Paint" then after.Style=choice
    elseif category=="Finish" then after.Finish=choice
    elseif category=="Wheels" then after.Wheels=choice end
    local frame=Instance.new("Frame")
    frame.Name="V2BeforeAfter"
    frame.Size=UDim2.new(1,-8,0,160)
    frame.BackgroundTransparency=1
    frame.Parent=parent
    local layout=Instance.new("UIListLayout")
    layout.FillDirection=Enum.FillDirection.Horizontal
    layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    layout.Padding=UDim.new(0,8)
    layout.SortOrder=Enum.SortOrder.LayoutOrder
    layout.Parent=frame
    local current=thumbnail(frame,"ANTES",modelName,{
        Stage="Restored",Style=before.Paint,Finish=before.Finish,Wheels=before.Wheels,
    },0.5)
    current.LayoutOrder=1
    local changed=thumbnail(frame,"DEPOIS (SIMULAÇÃO)",modelName,after,0.5)
    changed.LayoutOrder=2
    return frame
end

return Preview
