--!strict
-- V2-14: propostas negociáveis de frota, estimativa de margem/estoque,
-- trabalho em equipe e recompensa com prova idempotente no mesmo perfil.
-- Nunca reconstrói cobrança de OS; trabalha APÓS a quitação normal V1.
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.Shared.Config)
local ContractRules=require(ReplicatedStorage.Shared.ContractRules)
local FleetRules=require(ReplicatedStorage.Shared.V2FleetBusinessRules)
local ProgressService=require(script.Parent.ProgressService)
local ProgressRules=require(ReplicatedStorage.Shared.ProgressRules)
local Service={}

type Contract={
    Token:number,Offer:any,Done:number,EndsAt:number,RewardKey:string,
    DoneJobs:{[string]:boolean},GrossReference:number,Methods:any,
}
local data:any=nil
local notify:((Player,string,boolean)->())?=nil
local broadcast:((string,any)->())?=nil
local rivalName:(()->string?)?=nil
local offerFor:((Player)->any)?=nil
local contracts:{[number]:Contract}={}
local proposals:{[number]:any}={}
local nextAt:{[number]:number}={}
local lastResult:{[number]:{Text:string,Success:boolean,At:number}}={}
-- Ligação ao mesmo Player que aceitou/recebeu a proposta. Não
-- armazenamos perfis, cópias de dinheiro nem tokens em snapshot público.
local playersByUserId:{[number]:Player}={}
local tokens=0

function Service.Init(dataService:any,notifier:(Player,string,boolean)->(),
    broadcaster:(string,any)->(),rival:(()->string?)?)
    data=dataService
    notify=notifier
    broadcast=broadcaster
    rivalName=rival
end

function Service.SetOfferBuilder(fn:(Player)->any)
    offerFor=fn
end

function Service.Active(userId:number):Contract?
    local c=contracts[userId]
    if c and os.time()<c.EndsAt and c.Done<c.Offer.Target then return c end
    return nil
end

function Service.WantsFleet(userId:number,inFlight:number,roll:number):Contract?
    local c=Service.Active(userId)
    if c and ContractRules.NeedsFleet(c.Done,inFlight,c.Offer.Target)
        and type(roll)=="number" and roll==roll
        and roll>=0 and roll<ContractRules.FleetChance then
        return c
    end
    return nil
end

-- V2-15: persistir antes de anunciar recompensa como CONCLUÍDA.
-- Se Save falhar, a chave/coins já estão selados em memória; no próximo
-- tick RecordFleetOutcomeOnce responde Duplicate e tentamos Save outra vez.
-- Nunca reaplicamos o prêmio ou os pontos da liga numa repetição.
local function endContract(player:Player,c:Contract,completed:boolean):boolean
    if contracts[player.UserId]~=c or not data or c.Settling then return false end
    c.Settling=true
    local record={
        Mode=c.Offer.QuoteMode or "Standard",
        At=os.time(),Done=c.Done,Target=c.Offer.Target,
        Gross=c.GrossReference,Bonus=completed and c.Offer.Coins or 0,
        Reputation=completed and c.Offer.Reputation or 0,
    }
    local added,reason=data.RecordFleetOutcomeOnce(player,c.RewardKey,
        c.Offer.Company,completed and "Completed" or "Expired",record)
    if not added and reason~="Duplicado." then
        c.Settling=false
        warn("[ContractService] Concessão pendente; perfil preservado para retry:",reason)
        return false
    end
    -- Mesmo se a conta estiver com Save intermitente, os pontos da liga
    -- só são acumulados uma vez (o perfil será salvo com o bônus).
    if completed and added and not c.LeagueCredited then
        ProgressService.AddLeague(player,ProgressRules.LeagueContractPoints)
        c.LeagueCredited=true
    end
    local ok,saved=pcall(data.Save,player)
    if not ok or not saved then
        c.Settling=false
        warn("[ContractService] Bonus aguardando Save valido. Tentara novamente:",saved)
        if notify and player.Parent==Players and not c.SaveWarned then
            notify(player,"Contrato atendido; bônus ainda aguardando confirmação do salvamento. Não saia antes da confirmação.",false)
            c.SaveWarned=true
        end
        return false
    end
    if contracts[player.UserId]~=c then return false end
    contracts[player.UserId]=nil
    nextAt[player.UserId]=os.time()+Config.ContractEverySeconds
    if completed then
        local message=string.format(
            "Contrato %s concluído: %d/%d carros. Bônus +%d moedas, +%d reputação.",
            c.Offer.Name,c.Done,c.Offer.Target,
            c.Offer.Coins,c.Offer.Reputation)
        lastResult[player.UserId]={Text=message,Success=true,At=os.time()}
        if notify then notify(player,message,true) end
        if broadcast then
            broadcast("Notice",{Message=string.format(
                "A oficina de %s concluiu o contrato da %s!",
                player.DisplayName,c.Offer.Name),Success=true})
        end
    else
        local rival=rivalName and rivalName() or nil
        local message=string.format(
            "Contrato %s venceu (%d/%d).%s Sem multa de desconexão.",
            c.Offer.Name,c.Done,c.Offer.Target,
            rival and (" Outra empresa contratou "..rival..".") or "")
        lastResult[player.UserId]={Text=message,Success=false,At=os.time()}
        if notify then notify(player,message,false) end
    end
    return true
