-- Estados visuais não podem liberar reparos nem mostrar etapas fora de contexto.
local Rules = require(game.ReplicatedStorage.Shared.RepairPartVisualRules)
local out = {}
local function check(name, ok)
	table.insert(out, (ok and "PASS " or "FAIL ") .. name)
end
local function mode(stage, parked, required, step, current, done, distance)
	return Rules.State(stage, parked, required, step, current, done, distance)
end
check("etapa corrente aparece ativa", mode("Repair", true, true, "WheelBolts", "WheelBolts", false, 20) == "active")
check("etapa concluída aparece finalizada", mode("Repair", true, true, "WheelBolts", "JackSupport", true, 20) == "completed")
check("etapa futura não aparece", mode("Repair", true, true, "BatteryBracket", "HoodRelease", false, 20) == nil)
check("antes do diagnóstico não aparece", mode("Diagnose", true, true, "WheelBolts", "WheelBolts", false, 20) == nil)
check("carro viajando não aparece", mode("Repair", false, true, "WheelBolts", "WheelBolts", false, 20) == nil)
check("serviço legado não aparece", mode("Repair", true, false, "WheelBolts", "WheelBolts", false, 20) == nil)
check("distância muito grande não aparece", mode("Repair", true, true, "WheelBolts", "WheelBolts", true, 120) == nil)
check("distância próxima ao limite aparece", mode("Repair", true, true, "WheelBolts", "WheelBolts", true, 90) == "completed")
check("NaN ou infinito negados", mode("Repair", true, true, "WheelBolts", "WheelBolts", true, 0/0) == nil
	and mode("Repair", true, true, "WheelBolts", "WheelBolts", true, math.huge) == nil)
check("step desconhecido não aparece", mode("Repair", true, true, "Wallet", "Wallet", false, 20) == nil)
check("ferramenta só na etapa correta", Rules.ToolAllowed("Prep_WheelBolts", "WheelBolts"))
check("ferramenta em outra etapa negada", not Rules.ToolAllowed("Prep_WheelBolts", "JackSupport"))
check("prompt arbitrário negado", not Rules.ToolAllowed("Prep_BuyCash", "BuyCash"))
return table.concat(out, "\n")
