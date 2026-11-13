-- QA local: puxa arquivos do repositório (servidor http em 127.0.0.1:34999) para o place aberto.
-- Uso no execute_luau: local files = {...}; <este código>. Só cria/atualiza scripts; nunca apaga.
local H = game:GetService("HttpService")
local roots = {
	["src/shared"] = game:GetService("ReplicatedStorage"):FindFirstChild("Shared"),
	["src/server"] = game:GetService("ServerScriptService"):FindFirstChild("Server"),
	["src/client"] = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Client"),
	["tools"] = game:GetService("ServerStorage"):FindFirstChild("Tools"),
}
local report = {}
for _, rel in ipairs(FILES) do
	local rootKey, rest
	for k in pairs(roots) do
		if rel:sub(1, #k + 1) == k .. "/" then rootKey, rest = k, rel:sub(#k + 2) end
	end
	local parent = rootKey and roots[rootKey]
	if not parent then table.insert(report, "SEM RAIZ " .. rel) continue end
	local parts = string.split(rest, "/")
	local file = table.remove(parts)
	for _, folder in ipairs(parts) do
		local f = parent:FindFirstChild(folder)
		if not f then f = Instance.new("Folder"); f.Name = folder; f.Parent = parent end
		parent = f
	end
	local class, name = "ModuleScript", file
	if file:match("%.server%.lua$") then class, name = "Script", file:gsub("%.server%.lua$", "")
	elseif file:match("%.client%.lua$") then class, name = "LocalScript", file:gsub("%.client%.lua$", "")
	else name = file:gsub("%.luau?$", "") end
	local ok, src = pcall(H.GetAsync, H, "http://127.0.0.1:34999/" .. rel .. "?t=" .. os.clock(), true)
	if not ok then table.insert(report, "HTTP " .. rel .. ": " .. tostring(src)) continue end
	src = src:gsub("\r\n", "\n")
	local inst = parent:FindFirstChild(name)
	if inst and inst.ClassName ~= class then table.insert(report, "CLASSE DIFERENTE " .. rel) continue end
	if not inst then inst = Instance.new(class); inst.Name = name; inst.Parent = parent end
	local same = inst.Source == src
	inst.Source = src
	table.insert(report, (same and "igual " or "ATUALIZADO ") .. inst:GetFullName() .. " (" .. #src .. ")")
end
return table.concat(report, "\n")
