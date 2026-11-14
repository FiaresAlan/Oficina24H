-- V2-15: limites globais dos remotes, payloads profundos, NaN, spam,
-- referências cíclicas e snapshot sem punir chamadas normais da UI.
local R=require(game.ReplicatedStorage.Shared.V2RemoteSecurityRules)
local out={}
local function check(name,yes)table.insert(out,(yes and "PASS " or "FAIL ")..name)end
check("payload vazio e ação econômica tipada são aceitos",
    R.PayloadValid({}) and R.PayloadValid({
        JobId="job_123",Presses={Token="test_123",
            Attempts={{Time=.3,Accuracy=.94},{Time=.6,Accuracy=.7}}},
    }))
check("rejeita valor NaN, infinidade e tipo Roblox Instance",
    not R.PayloadValid({Quantity=0/0})
    and not R.PayloadValid({Multiplier=math.huge})
    and not R.PayloadValid({Target=Instance.new("Part")}))
check("não aceita payload de tipo primitivo",
    not R.PayloadValid("BuyPart") and not R.PayloadValid(nil))
local large=string.rep("x",R.MaxString+1)
check("texto excessivo e chave excessiva não chegam ao servidor",
    not R.PayloadValid({Code=large})
    and not R.PayloadValid({[string.rep("x",65)]=1}))
local wide={}
for i=1,R.MaxNodes+1 do wide[i]=i end
check("array gigantesco recusado antes de alocar recursos",
    not R.PayloadValid(wide))
local nested={Code=3}
for _=1,R.MaxDepth do nested={Value=nested} end
check("recusa profundidade excessiva",
    not R.PayloadValid(nested))
local circular={}
circular.Myself=circular
check("recusa ciclo que provocaria CPU infinita",
    not R.PayloadValid(circular))
local shared={Amount=1}
check("recusa ponteiro compartilhado que pode conter estrutura falsa",
    not R.PayloadValid({First=shared,Second=shared}))
check("chaves numéricas esparsas inválidas ou não finitas",
    not R.PayloadValid({[0]="hack"})
    and not R.PayloadValid({[math.huge]="hack"})
    and not R.PayloadValid({[-1]="hack"}))
local bucket=nil
local allowed=0
for i=1,100 do
    local ok,nextState=R.ConsumeAction(bucket,10)
    if ok then allowed+=1 end
    bucket=nextState
end
check("rajada global aceita no máximo 44 comandos por jogador",
    allowed==R.ActionBurst and bucket.Tokens==0)
local exhausted,b=R.ConsumeAction(bucket,10.01)
check("limite rejeita rajada sem punir ou alterar estado financeiro",
    not exhausted and b.Tokens>0 and b.Tokens<1)
local recovered,refilled=R.ConsumeAction(b,11)
check("tokens retornam pelo tempo do servidor",
    recovered and refilled.Tokens>0)
local s=nil
local count=0
for i=1,50 do
    local ok,nextS=R.ConsumeSnapshot(s,1)
    if ok then count+=1 end
    s=nextS
end
check("snapshots não podem reconstruir UI sem limite",
    count==R.SnapshotBurst and s.Tokens==0)
check("snapshot legítimo liberado após recuperação",
    (function()
        local ok=R.ConsumeSnapshot(s,2)
        return ok
    end)())
check("orçamento rejeita relógios/valores forjados",
    not R.ConsumeAction(nil,0/0)
    and not R.ConsumeAction(nil,-1)
    and not R.Consume(nil,1,0,10,1)
    and not R.Consume(nil,1,10,10,0))
return table.concat(out,"\n")
