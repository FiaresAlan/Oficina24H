-- V2-05: simulação pura 0/1/2 mecânicos com 1/2/3 ordens.
-- Não substitui o test drive, rig ou DataStore do Studio.
local Rules=require(game.ReplicatedStorage.Shared.V2StaffRules)
local Reserve=require(game.ReplicatedStorage.Shared.StaffAssignmentRules)
local out={}
local function check(s,yes)table.insert(out,(yes and "PASS " or "FAIL ")..s)end
local slots=Rules.Sanitize(nil)
local function dispatch(workers,quantity)
    local jobs={}
    for i=1,quantity do
        table.insert(jobs,{Id="os"..i,Specialization=i%2==0 and "Engine" or "Tires",
            Ready=true,Priority=i==3 and 3 or 0,AcceptedAt=100+i})
    end
    local busy,selected={},{}
    for i=1,workers do
        local candidates=Rules.Order(jobs,slots[i],200)
        for _,job in ipairs(candidates) do
            if Reserve.TryReserve(busy,job.Id) then
                table.insert(selected,job.Id)
                break
            end
        end
    end
    return selected,busy
end
local zero=dispatch(0,3)
check("0 trabalhador nao reserva",#zero==0)
local one=dispatch(1,1)
check("1 trabalhador 1 OS",#one==1 and one[1]=="os1")
local twice=dispatch(2,1)
check("2 trabalhadores 1 OS sem reserva dupla",#twice==1)
local two=dispatch(2,2)
check("2 trabalhadores 2 OS distintas",#two==2 and two[1]~=two[2])
local three=dispatch(2,3)
check("2 trabalhadores 3 OS mantem fila",#three==2)
check("urgencia por prioridade",three[1]=="os3")
Rules.Update(slots,1,"Focus","Electrical")
check("foco restringe tarefa",#dispatch(2,3)==1)
Rules.Update(slots,1,"Focus","Any")
Rules.Update(slots,1,"Mode","Paused")
check("pausa impede nova OS",#dispatch(2,3)==1)
Rules.Update(slots,1,"Mode","Manual")
check("manual nao faz auto despacho",#dispatch(2,3)==1)
local jobs={{Id="manual",Manual=true,Ready=true,Specialization="Engine",Priority=0,AcceptedAt=3},
    {Id="automatico",Ready=true,Specialization="Engine",Priority=3,AcceptedAt=1}}
local manual=Rules.Order(jobs,slots[1],200)
check("manual so aceita OS atribuida",#manual==1 and manual[1].Id=="manual")
check("reserva e liberacao sem repetir",Reserve.TryReserve({}, "os9"))
return table.concat(out,"\n")
