local S=require(game.ReplicatedStorage.Shared.V2StaffRules)
local out={}
local function ok(n,v)table.insert(out,(v and "PASS " or "FAIL ")..n)end
local slots=S.Sanitize(nil)
ok("duas vagas e modo automatico",#slots==2 and slots[1].Mode=="Auto")
ok("sem alterar origem e sem aceitar dados estranhos",S.Sanitize({{Mode="hack",Focus="x",Completed=math.huge}})[1].Completed==0)
local changed=S.Update(slots,1,"Focus","Engine")
ok("foco valido",changed and slots[1].Focus=="Engine")
ok("foco invalido",S.Update(slots,1,"Focus","HACK")==false)
ok("slot inexistente",S.Update(slots,3,"Mode","Auto")==false)
ok("pausa valida",S.Update(slots,1,"Mode","Paused")==true and not S.CanHandle(slots[1],"Engine"))
S.Update(slots,1,"Mode","Auto")
ok("foco respeitado",S.CanHandle(slots[1],"Engine") and not S.CanHandle(slots[1],"Tires"))
S.Update(slots,1,"Focus","Any")
local jobs={
 {Id="j2",Specialization="Tires",Ready=true,Priority=0,AcceptedAt=4},
 {Id="j1",Specialization="Engine",Ready=true,Priority=2,AcceptedAt=1},
 {Id="j3",Specialization="Tires",Ready=true,Priority=2,AcceptedAt=1},
 {Id="bad",Specialization="Tires",Ready=false,Priority=10,AcceptedAt=0},
}
local sorted=S.Order(jobs,slots[1],100)
ok("ordem deterministica prioridade idade id",#sorted==3 and sorted[1].Id=="j1" and sorted[2].Id=="j3")
jobs[1].Manual=true
ok("manual tem precedencia",S.Order(jobs,slots[1],100)[1].Id=="j2")
S.Update(slots,1,"Mode","Manual")
ok("manual nao escolhe auto",#S.Order(jobs,slots[1],100)==1)
local badRecord=S.Record(slots,1,"Troca de pneus",125,75,50,1777777777)
ok("registro apos liquidacao",badRecord and slots[1].Completed==1 and slots[1].Gross==125)
ok("registro rejeita valores invalidos",not S.Record(slots,1,"Falso",-1,120,1,1))
for i=1,19 do S.Record(slots,1,"Serviço",30,70,25,1777777777) end
ok("historico limitado 12",#slots[1].Recent==S.MaxHistory and slots[1].Completed==20)
ok("sanitizacao de historico preserva quantidade",#S.Sanitize(slots)[1].Recent==S.MaxHistory)
return table.concat(out,"\n")
