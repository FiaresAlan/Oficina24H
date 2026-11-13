-- V2-10: personalização transparente, vitrines limitadas e reputação sem replay.
local C=require(game.ReplicatedStorage.Shared.V2ShowroomRules)
local R=require(game.ReplicatedStorage.Shared.V2UsedMarketRules)
local F=require(game.ReplicatedStorage.Shared.V2FinancialRules)
local out={}
local function test(n,ok)table.insert(out,(ok and "PASS " or "FAIL ")..n)end
local function profile()
    return {Coins=20000,WorkshopLevel=1,OrderHistory={{},{},{}},
        UsedMarket=R.New(),Parts={TirePatch=20,Battery=20,SparkPlug=20,
            BrakePad=20,SuspensionKit=20}}
end
local function commit(p,plan)
    for id,qty in pairs(plan.Parts or {}) do p.Parts[id]-=qty end
    p.Coins+=plan.Delta
    p.Reputation=(p.Reputation or 0)+(plan.ReputationAward or 0)
    p.UsedMarket=plan.Market
end
local function ready(p,variant,uid,at)
    local buy=R.Plan(p,"Buy",variant,at,uid,0)
    if not buy then return false end
    commit(p,buy)
    commit(p,R.Plan(p,"Inspect",uid,at+1))
    commit(p,R.Plan(p,"Strip",uid,at+2))
    commit(p,R.Plan(p,"Restore",uid,at+3))
    return true
end
test("catálogo com tinta, acabamento e rodas",#C.Order==3
    and C.ValidOption("Paint","Graphite")
    and C.ValidOption("Finish","Matte")
    and C.ValidOption("Wheels","Classic"))
test("rejeita payload inventado ou com separadores",
    C.Parse("Paint:__Bad")==nil and C.Parse("Math:Red")==nil
    and C.Parse("Paint:Blue:Free")==nil)
test("todo cosmético custa mais que acrescenta à revenda",(function()
    for _,category in ipairs(C.Order) do
        for _,option in pairs(C.Catalog[category]) do
            if option.ResaleBonus>=option.Cost then return false end
        end
    end
    return true
end)())
local q=profile()
local uid=string.rep("1",32)
test("carro Hatch restaura no fluxo V2-09",ready(q,"Hatch",uid,1000))
local initial=q.Coins
local first=R.Plan(q,"Customize",uid,1004,nil,"Paint:Graphite")
test("prévia não debita nem muda estado",first and first.Delta==-50
    and q.Coins==initial and q.UsedMarket.Owned[1].Style=="Factory")
commit(q,first)
test("aplicação de grafite paga exatamente 50 e mantém outras categorias",
    q.Coins==initial-50 and q.UsedMarket.Owned[1].Style=="Graphite"
    and q.UsedMarket.Owned[1].Finish=="Standard")
test("reaplicação pintura não cobra de novo",R.Plan(q,"Customize",uid,1005,nil,"Paint:Red")==nil
    and R.Plan(q,"Paint",uid,1005,nil,"Blue")==nil)
local matte=R.Plan(q,"Customize",uid,1006,nil,"Finish:Matte")
commit(q,matte)
local wheels=R.Plan(q,"Customize",uid,1007,nil,"Wheels:Sport")
commit(q,wheels)
test("acabamento e rodas persistem na mesma coleção",
    q.UsedMarket.Owned[1].Finish=="Matte"
    and q.UsedMarket.Owned[1].Wheels=="Sport")
test("bônus é menor que dinheiro gasto",C.SaleBonus(q.UsedMarket.Owned[1])==35+30+40
    and C.Spent(q.UsedMarket.Owned[1])==50+55+75)
test("cotação antiga da V2-09 preservada",C.Catalog.Paint.Blue.Cost==R.StyleCost
    and C.Catalog.Paint.Blue.ResaleBonus==R.StyleBonus)
local deposit=R.Plan(q,"Showcase",uid,1010)
test("primeira exposição concede +1 única vez",deposit and deposit.Delta==0
    and deposit.ReputationAward==1)
commit(q,deposit)
test("showroom transfere sem vender, ocupa um dos dois slots",
    #q.UsedMarket.Owned==0 and #q.UsedMarket.Showroom==1
    and q.Reputation==1 and q.UsedMarket.TotalSales==0)
test("repetição de showcase não duplica reputação",
    R.Plan(q,"Showcase",uid,1011)==nil and q.Reputation==1)
