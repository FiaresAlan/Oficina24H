-- V2-13: qualidade deriva do resultado real do minijogo e nunca de
-- sorteio, remoto, tempo reportado pelo cliente ou falha de rede.
local R=require(game.ReplicatedStorage.Shared.V2QualityDriveRules)
local out={}
local function check(name,ok)table.insert(out,(ok and "PASS " or "FAIL ")..name)end
local yes={Diagnostic=true,Quality=true}
local no={Diagnostic=true,Quality=false}
check("somente OS elegível recebe revisão opcional",
    R.CanOffer(yes,true,false,false,0,false)
    and not R.CanOffer(no,true,false,false,0,false)
    and not R.CanOffer(yes,false,false,false,0,false))
check("não obriga colaborador, funcionário NPC ou OS quitada",
    not R.CanOffer(yes,true,true,false,0,false)
    and not R.CanOffer(yes,true,false,true,0,false)
    and not R.CanOffer(yes,true,false,false,0,true))
check("no máximo um retrabalho",
    R.CanOffer(yes,true,false,false,0,false)
    and not R.CanOffer(yes,true,false,false,1,false))
local job="job_98765432101234"
local token=string.rep("a",36)
local pending=R.NewPending(job,token,61,1000)
check("resultado selado preserva token, nota e estado",
    pending and pending.JobId==job and pending.Token==token
    and pending.Quality==61 and pending.State=="Offer")
check("token inválido ou qualidade falsa rejeitados",
    R.NewPending(job,"short",80,10)==nil
    and R.NewPending(job,token,0/0,10)==nil
    and R.NewPending(job,token,101,10)==nil)
check("pode dispensar revisão sem punição de rede",
    R.CanFinalize(pending,"Skip")
    and not R.CanFinalize(pending,"Finalize"))
pending.State="Driving"
local status,msg=R.OnReturn(pending,{
    Kind="Quality",Complete=false,Passed=2,Elapsed=19,
},1040)
check("colisão ou abortos apenas restauram oferta",
    status=="Incomplete" and pending.State=="Offer"
    and pending.LastDriveComplete==false
    and R.CanFinalize(pending,"Skip"))
pending.State="Driving"
status,msg=R.OnReturn(pending,{
    Kind="Quality",Complete=true,Passed=4,Elapsed=50,
},1100)
check("reparo 61% verificado recomenda retrabalho por causa real",
    status=="Rework" and pending.State=="Rework"
    and pending.CompletedAt==1100 and pending.LastDriveComplete)
check("sem cobrança ou reembolso independente da liquidação original",
    pending.Coins==nil and pending.XP==nil
    and pending.Parts==nil and pending.Penalty==nil)
check("jogador pode refazer com limite e sem consumo adicional",
    R.CanFinalize(pending,"Redo") and R.CanFinalize(pending,"Finalize")
    and not R.CanFinalize(pending,"Skip"))
local public=R.Public(pending)
check("interface revela preço zero e motivos legíveis",
    public and public.State=="Rework" and public.ReworkRecommended
    and public.ExtraCost==0 and public.ExtraParts==0
    and public.CanRedo and public.CanFinalize)
check("snapshot não expõe token/seed nem credita reparo",
    public.Token==nil and public.RepairReceipt==nil
    and public.JobId==nil and public.Reward==nil)
pending.Attempts=1
check("não permite múltiplos retrabalhos do mesmo reparo",
    not R.CanFinalize(pending,"Redo"))
local good=R.NewPending(job,token,85,400)
good.State="Driving"
local approved,msg2=R.OnReturn(good,{
    Kind="Quality",Complete=true,Passed=4,Elapsed=57,
},460)
check("boa qualidade comprovada aprova, sem bônus automático",
    approved=="Approved" and good.State=="Approved"
    and R.CanFinalize(good,"Finalize")
    and good.Bonus==nil and good.Reward==nil)
check("não aceita evento de diagnóstico como inspeção pós-reparo",
    R.OnReturn(good,{Kind="Diagnosis",Complete=true,Passed=4,Elapsed=60},470)=="Rejected")
check("QA incompleta não pode forjar aprovação de nota baixa",
    (function()
        local low=R.NewPending(job,token,35,0)
        low.State="Driving"
        local verdict=R.OnReturn(low,{
            Kind="Quality",Complete=true,Passed=2,Elapsed=12,
        },80)
        return verdict=="Incomplete" and low.State=="Offer"
    end)())
check("timeout de 5min libera fallback neutro",
    not R.Timeout(pending,1100)
    and R.Timeout(pending,1301))
check("estados de revisão desconhecidos não produzem botões",
    R.Public({State="PayWithoutLedger"})==nil
    and not R.CanFinalize(pending,"FreeMoney"))
check("nota limite tem resultado reproduzível e previsível",
    (function()
        local q=R.NewPending(job,token,R.MinPassQuality,10)
        q.State="Driving"
        local result=R.OnReturn(q,{
            Kind="Quality",Complete=true,Passed=4,Elapsed=45,
        },55)
        return result=="Approved"
    end)())
return table.concat(out,"\n")
