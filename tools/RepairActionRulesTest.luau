-- Prova incremental de gestos: testes puros sem RemoteEvent, economia ou Place físico.
local Rules = require(game.ReplicatedStorage.Shared.RepairActionRules)
local Operations = require(game.ReplicatedStorage.Shared.RepairOperations)
local results = {}
local function check(name, ok)
	table.insert(results, (ok and "PASS " or "FAIL ") .. name)
end
local function plan(defect)
	local p = Operations.BuildPlan(defect, 123)
	assert(p and p.Kind == "Operations", "falta plano: " .. defect)
	return p
end
local function send(p, state, kind, id, value)
	return Rules.Apply(p, state, { Revision = state.Revision, Kind = kind, Id = id, Value = value })
end
local function complete(p, state)
	local input, reason = Rules.FinalInput(p, state)
	return input, reason
end

check("rejeita plano não-operacional", Rules.New({ Kind = "Timing" }) == nil)
check("rejeita plano nil", Rules.New(nil) == nil)
check("limite de comandos definido", Rules.MaxCommands >= 40 and Rules.MaxCommands <= 128)

-- Pneu: troca a pressão em passos de 2, local selecionado separadamente.
do
	local p = plan("FlatTire")
	local s = Rules.New(p)
	check("pneu inicial exige ação", complete(p, s) == nil)
	check("pneu rejeita local inexistente", not send(p, s, "Spot", nil, "Hack"))
	check("pneu rejeita pressão absurda", not send(p, s, "Pressure", nil, 400))
	check("pneu rejeita salto impossível", not send(p, s, "Pressure", nil, 36))
	check("pneu sem comandos não avança", s.Revision == 0 and s.Commands == 0)
	check("pneu registra local", send(p, s, "Spot", nil, p.LeakSpot))
	check("pneu registra calibração", send(p, s, "Pressure", nil, 30))
	local input = complete(p, s)
	check("pneu final reconstruído no servidor", input ~= nil and input.Spot == p.LeakSpot and input.Pressure == 30)
	check("replay de revisão antiga rejeitado", not Rules.Apply(p, s, { Revision = 1, Kind = "Pressure", Value = 32 }))
	check("replay não altera valor", s.Pressure == 30 and s.Revision == 2)
end