local afterReopen=R.Sanitize(q.UsedMarket)
test("relogin preserva UID, material, rodas e marca da reputação",
    afterReopen.Showroom[1].Uid==uid
    and afterReopen.Showroom[1].Finish=="Matte"
    and afterReopen.Showroom[1].Wheels=="Sport"
    and afterReopen.ShowroomSeen.Hatch)
local recall=R.Plan(q,"Recall",uid,1012)
commit(q,recall)
test("retirar vitrine é grátis e exige slot ativo livre",
    #q.UsedMarket.Owned==1 and #q.UsedMarket.Showroom==0
    and q.Reputation==1 and q.Coins==initial-50-55-75)
local repeated=R.Plan(q,"Showcase",uid,1013)
test("reexibir mesma variante não gera mais reputação",repeated
    and repeated.ReputationAward==0)
commit(q,repeated)
local sell=R.Plan(q,"SellExhibit",uid,1014)
test("venda de exposição usa personalizações e preço correto",
    sell and sell.Delta==R.Offers.Hatch.SalePrice+35+30+40)
commit(q,sell)
test("venda remove UID e proíbe replay ou recall",
    #q.UsedMarket.Showroom==0 and q.UsedMarket.TotalSales==1
    and R.Plan(q,"SellExhibit",uid,1015)==nil
    and R.Plan(q,"Recall",uid,1015)==nil)
test("compras bloqueadas por cooldown persistente",
    R.Plan(q,"Buy","Sedan",1015,string.rep("2",32),0)==nil)
-- Antes do segundo ciclo, recebe carência concluída no horário controlado.
local sedan=string.rep("2",32)
test("novo Sedan após cooldown",ready(q,"Sedan",sedan,1615))
local p=R.Plan(q,"Showcase",sedan,1620)
commit(q,p)
test("primeiro Sedan concede segunda reputação",p.ReputationAward==1
    and q.Reputation==2 and #q.UsedMarket.Showroom==1)
local truck=string.rep("3",32)
test("Picape pode ficar ativa mesmo com showroom ocupado",
    ready(q,"Pickup",truck,1621))
test("não é possível retirar exposto com estoque ativo",
    R.Plan(q,"Recall",sedan,1625)==nil)
local second=R.Plan(q,"Showcase",truck,1626)
commit(q,second)
test("showroom cheio, duas posições, limite da reputação",#q.UsedMarket.Showroom==2
    and second.ReputationAward==1 and q.Reputation==3
    and R.Public(q,1627).ShowroomCapacity==2)
local uid4=string.rep("4",32)
test("Hatch ativo permitido, mas terceiro showcase recusado",
    ready(q,"Hatch",uid4,1627)
    and R.Plan(q,"Showcase",uid4,1632)==nil)
test("vender carro exposto com outro carro ativo não transfere UID errado",
    (function()
        local cash=q.Coins
        local quote=R.Plan(q,"SellExhibit",sedan,1635)
        if not quote then return false end
        commit(q,quote)
        return q.Coins==cash+quote.Delta
            and #q.UsedMarket.Showroom==1 and #q.UsedMarket.Owned==1
            and q.UsedMarket.Owned[1].Uid==uid4
    end)())
test("venda exibida não se confunde com receita OS",
    F.Category("Usados: venda showroom de Sedan",700)=="Market"
    and F.Category("Usados: personalizado Rodas",-75)=="Market")
local malicious=R.Sanitize({
    Owned={{Uid=string.rep("a",32),Variant="Hatch",Stage="Restored"}},
    Showroom={{
        Uid=string.rep("a",32),Variant="Hatch",Stage="Restored",
    },{
        Uid=string.rep("b",32),Variant="Hatch",Stage="Purchased",
    },{
        Uid=string.rep("c",32),Variant="Sedan",Stage="Restored",
        Style="Gold",Finish="Unobtainable",Wheels="Free",
    }},
    ShowroomSeen={Hatch=true,FreeSupercar=true},
})
test("migração valida IDs/estágios/atributos sem duplicar ativos",
    #malicious.Showroom==1 and malicious.Showroom[1].Uid==string.rep("c",32)
    and malicious.Showroom[1].Style=="Factory"
    and malicious.Showroom[1].Finish=="Standard"
    and malicious.Showroom[1].Wheels=="Stock"
    and malicious.ShowroomSeen.FreeSupercar==nil)
return table.concat(out,"\n")
