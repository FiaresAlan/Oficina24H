local R = require(game:GetService("ReplicatedStorage").Shared.V2ReceptionRules)
local out={}
local function check(name,ok) table.insert(out,(ok and "PASS " or "FAIL ")..name) end
check("validacao numerica sem exploits",R.ValidPriority(1) and not R.ValidPriority(10)
    and not R.ValidPriority(0/0) and not R.ValidAppointment(300)
    and R.ValidAppointment(60) and R.ValidDiscount(10) and not R.ValidDiscount(11))
check("desconto calculado da base",R.PriceAfterDiscount(100,10)==90 and R.PriceAfterDiscount(100,0)==100)
local a,b=R.GeneralPriceGuide(1)
check("faixa geral de preco nao envolve defeito oculto",a>0 and b>=a)
local j={Status="Available",OwnerUserId=12,Priority=1,WaitSeconds=30,ScheduledUntil=200}
check("agendamento visivel",R.Stage(j,{},100)=="Agendado")
check("agendamento vencido retorna fila",R.Stage(j,{},201)=="Aguardando cliente")
local v=R.BuildVisible(j,{PriceMultiplier=1},100)
check("pre-diagnostico nao expoe valor exato",v.PriceGuideMin>0 and v.MissingParts~=nil and v.DiscountPercent==0)
check("ordenacao por prioridade e antiguidade",R.QueueLess({Priority=1,WaitSeconds=2},{Priority=0,WaitSeconds=300}))
local missing=R.MissingParts({Battery=1,Fuse=2},{Battery=0,Fuse=1})
check("faltas somente de itens reais",missing.Battery==1 and missing.Fuse==1)
j.Status="InProgress" j.Diagnosed=true
j.Requirement={Parts={Battery=1}}
check("esperando peca quando faltar",R.Stage(j,{Battery=0},200)=="Aguardando peça")
check("exame pronto quando ha estoque",R.Stage(j,{Battery=1},200)=="Pronto para reparar")
check("custo estimado de pecas",R.EstimatedPartsCost({Battery=1,Fuse=2})>0)
local visible=R.BuildVisible({Diagnosed=true,Status="InProgress",Requirement={Reward=150,Parts={Battery=1}}},{Parts={Battery=0},PriceMultiplier=1},200)
check("margem prevista sem vazar defeito",visible.EstimatedPartsCost>0 and visible.ContributionBeforeLabor==150-visible.EstimatedPartsCost)
return table.concat(out,"\n")