end

-- Aceita SOMENTE OS de frota do contrato vigente e JobId único.
-- O cliente não indica payout, Company, multiplicador nem token de reparo.
function Service.FleetDone(owner:Player,token:any,jobId:any,referenceGross:any,
    method:any):boolean
    local c=contracts[owner.UserId]
    if not c or c.Token~=token or c.Settling
        or not Service.Active(owner.UserId)
        or type(jobId)~="string" or #jobId<1 or #jobId>80
        or c.DoneJobs[jobId] then return false end
    c.DoneJobs[jobId]=true
    c.Done+=1
    if type(referenceGross)=="number" and referenceGross==referenceGross
        and referenceGross~=math.huge and referenceGross~=-math.huge then
        c.GrossReference+=math.clamp(math.floor(referenceGross),0,100000)
    end
    local key=(method=="Staff" or method=="Collaborator" or method=="Npc")
        and method or "Owner"
    c.Methods[key]=(c.Methods[key] or 0)+1
    if c.Done>=c.Offer.Target then
        endContract(owner,c,true)
    elseif notify then
        notify(owner,string.format("%s: %d/%d carros da frota atendidos.",
            c.Offer.Name,c.Done,c.Offer.Target),true)
    end
    return true
end

-- Chamada automática do ciclo: gera PROPOSTA, não força compromisso.
function Service.Offer(player:Player):boolean
    if contracts[player.UserId] or proposals[player.UserId] or not offerFor
        or (nextAt[player.UserId] and os.time()<nextAt[player.UserId]) then
        return false
    end
    local offer=offerFor(player)
    if not offer or not offer.Quote or not FleetRules.TermsFromQuote(
        offer,offer.Quote,"Standard") then
        nextAt[player.UserId]=os.time()+60
        return false
    end
    tokens+=1
    playersByUserId[player.UserId]=player
    proposals[player.UserId]={
        Token=tokens,Offer=offer,ExpiresAt=os.time()+FleetRules.ProposalSeconds,
    }
    if notify then
        notify(player,string.format(
            "Nova proposta de frota — %s. Compare prazo, equipe, estoque e margem na TV de ordens; aceitar é opcional.",
            offer.Name),true)
    end
    return true
end

function Service.Negotiate(player:Player,action:any,mode:any): (boolean,string)
    if not data or not data.Get(player) then return false,"Perfil não carregado." end
    if action~="Accept" and action~="Decline" then
        return false,"Ação de contrato inválida."
    end
    local proposal=proposals[player.UserId]
    if not proposal or contracts[player.UserId] then
        return false,"Não há proposta aguardando sua decisão."
    end
    if os.time()>=proposal.ExpiresAt then
        proposals[player.UserId]=nil
        nextAt[player.UserId]=os.time()+Config.ContractEverySeconds
        return false,"Proposta expirada. Nenhuma multa foi aplicada."
    end
    if action=="Decline" then
        proposals[player.UserId]=nil
        nextAt[player.UserId]=os.time()+Config.ContractEverySeconds
        return true,"Proposta recusada sem perda de reputação."
    end
    if not FleetRules.Modes[mode] then
        return false,"Escolha prazo normal ou entrega prioritária."
    end
    local selected=FleetRules.TermsFromQuote(proposal.Offer,
        proposal.Offer.Quote,mode)
    if not selected then return false,"Cotação expirada ou inválida." end
    -- A proposta é bloqueada ANTES de gerar serviço/pagamento.
    proposals[player.UserId]=nil
    contracts[player.UserId]={
        Token=proposal.Token,RewardKey=HttpService:GenerateGUID(false),
        Offer=selected,Done=0,EndsAt=os.time()+selected.Seconds,
        DoneJobs={},GrossReference=0,
        Methods={Owner=0,Staff=0,Collaborator=0,Npc=0},
    }
    local text=string.format(
        "Contrato aceito: %s · %d carros em %d min · bônus %d moedas. Sem multa por expirar.",
        selected.Name,selected.Target,math.ceil(selected.Seconds/60),
        selected.Coins)
    if notify then notify(player,text,true) end
    return true,text
