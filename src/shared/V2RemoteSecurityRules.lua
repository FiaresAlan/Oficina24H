--!strict
-- V2-15: anti-flood e anti-payload malformado das interfaces remotas.
-- Regra PURA: sem Instances/serviços. Limita trabalho do servidor
-- antes de acessar Shop/OS/DataStore; não concede crédito por si.
local R={}
R.MaxNodes=120
R.MaxDepth=5
R.MaxString=512
R.ActionBurst=44
R.ActionPerSecond=26
R.SnapshotBurst=12
R.SnapshotPerSecond=8

local function finite(v:any):boolean
    return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
function R.PayloadValid(data:any):(boolean,string)
    if type(data)~="table" then return false,"Payload precisa ser tabela." end
    local seen={}
    local nodes=0
    local function check(v:any,depth:number):(boolean,string)
        if depth>R.MaxDepth then return false,"Profundidade excedida." end
        local kind=typeof(v)
        if kind=="number" then
            if not finite(v) then return false,"Número não finito." end
            return true,""
        end
        if kind=="string" then
            if #v>R.MaxString then return false,"Texto excessivo." end
            return true,""
        end
        if kind=="boolean" or kind=="nil" then return true,"" end
        if kind~="table" then return false,"Tipo não permitido." end
        if seen[v] then return false,"Tabela circular ou repetida." end
        seen[v]=true
        for k,value in pairs(v) do
            nodes+=1
            if nodes>R.MaxNodes then return false,"Muitas entradas." end
            if type(k)=="string" then
                if #k>64 then return false,"Chave excessiva." end
            elseif type(k)=="number" then
                if not finite(k) or k%1~=0 or k<1 or k>R.MaxNodes then
                    return false,"Índice inválido."
                end
            else
                return false,"Chave inválida."
            end
            local ok,reason=check(value,depth+1)
            if not ok then return ok,reason end
        end
        return true,""
    end
    return check(data,1)
end

function R.Consume(bucket:any,now:any,rate:any,burst:any,cost:any):(boolean,any)
    if not finite(now) or now<0 or not finite(rate) or rate<=0
        or not finite(burst) or burst<=0 or not finite(cost)
        or cost<=0 or cost>burst then return false,bucket end
    local prior=type(bucket)=="table" and bucket or nil
    local previousTime=prior and prior.At
    local previousTokens=prior and prior.Tokens
    local delta=finite(previousTime) and math.max(0,now-previousTime) or 0
    local tokens=finite(previousTokens)
        and math.clamp(previousTokens+delta*rate,0,burst) or burst
    local accepted=tokens>=cost
    if accepted then tokens-=cost end
    return accepted,{At=now,Tokens=tokens}
end

function R.ConsumeAction(bucket:any,now:any):(boolean,any)
    return R.Consume(bucket,now,R.ActionPerSecond,R.ActionBurst,1)
end
function R.ConsumeSnapshot(bucket:any,now:any):(boolean,any)
    return R.Consume(bucket,now,R.SnapshotPerSecond,R.SnapshotBurst,1)
end

return R
