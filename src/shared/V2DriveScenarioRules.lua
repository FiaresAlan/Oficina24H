--!strict
-- V2-12: plano imutável de diagnóstico veicular. A autorização para
-- produção permanece DESLIGADA até homologação real da física V2-11.
-- Clientes não escolhem seed, tipo de sintoma ou defeito.
local R={}
R.LiveEnabled=false -- gate Studio V2-11: após QA explícito, aprovar em PR próprio
R.DiagnosticChance=.38
R.QualityChance=.24
R.MinDrivingSeconds=32
R.TargetDrivingSeconds=65
R.MaxSuggestedSeconds=95
R.RevealEarliestCheckpoint=1

R.Signals={
    WornTire={Family="Rolling",Name="Vibração progressiva",
        Cue="Vibração aumenta com a velocidade; confira pneus e rodas.",
        Condition="Speed",Sound="Buzz",Color="Amber"},
    WheelImbalance={Family="Rolling",Name="Tremor no volante",
        Cue="Tremor no volante sob velocidade; verifique balanceamento e pneus.",
        Condition="Speed",Sound="Buzz",Color="Amber"},
    FlatTire={Family="Rolling",Name="Roda irregular",
        Cue="O veículo oscila ao rolar; verifique pressão, pneus e rodas.",
        Condition="Speed",Sound="Hiss",Color="Amber"},
    LooseSuspension={Family="Chassis",Name="Batida sob curva",
        Cue="Ruído seco e oscilação ao virar; inspeção de suspensão recomendada.",
        Condition="Turn",Sound="Ratchet",Color="Amber"},
    BrokenArm={Family="Chassis",Name="Geometria instável",
        Cue="A carroceria oscila nas curvas; confira suspensão e apoios.",
        Condition="Turn",Sound="Ratchet",Color="Amber"},
    Misalignment={Family="Steering",Name="Direção puxando",
        Cue="O volante pede correção constante; confira alinhamento e suspensão.",
        Condition="Turn",Sound="Buzz",Color="Amber"},
    BrakeWear={Family="Braking",Name="Frenagem irregular",
        Cue="Frenagem com rangido; examine pastilhas, discos e suspensão.",
        Condition="Brake",Sound="AirWrench",Color="Amber"},
    EngineMisfire={Family="Power",Name="Falha sob carga",
        Cue="Resposta irregular ao acelerar; scanner e ignição precisam de exame.",
        Condition="Throttle",Sound="Buzz",Color="Red"},
    Overheating={Family="Power",Name="Temperatura elevada",
        Cue="Indicador de temperatura subindo; verifique arrefecimento sem forçar o motor.",
        Condition="Warm",Sound="Hiss",Color="Red"},
    EngineOverhaul={Family="Power",Name="Motor sem força",
        Cue="Resposta fraca do motor sob carga; inspeção de compressão recomendada.",
        Condition="Throttle",Sound="Engine",Color="Red"},
}

local function validSeed(seed:any):boolean
    return type(seed)=="number" and seed==math.floor(seed)
        and seed>=1 and seed<=2147483646
end

function R.IsCandidate(vehicle:any,defect:any,rookie:any):boolean
    return vehicle=="Hatch amarelo" and R.Signals[defect]~=nil
        and rookie~=true
end

-- Chamado uma única vez ao criar a OS. Seeds não entram no snapshot.
function R.Plan(vehicle:any,defect:any,rookie:any,seed:any):any
    if not validSeed(seed) then return {
        Diagnostic=false,Quality=false,Seed=0,TriggerCheckpoint=0
    } end
    if not R.IsCandidate(vehicle,defect,rookie) then
        return {Diagnostic=false,Quality=false,Seed=seed,TriggerCheckpoint=0}
    end
    local rng=Random.new(seed)
    local diag=rng:NextNumber()<R.DiagnosticChance
    local quality=rng:NextNumber()<R.QualityChance
    -- Raramente o problema só aparece mais adiante, NÃO é criado depois
    -- que o mecânico já começou a reparar. A decisão fica selada na OS.
    local intermittent=rng:NextNumber()<.12
    return {
        Diagnostic=diag,Quality=quality,Seed=seed,
        TriggerCheckpoint=intermittent and 3 or 2,
        Intermittent=intermittent,
    }
end

function R.CanRequest(plan:any,phase:any,diagnosed:any,optionsOpened:any,
    used:any,driverBusy:any): (boolean,string)
    if type(plan)~="table" or type(phase)~="string" or driverBusy then
        return false,"Test-drive indisponível ou já iniciado."
    end
    if phase=="Diagnosis" then
        if not plan.Diagnostic or diagnosed or not optionsOpened or used then
            return false,"Este diagnóstico não precisa de test-drive ou já teve tentativa."
        end
        return true,""
    elseif phase=="Quality" then
        if not plan.Quality or not diagnosed or used then
            return false,"Não há verificação pós-reparo ativa para esta OS."
        end
        return true,""
    end
    return false,"Tipo de teste inválido."
end

function R.HasCondition(signal:any,speed:any,gas:any,steer:any,elapsed:any,
    passed:any,checkpoint:any):boolean
    if type(signal)~="table" or type(speed)~="number"
        or type(gas)~="number" or type(steer)~="number"
        or type(elapsed)~="number" or type(passed)~="number"
        or type(checkpoint)~="number" then return false end
    if speed~=speed or gas~=gas or steer~=steer or elapsed~=elapsed
        or speed<0 or elapsed<0 or passed<checkpoint then return false end
    if signal.Condition=="Speed" then return speed>=15 end
    if signal.Condition=="Turn" then return speed>=10 and math.abs(steer)>=.22 end
    if signal.Condition=="Brake" then return speed>=7 and gas<=-.25 end
    if signal.Condition=="Throttle" then return speed>=8 and gas>=.35 end
    if signal.Condition=="Warm" then return elapsed>=22 and speed>=5 end
    return false
end

function R.CanConclude(passed:any,elapsed:any):boolean
    return type(passed)=="number" and passed>=4
        and type(elapsed)=="number" and elapsed>=R.MinDrivingSeconds
        and elapsed<180
end

-- O diagnóstico continua dependendo da escolha, dos exames físicos e do
-- defeito real. Este laudo apenas adiciona pista e não revela DefectId.
function R.DiagnosticEvidence(plan:any,defect:any,outcome:any):any
    if type(plan)~="table" or not plan.Diagnostic
        or type(outcome)~="table" or outcome.Kind~="Diagnosis"
        or not outcome.Complete or outcome.Reproduced~=true then return nil end
    local signal=R.Signals[defect]
    if not signal then return nil end
    local elapsed=type(outcome.Elapsed)=="number"
        and outcome.Elapsed==outcome.Elapsed and outcome.Elapsed or 0
    return {
        Id="DriveObservation",Name="Teste de rodagem",
        Text=signal.Cue,Family=signal.Family,
        Time=math.max(0,math.floor(elapsed)),
    }
end

function R.Public(plan:any,diagnosed:boolean,attempted:boolean,hasEvidence:boolean):any
    if type(plan)~="table" then return nil end
    return {
        Offered=plan.Diagnostic==true and not diagnosed and not attempted,
        Attempted=attempted==true,
        EvidenceReady=hasEvidence==true,
        MinimumSeconds=R.MinDrivingSeconds,
        TargetSeconds=R.TargetDrivingSeconds,
    }
end

return R
