--!strict
-- V2-14: contrato comercial testável, preços exclusivamente de servidor,
-- comparação de contratação/estoque e relacionamento persistente.
-- QUOTE É ESTIMATIVA, não crédito ou previsão de ganho garantido.
local Catalog=require(script.Parent.Catalog)
local ContractRules=require(script.Parent.ContractRules)
local Rules={}
Rules.MaxHistory=20
Rules.MaxCreditKeys=96
Rules.ProposalSeconds=130
Rules.MaxPartnerWins=100000
Rules.Modes={
    Standard={Id="Standard",Name="Prazo normal",PayMultiplier=1,TimeMultiplier=1},
    Express={Id="Express",Name="Entrega prioritária",PayMultiplier=1.20,TimeMultiplier=.78},
}
Rules.ModeOrder={"Standard","Express"}

local function int(value:any,max:number):number
    return type(value)=="number" and value==value
        and value~=math.huge and value~=-math.huge
        and math.clamp(math.floor(value),0,max) or 0
end
local function finite(value:any):boolean
    return type(value)=="number" and value==value
        and value~=math.huge and value~=-math.huge
end
function Rules.NewAccounts()
    return {Keys={},Partners={},History={}}
end

function Rules.SanitizeAccounts(raw:any):any
    local result=Rules.NewAccounts()
    if type(raw)~="table" then return result end
    local keys=type(raw.Keys)=="table" and raw.Keys or {}
    local seen={}
    for _,key in ipairs(keys) do
        if type(key)=="string" and #key>=18 and #key<=80
            and not seen[key] then
            seen[key]=true
            table.insert(result.Keys,key)
            if #result.Keys>Rules.MaxCreditKeys then table.remove(result.Keys,1) end
        end
    end
    local partners=type(raw.Partners)=="table" and raw.Partners or {}
    for company in pairs(ContractRules.ById) do
        local p=partners[company]
        if type(p)=="table" then
            result.Partners[company]={
                Wins=int(p.Wins,Rules.MaxPartnerWins),
                Expired=int(p.Expired,Rules.MaxPartnerWins),
                Gross=int(p.Gross,2000000000),
                LastAt=int(p.LastAt,4102444800),
            }
        end
    end
    local history=type(raw.History)=="table" and raw.History or {}
    for _,entry in ipairs(history) do
        if type(entry)=="table" and ContractRules.ById[entry.Company]
            and (entry.Result=="Completed" or entry.Result=="Expired") then
            table.insert(result.History,{
                Company=entry.Company,Result=entry.Result,
                Mode=Rules.Modes[entry.Mode] and entry.Mode or "Standard",
                At=int(entry.At,4102444800),
                Done=int(entry.Done,12),Target=int(entry.Target,12),
                Gross=int(entry.Gross,2000000000),
                Bonus=int(entry.Bonus,2000000),
            })
            if #result.History>Rules.MaxHistory then table.remove(result.History,1) end
        end
    end
    return result
end

function Rules.HasCredit(accounts:any,key:any):boolean
    if type(accounts)~="table" or type(key)~="string" then return false end
    return table.find(accounts.Keys or {},key)~=nil
end

-- A mesma conta de DataStore guarda prova da concessão e saldo/rep.
-- Não existe reset/re-roll de chave pelo cliente.
function Rules.Record(accounts:any,key:any,company:any,result:any,record:any): (boolean,string)
    if type(accounts)~="table" or type(key)~="string"
        or #key<18 or #key>80 or not ContractRules.ById[company]
        or (result~="Completed" and result~="Expired")
        or type(record)~="table" then return false,"Contrato inválido." end
    if Rules.HasCredit(accounts,key) then return false,"Duplicado." end
    if #accounts.Keys>=Rules.MaxCreditKeys then table.remove(accounts.Keys,1) end
    table.insert(accounts.Keys,key)
    local partners=accounts.Partners
    local partner=partners[company] or {Wins=0,Expired=0,Gross=0,LastAt=0}
    partner.LastAt=int(record.At,4102444800)
    if result=="Completed" then
        partner.Wins=math.min(Rules.MaxPartnerWins,partner.Wins+1)
        partner.Gross=math.min(2000000000,partner.Gross+int(record.Gross,2000000000))
    else
        partner.Expired=math.min(Rules.MaxPartnerWins,partner.Expired+1)
    end
    partners[company]=partner
    table.insert(accounts.History,{
        Company=company,Result=result,Mode=Rules.Modes[record.Mode]
            and record.Mode or "Standard",
        At=partner.LastAt,Done=int(record.Done,12),
        Target=int(record.Target,12),
        Gross=int(record.Gross,2000000000),
        Bonus=result=="Completed" and int(record.Bonus,2000000) or 0,
    })
    while #accounts.History>Rules.MaxHistory do table.remove(accounts.History,1) end
    return true,"Registrado."
end

function Rules.PartnerBonus(accounts:any,company:string):number
    local p=accounts and accounts.Partners and accounts.Partners[company]
    local wins=p and int(p.Wins,Rules.MaxPartnerWins) or 0
    return math.min(.10,wins*.02)
end

