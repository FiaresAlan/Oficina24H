--!strict
-- V2-08: caixa por categoria; não confundir fluxo com lucro de competência.
-- Única fonte de dinheiro é DataService.AddCoins (já protegida pela V1).
local Catalog=require(script.Parent.Catalog)
local Rules={}
Rules.Categories={
    Service="Service",Inventory="Inventory",Payroll="Payroll",
    Marketing="Marketing",Equipment="Equipment",Building="Building",
    Hiring="Hiring",Rewards="Rewards",Other="Other",
}
Rules.CategoryOrder={"Service","Inventory","Payroll","Marketing",
    "Equipment","Building","Hiring","Rewards","Other"}
Rules.MaxMoney=1000000000000
Rules.MaxRecent=50
Rules.MaxEntries=100000000
local function finite(v: any): boolean
    return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
local function int(v: any, hi: number): number
    return finite(v) and math.floor(math.clamp(v,0,hi)) or 0
end
local function bucket(name: string)
    return {In=0,Out=0}
end
local function base(opening: any,since: any,partial: boolean): any
    local groups={}
    for _,name in ipairs(Rules.CategoryOrder) do groups[name]=bucket(name) end
    return { Since=int(since,4102444800),OpeningBalance=int(opening,Rules.MaxMoney),
        CashIn=0,CashOut=0,Count=0,LegacyWindow=partial==true,Groups=groups }
end
function Rules.Category(reason: any,delta: any): string
    local r=type(reason)=="string" and reason or ""
    if string.find(r,"^Liquidação de OS:") then return "Service" end
    if string.find(r,"^Peças:") or r=="Loja de peças" then return "Inventory" end
    if string.find(r,"^Salário dos funcionários") then return "Payroll" end
    if string.find(r,"^Publicidade:") then return "Marketing" end
    if string.find(r,"^Melhoria:") or string.find(r,"^Compra:") then return "Equipment" end
    if string.find(r,"^Ampliação da oficina:") then return "Building" end
    if string.find(r,"^Contratação de mecânico") then return "Hiring" end
    if string.find(r,"^Bônus do primeiro serviço")
        or string.find(r,"^Conquista:") or string.find(r,"^Missão:")
        or string.find(r,"^Recompensa diária") or string.find(r,"^Liga semanal:")
        or string.find(r,"^Código ") then return "Rewards" end
    return "Other"
end
function Rules.New(opening: number,at: number): any
    return base(opening,at,false)
end
function Rules.Apply(book: any,amount: any,reason: any): (boolean,string?)
    if type(book)~="table" or not finite(amount) or amount%1~=0
        or math.abs(amount)>Rules.MaxMoney or amount==0 then return false,nil end
    if type(book.Groups)~="table" then return false,nil end
    local group=Rules.Category(reason,amount)
    local b=book.Groups[group]
    if not b or not finite(b.In) or not finite(b.Out)
        or not finite(book.CashIn) or not finite(book.CashOut) then return false,nil end
    if book.Count>=Rules.MaxEntries then return false,nil end
    local n=math.abs(amount)
    if amount>0 then
        if b.In+n>Rules.MaxMoney or book.CashIn+n>Rules.MaxMoney then return false,nil end
        b.In+=n;book.CashIn+=n
    else
        if b.Out+n>Rules.MaxMoney or book.CashOut+n>Rules.MaxMoney then return false,nil end
        b.Out+=n;book.CashOut+=n
    end
    book.Count+=1
    return true,group
end
function Rules.Sanitize(data: any,opening: number,at: number): any
    if type(data)~="table" or type(data.Groups)~="table" then
        return Rules.New(opening,at)
    end
    local clean=base(data.OpeningBalance,data.Since,data.LegacyWindow==true)
    clean.CashIn=int(data.CashIn,Rules.MaxMoney)
    clean.CashOut=int(data.CashOut,Rules.MaxMoney)
    clean.Count=int(data.Count,Rules.MaxEntries)
    local inGroups,outGroups=0,0
    for _,name in ipairs(Rules.CategoryOrder) do
        local value=type(data.Groups[name])=="table" and data.Groups[name] or {}
        local received=int(value.In,Rules.MaxMoney)
        local paid=int(value.Out,Rules.MaxMoney)
        clean.Groups[name]={In=received,Out=paid}
        inGroups+=received
        outGroups+=paid
    end
    -- Never invent an aggregate when corrupted data disagrees. A partial
    -- journal is safer than misreporting a larger false financial total.
    if inGroups~=clean.CashIn or outGroups~=clean.CashOut then
        clean.CashIn=math.min(inGroups,Rules.MaxMoney)
        clean.CashOut=math.min(outGroups,Rules.MaxMoney)
        clean.LegacyWindow=true
    end
    return clean
