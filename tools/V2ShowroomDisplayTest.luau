-- V2-10: auditoria de cenários de vitrine em Studio Edit sem DataStore real.
-- Carros são decorativos e nenhuma parte pode ocupar box ou ter script externo.
local Plot=require(game.ServerScriptService.Server.PlotService)
local Display=require(game.ServerScriptService.Server.V2UsedMarketDisplay)
local Rules=require(game.ReplicatedStorage.Shared.V2UsedMarketRules)
local out={}
local function test(n,ok)table.insert(out,(ok and "PASS " or "FAIL ")..n)end
local folder=Instance.new("Folder")
folder.Name="V2ShowroomAuditTemp"
folder.Parent=workspace
local plot=Instance.new("Folder")
plot.Name="PlotShowroomAudit"
plot:SetAttribute("PlotId",1)
plot:SetAttribute("OwnerUserId",0)
plot:SetAttribute("Side",1)
plot.Parent=folder
local base=Instance.new("Part")
base.Name="Base"
base.Size=Vector3.new(90,0.8,90)
base.CFrame=CFrame.new(1500,0.4,1500)
base.Anchored=true
base.Parent=plot
Plot._initForTesting(folder)
local user={UserId=87654321,DisplayName="ShowroomQA",Character=nil}
Plot.Assign(user)
local market=Rules.New()
market.Owned={{
    Uid=string.rep("a",32),Variant="Hatch",Stage="Restored",
    Style="Graphite",Finish="Matte",Wheels="Sport",RiskFee=1,PurchasedAt=1,
}}
market.Showroom={{
    Uid=string.rep("b",32),Variant="Sedan",Stage="Restored",
    Style="Red",Finish="Gloss",Wheels="Classic",RiskFee=2,PurchasedAt=2,
},{
    Uid=string.rep("c",32),Variant="Pickup",Stage="Restored",
    Style="Blue",Finish="Standard",Wheels="Stock",RiskFee=3,PurchasedAt=3,
}}
local profile={UsedMarket=market}
local invoked=0
local callback=function() invoked+=1 end
local ok=Display.Sync(user,profile,callback)
local active=plot:FindFirstChild("V2UsedMarketDisplay")
local bay1=plot:FindFirstChild("V2ShowroomBay1")
local bay2=plot:FindFirstChild("V2ShowroomBay2")
test("um em restauro e dois expostos simultaneamente",
    ok and active and bay1 and bay2)
test("exposição não altera UID ou é tratada como OS",
    bay1 and bay1:GetAttribute("MarketUid")==market.Showroom[1].Uid
    and bay2:GetAttribute("MarketUid")==market.Showroom[2].Uid
    and active:GetAttribute("JobId")==nil
    and bay1:GetAttribute("JobId")==nil)
local safe=true
local noScript=true
local total=0
for _,display in ipairs({active,bay1,bay2}) do
    if display then
        total+=1
        for _,node in ipairs(display:GetDescendants()) do
            if node:IsA("BasePart") then
                if not node.Anchored or node.CanCollide or node.CanTouch or node.CanQuery then
                    safe=false
                end
            elseif node:IsA("Script") or node:IsA("LocalScript")
                or node:IsA("ModuleScript") then
                noScript=false
            end
        end
    end
end
test("todo o showroom sem física nem colisão",total==3 and safe)
test("modelos não executam scripts de asset",noScript)
local recall=bay1 and bay1:FindFirstChild("PromptRevenda",true)
test("prompt é retirada reversível e autenticada no servidor",
    recall and recall.ActionText=="RETIRAR DA EXPOSIÇÃO"
    and recall.MaxActivationDistance<=9)
local first=bay1
Display.Sync(user,profile,callback)
local count=0
for _,item in ipairs(plot:GetChildren()) do
    if item.Name=="V2ShowroomBay1" or item.Name=="V2ShowroomBay2"
        or item.Name=="V2UsedMarketDisplay" then count+=1 end
end
test("ressincronização não duplica carros nem prompts",
    count==3 and first~=plot:FindFirstChild("V2ShowroomBay1"))
local positions={}
for _,name in ipairs({"V2ShowroomBay1","V2ShowroomBay2"}) do
    local m=plot:FindFirstChild(name)
    local plate=m and m:FindFirstChild("PisoRevenda")
    if plate and plate:IsA("BasePart") then
        table.insert(positions,plate.Position)
    end
end
test("vitrines ocupam posições distintas no pátio, não os bays",
    #positions==2 and (positions[1]-positions[2]).Magnitude>20
    and plot:FindFirstChild("Bay1")==nil and invoked==0)
Display.Clear(user.UserId)
test("cleanup total ao sair",not plot:FindFirstChild("V2ShowroomBay1")
    and not plot:FindFirstChild("V2ShowroomBay2")
    and not plot:FindFirstChild("V2UsedMarketDisplay"))
Plot._initForTesting(workspace:FindFirstChild("Plots") or folder)
folder:Destroy()
return table.concat(out,"\n")
