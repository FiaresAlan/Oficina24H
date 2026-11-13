local Visuals=require(game:GetService("ServerScriptService").Server.V2ExpansionVisuals)
local Levels=require(game.ReplicatedStorage.Shared.WorkshopLevels)
local output={}
local function check(name,ok)table.insert(output,(ok and "PASS " or "FAIL ")..name)end
local sandbox=Instance.new("Folder")
sandbox.Name="V2VisualTestOnly"
local count=0
for level=0,3 do
    local folder=Visuals.Apply(sandbox,CFrame.new(0,0,0),level)
    local expected=Levels.Levels[level]
    check("nível "..level.." mantém boxes reais",folder:GetAttribute("V2Bays")==#expected.Bays)
    check("nível "..level.." permite contratação exata",
        folder:GetAttribute("V2MaxEmployees")==expected.MaxEmployees)
    check("nível "..level.." capacidade de equipamentos real",
        folder:GetAttribute("V2EquipmentCapacity")==Levels.MaxEquipment(level))
    local n=0
    for _,item in ipairs(folder:GetDescendants()) do
        if item:IsA("BasePart") then
            n+=1
            check("decoração não bloqueia carro/pedestre",
                item.CanCollide==false and item.CanTouch==false and item.CanQuery==false)
        end
    end
    count+=n
    check("peças decorativas limitadas "..level,n<=Visuals.MaxPieces)
    local same=Visuals.Apply(sandbox,CFrame.new(),level)
    check("rebuild idempotente sem peças órfãs",
        same~=folder and folder.Parent==nil and #sandbox:GetChildren()==1)
end
sandbox:Destroy()
check("quatro estágios renderizados",count>10)
return table.concat(output,"\n")
