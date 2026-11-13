-- V2-09: regras do mercado sem depender de Studio assets.
local R=require(game.ReplicatedStorage.Shared.V2UsedMarketRules)
local F=require(game.ReplicatedStorage.Shared.V2FinancialRules)
local HttpService=game:GetService("HttpService")
local out={}
local function test(name,cond)table.insert(out,(cond and "PASS " or "FAIL ")..name)end
local function profile()
    return {Coins=5000,WorkshopLevel=1,UsedMarket=R.New(),Parts={
        TirePatch=3,Battery=2,SparkPlug=3,BrakePad=3,SuspensionKit=2,
    },OrderHistory={{},{},{}},}
end
local function commit(p,plan)
    for partId,qty in pairs(plan.Parts or {}) do
        p.Parts[partId]=(p.Parts[partId] or 0)-qty
    end
    p.Coins+=plan.Delta
    p.UsedMarket=plan.Market
end
local p=profile()
local m=R.Public(p,1000)
test("tres ofertas e estimativas positivas",#m.Offers==3
    and m.Offers[1].Id=="Hatch"
    and m.Offers[2].Id=="Sedan"
    and m.Offers[3].Id=="Pickup"
    and m.Offers[3].EstimatedContributionMin>=0)
test("mercado não oferece propriedade sem contexto",R.Public(nil,1000).CanBuy==false)
local denied=profile()
denied.WorkshopLevel=0
test("nivel de prédio obrigatório",R.Plan(denied,"Buy","Hatch",1000,string.rep("a",32),1)==nil)
denied.WorkshopLevel=1;denied.OrderHistory={}
test("tres OS de clientes obrigatórias",R.Plan(denied,"Buy","Hatch",1000,string.rep("a",32),1)==nil)
test("UID/risco falsos rejeitados",R.Plan(p,"Buy","Hatch",1000,"client",0)==nil
    and R.Plan(p,"Buy","Hatch",1000,string.rep("a",32),math.huge)==nil
    and R.Plan(p,"Buy","Hatch",1000,string.rep("a",32),21)==nil)
