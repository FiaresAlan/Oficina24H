-- V2-01: executar SEPARADAMENTE no Studio Edit; nenhum modelo e modificado.
local Store=game:GetService("ServerStorage")
local Rules=require(game:GetService("ReplicatedStorage").Shared.V2VehiclePilotRules)
local folder=Store:FindFirstChild("Assets")
folder=folder and folder:FindFirstChild("Veiculos")
local lines={"V2 PILOTOS — auditoria somente leitura"}
local nerr,nwarn=0,0
for _,spec in ipairs(Rules.Pilots) do
    local model=folder and folder:FindFirstChild(spec.Model)
    local errors,warnings=Rules.Inspect(model)
    nerr+=#errors nwarn+=#warnings
    table.insert(lines,spec.Id.." / "..spec.Model..": "..#errors.." erros, "..#warnings.." avisos")
    for _,err in ipairs(errors) do table.insert(lines,"FAIL "..err) end
    for _,warn in ipairs(warnings) do table.insert(lines,"WARN "..warn) end
end
table.insert(lines,"TOTAL "..nerr.." erros; "..nwarn.." avisos. Pivôs faltantes: rig V2-03 ainda pendente.")
return table.concat(lines,"\n")
