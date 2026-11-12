-- Situações do "próximo passo" em ordens de serviço, sem depender do cliente/UI.
local Rules = require(game.ReplicatedStorage.Shared.ServiceFocusRules)
local out = {}
local function check(title, value)
	table.insert(out, (value and "PASS " or "FAIL ") .. title)
end
local function select(jobs, profile, collabs)
	return Rules.Select({ HasWorkshop = true, Jobs = jobs or {}, Profile = profile or { Parts = {} }, CollabJobs = collabs or {} })
end
check("snapshot ausente mostra carregamento", Rules.Select(nil).Kind == "Loading")
check("sem oficina prioriza cadastro", Rules.Select({ HasWorkshop = false, Jobs = {} }).Kind == "Register")
check("sem serviços oficina disponível", select({}).Kind == "Idle")
local unexamined = { Id = "1", Status = "InProgress", VehicleName = "Carro A", Diagnosed = false }
check("diagnóstico priorizado", select({ unexamined }).Kind == "Diagnose")
check("cliente ativo guia ao veículo", select({ unexamined }).Target == "vehicle")
check("não revela defeito antes de diagnóstico", not string.find(select({ unexamined }).Description, "FlatTire", 1, true))
local delegated = { Id = "2", Status = "InProgress", Diagnosed = true, CollaboratorUserId = 99 }
check("OS delegada não manda proprietário reparar", select({ delegated }).Kind == "Delegated")
local missing = {
	Id = "3", Status = "InProgress", Diagnosed = true, VehicleName = "Carro C",
	Requirement = { Parts = { Battery = 1 }, EquipmentId = "BasicToolset" },
}
check("falta de peça leva à loja", select({ missing }).Target == "shop")
check("repor peça desbloqueia próximo passo", select({ missing }, { Parts = { Battery = 1 } }).Kind == "Repair")
local prepare = { Id = "4", Status = "InProgress", Diagnosed = true, PrepRequired = true, PrepComplete = false }
check("preparo físico vem antes de reparo", select({ prepare }).Kind == "Prepare")
prepare.PrepComplete = true
check("preparo concluído pode avançar", select({ prepare }).Kind == "Repair")
prepare.Requirement = { EquipmentId = "WheelBalancer" }
check("máquina de oficina vira objetivo", select({ prepare }).Kind == "Equipment")
check("equipamento identificado sem acesso ao defeito", select({ prepare }).EquipmentId == "WheelBalancer")
local p1 = { Id = "5", Status = "Available", WaitSeconds = 120, PatienceSeconds = 300 }
local p2 = { Id = "6", Status = "Available", WaitSeconds = 270, PatienceSeconds = 300 }
check("ordem mais urgente escolhida independentemente da sequência", select({ p1, p2 }).JobId == "6")
check("urgência indicada depois de 75% de paciência", select({ p2 }).Kind == "Urgent")
check("ordem disponível manda à TV de ordens", select({ p1 }).Target == "orders")
check("ordem ativa prevalece sobre lista de espera", select({ p2, unexamined }).JobId == "1")
check("contrato trabalhista aparece sem OS própria", select({}, nil, { { Id = "7", VehicleName = "Carro B" } }).Kind == "Collaboration")
check("OS própria prevalece sobre contrato quando ativa", select({ unexamined }, nil, { { Id = "7" } }).JobId == "1")
check("inventário vazio não é considerado suficiente", Rules.MissingParts(missing, { Parts = {} }))
check("inventário completo satisfaz a receita", not Rules.MissingParts(missing, { Parts = { Battery = 2 } }))
check("requisitos ausentes não inventam falta", not Rules.MissingParts(unexamined, {}))
check("urgência inválida é neutra", Rules.Urgency({ PatienceSeconds = 0, WaitSeconds = math.huge }) == 0)
check("urgência limitada a 100%", Rules.Urgency({ PatienceSeconds = 100, WaitSeconds = 9999 }) == 1)
check("ordem status estranho ignorada", select({ { Id = "A", Status = "Cancelled" } }).Kind == "Idle")
check("desempate determinista por ID", select({ { Id = "B", Status = "Available", WaitSeconds = 5, PatienceSeconds = 10 },
	{ Id = "A", Status = "Available", WaitSeconds = 5, PatienceSeconds = 10 } }).JobId == "A")
check("duas OS ativas não alternam aleatoriamente", select({ { Id = "B", Status = "InProgress", Diagnosed = false },
	{ Id = "A", Status = "InProgress", Diagnosed = false } }).JobId == "A")
check("duas OS colaborativas têm desempate fixo", select({}, nil, { { Id = "B" }, { Id = "A" } }).JobId == "A")
check("ação para uma OS não depende de outra", Rules.ForActive({ Id = "X", Diagnosed = true }, { Parts = {} }).Kind == "Repair")
check("OS inválida não apresenta ação técnica", Rules.ForActive(nil, nil).Kind == "Idle")
return table.concat(out, "\n")
