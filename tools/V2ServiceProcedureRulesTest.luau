local ReplicatedStorage=game:GetService("ReplicatedStorage")
local R=require(ReplicatedStorage.Shared.V2ServiceProcedureRules)
local Catalog=require(ReplicatedStorage.Shared.Catalog)
local out={}
local function test(n,ok)table.insert(out,(ok and "PASS " or "FAIL ")..n)end
local errors=R.ValidateCatalog()
test("15 receitas completas e válidas",#errors==0)
local n=0
for defectId in pairs(Catalog.Defects) do
    n+=1
    local spec=R.Recipes[defectId]
    test("procedimento cobre "..defectId,spec~=nil and #spec.Steps>=2)
    local states={Hood="Open",DoorLeft="Closed",DoorRight="Closed",
        WheelFL="Detached",WheelFR="Mounted",WheelRL="Mounted",WheelRR="Mounted"}
    local ctx={Parked=true,Authorized=true,Diagnosed=true,JobActive=true,
        RepairBusy=false,NpcBusy=false,EquipmentReady=true,PartsReady=true,States=states}
    local i=1
    for _,step in ipairs(spec.Steps) do
        states[step.Area]=step.State
        local nextIdx=R.Advance(defectId,i,step.Id,ctx)
        test(defectId.." "..step.Id.." ordem correta",nextIdx==i+1)
        test(defectId.." replay negado",R.Advance(defectId,i+1,step.Id,ctx)==nil)
        i+=1
    end
    test(defectId.." libera minijogo",R.Ready(defectId,i,"Hatch"))
    test(defectId.." mantém V1 não piloto",R.Ready(defectId,1,nil))
end
test("catálogo tem exatamente 15 defeitos",n==15)
local ctx={Parked=true,Authorized=true,Diagnosed=true,JobActive=true,
    RepairBusy=false,NpcBusy=false,EquipmentReady=true,PartsReady=true,States={Hood="Open"}}
local first=R.Current("WeakBattery",1)
test("etapa correta pode avançar",R.Advance("WeakBattery",1,first.Id,ctx)==2)
ctx.Authorized=false
test("outro jogador bloqueado",R.Advance("WeakBattery",1,first.Id,ctx)==nil)
ctx.Authorized=true ctx.EquipmentReady=false
test("equipamento ausente bloqueia",R.Advance("WeakBattery",1,first.Id,ctx)==nil)
ctx.EquipmentReady=true ctx.RepairBusy=true
test("reparo concorrente bloqueia",R.Advance("WeakBattery",1,first.Id,ctx)==nil)
ctx.RepairBusy=false ctx.PartsReady=false
test("estoque ausente bloqueia passo de peça",R.Advance("WeakBattery",3,"FitBattery",ctx)==nil)
ctx.PartsReady=true ctx.States.Hood="Closed"
test("capô fechado bloqueia trabalho",R.Advance("WeakBattery",1,first.Id,ctx)==nil)
test("mensagem não revela defeito antes do diagnóstico",R.Public("WeakBattery",1,nil)==nil)
test("índice inválido e spam negados",R.Advance("WeakBattery",999,"FitBattery",ctx)==nil
    and R.Current("WeakBattery",1.1)==nil)
return table.concat(out,"\n")
