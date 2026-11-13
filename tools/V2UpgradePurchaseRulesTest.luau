local R=require(game.ReplicatedStorage.Shared.V2UpgradePurchaseRules)
local out={}
local function check(n,v)table.insert(out,(v and "PASS " or "FAIL ")..n)end
local a={Kind="Building",Id="Oficina",Source="Construtora",Target=1,Cost=1500}
local allowed,pending,notice=R.Step(nil,a,200)
check("primeiro clique nao cobra",not allowed and pending~=nil and notice:find("CONFIRME")~=nil)
local yes,cleared=R.Step(pending,a,202)
check("segundo clique confirma e consome",yes and cleared==nil)
check("replay sem nova confirmacao nao cobra",R.Step(cleared,a,203)==false)
check("expiracao impede compra",R.Step(pending,a,215)==false)
check("custo alterado invalida confirmacao",R.Step(pending,{Kind=a.Kind,Id=a.Id,Target=1,Cost=1700,Source=a.Source},201)==false)
check("proximo nivel nao e comprado na mesma confirmacao",R.Step(pending,{Kind=a.Kind,Id=a.Id,Target=2,Cost=6000,Source=a.Source},201)==false)
check("vizinho / fonte diferente nao confirma",R.Step(pending,{Kind=a.Kind,Id=a.Id,Target=1,Cost=1500,Source="OutroLote"},201)==false)
check("oferta adulterada invalida",R.Step(nil,{Kind="Building",Id="Oficina",Target=1,Cost=-12,Source="Construtora"},200)==false)
check("NaN e infinito nao valem",R.Step(nil,a,0/0)==false and R.Step(nil,a,math.huge)==false)
local machine={Kind="Equipment",Id="Jack",Source="Plot3",Target=2,Cost=200}
local ok,q=R.Step(nil,machine,300)
check("equipamento exige duas interacoes",not ok and q~=nil and R.Step(q,machine,301)==true)
local n1={Bays={1},MaxEmployees=0}
local n2={Bays={1,2,3},MaxEmployees=1}
local benefits=R.Benefits(n1,n2,5,9)
check("beneficios usam capacidades reais",benefits.ExtraBays==2 and benefits.ExtraStaff==1 and benefits.ExtraEquipment==4)
return table.concat(out,"\n")
