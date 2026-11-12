-- Roda todos os testes automáticos no modo Edit (via MCP). Resultado: resumo por suíte + linhas que falharam.
-- Requer o Rojo conectado (tools e scripts sincronizados). Duração ~25 s (PersistenceTest espera travas simuladas).
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local suites = { "CatalogTest", "CustomerTest", "RepairTest", "PlotTest", "PersistenceTest", "ProgressTest", "LocationTest", "RivalRulesTest" }
local out = {}

-- O cache de require do Edit guarda versões antigas de Shared (Catalog/Config). Durante os testes, uma cópia nova de
-- Shared assume o nome "Shared" e o original é restaurado no final (mesmo se alguma suíte falhar).
local original = ReplicatedStorage:FindFirstChild("Shared")
local fresh
if original then
	fresh = original:Clone()
	original.Name = "Shared_original"
	fresh.Name = "Shared"
	fresh.Parent = ReplicatedStorage
end

for _, name in ipairs(suites) do
	local source = ServerStorage.Tools:FindFirstChild(name)
	if not source then
		table.insert(out, name .. ": AUSENTE")
	else
		local c = source:Clone()
		c.Source = "local ok, r = xpcall(function()\n" .. source.Source .. "\nend, debug.traceback)\nreturn (ok and '' or 'ERRO: ') .. tostring(r)"
		c.Parent = ServerStorage
		local ok, res = pcall(require, c)
		c:Destroy()
		local pass, fail = 0, {}
		for line in tostring(res):gmatch("[^\n]+") do
			if line:find("^PASS") then pass += 1 elseif line:find("^FAIL") or line:find("^ERRO") then table.insert(fail, line) end
		end
		table.insert(out, string.format("%s: %d aprovados, %d falhas", name, pass, #fail))
		for _, f in ipairs(fail) do table.insert(out, "  " .. f) end
	end
end
if fresh then
	fresh:Destroy()
	original.Name = "Shared"
end
return table.concat(out, "\n")