test("modelo de oferta inexistente rejeitado",R.Plan(p,"Buy","FreeSupercar",1000,string.rep("a",32),0)==nil)
local uid=string.rep("f",32)
local buy=R.Plan(p,"Buy","Hatch",1000,uid,15)
test("compra apenas planejada não desconta moedas",buy~=nil
    and p.Coins==5000 and #p.UsedMarket.Owned==0 and buy.Delta==-260)
commit(p,buy)
test("compra transforma o único slot",#p.UsedMarket.Owned==1
    and p.Coins==4740 and R.Public(p,1001).Owned[1].RiskFee==15)
test("replay de compra bloqueado",R.Plan(p,"Buy","Hatch",1001,string.rep("b",32),0)==nil)
test("outro UID e salto de etapa bloqueados",
    R.Plan(p,"Inspect","hacker",1001)==nil
    and R.Plan(p,"Restore",uid,1001)==nil)
local inspect=R.Plan(p,"Inspect",uid,1001)
commit(p,inspect)
test("inspecao não altera saldo",p.Coins==4740 and p.UsedMarket.Owned[1].Stage=="Inspected")
test("dupla inspeção rejeitada",R.Plan(p,"Inspect",uid,1002)==nil)
commit(p,R.Plan(p,"Strip",uid,1002))
test("desmontagem autoritativa",p.UsedMarket.Owned[1].Stage=="Stripped")
local missing=profile()
missing.UsedMarket=R.Sanitize(p.UsedMarket);missing.Coins=p.Coins;missing.Parts={}
test("estoque ausente não executa nem debita",R.Plan(missing,"Restore",uid,1003)==nil
    and missing.Coins==p.Coins and missing.UsedMarket.Owned[1].Stage=="Stripped")
local restored=R.Plan(p,"Restore",uid,1003)
test("reforma inclui risco e não confia em custo enviado",restored
    and restored.Delta==-(35+15) and restored.Parts.TirePatch==1)
commit(p,restored)
test("estoque debitado só na conclusão",p.Parts.TirePatch==2
    and p.UsedMarket.Owned[1].Stage=="Restored")
test("repetir instalação não consome",R.Plan(p,"Restore",uid,1004)==nil)
test("estilo inválido ou preço insuficiente bloqueado",
    R.Plan(p,"Paint",uid,1004,nil,"gold")==nil)
local paint=R.Plan(p,"Paint",uid,1004,nil,"Blue")
commit(p,paint)
test("pintura opcional tem custo sem lucro garantido",
    p.UsedMarket.Owned[1].Style=="Blue" and paint.Delta==-40
    and R.Public(p,1004).Owned[1].SellPrice==400)
test("segunda pintura rejeitada",R.Plan(p,"Paint",uid,1005,nil,"Red")==nil)
local persisted=R.Sanitize(HttpService:JSONDecode(HttpService:JSONEncode(p.UsedMarket)))
test("salvamento/relogin preservam estágio, UID, custo e estilo",
    persisted.Owned[1].Uid==uid and persisted.Owned[1].Stage=="Restored"
    and persisted.Owned[1].RiskFee==15 and persisted.Owned[1].Style=="Blue")
local sell=R.Plan(p,"Sell",uid,1006)
test("venda calculada no servidor",sell and sell.Delta==400)
commit(p,sell)
test("venda libera slot e inicia cooldown",#p.UsedMarket.Owned==0
    and p.UsedMarket.NextBuyAt==1606 and p.UsedMarket.TotalSales==1)
test("replay de venda sem carro não paga",R.Plan(p,"Sell",uid,1007)==nil)
test("cooldown não contornável por reconexão",R.Plan(p,"Buy","Hatch",1605,string.rep("a",32),0)==nil
    and R.Plan(p,"Buy","Hatch",1606,string.rep("a",32),0)~=nil)
test("lançamento de usados não contamina receita de OS",
    F.Category("Usados: venda de Hatch",400)=="Market"
    and F.Category("Usados: compra de Hatch",-260)=="Market")
local b=F.New(5000,0)
local ok=F.Apply(b,400,"Usados: venda de Hatch")
test("categoria Mercado sobrevive reconciliação",ok
    and F.Sanitize(b,0,0).Groups.Market.In==400
    and F.Sanitize(b,0,0).Groups.Service.In==0)
local scrap=profile()
local scrapUid=string.rep("c",32)
commit(scrap,R.Plan(scrap,"Buy","Sedan",2000,scrapUid,30))
test("sucata recupera menos do que compra",
    R.Plan(scrap,"Scrap",scrapUid,2001).Delta
    < R.Offers.Sedan.BuyPrice)
local scrapPlan=R.Plan(scrap,"Scrap",scrapUid,2001)
commit(scrap,scrapPlan)
test("descarte repetido não paga",R.Plan(scrap,"Scrap",scrapUid,2002)==nil)
local dirty=R.Sanitize({Owned={
    {Uid="short",Variant="Pickup",Stage="Restored"},
    {Uid=string.rep("d",32),Variant="Fake",Stage="Restored"},
    {Uid=string.rep("e",32),Variant="Hatch",Stage="HACK",RiskFee=math.huge},
    {Uid=string.rep("f",32),Variant="Sedan",Stage="Restored"},
},NextBuyAt=math.huge,TotalSales=-1})
test("dados corrompidos não criam carros de bônus ou riscos infinitos",
    #dirty.Owned==1 and dirty.Owned[1].Stage=="Purchased"
    and dirty.Owned[1].RiskFee==0 and dirty.NextBuyAt==0)
test("mercado não altera OS nem concede XP, rep ou rating",
    p.Stats==nil and p.Reputation==nil and p.SkillXP==nil)
return table.concat(out,"\n")
