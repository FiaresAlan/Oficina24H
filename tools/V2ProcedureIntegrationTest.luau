-- V2-04: integração sem Studio do caminho físico V2 + 15 minijogos V1.
-- Nenhum crédito real/DataStore: V1 AllServiceActionFlowTest cobre as regras de pagamento.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.Catalog)
local Physical=require(Shared.V2ServiceProcedureRules)
local Parts=require(Shared.V2ComponentRules)
local Operations=require(game:GetService("ServerScriptService").Server.RepairOperations)
local RepairActions=require(Shared.RepairActionRules)
local result={}
local function check(name,valid)
    table.insert(result,(valid and "PASS " or "FAIL ")..name)
end

local seen={}
local modes={}
local total=0
for defectId,defect in pairs(Catalog.Defects) do
    total+=1
    local recipe=Physical.Recipes[defectId]
    local plan=Operations.BuildPlan(defectId,7402)
    check(defectId.." tem receita, minijogo e equipamento",
        recipe~=nil and plan~=nil and plan.Kind=="Operations"
        and type(defect.RequiredEquipment)=="string"
        and Catalog.Equipment[defect.RequiredEquipment]~=nil)
    if recipe and plan then
        local public=Operations.PublicPlan(plan)
        check(defectId.." mantém gabarito no servidor",
            public and public.Correct==nil and public.CorrectSource==nil
            and public.CorrectAction==nil and public.LeakSpot==nil and public.DefectId==nil)
        modes[plan.Mode]=(modes[plan.Mode] or 0)+1
        local st={Hood="Closed",DoorLeft="Closed",DoorRight="Closed",Trunk="Closed",
            WheelFL="Mounted",WheelFR="Mounted",WheelRL="Mounted",WheelRR="Mounted"}
        local ctx={
            Authorized=true,Parked=true,Diagnosed=true,JobActive=true,
            RepairBusy=false,NpcBusy=false,EquipmentReady=true,PartsReady=true,States=st,
        }
        local i=1
        check(defectId.." exige serviço no mundo",
            not Physical.Ready(defectId,i,"Hatch") and Physical.Ready(defectId,i,nil))
        for _,step in ipairs(recipe.Steps) do
            check(defectId.." area existente "..step.Id,Parts.ById[step.Area]~=nil)
            st[step.Area]=step.State
            local nextStep=Physical.Advance(defectId,i,step.Id,ctx)
            check(defectId.." confirma etapa "..step.Id,nextStep==i+1)
            check(defectId.." recusa repetição "..step.Id,
                Physical.Advance(defectId,i+1,step.Id,ctx)==nil)
            i+=1
        end
        check(defectId.." libera minijogo só ao final",
            Physical.Ready(defectId,i,"Sedan") and not Physical.Ready(defectId,i-1,"Sedan"))
        local safe=Physical.Public(defectId,1,"Hatch")
        check(defectId.." snapshot não revela solução",
            safe and safe.Family==defect.Specialization
            and safe.StepName~=nil and safe.Ready==false
            and safe.Correct==nil and safe.DefectId==nil and safe.Parts==nil)
        local state=RepairActions.New(plan)
        check(defectId.." minijogo incremental carregável",state~=nil and state.Revision==0)
        seen[defectId]=true
    end
end
check("exatamente quinze serviços integrados",total==15)
check("sete modos anteriores ainda disponíveis",
    modes.Tire==1 and modes.Battery==1 and modes.Cooling==1
    and modes.Sequence==5 and modes.Calibration==2 and modes.Circuit==2
    and modes.Surface==3)
check("não aceitar preparo de defeito não catalogado",
    Physical.Current("HACK",1)==nil and not Physical.Ready("HACK",4,"Pickup"))
local step=Physical.Current("WeakBattery",1)
local ctx={Authorized=true,Parked=true,Diagnosed=true,JobActive=true,
    RepairBusy=false,NpcBusy=false,EquipmentReady=true,PartsReady=true,
    States={Hood="Open"}}
check("um passo só não habilita reparo",Physical.Advance("WeakBattery",1,step.Id,ctx)==2
    and not Physical.Ready("WeakBattery",2,"Pickup"))
ctx.Diagnosed=false
check("sem diagnóstico não há avanço",Physical.Advance("WeakBattery",1,step.Id,ctx)==nil)
ctx.Diagnosed=true ctx.Parked=false
check("carro em movimento não pode preparar",Physical.Advance("WeakBattery",1,step.Id,ctx)==nil)
ctx.Parked=true ctx.RepairBusy=true
check("preparo simultâneo ao pagamento não avança",Physical.Advance("WeakBattery",1,step.Id,ctx)==nil)
return table.concat(result,"\n")
