-- V2-12: seleção selada do servidor, condições mensuráveis e
-- evidência sem defeito privado, moedas, XP ou fraude de checkpoint.
local R=require(game.ReplicatedStorage.Shared.V2DriveScenarioRules)
local out={}
local function check(name,good)table.insert(out,(good and "PASS " or "FAIL ")..name)end
check("gate de release físico continua desligado sem QA real",R.LiveEnabled==false)
check("tabela cobre pneus, volante, suspensão, freios e motor",
    R.Signals.WornTire~=nil and R.Signals.Misalignment~=nil
    and R.Signals.LooseSuspension~=nil and R.Signals.BrakeWear~=nil
    and R.Signals.EngineMisfire~=nil and R.Signals.Overheating~=nil)
local seed=19727
local a=R.Plan("Hatch amarelo","WheelImbalance",false,seed)
local b=R.Plan("Hatch amarelo","WheelImbalance",false,seed)
check("seed único gera decisão reprodutível sem nova rolagem",
    a.Seed==seed and b.Seed==seed and a.Diagnostic==b.Diagnostic
    and a.Quality==b.Quality and a.TriggerCheckpoint==b.TriggerCheckpoint)
check("sem Hatch não pode gerar teste sorteado",
    not R.Plan("Sedã azul","WornTire",false,seed).Diagnostic
    and not R.Plan("Picape antiga","EngineMisfire",false,seed).Quality)
check("novato ou amassado não gera rodagem",
    not R.Plan("Hatch amarelo","WornTire",true,seed).Diagnostic
    and not R.Plan("Hatch amarelo","Dent",false,seed).Quality)
check("seed malicioso não habilita cenário",
    not R.Plan("Hatch amarelo","WornTire",false,0).Diagnostic
    and not R.Plan("Hatch amarelo","WornTire",false,0/0).Quality)
local count,qa=0,0
for n=1,500 do
    local p=R.Plan("Hatch amarelo","WornTire",false,n)
    if p.Diagnostic then count+=1 end
    if p.Quality then qa+=1 end
end
check("distribuição aleatória não obriga 100% das OS",
    count>90 and count<300 and qa>50 and qa<200)
local plan={Diagnostic=true,Quality=true,Seed=128,TriggerCheckpoint=2}
check("rejeita teste antes de conversar com cliente",
    not R.CanRequest(plan,"Diagnosis",false,false,false,false))
check("libera observação legítima antes do diagnóstico",
    R.CanRequest(plan,"Diagnosis",false,true,false,false))
check("diagnóstico pós-procedimento não pode ser reaberto",
    not R.CanRequest(plan,"Diagnosis",true,true,false,false))
check("replay de sessão terminada não habilita 2º diagnóstico",
    not R.CanRequest(plan,"Diagnosis",false,true,true,false))
check("test-drive de qualidade só depois do reparo",
    not R.CanRequest(plan,"Quality",false,true,false,false)
    and R.CanRequest(plan,"Quality",true,true,false,false))
check("sessão ocupada bloqueia segundo motorista",
    not R.CanRequest(plan,"Diagnosis",false,true,false,true))
check("tipo de sessão forjado não é aceito",
    not R.CanRequest(plan,"FreeMoney",false,true,false,false))
local speed=R.Signals.WornTire
local turn=R.Signals.Misalignment
local brake=R.Signals.BrakeWear
local throttle=R.Signals.EngineMisfire
local warm=R.Signals.Overheating
check("velocidade reproduz sintoma apenas após checkpoint sorteado",
    not R.HasCondition(speed,25,1,0,20,1,2)
    and R.HasCondition(speed,25,1,0,20,2,2)
    and not R.HasCondition(speed,5,1,0,20,2,2))
check("volante exige curva e velocidade reais",
    R.HasCondition(turn,17,0,.45,22,2,2)
    and not R.HasCondition(turn,17,0,0,22,2,2))
check("frenagem exige desaceleração válida",
    R.HasCondition(brake,11,-.5,0,15,2,2)
    and not R.HasCondition(brake,11,1,0,15,2,2))
check("falha sob carga requer aceleração",
    R.HasCondition(throttle,16,.7,0,12,2,2)
    and not R.HasCondition(throttle,16,0,0,12,2,2))
check("motor aquecido exige ao menos 22 segundos",
    not R.HasCondition(warm,16,.7,0,10,3,2)
    and R.HasCondition(warm,16,.7,0,23,3,2))
check("NaN não abre observação",
    not R.HasCondition(speed,0/0,1,0,23,3,2))
check("rota em 10s não vale resultado clínico",
    not R.CanConclude(4,10) and not R.CanConclude(3,40)
    and R.CanConclude(4,40))
local done={Kind="Diagnosis",Complete=true,Reproduced=true,Elapsed=48}
local evidence=R.DiagnosticEvidence(plan,"Misalignment",done)
check("laudo útil e não inclui o defeito secreto, preço nem XP",
    evidence and evidence.Id=="DriveObservation"
    and type(evidence.Text)=="string" and #evidence.Text>20
    and evidence.DefectId==nil and evidence.Reward==nil and evidence.XP==nil)
check("aborto, rota inválida ou sem vibração não cria evidência",
    R.DiagnosticEvidence(plan,"Misalignment",{
        Kind="Diagnosis",Complete=false,Reproduced=true,Elapsed=8,
    })==nil
    and R.DiagnosticEvidence(plan,"Misalignment",{
        Kind="Diagnosis",Complete=true,Reproduced=false,Elapsed=50,
    })==nil)
local pub=R.Public(plan,false,false,false)
check("snapshot só expõe oferta, nunca seed/defeito real",
    pub and pub.Offered and pub.Seed==nil and pub.DefectId==nil
    and pub.TriggerCheckpoint==nil)
check("resultado sensorial não concede moedas e XP",
    evidence and evidence.Coins==nil and evidence.Quality==nil)
return table.concat(out,"\n")