-- Bateria: quatro passos exatos, com reset de sessão.
do
	local p = plan("WeakBattery")
	local s = Rules.New(p)
	check("bateria sem etapas não conclui", complete(p, s) == nil)
	check("bateria aceita primeira etapa", send(p, s, "Step", nil, "OffNegative"))
	check("bateria impede duplicação", not send(p, s, "Step", nil, "OffNegative"))
	check("bateria exige sequência completa", complete(p, s) == nil)
	check("bateria registra reset", send(p, s, "Reset", nil, nil))
	check("bateria reset remove etapas", #s.Steps == 0)
	for _, step in ipairs({ "OffNegative", "OffPositive", "OnPositive", "OnNegative" }) do
		check("bateria registro " .. step, send(p, s, "Step", nil, step))
	end
	local input = complete(p, s)
	check("bateria completa sai do estado confirmado", input and #input.Steps == 4)
end

-- Arrefecimento: três modalidades devem ser tocadas.
do
	local p = plan("Overheating")
	local s = Rules.New(p)
	check("cooling rejeita fluido inventado", not send(p, s, "Fluid", nil, 2.25))
	check("cooling registra primeiro incremento", send(p, s, "Fluid", nil, 1.75))
	check("cooling só fluido não conclui", complete(p, s) == nil)
	check("cooling registra segundo incremento", send(p, s, "Fluid", nil, 2))
	check("cooling primeiro ciclo", send(p, s, "Bleed", nil, 1))
	check("cooling segundo ciclo", send(p, s, "Bleed", nil, 2))
	check("cooling exige ventilador", complete(p, s) == nil)
	check("cooling testa ventilador", send(p, s, "Fan", nil, true))
	local input = complete(p, s)
	check("cooling reconstrói os três controles", input and input.Fluid == 2 and input.BleedCycles == 2 and input.FanChecked == true)
end

-- Sequências de chassi/freio/retífica: todos os botões rastreados.
do
	local p = plan("EngineOverhaul")
	local s = Rules.New(p)
	check("retífica bloqueia etapa inválida", not send(p, s, "Step", nil, "SkipEngine"))
	for i, step in ipairs(p.Correct) do
		check("retífica etapa " .. i, send(p, s, "Step", nil, step))
	end
	local input = complete(p, s)
	check("retífica todas as etapas", input and #input.Steps == #p.Correct)
	check("retífica bloqueia sexto passo", not send(p, s, "Step", nil, p.Correct[1]))
	check("retífica aceita reset", send(p, s, "Reset", nil, nil))
	check("retífica reiniciada não conclui", complete(p, s) == nil)
end

-- Calibração: cada campo precisa ter sido ajustado em passos instrumentais válidos.
do
	local p = plan("WheelImbalance")
	local s = Rules.New(p)
	local a = p.Fields[1]
	local b = p.Fields[2]
	check("calibração não aceita salto", not send(p, s, "Measure", a.Id, a.Target))
	check("calibração aceita passo", send(p, s, "Measure", a.Id, a.Initial + a.Step))
	check("calibração exige outro campo", complete(p, s) == nil)
	check("calibração recusa campo desconhecido", not send(p, s, "Measure", "Hack", 10))
	check("calibração aceita segunda medida", send(p, s, "Measure", b.Id, b.Initial + b.Step))
	local input = complete(p, s)
	check("calibração final mantém duas medidas", input and input.Values[a.Id] == a.Initial + a.Step and input.Values[b.Id] == b.Initial + b.Step)
end

-- Circuito: ambos os IDs precisam existir no plano do servidor.
do
	local p = plan("ElectricalFault")
	local s = Rules.New(p)
	check("circuito não aceita origem inventada", not send(p, s, "Source", nil, "ServerHack"))
	check("circuito aceita origem", send(p, s, "Source", nil, p.CorrectSource))
	check("circuito exige intervenção", complete(p, s) == nil)
	check("circuito recusa ação inventada", not send(p, s, "Action", nil, "Bypass"))
	check("circuito aceita intervenção", send(p, s, "Action", nil, p.CorrectAction))
	local input = complete(p, s)
	check("circuito final server-side", input and input.Source == p.CorrectSource and input.Action == p.CorrectAction)
end

-- Carroceria: a força é discreta, por região e jamais arbitrária.
do
	local p = plan("BodyDamage")
	local s = Rules.New(p)
	check("lataria força decimal negada", not send(p, s, "Level", p.Zones[1].Id, 1.5))
	check("lataria força excessiva negada", not send(p, s, "Level", p.Zones[1].Id, 3))
	for _, zone in ipairs(p.Zones) do
		check("lataria trabalha zona " .. zone.Id, send(p, s, "Level", zone.Id, 1))
	end
	local input = complete(p, s)
	check("lataria final contém todas regiões", input ~= nil and input.Levels[p.Zones[1].Id] == 1)
	check("lataria zona fantasma negada", not send(p, s, "Level", "Other", 1))
end

do
	local p = plan("FlatTire")
	local s = Rules.New(p)
	s.Commands = Rules.MaxCommands
	check("limite de interações impede spam", not send(p, s, "Spot", nil, "Inner"))
	check("limite não incrementa revisão", s.Revision == 0)
	check("estado adulterado de outro modo rejeitado", not Rules.Apply(p, { Mode = "Battery", Revision = 0, Commands = 0 }, { Revision = 0, Kind = "Spot", Value = "Inner" }))
	check("comando vazio rejeitado", not Rules.Apply(p, s, {}))
end

return table.concat(results, "\n")
