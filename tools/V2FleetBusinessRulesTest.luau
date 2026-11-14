-- V2-14: negócio de frotas, capacidade, estoque, prazo, teto de
-- remuneração, relacionamento, corrupção de perfil e replay de bônus.
local R=require(game.ReplicatedStorage.Shared.V2FleetBusinessRules)
local Legacy=require(game.ReplicatedStorage.Shared.ContractRules)
local Catalog=require(game.ReplicatedStorage.Shared.Catalog)
local t={}
local function check(name,ok)table.insert(t,(ok and "PASS " or "FAIL ")..name)end
local a=R.NewAccounts()
check("conta de parceiros começa sem créditos ou histórico",
    #a.Keys==0 and #a.History==0 and next(a.Partners)==nil)
local offer={Company="taxi",Name="Táxi Veloz",Spec="Tires",
    Unit="reparos de pneu",Target=3,Seconds=600,Coins=400,Reputation=5}
local skills={Tires=3,Engine=1,Electrical=1,Suspension=1,Bodywork=1}
local equipment={BasicToolset=true,TireMachine=true,Balancer=true}
local quote=R.Quote(offer,{
    Skills=skills,Equipment=equipment,Stock={TirePatch=8,Tire=2,WheelWeight=0},
    Employees=1,Bays=2,OpenJobs=1,SalaryReserve=60,
    PriceMultiplier=1.2,
},a)
check("oferta comercial exige área e serviços de fato atendíveis",
    quote and quote.Spec=="Tires" and quote.EligibleDefects>=2)
check("consulta inclui equipe, boxes e carga, sem inventar saldo",
    quote and quote.Staff==1 and quote.Capacity==2
    and quote.LoadPercent==50)
check("baixo estoque é sinalizado, sem recusar a OS inteira",
    quote and #quote.LowStock>=1 and quote.PartTypeCount>=2)
local standard=R.TermsFromQuote(offer,quote,"Standard")
local express=R.TermsFromQuote(offer,quote,"Express")
check("negociação troca preço e prazo do bônus só no servidor",
    standard and express and express.Coins>standard.Coins
    and express.Seconds<standard.Seconds and express.Target==3)
check("preço do serviço e estimativa de margem não têm caminho de crédito",
    quote and quote.Variants[1].OwnerContribution~=nil
    and quote.Variants[1].NpcContribution~=nil
    and quote.Variants[1].CollaboratorContribution~=nil
    and quote.Variants[1].PaysNow==nil)
check("modo forjado não gera contrato",
    R.TermsFromQuote(offer,quote,"FreeBonus")==nil
    and R.TermsFromQuote(offer,nil,"Express")==nil)
check("sem equipamento da área não gera cotação enganosa",
    R.Quote(offer,{Skills=skills,Equipment={},Stock={}},a)==nil)
check("empresa falsa não tem contrato",
    R.Quote({Company="fake",Spec="Tires",Coins=100,Target=2,Seconds=600},{
        Skills=skills,Equipment=equipment,Stock={},
    },a)==nil)
check("recompensa é idempotente no próprio ledger",
    R.Record(a,string.rep("a",36),"taxi","Completed",{
        Mode="Express",At=1000,Done=3,Target=3,Gross=510,Bonus=500,
    }))
check("replay da mesma chave não altera relação nem histórico",
    not R.Record(a,string.rep("a",36),"taxi","Completed",{
        Mode="Express",At=1000,Done=3,Target=3,Gross=510,Bonus=500,
    }) and a.Partners.taxi.Wins==1 and #a.History==1
    and a.Partners.taxi.Gross==510)
check("parceria concede no máximo 10% em oferta futura",
    (function()
        for i=1,9 do
            R.Record(a,string.format("%036d",i),"taxi","Completed",{
                Mode="Standard",At=1000+i,Done=3,Target=3,Gross=200,Bonus=300,
            })
        end
        return R.PartnerBonus(a,"taxi")==.10
    end)())
check("cliente não recebe chave de bônus nem token",
    (function()
        local pub=R.PublicAccounts(a)
        return pub.Completed==10 and pub.Partners[1]~=nil
            and pub.Keys==nil and pub.RewardKey==nil
            and pub.Partners[1].Key==nil
    end)())
local expiredKey=string.rep("e",36)
check("prazo vencido registra histórico sem conceder bônus",
    R.Record(a,expiredKey,"taxi","Expired",{
        Mode="Standard",At=2000,Done=1,Target=3,Gross=120,Bonus=0,
    }) and a.Partners.taxi.Expired==1
    and a.History[#a.History].Bonus==0)
local corrupt=R.SanitizeAccounts({
    Keys={string.rep("x",36),string.rep("x",36),"","bad"},
    Partners={taxi={Wins=0/0,Expired=math.huge,Gross=-50,LastAt=1e15},
        fake={Wins=99999}},
    History={{Company="fake",Result="Completed",At=1e99},
        {Company="taxi",Result="Completed",Mode="FreeCoin",Bonus=-999,
            Done=1e99,Target=0/0,At=-5}},
})
check("migração remove keys repetidas/corrompidas",
    #corrupt.Keys==1 and corrupt.Keys[1]==string.rep("x",36))
check("migração limita números inválidos sem aceitar parceiros falsos",
    corrupt.Partners.fake==nil and corrupt.Partners.taxi.Wins==0
    and corrupt.Partners.taxi.Gross==0 and corrupt.Partners.taxi.LastAt<=4102444800)
check("histórico saneado sem porcentagem ou modo inventado",
    #corrupt.History==1 and corrupt.History[1].Mode=="Standard"
    and corrupt.History[1].Bonus==0)
local max=R.NewAccounts()
for i=1,160 do
    R.Record(max,string.format("%036d",i),"taxi","Completed",{
        Mode="Standard",At=10000+i,Done=1,Target=1,Gross=100,Bonus=150,
    })
end
check("ledger privado limitado e histórico recente limitado",
    #max.Keys==R.MaxCreditKeys and #max.History==R.MaxHistory
    and max.Partners.taxi.Wins==160)
check("regras V1 de escolha de frota continuam compatíveis",
    Legacy.NeedsFleet(1,0,3) and not Legacy.NeedsFleet(2,1,3))
return table.concat(t,"\n")
