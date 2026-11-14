-- V2-16: portões fail-closed; suíte somente da regra pura em Studio
-- Edit. Não afirma que um único teste de gameplay já foi realizado.
local R=require(game.ReplicatedStorage.Shared.V2ReleaseGateRules)
local cases={}
local function check(name,ok)table.insert(cases,(ok and "PASS " or "FAIL ")..name)end
local sha=string.rep("a",40)
local other=string.rep("b",40)
local empty=R.NewEvidence()
local pending=R.Evaluate(empty,sha)
check("release sem nenhuma evidência é bloqueado",
    not pending.Approved and pending.Total==16
    and pending.Pending==16 and pending.Passed==0)
check("SHA ausente não pode aprovar release",
    not R.Evaluate(empty,"").Approved
    and not R.Evaluate(empty,other:sub(2)).Approved)
check("manifest ausente e versão diferente bloqueiam",
    not R.Evaluate(nil,sha).Approved
    and not R.Evaluate({Version=2,Entries=empty.Entries},sha).Approved)
local full=R.NewEvidence()
for _,gate in ipairs(R.Gates) do
    local item=full.Entries[gate.Id]
    item.Status="Passed"
    item.Source=gate.Source
    item.Proof="https://github.com/FiaresAlan/Oficina24H/actions/runs/100000"
    item.Notes="Registro de QA verificado manualmente na branch."
    item.VerifiedAt="2026-11-13T23:30:00Z"
    item.BuildSha=sha
end
local passed=R.Evaluate(full,sha)
check("aprovação lógica só exige 16 provas em commit exato",
    passed.Approved and passed.Passed==16
    and passed.Pending==0 and passed.Failed==0)
check("prova de SHA diferente é inválida",
    not R.Evaluate(full,other).Approved)
local modified=R.NewEvidence()
for k,v in pairs(full.Entries) do modified.Entries[k]=table.clone(v) end
modified.Entries.licenses.Status="Blocked"
local block=R.Evaluate(modified,sha)
check("licença pendente veta publicação mesmo com CI, Studio e beta OK",
    not block.Approved and block.Blocked==1 and block.Passed==15)
modified.Entries.licenses.Status="Passed"
modified.Entries.owner_go.Status="Pending"
check("sem decisão explícita do dono nunca declara GO",
    not R.Evaluate(modified,sha).Approved)
modified.Entries.owner_go.Status="Passed"
modified.Entries.inventory_fifo.Status="Failed"
check("fornecedor FIFO P0 faltante impede aprovação",
    not R.Evaluate(modified,sha).Approved)
modified.Entries.inventory_fifo.Status="Passed"
modified.Entries.merge_main.Proof="sem link"
check("PR com evidência inválida não passa",
    not R.Evaluate(modified,sha).Approved)
modified.Entries.merge_main.Proof=full.Entries.merge_main.Proof
modified.Entries.drive_physics.Source="CI"
check("CI não pode falsificar gate de física Studio",
    not R.Evaluate(modified,sha).Approved)
modified.Entries.drive_physics.Source="Studio"
modified.Entries.data_safety.Notes="curto"
check("prova sem detalhes reprovada",
    not R.Evaluate(modified,sha).Approved)
modified.Entries.data_safety.Notes=full.Entries.data_safety.Notes
modified.Entries.services_15.VerifiedAt="2026-11-13"
check("data sem ISO UTC é rejeitada",
    not R.Evaluate(modified,sha).Approved)
modified.Entries.services_15.VerifiedAt=full.Entries.services_15.VerifiedAt
check("relatório é explicitamente bloqueado até validação",
    string.find(R.Summary(pending),"BLOQUEADO",1,true)~=nil)
check("nenhuma função de regras ativa fases do jogo",
    R.ActivateGameplay==nil and R.Publish==nil and R.Launch==nil)
return table.concat(cases,"\n")
