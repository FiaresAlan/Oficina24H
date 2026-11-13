--!strict
-- V2-06: confirmação explícita vinculada a nível, preço, fonte e prazo.
-- Sem efeitos colaterais, moeda, identificador do cliente ou DataStore.
local Rules = {}
Rules.ConfirmSeconds = 14

export type Quote = { Kind: string, Id: string, Target: number, Cost: number, Source: string }
export type Pending = { Quote: Quote, Expires: number }

function Rules.Valid(q: any): boolean
    return type(q)=="table"
        and (q.Kind=="Building" or q.Kind=="Equipment")
        and type(q.Id)=="string" and #q.Id>0 and #q.Id<=80
        and type(q.Source)=="string" and #q.Source>0 and #q.Source<=80
        and type(q.Target)=="number" and q.Target%1==0 and q.Target>=1 and q.Target<=3
        and type(q.Cost)=="number" and q.Cost%1==0 and q.Cost>0 and q.Cost<100000000
end

function Rules.Match(left: any,right: any): boolean
    return Rules.Valid(left) and Rules.Valid(right)
        and left.Kind==right.Kind and left.Id==right.Id
        and left.Target==right.Target and left.Cost==right.Cost
        and left.Source==right.Source
end

-- Somente a SEGUNDA interação intencional para a mesma cotação autoriza cobrança.
-- A primeira nunca cobra. Expiração ou mudança de nível/preço inicia nova cotação.
function Rules.Step(previous: any, current: any, now: number): (boolean, Pending?, string)
    if not Rules.Valid(current) or type(now)~="number" or now~=now
        or now==math.huge or now==-math.huge or now<0 then
        return false,nil,"Oferta inválida."
    end
    if type(previous)=="table" and Rules.Match(previous.Quote,current)
        and type(previous.Expires)=="number" and now<=previous.Expires
        and now>=previous.Expires-Rules.ConfirmSeconds then
        return true,nil,"Compra confirmada."
    end
    return false,{Quote=table.clone(current),Expires=now+Rules.ConfirmSeconds},
        string.format("CONFIRME: %s N%d por %d moedas. Ative novamente em até %d segundos.",
            current.Id,current.Target,current.Cost,Rules.ConfirmSeconds)
end

function Rules.Benefits(current: any,nextLevel: any,maxNow: any,maxNext: any): any
    if type(current)~="table" or type(nextLevel)~="table" then return nil end
    local bays=#(current.Bays or {})
    local after=#(nextLevel.Bays or {})
    local nextEquipment=type(maxNext)=="number" and maxNext or 0
    local currentEquipment=type(maxNow)=="number" and maxNow or 0
    return {
        ExtraBays=math.max(0,after-bays),
        ExtraStaff=math.max(0,(nextLevel.MaxEmployees or 0)-(current.MaxEmployees or 0)),
        ExtraEquipment=math.max(0,nextEquipment-currentEquipment),
        CapacityBefore=bays, CapacityAfter=after,
    }
end

return Rules
