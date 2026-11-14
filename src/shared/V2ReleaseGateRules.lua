--!strict
-- V2-16: matriz PURA de go/no-go para o proprietário e a homologação.
-- Isto NÃO autoriza publicação, não ativa fases V2-12/13 e não
-- concede ao cliente poderes de alterar evidências ou economias.
local Rules = {}

Rules.Version = 1
Rules.Gates = {
    {Id="ci_code",       Category="Engenharia",    Title="Contratos estáticos e Rojo no commit da release", Source="CI"},
    {Id="merge_main",    Category="Integração",    Title="PR sem conflitos contra main atual e diffs V1 revisados", Source="GitHub"},
    {Id="studio_suites", Category="Studio",       Title="RunAllTests e StudioPlaceAudit sem falhas", Source="Studio"},
    {Id="assets_place",  Category="Assets",       Title="Assets importados no place final, scripts externos removidos", Source="Studio"},
    {Id="services_15",   Category="Jogabilidade", Title="15 reparos completos com avaliação e recibo únicos", Source="Studio"},
    {Id="onboarding",    Category="Jogabilidade", Title="Novo jogador, primeira OS e primeiro upgrade testados", Source="Studio"},
    {Id="cooperation",   Category="Multiplayer",  Title="Dois jogadores, convite, NPC, funcionário e saída em OS", Source="Studio"},
    {Id="data_safety",   Category="Economia",     Title="DataStore: Save/Load, replay, saldo, rep, claim e rollback", Source="Studio"},
    {Id="inventory_fifo",Category="Economia",    Title="Fornecedores Econômico/Padrão/Premium e lotes FIFO V2-08",Source="Studio"},
    {Id="drive_physics", Category="Física",       Title="Hatch real: torque, câmera, checkpoints, colisão, retorno seguro",Source="Studio"},
    {Id="touch_gamepad", Category="Acessibilidade",Title="Celular, touch, gamepad, HUD e modo sem áudio",Source="Studio"},
    {Id="performance",   Category="Desempenho",   Title="FPS/memória/latência medidos em dispositivos alvo",Source="Studio"},
    {Id="stream_audio",  Category="Ambiente",     Title="StreamingEnabled, música, efeitos e animações testados",Source="Studio"},
    {Id="licenses",      Category="Legal",        Title="HUD/ícones/modelos/marcas e atribuições com direito comprovado",Source="Legal"},
    {Id="beta_closed",   Category="Beta",         Title="Beta fechado, métricas e bugs P0/P1 resolvidos",Source="Beta"},
    {Id="owner_go",      Category="Decisão",      Title="Autorização explícita do proprietário para o build final",Source="Owner"},
}

Rules.ValidStates = {Pending=true,Passed=true,Failed=true,Blocked=true}

function Rules.NewEvidence():any
    local entries={}
    for _,gate in ipairs(Rules.Gates) do
        entries[gate.Id]={
            Status="Pending", Source="", Proof="", Notes="",
            VerifiedAt="", BuildSha="",
        }
    end
    return {Version=Rules.Version,Entries=entries}
end

local function isSha(value:any):boolean
    return type(value)=="string" and (#value==40 or #value==64)
        and string.match(value,"^[0-9a-fA-F]+$")~=nil
end

local function validLink(value:any):boolean
    return type(value)=="string" and #value>=18 and #value<=1000
        and (string.match(value,"^https://[^%s]+$")~=nil
            or string.match(value,"^studio://[%w%-%._/]+$")~=nil)
end

function Rules.ValidProof(gate:any,entry:any,headSha:any): (boolean,string)
    if type(gate)~="table" or type(entry)~="table" then
        return false,"Prova ausente."
    end
    if entry.Status~="Passed" then
        return false,"Aguardando evidência aprovada."
    end
    if entry.Source~=gate.Source then
        return false,"A fonte da evidência não corresponde ao gate."
    end
    if not validLink(entry.Proof) then
        return false,"A evidência precisa de referência verificável."
    end
    if type(entry.Notes)~="string" or #entry.Notes<12 then
        return false,"Incluir descrição verificável do teste."
    end
    if type(entry.VerifiedAt)~="string"
        or string.match(entry.VerifiedAt,"^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$")==nil then
        return false,"Falta horário ISO UTC do teste."
    end
    if not isSha(entry.BuildSha) or entry.BuildSha~=headSha then
        return false,"A prova refere-se a um commit anterior ou inválido."
    end
    return true,""
end

function Rules.Evaluate(evidence:any,headSha:any):any
    local result={
        Approved=false,Version=Rules.Version,
        Total=#Rules.Gates,Passed=0,Failed=0,Blocked=0,Pending=0,Problems={},
    }
    if not isSha(headSha) then
        table.insert(result.Problems,"SHA alvo ausente ou inválido.")
        result.Pending=#Rules.Gates
        return result
    end
    if type(evidence)~="table" or evidence.Version~=Rules.Version
        or type(evidence.Entries)~="table" then
        table.insert(result.Problems,"Manifest de evidências ausente ou incompatível.")
        result.Pending=#Rules.Gates
        return result
    end
    for _,gate in ipairs(Rules.Gates) do
        local entry=evidence.Entries[gate.Id]
        local state=type(entry)=="table" and entry.Status or "Pending"
        if not Rules.ValidStates[state] then state="Failed" end
        if state=="Passed" then
            local valid,reason=Rules.ValidProof(gate,entry,headSha)
            if valid then
                result.Passed+=1
            else
                result.Failed+=1
                table.insert(result.Problems,gate.Id..": "..reason)
            end
        elseif state=="Failed" then
            result.Failed+=1
            table.insert(result.Problems,gate.Id..": falha de homologação.")
        elseif state=="Blocked" then
            result.Blocked+=1
            table.insert(result.Problems,gate.Id..": bloqueado.")
        else
            result.Pending+=1
            table.insert(result.Problems,gate.Id..": evidência pendente.")
        end
    end
    -- Nenhum resultado de CI, flag de gameplay ou botão de usuário
    -- ignora estes 16 gates. Go só quando TODOS estiverem verificados.
    result.Approved=result.Passed==result.Total
        and result.Failed==0 and result.Blocked==0 and result.Pending==0
    return result
end

-- Só um operador no QA deve montar o relatório; nunca expor essa
-- decisão como RemoteEvent, atributo replicado ou recompensa.
function Rules.Summary(result:any):string
    if type(result)~="table" then return "BLOQUEADO — sem avaliação" end
    return string.format("%s | %d/%d verificados | %d falhas | %d bloqueados | %d pendentes",
        result.Approved and "ELEGÍVEL PARA DECISÃO HUMANA" or "BLOQUEADO",
        result.Passed or 0,result.Total or 0,
        result.Failed or 0,result.Blocked or 0,result.Pending or 0)
end
return Rules
