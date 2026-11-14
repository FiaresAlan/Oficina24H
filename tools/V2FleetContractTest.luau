-- V2-14: contrato gerenciado no servidor; acceptance por proposta,
-- JobId único, comissão/funcionário/NPC e bônus só na OS final.
-- Isolado em Studio Edit com perfil falso (nunca toca DataStore real).
local Players=game:GetService("Players")
local Rules=require(game.ReplicatedStorage.Shared.V2FleetBusinessRules)
local Contract=require(game.ServerScriptService.Server.ContractService)
local t={}
local function check(n,ok)table.insert(t,(ok and "PASS " or "FAIL ")..n)end
local user={UserId=9283741,DisplayName="Operador V2",Parent=Players}
local data={Accounts=Rules.NewAccounts(),Credits=0,Reputation=0,Saves=0}
function data.Get(player)
    if player~=user then return nil end
    return {Onboarding={Done=true},FleetAccounts=data.Accounts}
end
function data.FleetAccountSummary(player)
    return Rules.PublicAccounts(data.Accounts)
end
function data.RecordFleetOutcomeOnce(player,key,company,status,record)
    if player~=user then return false,"Usuário divergente." end
    local ok,reason=Rules.Record(data.Accounts,key,company,status,record)
    if ok and status=="Completed" then
        data.Credits+=record.Bonus
        data.Reputation+=record.Reputation
    end
    return ok,reason
end
function data.Save(player)
    data.Saves+=1
    return true
end
local notifications={}
Contract.Init(data,function(_,message,ok)
    table.insert(notifications,{Text=message,Ok=ok})
end,function()end,function()return nil end)
Contract.SetOfferBuilder(function()
    local base={
        Company="taxi",Name="Táxi Veloz",Spec="Tires",Unit="reparos de pneu",
        Target=3,Seconds=520,Coins=300,Reputation=4,
    }
    base.Quote=Rules.Quote(base,{
        Skills={Tires=3},Equipment={BasicToolset=true,TireMachine=true},
        Stock={TirePatch=6,Tire=6},Employees=1,Bays=2,OpenJobs=0,
        SalaryReserve=40,PriceMultiplier=1,
    },data.Accounts)
    return base
end)
check("oferta vira proposta, sem contrato nem bônus automático",Contract.Offer(user)
    and Contract.Active(user.UserId)==nil and data.Credits==0)
check("proposta visível somente por status e preço autorizado",
    (function()
        local snap=Contract.Snapshot(user.UserId)
        return snap.Proposal and not snap.Active and snap.Quote~=nil
            and snap.RewardKey==nil and snap.Token==nil
    end)())
check("não aceita preço/mode forjados pelo cliente",
    (function()
        local ok=Contract.Negotiate(user,"Accept","Boost999")
        return not ok and Contract.Active(user.UserId)==nil
    end)())
local accepted=Contract.Negotiate(user,"Accept","Express")
local active=Contract.Active(user.UserId)
check("aceite troca prazo e bônus pelo catálogo do servidor",
    accepted and active and active.Offer.Coins>300
    and active.Offer.Seconds<520 and active.Offer.QuoteMode=="Express")
check("replay de aceite após proposta consumida é negado",
    not Contract.Negotiate(user,"Accept","Standard"))
local token=active and active.Token
check("contrato não avança com token vencido ou sem JobId",
    not Contract.FleetDone(user,(token or 0)+1,"job-1",100,"Owner")
    and not Contract.FleetDone(user,token,"",100,"Owner")
    and active.Done==0)
check("colaborador liquidado conta um carro válido",
    Contract.FleetDone(user,token,"job-1",210,"Collaborator")
    and active.Done==1 and active.Methods.Collaborator==1)
check("replay do mesmo JobId não aumenta progresso nem dinheiro",
    not Contract.FleetDone(user,token,"job-1",210,"Collaborator")
    and active.Done==1 and data.Credits==0)
check("funcionário liquidado também conta",Contract.FleetDone(user,token,
    "job-2",200,"Staff") and active.Done==2 and active.Methods.Staff==1)
check("última OS válida libera exatamente um prêmio",
    Contract.FleetDone(user,token,"job-3",190,"Owner")
    and Contract.Active(user.UserId)==nil and data.Credits==active.Offer.Coins
    and data.Reputation==active.Offer.Reputation
    and active.Methods.Owner==1)
check("conclusão repetida não paga duas vezes",
    not Contract.FleetDone(user,token,"job-3",190,"Owner")
    and data.Credits==active.Offer.Coins and #data.Accounts.Keys==1)
check("histórico do parceiro e methods preservados no snapshot",
    (function()
        local result=Contract.Snapshot(user.UserId)
        return result.Relationships.Completed==1
            and result.Relationships.Partners[1].Wins==1
            and result.Relationships.History[1].Gross==600
            and result.Relationships.Keys==nil
    end)())
check("contrato só pode oferecer outro após limpeza de proposta",
    not Contract.Offer(user))
-- QA não precisa criar novo jogador: chaves de bônus já garantem
-- persistência; a oferta proposta pode ser recusada sem multas.
check("proposta QA substitui estado anterior só no Studio",
    Contract.QaOfferNow(user) and Contract.Snapshot(user.UserId).Proposal)
check("recusa de proposta não altera saldo/rep",
    Contract.Negotiate(user,"Decline","")
    and data.Credits==active.Offer.Coins
    and data.Reputation==active.Offer.Reputation)
check("idempotência registrada em contas privadas",
    Rules.HasCredit(data.Accounts,data.Accounts.Keys[1])
    and not Rules.HasCredit(data.Accounts,"fake"))
return table.concat(t,"\n")