function Rules.Quote(offer:any,params:any,accounts:any):any
    if type(offer)~="table" or not ContractRules.ById[offer.Company]
        or type(params)~="table" or not finite(offer.Coins)
        or not finite(offer.Seconds) or not finite(offer.Target)
        or offer.Target<1 or offer.Target>10 or offer.Seconds<120 then return nil end
    local skillLevels=type(params.Skills)=="table" and params.Skills or {}
    local equipment=type(params.Equipment)=="table" and params.Equipment or {}
    local stock=type(params.Stock)=="table" and params.Stock or {}
    local currentJobs=int(params.OpenJobs,30)
    local employees=int(params.Employees,2)
    local priceMultiplier=finite(params.PriceMultiplier)
        and math.clamp(params.PriceMultiplier,.7,1.5) or 1
    local eligible={}
    local totalPartCost,totalReward=0,0
    local sourceParts={}
    local needed={}
    for defectId,defect in pairs(Catalog.Defects) do
        if defect.Specialization==offer.Spec
            and (skillLevels[offer.Spec] or 0)>=defect.RequiredLevel
            and equipment[defect.RequiredEquipment]==true then
            table.insert(eligible,defectId)
            local unitCost=0
            for partId,count in pairs(defect.Parts or {}) do
                local part=Catalog.Parts[partId]
                unitCost+=(part and part.Cost or 0)*count
                sourceParts[partId]=true
                needed[partId]=math.max(needed[partId] or 0,count)
            end
            totalPartCost+=unitCost
            local service=Catalog.Services[defect.ServiceId]
            totalReward+=service and service.Reward or 0
        end
    end
    table.sort(eligible)
    if #eligible==0 then return nil end
    local unitParts=math.ceil(totalPartCost/#eligible)
    local averageRevenue=math.floor(totalReward/#eligible*priceMultiplier+.5)
    local units=math.min(int(offer.Target,10),10)
    local lowStock={}
    local readyTypes=0
    for partId in pairs(sourceParts) do
        local count=int(stock[partId],10000)
        if count<units then
            table.insert(lowStock,{PartId=partId,Have=count,ReferenceNeed=units})
        else
            readyTypes+=1
        end
    end
    table.sort(lowStock,function(a,b)return a.PartId<b.PartId end)
    local capacity=math.max(1,int(params.Bays,6))
    local load=math.min(1,currentJobs/math.max(1,capacity))
    local crewScore=employees>0 and "Equipe disponível" or "Sem mecânico NPC"
    local relationship=Rules.PartnerBonus(accounts,offer.Company)
    local variants={}
    for _,mode in ipairs(Rules.ModeOrder) do
        local spec=Rules.Modes[mode]
        local bonus=math.floor(offer.Coins*spec.PayMultiplier*(1+relationship)+.5)
        local seconds=math.ceil(offer.Seconds*spec.TimeMultiplier)
        local combinedRevenue=units*averageRevenue+bonus
        local referenceParts=units*unitParts
        -- Cenário custo de delegação: NPC avulso consome ~55% por OS.
        -- Mão de obra da equipe própria NÃO é zero: folha de pagamento
        -- continua contabilizada separadamente no V2FinancialRules.
        local npcCost=math.floor(units*averageRevenue*.55+.5)
        local collabCost=math.floor(units*averageRevenue*.25+.5)
        local reserve=math.max(0,int(params.SalaryReserve,999999))
        table.insert(variants,{
            Mode=mode,Name=spec.Name,
            Bonus=bonus,Reputation=offer.Reputation,
            Seconds=seconds,VehicleCount=units,
            GrossReference=combinedRevenue,
            PartsReference=referenceParts,
            OwnerContribution=combinedRevenue-referenceParts-reserve,
            CollaboratorContribution=combinedRevenue-referenceParts-collabCost-reserve,
            NpcContribution=combinedRevenue-referenceParts-npcCost-reserve,
            Risk=mode=="Express" and "Prazo curto; não aumenta a dificuldade do reparo."
                or "Prazo padrão; confirme disponibilidade de peças.",
        })
    end
    return {
        Spec=offer.Spec,Target=units,
        EligibleDefects=#eligible,
        PartTypeCount=readyTypes+#lowStock,
        LowStock=lowStock,
        ReferencePerRepair=averageRevenue,
        ReferencePartsPerRepair=unitParts,
        Staff=employees,Capacity=capacity,OpenJobs=currentJobs,
        LoadPercent=math.floor(load*100+.5),
        Crew=crewScore,
        PartnerBonusPercent=math.floor(relationship*100+.5),
        Variants=variants,
        PartnerWins=(accounts and accounts.Partners and accounts.Partners[offer.Company]
            and accounts.Partners[offer.Company].Wins) or 0,
        Disclaimer="Projeção antes da qualidade real; peça, salário e comissão do colaborador impactam margem.",
    }
end

function Rules.TermsFromQuote(base:any,quote:any,mode:any):any
    if not quote or type(quote.Variants)~="table"
        or not Rules.Modes[mode] or type(base)~="table" then return nil end
    for _,v in ipairs(quote.Variants) do
        if v.Mode==mode then
            local out=table.clone(base)
            out.Seconds=v.Seconds
            out.Coins=v.Bonus
            out.QuoteMode=mode
            out.QuoteMargin=v
            return out
        end
    end
    return nil
end

function Rules.PublicAccounts(raw:any):any
    local a=Rules.SanitizeAccounts(raw)
    local partners={}
    local completed,expired=0,0
    for _,company in ipairs(ContractRules.Companies) do
        local p=a.Partners[company.Id]
        if p then
            completed+=p.Wins
            expired+=p.Expired
            table.insert(partners,{Id=company.Id,Name=company.Name,
                Wins=p.Wins,Expired=p.Expired,
                Gross=p.Gross,LastAt=p.LastAt})
        end
    end
    return {Partners=partners,History=a.History,Completed=completed,
        Expired=expired}
end

return Rules
