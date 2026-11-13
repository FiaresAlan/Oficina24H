local R=require(game.ReplicatedStorage.Shared.V2FinancialRules)
local Catalog=require(game.ReplicatedStorage.Shared.Catalog)
local out={}
local function test(n,ok)table.insert(out,(ok and "PASS " or "FAIL ")..n)end
local b=R.New(200,100)
test("abertura nao e receita",b.CashIn==0 and b.OpeningBalance==200)
local cases={
    {90,"Liquidação de OS: Reparar pneu","Service"},
    {-20,"Peças: 2x Remendo","Inventory"},
    {-30,"Salário dos funcionários","Payroll"},
    {-8,"Publicidade: panfletos","Marketing"},
    {-100,"Melhoria: Jack","Equipment"},
    {-50,"Ampliação da oficina: Oficina","Building"},
    {-20,"Contratação de mecânico","Hiring"},
    {15,"Bônus do primeiro serviço","Rewards"},
    {12,"Recompensa diária","Other"},
}
for _,x in ipairs(cases) do
    local ok,group=R.Apply(b,x[1],x[2])
    test("classificação "..x[3],ok and group==x[3])
end
local report=R.Snapshot(b,{Coins=69,Employees=1,Parts={TirePatch=2},
    Bag={Battery=1},Transactions={}},200,25)
test("saldo e fluxo corretos sem dupla contagem",report.OperatingCash==90-20-30-8
    and report.CashDelta==90+15+12-20-30-8-100-50-20)
test("estoque nao subtrai novamente do fluxo",
    report.StockReferenceValue==2*Catalog.Parts.TirePatch.Cost+Catalog.Parts.Battery.Cost)
test("risco de folha detectado",report.AvailableAfterPayroll==44)
test("categoria não estimada vira outros",report.Groups.Other.In==12)
test("recompensas da V1 separadas de receita de serviços",
    R.Category("Missão: Oficina",15)=="Rewards"
    and R.Category("Recompensa diária (dia 1)",10)=="Rewards"
    and R.Category("Conquista: Primeira OS",10)=="Rewards"
    and R.Category("Liga semanal: Bronze",10)=="Rewards"
    and R.Category("Código RESGATE",10)=="Rewards")
test("não finge lucro",report.AccountingProfitAvailable==false)
test("não conta replay de entrada inválida",R.Apply(b,0,"Liquidação de OS: X")==false
    and R.Apply(b,0/0,"Liquidação de OS: X")==false
    and R.Apply(b,math.huge,"Liquidação de OS: X")==false)
local migrated=R.Bootstrap({
    {At=50,Amount=40,Balance=240,Reason="Liquidação de OS: antigo"},
    {At=55,Amount=-10,Balance=230,Reason="Peças: estoque"},
},230,100)
test("perfil legado migra só histórico disponível",migrated.LegacyWindow==true
    and migrated.OpeningBalance==200 and migrated.CashIn==40 and migrated.CashOut==10)
local clean=R.CleanTransactions({
    {At=1,Amount=0/0,Balance=999,Reason="hack"},
    {At=2,Amount=90,Balance=220,Reason="Liquidação de OS: X"},
})
test("NaN rejeitado e categoria recalculada",#clean==1 and clean[1].Category=="Service")
local quotes=R.ServiceQuotes(1)
test("15 serviços e peças referenciadas",#quotes==15)
for _,q in ipairs(quotes) do
    test("cotação sem ganho fictício "..q.Id,q.BeforeLabor==q.BasePrice-q.PartsReferenceCost
        and q.BasePrice>=0)
end
local warning=R.Snapshot(R.New(8,0),{Coins=8,Employees=1,Transactions={}},100,25)
test("caixa insuficiente não é mascarado",warning.Warning:find("INSUFICIENTE")~=nil)
test("saldo não negativo e fonte só no perfil",warning.Cash==8)
local discrepancy=R.Snapshot(b,{Coins=999,Employees=0,Transactions={}},200,0)
test("diferença entre saldo e extrato sempre visível",
    discrepancy.ReconciliationGap~=0
    and discrepancy.Warning:find("AUDITORIA")~=nil)
local stock={Parts={Battery=0,TirePatch=1},OrderHistory={},
    Coins=5,Employees=0,Transactions={}}
local hidden={Status="InProgress",Diagnosed=false,
    Requirement={Parts={Battery=99}}}
local serviceable={Status="InProgress",Diagnosed=true,
    Requirement={Parts={Battery=1,TirePatch=1}}}
local recommendations=R.Restock(stock,{hidden,serviceable})
test("não inferir defeito nem estoque de OS não diagnosticada",
    recommendations.UrgentCost==Catalog.Parts.Battery.Cost
    and #recommendations.Items==1
    and recommendations.Items[1].Id=="Battery")
test("reposição nunca debita estoque ou caixa",stock.Coins==5
    and stock.Parts.Battery==0 and stock.Parts.TirePatch==1)
local warningParts=R.Snapshot(R.New(5,0),stock,100,0,{hidden,serviceable})
test("alerta de falta de caixa para OS diagnosticada",
    warningParts.Warning=="FALTA CAIXA PARA PEÇAS DE ORDENS EM ANDAMENTO"
    and warningParts.Restock.UrgentCost==Catalog.Parts.Battery.Cost)
local past=R.Restock({Parts={},OrderHistory={
    {Service="Reparar pneu"},{Service="Reparar pneu"},{Service="Substituir bateria"},
}}, {})
test("estoque de segurança depende somente de serviços passados",
    past.HistoryServices==3 and past.TotalCost>0)
return table.concat(out,"\n")