end
function Rules.Bootstrap(transactions: any,currentBalance: number,at: number): any
    local entries=type(transactions)=="table" and transactions or {}
    local first=entries[1]
    local opening=int(currentBalance,Rules.MaxMoney)
    if type(first)=="table" and finite(first.Balance) and finite(first.Amount) then
        opening=int(first.Balance-first.Amount,Rules.MaxMoney)
    end
    local since=type(first)=="table" and int(first.At,4102444800) or at
    local book=base(opening,since,true)
    for i,e in ipairs(entries) do
        if i>Rules.MaxRecent then break end
        if type(e)=="table" then
            Rules.Apply(book,e.Amount,e.Reason)
        end
    end
    return book
end
function Rules.CleanTransactions(transactions: any): {any}
    local clean={}
    if type(transactions)~="table" then return clean end
    for _,item in ipairs(transactions) do
        if type(item)=="table" and finite(item.Amount) and item.Amount%1==0
            and math.abs(item.Amount)<=Rules.MaxMoney and item.Amount~=0
            and finite(item.Balance) and item.Balance>=0
            and item.Balance<=Rules.MaxMoney then
            table.insert(clean,{
                At=int(item.At,4102444800),
                Amount=item.Amount,
                Balance=int(item.Balance,Rules.MaxMoney),
                Reason=type(item.Reason)=="string" and string.sub(item.Reason,1,96) or "",
                Category=Rules.Category(item.Reason,item.Amount),
            })
        end
    end
    while #clean>Rules.MaxRecent do table.remove(clean,1) end
    return clean
end
function Rules.PartCost(parts: any): number
    local total=0
    if type(parts)~="table" then return total end
    for id,qty in pairs(parts) do
        local p=Catalog.Parts[id]
        if p and finite(qty) and qty>=0 and qty%1==0 and qty<=100 then
            total+=p.Cost*qty
        end
    end
    return math.floor(math.min(total,Rules.MaxMoney))
end
function Rules.ServiceQuotes(multiplier: any): {any}
    local m=finite(multiplier) and math.clamp(multiplier,0.7,1.5) or 1
    local rows={}
    for id,service in pairs(Catalog.Services) do
        local defect=Catalog.Defects[service.DefectId]
        if defect then
            local partCost=Rules.PartCost(defect.Parts)
            local basePrice=math.floor(service.Reward*m+0.5)
            table.insert(rows,{
                Id=id,Name=service.DisplayName,BasePrice=basePrice,
                PartsReferenceCost=partCost,BeforeLabor=basePrice-partCost,
                Specialization=defect.Specialization,
            })
        end
    end
    table.sort(rows,function(a,b)
        if a.BeforeLabor==b.BeforeLabor then return a.Id<b.Id end
        return a.BeforeLabor<b.BeforeLabor
    end)
    return rows
