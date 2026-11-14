-- V2-15: créditos do jogo consultáveis, e bloqueios de licença
-- explícitos; ter um asset grátis NÃO comprova redistribuição permitida.
local R=require(game.ReplicatedStorage.Shared.V2Credits)
local out={}
local function check(n,ok)table.insert(out,(ok and "PASS " or "FAIL ")..n)end
check("catálogo de autoria tem entradas auditáveis",
    #R.Entries>=10 and #R.Validate()==0)
local found={Veículos=false,Cidade=false,Oficina=false,Áudio=false}
for _,entry in ipairs(R.Entries) do
    if found[entry.Group]~=nil then found[entry.Group]=true end
    check("autor identificável: "..entry.Name,
        type(entry.Author)=="string" and #entry.Author>0
        and type(entry.Source)=="string" and #entry.Source>5)
end
check("créditos cobrem carros, cidade, oficina e áudio",
    found["Veículos"] and found.Cidade and found.Oficina and found["Áudio"])
local pending=table.concat(R.Pending," ")
check("direitos autorais de HUD e modelos são bloqueio público",
    pending:find("Sprites do HUD")~=nil
    and pending:find("Pacote de ícones")~=nil
    and pending:find("esportivo")~=nil
    and pending:find("CC BY")~=nil)
check("tela de créditos não alega liberação comercial universal",
    not pending:find("Todos os direitos aprovados"))
return table.concat(out,"\n")
