--!strict
-- V2-06: sinalização física e melhoria visível proporcionais ao prédio REAL
-- (1, 2, 4, 6 boxes). Partes de decoração, nunca colisores ou novos remotes.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Levels=require(ReplicatedStorage.Shared.WorkshopLevels)
local Visuals={}
Visuals.MaxPieces=18

local function panel(parent: Instance, name: string, root: CFrame,
    size: Vector3, position: Vector3, color: Color3, message: string)
    local p=Instance.new("Part")
    p.Name=name
    p.Size=size
    p.CFrame=root*CFrame.new(position)
    p.Anchored=true
    p.CanCollide,p.CanTouch,p.CanQuery=false,false,false
    p.CastShadow=false
    p.Material=Enum.Material.Metal
    p.Color=Color3.fromRGB(25,34,44)
    p.Parent=parent
    local gui=Instance.new("SurfaceGui")
    gui.Name="Placa"
    gui.Face=Enum.NormalId.Front
    gui.PixelsPerStud=36
    gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.MaxDistance=115
    gui.LightInfluence=0
    gui.Parent=p
    local t=Instance.new("TextLabel")
    t.Name="Texto"
    t.Size=UDim2.fromScale(1,1)
    t.BackgroundTransparency=1
    t.TextColor3=color
    t.Font=Enum.Font.GothamBold
    t.TextScaled=true
    t.TextWrapped=true
    t.Text=message
    t.Parent=gui
    return p
end

function Visuals.Apply(plot: Instance,root: CFrame,level: number): Folder
    local previous=plot:FindFirstChild("V2ExpansionVisuals")
    if previous then previous:Destroy() end
    local folder=Instance.new("Folder")
    folder.Name="V2ExpansionVisuals"
    folder.Parent=plot
    local L=Levels.Levels[level] or Levels.Levels[0]
    -- Número verdadeiro por box, suspenso fora da área de circulação de veículos.
    for i,x in ipairs(L.Bays) do
        panel(folder,"BoxSign_"..i,root,Vector3.new(7,1.1,0.18),
            Vector3.new(x,L.Height-1.8,Levels.FrontZ+0.8),L.Color,
            string.format("BOX %02d",i))
    end
    -- Recepção melhora de balcão pequeno para atendimento com painel de status.
    local front=Levels.BackWallZ-1
    panel(folder,"ReceptionTier",root,Vector3.new(5.4,1.1,0.12),
        Vector3.new(L.X0+5.5,7,front),L.Color,
        level==0 and "RECEPÇÃO · GARAGEM" or "RECEPÇÃO · ATENDIMENTO")
    panel(folder,"StockTier",root,Vector3.new(4.1,0.9,0.12),
        Vector3.new(L.X0+1.6,8,18),L.Color,
        string.format("ESTOQUE · %d VAGAS EQUIP.",Levels.MaxEquipment(level)))
    if L.MaxEmployees>0 then
        panel(folder,"StaffTier",root,Vector3.new(4.7,1,0.12),
            Vector3.new(L.X1-5,6,front),L.Color,
            string.format("EQUIPE · ATÉ %d MECÂNICOS",L.MaxEmployees))
    end
    if level>=2 then
        panel(folder,"ServiceTier",root,Vector3.new(5.7,1.1,0.12),
            Vector3.new((L.X0+L.X1)/2,L.Height-2.5,Levels.BackWallZ-1),
            L.Color,level==3 and "CENTRO PREMIUM" or "CENTRO AUTOMOTIVO")
    end
    folder:SetAttribute("V2Level",level)
    folder:SetAttribute("V2Bays",#L.Bays)
    folder:SetAttribute("V2EquipmentCapacity",Levels.MaxEquipment(level))
    folder:SetAttribute("V2MaxEmployees",L.MaxEmployees)
    return folder
end

return Visuals
