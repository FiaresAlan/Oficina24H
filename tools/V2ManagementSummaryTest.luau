local R=require(game:GetService("ReplicatedStorage").Shared.V2ManagementSummaryRules)
local out={}
local function test(name,ok) table.insert(out,(ok and "PASS " or "FAIL ")..name) end
local s={HasWorkshop=true,Profile={WorkshopLevel=1,Coins=150,Employees=1,
 OrderHistory={{Price=90},{Price=55}}},
 Jobs={{Status="Available",WaitSeconds=85,PatienceSeconds=100},
 {Status="Available",WaitSeconds=1,PatienceSeconds=100},
 {Status="InProgress",Diagnosed=true,Requirement={Reward=120}}}}
local a=R.Build(s)
test("capacidade do predio",a.Bays==2 and a.FreeBays==1)
s.FreeBays=0
local occupied=R.Build(s)
test("capacidade respeita vaga realmente reservada",occupied.FreeBays==0)
s.FreeBays=nil
test("fila/risco/ocupacao",a.Waiting==2 and a.Working==1 and a.Urgent==1)
test("dados financeiros e equipe",a.Coins==150 and a.Employees==1 and a.RecentGross==145)
test("nao inventa lucro",a.NetProfitAvailable==false and a.DiagnosedEstimateGross==120)
test("contribuicao e anterior ao salario",a.DiagnosedPartsEstimate==0 and a.DiagnosedContributionBeforeLabor==120)
test("recomenda atendimento urgente",a.NextAction=="Clientes aguardando há muito tempo")
test("somente leitura",s.Profile.Coins==150 and s.Jobs[1].WaitSeconds==85)
s.Jobs[1].WaitSeconds=-100
local b=R.Build(s)
test("entrada invalida nao vira urgente",b.Urgent==0)
test("snapshot ausente tolerado",R.Build(nil).Bays==1)
return table.concat(out,"\n")
