-- Regressao isolada: modelos importados nao podem executar codigo embutido.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.AssetSafetyRules)
local output = {}
local function check(label, condition)
	table.insert(output, (condition and "PASS " or "FAIL ") .. label)
end
local root = Instance.new("Model")
root.Name = "ImportedCar"
local body = Instance.new("Part")
body.Name = "Raiz"
body.Parent = root
local nested = Instance.new("Folder")
nested.Parent = root
for _, className in ipairs({ "Script", "LocalScript", "ModuleScript" }) do
	local scriptObject = Instance.new(className)
	scriptObject.Name = "ThirdParty_" .. className
	scriptObject.Parent = nested
end
local unrelated = Instance.new("Model")
local unrelatedScript = Instance.new("Script")
unrelatedScript.Parent = unrelated

local removed = Rules.StripScripts(root)
check("remove scripts aninhados das tres classes", removed == 3)
check("nenhum script sobrevive no modelo saneado", #nested:GetChildren() == 0)
check("mantem partes, pastas e geometria", root:FindFirstChild("Raiz") == body and nested.Parent == root)
check("nao modifica modelos fora do clone", unrelatedScript.Parent == unrelated)
check("repeticao nao altera estado", Rules.StripScripts(root) == 0)
root:Destroy()
unrelated:Destroy()
return table.concat(output, "\n")
