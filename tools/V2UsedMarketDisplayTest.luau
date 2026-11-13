-- V2-09: a vitrine nao deve ocupar box nem gerar partes colidiveis.
-- Usa lote falso de Edit, sem tocar DataStore nem criar jogadores reais.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.V2UsedMarketRules)
local Plot=require(game.ServerScriptService.Server.PlotService)
local Display=require(game.ServerScriptService.Server.V2UsedMarketDisplay)
local out={}
local function test(n,ok)table.insert(out,(ok and "PASS " or "FAIL ")..n)end
local folder=Instance.new("Folder")
folder.Name="V2UsedMarketAuditTemp"
folder.Parent=workspace
local plot=Instance.new("Folder")
plot.Name="PlotUsedAudit"
plot:SetAttribute("PlotId",1)
plot:SetAttribute("OwnerUserId",0)
plot:SetAttribute("Side",1)
plot.Parent=folder
local base=Instance.new("Part")
base.Name="Base"
base.Size=Vector3.new(90,0.8,90)
base.CFrame=CFrame.new(1000,0.4,1000)
base.Anchored=true
base.Parent=plot
Plot._initForTesting(folder)
local player={UserId=987654321,DisplayName="V2 Test",Character=nil}
local assigned=Plot.Assign(player)
test("lote de ensaio atribuido",assigned)
local market=Rules.New()
table.insert(market.Owned,{
    Uid=string.rep("a",32),Variant="Hatch",Stage="Purchased",
    RiskFee=5,Style="Factory",PurchasedAt=10,
})
local state={UsedMarket=market}
local callbackCount=0
local callback=function(_player, _action, _id)
    callbackCount+=1
end
local ok=Display.Sync(player,state,callback)
local model=plot:FindFirstChild("V2UsedMarketDisplay")
local prompt=model and model:FindFirstChild("PromptRevenda",true)
test("vitrine existe no lote com UID da conta",
    ok and model and model:GetAttribute("OwnerUserId")==player.UserId
    and model:GetAttribute("MarketUid")==market.Owned[1].Uid)
test("inspecao fisica tem prompt sem autorizar compra",
    prompt and prompt:IsA("ProximityPrompt")
    and prompt.ActionText=="INSPECIONAR")
local safe=true
if model then
    for _,child in ipairs(model:GetDescendants()) do
        if child:IsA("BasePart") and
            (child.CanCollide or child.CanTouch or child.CanQuery or not child.Anchored) then
            safe=false
        end
    end
end
test("todas as pecas decorativas sem colisao ou simulacao",model and safe)
test("vitrine nao reivindica bay/OS",not plot:FindFirstChild("Bay1")
    and model and model:GetAttribute("JobId")==nil)
market.Owned[1].Stage="Restored"
market.Owned[1].Style="Blue"
Display.Sync(player,state,callback)
local replaced=plot:FindFirstChild("V2UsedMarketDisplay")
local models=0
for _,child in ipairs(plot:GetChildren()) do
    if child.Name=="V2UsedMarketDisplay" then models+=1 end
end
test("troca de etapa nao duplica carro",models==1
    and replaced~=model and replaced:GetAttribute("MarketStage")=="Restored")
local sellPrompt=replaced and replaced:FindFirstChild("PromptRevenda",true)
test("carro restaurado oferece venda",sellPrompt and sellPrompt.ActionText=="VENDER")
Display.Clear(player.UserId)
test("desconexao limpa a vitrine",plot:FindFirstChild("V2UsedMarketDisplay")==nil)
market.Owned={}
test("sem carro nenhuma vitrine fantasma",Display.Sync(player,state,callback)
    and plot:FindFirstChild("V2UsedMarketDisplay")==nil)
test("nenhum dinheiro foi produzido pelo display",callbackCount==0)
Plot._initForTesting(workspace:FindFirstChild("Plots") or folder)
folder:Destroy()
return table.concat(out,"\n")