end
-- Reposição baseada SOMENTE em OS diagnosticadas e demanda recente visível.
-- Não reserva estoque, não compra nada e não adivinha defeitos ocultos.
function Rules.Restock(profile: any,jobs: any): any
    local p=type(profile)=="table" and profile or {}
    local stock=type(p.Parts)=="table" and p.Parts or {}
    local required,historyUsage,historyCount={}, {},0
    for _,job in ipairs(type(jobs)=="table" and jobs or {}) do
        if type(job)=="table" and job.Status=="InProgress" and job.Diagnosed==true
            and type(job.Requirement)=="table" then
            for id,qty in pairs(job.Requirement.Parts or {}) do
                if Catalog.Parts[id] and finite(qty) and qty%1==0 and qty>0 and qty<=100 then
                    required[id]=(required[id] or 0)+qty
                end
            end
        end
    end
    local serviceNames={}
    for _,service in pairs(Catalog.Services) do serviceNames[service.DisplayName]=service end
    for _,h in ipairs(type(p.OrderHistory)=="table" and p.OrderHistory or {}) do
        if historyCount>=30 then break end
        if type(h)=="table" then
            local service=type(h.Service)=="string" and serviceNames[h.Service]
            local defect=service and Catalog.Defects[service.DefectId]
            if defect then
                for id,qty in pairs(defect.Parts or {}) do
                    historyUsage[id]=(historyUsage[id] or 0)+qty
                end
                historyCount+=1
            end
        end
    end
    local lines,total,urgentCost={},0,0
    for id,part in pairs(Catalog.Parts) do
        local owned=int(stock[id],1000000)
        local reserved=int(required[id],1000000)
        -- Reserva recomendada para os PRÓXIMOS dois serviços, proporcional
        -- ao histórico disponível. Não é previsão infalível nem mínimo obrigatório.
        local buffer=historyCount>0 and math.ceil(2*(historyUsage[id] or 0)/historyCount) or 0
        local toBuy=math.max(0,reserved+buffer-owned)
        if toBuy>0 then
            local shortage=math.max(0,reserved-owned)
            table.insert(lines,{
                Id=id,Name=part.DisplayName,OnHand=owned,
                Required=reserved,MissingForJobs=shortage,
                SuggestedBuffer=buffer,Quantity=toBuy,Cost=toBuy*part.Cost,
            })
            total+=toBuy*part.Cost
            urgentCost+=shortage*part.Cost
        end
    end
    table.sort(lines,function(a,b)
        if a.MissingForJobs~=b.MissingForJobs then return a.MissingForJobs>b.MissingForJobs end
        if a.Cost~=b.Cost then return a.Cost>b.Cost end
        return a.Id<b.Id
    end)
    return {Items=lines,TotalCost=total,UrgentCost=urgentCost,
        HistoryServices=historyCount}
end

function Rules.Snapshot(book: any, profile: any,now: number,employeeSalary: number,jobs: any?): any
    local p=type(profile)=="table" and profile or {}
    local b=Rules.Sanitize(book,p.Coins,now)
    local groups={}
    for _,name in ipairs(Rules.CategoryOrder) do
        local v=b.Groups[name]
        groups[name]={In=v.In,Out=v.Out}
    end
    local operationIn=groups.Service.In
    local operationOut=groups.Inventory.Out+groups.Payroll.Out+groups.Marketing.Out
    local operatingCash=operationIn-operationOut
    local cashDelta=b.CashIn-b.CashOut
    local stockCost=Rules.PartCost(p.Parts)
    local bagCost=Rules.PartCost(p.Bag)
    local employees=int(p.Employees,2)
    local payable=employees*int(employeeSalary,100000)
    local available=int(p.Coins,Rules.MaxMoney)
    local nextPay=payable>0 and int(p.NextPayAt,4102444800) or 0
    local reserve=payable
    local restock=Rules.Restock(p,jobs)
    local warning=""
    if available<reserve then warning="CAIXA INSUFICIENTE PARA PRÓXIMA FOLHA"
    elseif restock.UrgentCost>0 and available-reserve<restock.UrgentCost then
        warning="FALTA CAIXA PARA PEÇAS DE ORDENS EM ANDAMENTO"
    elseif operatingCash<0 and b.Count>=2 then warning="FLUXO OPERACIONAL NEGATIVO NO PERÍODO"
    elseif b.LegacyWindow then warning="HISTÓRICO ANTIGO PARCIAL: EXIBINDO APENAS LANÇAMENTOS DISPONÍVEIS"
    end
    local recent=Rules.CleanTransactions(p.Transactions)
    return {
        Since=b.Since,LegacyWindow=b.LegacyWindow,TransactionsCount=b.Count,
        CashIn=b.CashIn,CashOut=b.CashOut,CashDelta=cashDelta,
        ServiceReceipts=operationIn,OperatingOut=operationOut,
        OperatingCash=operatingCash,NonOperatingIn=b.CashIn-operationIn,
        NonOperatingOut=b.CashOut-operationOut,Groups=groups,
        Cash=available,StockReferenceValue=stockCost+bagCost,
        NextPayroll=payable,NextPayAt=nextPay,
        AvailableAfterPayroll=available-reserve,Warning=warning,
        Recent=recent,Quotes=Rules.ServiceQuotes(p.PriceMultiplier),Restock=restock,
        -- Nunca alegar lucro contábil: custos de peça de estoque legado
        -- não são rastreados por lote e o caixa inclui CAPEX não amortizado.
        AccountingProfitAvailable=false,
    }
end
return Rules
