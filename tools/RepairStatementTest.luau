--!strict
local Statement = require(game.ReplicatedStorage.Shared.RepairStatementRules)
local result = {}
local function check(name: string, ok: any)
	table.insert(result, (ok and "PASS " or "FAIL ") .. name)
end
local empty = Statement.Build(nil)
check("lista ausente não quebra", empty.Count == 0 and empty.Total == 0)
check("lista vazia não define média", Statement.Build({}).AverageQuality == nil)
local statement = Statement.Build({
	{ At = 100, Amount = 50, Role = "Owner", Service = "Motor", Vehicle = "Sedã", Quality = 98, Token = "secret" },
	{ At = 115, Amount = 25, Role = "Worker", Service = "Freio", Vehicle = "Hatch", Quality = 82, Stars = 4 },
	{ At = 115, Amount = 15, Role = "Owner", Service = "Pneu", Vehicle = "SUV", Quality = 70 },
})
check("três créditos exibidos", statement.Count == 3)
check("soma apenas valores realmente creditados", statement.Total == 90)
check("separa recebimento da oficina", statement.OwnerEarnings == 65)
check("separa trabalho contratado", statement.WorkerEarnings == 25)
check("calcula média de qualidade dos recibos", statement.AverageQuality == 83)
check("ordena do mais recente", statement.Rows[1].Service == "Freio")
check("desempate estável", statement.Rows[2].Service == "Pneu")
check("não revela o GUID", statement.Rows[3].Token == nil)
check("não expõe o JobId", statement.Rows[1].JobId == nil)
check("não expõe índices internos", statement.Rows[1].SortIndex == nil)
local invalid = Statement.Build({
	{ Amount = -5, Role = "Owner" },
	{ Amount = math.huge, Role = "Worker" },
	{ Amount = 10, Role = "Intruder" },
	{ Amount = 10, Role = "Owner", At = 20, Service = string.rep("a", 100), Vehicle = 3 },
})
check("valores inválidos ignorados", invalid.Count == 1)
check("não divulga campos extras", invalid.Rows[1].Other == nil)
check("limita texto de serviço", #invalid.Rows[1].Service == 64)
check("campo de veículo inválido vira vazio", invalid.Rows[1].Vehicle == "")
local noQuality = Statement.Build({ { Amount = 4, Role = "Worker", At = 1 } })
check("qualidade ausente não inventada", noQuality.AverageQuality == nil and noQuality.Rows[1].Quality == nil)
local oversized = {}
for i = 1, 40 do
	table.insert(oversized, { At = i, Amount = i, Role = i % 2 == 0 and "Owner" or "Worker" })
end
local limited = Statement.Build(oversized)
check("interface limita a 20 linhas", limited.Count == 20)
check("linha mais recente dentro do limite", limited.Rows[1].At == 20)
check("soma apenas as 20 linhas visíveis", limited.Total == 210)
check("não soma itens omitidos", limited.Total ~= 820)
local malformed = Statement.Build({ false, "x", {}, { Amount = 2.7, Role = "Owner", At = -10 } })
check("saneia valores fracionários", malformed.Rows[1].Amount == 2)
check("datas negativas não quebram", malformed.Rows[1].At == 0)
return table.concat(result, "\n")