end

function Service.Snapshot(userId:number):any
    local now=os.time()
    local accountPlayer=Players:GetPlayerByUserId(userId)
        or playersByUserId[userId]
    local accounts=accountPlayer and data and data.FleetAccountSummary(accountPlayer)
        or {Partners={},History={},Completed=0,Expired=0}
    local c=Service.Active(userId)
    local settling=contracts[userId]
    if not c and settling and settling.Done>=settling.Offer.Target then
        c=settling -- mostra pendência real em vez de cartão vazio
    end
    local r=lastResult[userId]
    if r and now-r.At>30 then r=nil end
    if c then
        return {
            Active=true,Proposal=false,
            PendingSettlement=c.Done>=c.Offer.Target,
            Name=c.Offer.Name,Text=ContractRules.Text(c.Offer),
            Company=c.Offer.Company,Spec=c.Offer.Spec,Unit=c.Offer.Unit,
            Done=c.Done,Target=c.Offer.Target,
            EndsIn=math.max(0,c.EndsAt-now),
            Coins=c.Offer.Coins,Reputation=c.Offer.Reputation,
            Mode=c.Offer.QuoteMode or "Standard",
            Methods=table.clone(c.Methods),
            GrossReference=c.GrossReference,
            Financials=c.Offer.QuoteMargin,
            Quote=c.Offer.Quote,Relationships=accounts,
        }
    end
    local p=proposals[userId]
    if p and now<p.ExpiresAt then
        return {
            Active=false,Proposal=true,Name=p.Offer.Name,
            Text=ContractRules.Text(p.Offer),Spec=p.Offer.Spec,
            Target=p.Offer.Target,ExpiresIn=math.max(0,p.ExpiresAt-now),
            Quote=p.Offer.Quote,Relationships=accounts,
            Result=r,
        }
    end
    return {
        Active=false,Proposal=false,
        NextIn=nextAt[userId] and math.max(0,nextAt[userId]-now) or nil,
        Relationships=accounts,Result=r,
    }
end

-- Retentativa exclusiva do servidor após falha de Save. Não permite
-- criar nova OS ou repetir bônus; serve ao watchdog e aos testes em Edit.
function Service.RetryPending(player:Player):boolean
    local c=contracts[player.UserId]
    if not c or c.Settling then return false end
    if c.Done>=c.Offer.Target then return endContract(player,c,true) end
    if os.time()>=c.EndsAt then return endContract(player,c,false) end
    return false
end

-- QA SOMENTE em Studio/rota de comando administrativo existente.
function Service.QaOfferNow(player:Player):boolean
    if not game:GetService("RunService"):IsStudio() then return false end
    proposals[player.UserId]=nil
    contracts[player.UserId]=nil
    nextAt[player.UserId]=nil
    return Service.Offer(player)
end

function Service.Start()
    Players.PlayerRemoving:Connect(function(player)
        contracts[player.UserId]=nil
        proposals[player.UserId]=nil
        nextAt[player.UserId]=nil
        lastResult[player.UserId]=nil
        playersByUserId[player.UserId]=nil
    end)
    task.spawn(function()
        while true do
            task.wait(1)
            local now=os.time()
            for _,player in ipairs(Players:GetPlayers()) do
                local id=player.UserId
                local profile=data and data.Get(player)
                if not profile then continue end
                local c=contracts[id]
                local p=proposals[id]
                if c then
                    Service.RetryPending(player)
                elseif p then
                    if now>=p.ExpiresAt then
                        proposals[id]=nil
                        nextAt[id]=now+Config.ContractEverySeconds
                        if notify then
                            notify(player,"Proposta de frota expirou; nenhuma penalidade.",false)
                        end
                    end
                elseif profile.Onboarding and profile.Onboarding.Done then
                    if not nextAt[id] then
                        nextAt[id]=now+Config.ContractFirstDelaySeconds
                    elseif now>=nextAt[id] then
                        Service.Offer(player)
                    end
                end
            end
        end
    end)
end

return Service
