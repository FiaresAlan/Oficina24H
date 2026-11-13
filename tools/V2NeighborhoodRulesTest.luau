local R=require(game.ReplicatedStorage.Shared.V2NeighborhoodRules)
local out={}
local function check(n,v)table.insert(out,(v and "PASS " or "FAIL ")..n)end
check("15 rotas sem duplicatas e sem atravessar principal",#R.Validate()==0)
check("capacidade global maxima",R.MaxActive==9 and R.MaxPooled<=12)
local desktop=R.Budget(false,60,1)
local touch=R.Budget(true,60,1)
local slow=R.Budget(false,20,10)
check("mobile custa menos CPU e malhas",touch.Total<desktop.Total and touch.Vehicle==1)
check("fps baixo e servidor cheio reduzem quantidade",slow.Total<desktop.Total and slow.Tick>desktop.Tick)
local r=R.Routes[1]
check("trajeto com distancia consistente",R.Length(r)>100 and R.Distance(r,r.From)<0.01)
check("longe da rota nao aloca ator",#R.Select(Vector3.new(0,0,600),desktop)==0)
local selected=R.Select(Vector3.new(-100,0,-5),desktop)
local p,c,seen=0,0,{}
for _,route in ipairs(selected) do
    check("nenhuma rota repetida",not seen[route.Id])
    seen[route.Id]=true
    if route.Kind=="Vehicle" then c+=1 else p+=1 end
end
check("seleção respeita cotas",c<=desktop.Vehicle and p<=desktop.Pedestrian and #selected<=desktop.Total)
local a,dir=R.Position(r,1,0)
local b=R.Position(r,2,0)
check("movimento segue direcao positiva",a~=nil and b~=nil
    and (b-a):Dot(dir)>0)
check("rejeita timestamp invalido",select(1,R.Position(r,0/0,0))==nil)
check("courier tem caminho e prazo limitados",R.Length(R.Courier)>=20 and R.DeliverySeconds<=15)
check("nunca aloca pedestre com distancia infinita",
    #R.Select(Vector3.new(100000,0,100000),desktop)==0)
return table.concat(out,"\n")
