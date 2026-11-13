local R = require(game:GetService("ReplicatedStorage").Shared.V2ComponentRules)
local lines={}
local function test(n,v)table.insert(lines,(v and "PASS " or "FAIL ")..n)end
local function context()
    return {Parked=true,Assigned=true,InProgress=true,Diagnosed=false,
        Repairing=false,WorkerBusy=false,WheelSupportReady=false,WheelSupportRequired=true,HoodLockedOpen=false}
end
test("oito pontos validos e unicos",#R.Components==8 and R.ById.Hood~=nil and R.ById.WheelRR~=nil)
test("prompt nao aceita prefixos arbitrarios",R.FromPrompt("V2_Hood")=="Hood" and R.FromPrompt("V2_Bogus")==nil)
test("nome e estado validos",R.Attribute("Hood")=="V2State_Hood" and R.Closed("WheelFL")=="Mounted")
local ctx=context()
local nextState,msg=R.Next("Hood","Closed",ctx)
test("capo abre depois de estacionar",nextState=="Open" and msg~="")
nextState=R.Next("Hood","Open",ctx)
test("capo fecha sem preparar reparo",nextState=="Closed")
ctx.HoodLockedOpen=true
test("capo travado enquanto prepara",R.Next("Hood","Open",ctx)==nil)
ctx.HoodLockedOpen=false
test("roda exige diagnostico",R.Next("WheelFL","Mounted",ctx)==nil)
ctx.Diagnosed=true
test("roda exige apoio",R.Next("WheelFL","Mounted",ctx)==nil)
ctx.WheelSupportReady=true
test("roda desmonta apos apoio",R.Next("WheelFL","Mounted",ctx)=="Detached")
test("roda retorna sem consumir pecas",R.Next("WheelFL","Detached",ctx)=="Mounted")
ctx.WorkerBusy=true
test("mecanico ocupado bloqueia interacao",R.Next("DoorLeft","Closed",ctx)==nil)
ctx.WorkerBusy=false ctx.Assigned=false
test("outro jogador nao opera componente",R.Next("DoorRight","Closed",ctx)==nil)
ctx.Assigned=true ctx.Parked=false
test("carro em movimento bloqueado",R.Next("Trunk","Closed",ctx)==nil)
test("distancia valida e finita",R.IsNear(Vector3.zero,Vector3.new(1,0,1),8)
    and not R.IsNear(Vector3.zero,Vector3.new(100,0,0),8)
    and not R.IsNear(Vector3.zero,Vector3.zero,math.huge))
test("reparo de bateria exige capo",R.ReadyToRepair("WeakBattery","Hatch",{Hood="Closed"})==false
    and R.ReadyToRepair("WeakBattery","Hatch",{Hood="Open"})==true)
test("reparo de pneu exige roda retirada",R.ReadyToRepair("FlatTire","Sedan",{WheelFL="Mounted"})==false
    and R.ReadyToRepair("FlatTire","Sedan",{WheelRR="Detached"})==true)
test("outro carro preserva V1",R.ReadyToRepair("FlatTire",nil,{})==true)
test("partida bloqueada com porta aberta/roda solta",not R.MayDrive({DoorLeft="Open"})
    and not R.MayDrive({WheelFR="Detached"}) and R.MayDrive({Hood="Closed",WheelFR="Mounted"}))
return table.concat(lines,"\n")
