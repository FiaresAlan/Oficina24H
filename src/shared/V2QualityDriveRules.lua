--!strict
-- V2-13: revisão de qualidade ocorre DEPOIS do minijogo finalizado e
-- ANTES da liquidação única. Falha é consequência de qualidade real,
-- nunca resultado aleatório ou falha de conexão. Nenhuma 2a cobrança.
local R={}
R.MinPassQuality=70
R.MaxReworks=1
R.ReviewTimeoutSeconds=300

function R.CanOffer(plan:any,diagnosed:any,delegated:any,npc:any,
    reworkCount:any,finished:any):boolean
    return type(plan)=="table" and plan.Quality==true and diagnosed==true
        and delegated~=true and npc~=true and finished~=true
        and type(reworkCount)=="number" and reworkCount<R.MaxReworks
end

function R.NewPending(jobId:any,token:any,quality:any,at:any):any
    if type(jobId)~="string" or #jobId<1 or #jobId>80
        or type(token)~="string" or #token<16 or #token>128
        or type(quality)~="number" or quality~=quality or quality<0 or quality>100
        or type(at)~="number" then return nil end
    return {JobId=jobId,Token=token,Quality=math.floor(quality),
        State="Offer",StartedAt=at,Attempts=0,ReworkCount=0,
        LastDriveComplete=false,CompletedAt=nil}
end

function R.OnReturn(pending:any,driveResult:any,at:any): (string,string)
    if type(pending)~="table" or pending.State~="Driving"
        or type(driveResult)~="table" or driveResult.Kind~="Quality" then
        return "Rejected","Nenhuma inspeção de qualidade em curso."
    end
    local verified=driveResult.Complete==true
        and type(driveResult.Passed)=="number" and driveResult.Passed>=4
        and type(driveResult.Elapsed)=="number" and driveResult.Elapsed==driveResult.Elapsed
        and driveResult.Elapsed>=32
    if not verified then
        -- Sem punição se abortou, desconectou, bateu ou rede oscilou.
        pending.State="Offer"
        pending.LastDriveComplete=false
        return "Incomplete","Teste interrompido; você pode repetir ou entregar sem teste."
    end
    pending.LastDriveComplete=true
    pending.CompletedAt=at
    if pending.Quality<R.MinPassQuality then
        pending.State="Rework"
        return "Rework",string.format(
            "Conferência detectou execução incompleta (%d%%). Retrabalho recomendado, sem cobrança de peças.",
            pending.Quality)
    end
    pending.State="Approved"
    return "Approved",string.format(
        "Conferência aprovada com qualidade de %d%%. Entrega liberada.",
        pending.Quality)
end

function R.CanFinalize(pending:any,action:any): (boolean,string)
    if type(pending)~="table" then return false,"Sem inspeção de qualidade." end
    if action=="Skip" and pending.State=="Offer" then
        return true,"Entrega sem teste. A qualidade original será preservada."
    end
    if action=="Finalize" and (pending.State=="Approved" or pending.State=="Rework") then
        return true,pending.State=="Rework"
            and "Cliente informado da correção recomendada; nota original preservada."
            or "Inspeção concluída; entrega autorizada."
    end
    if action=="Redo" and pending.State=="Rework"
        and (pending.Attempts or 0)<R.MaxReworks then
        return true,"Reexecutar procedimento, sem cobrar peças novamente."
    end
    return false,"Ação incompatível com estado da inspeção."
end

function R.Timeout(pending:any,now:any):boolean
    return type(pending)=="table" and type(now)=="number"
        and type(pending.StartedAt)=="number"
        and now-pending.StartedAt>R.ReviewTimeoutSeconds
end

function R.Public(pending:any):any
    if type(pending)~="table" then return nil end
    local state=pending.State
    if state~="Offer" and state~="Driving" and state~="Approved"
        and state~="Rework" then return nil end
    return {
        State=state,
        Quality=pending.Quality,
        ReworkRecommended=state=="Rework",
        HasTested=pending.LastDriveComplete==true,
        ExtraCost=0,ExtraParts=0,
        MaxReworks=R.MaxReworks,
        CanSkip=state=="Offer",
        CanFinalize=state=="Approved" or state=="Rework",
        CanRedo=state=="Rework" and (pending.Attempts or 0)<R.MaxReworks,
    }
end

return R
