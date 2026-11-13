-- QA local: roda SUITES em sequência, cada uma em thread própria com limite de PERSUITE s (padrão 90);
-- resultados em ServerStorage.QAResults. Igual ao RunAllTests (cópia nova de Shared), mas uma suíte
-- travada (ex.: WaitForChild) vira TIMEOUT e não bloqueia as outras. Retorna logo; use collect.luau.
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local out = SS:FindFirstChild("QAResults") or Instance.new("Folder")
out.Name = "QAResults"
out.Parent = SS
if RS:FindFirstChild("Shared_original") then return "ERRO: Shared_original já existe (execução anterior em curso)" end
for _, name in ipairs(SUITES) do
	local old = out:FindFirstChild(name)
	if old then old:Destroy() end
	local v = Instance.new("StringValue"); v.Name = name; v.Value = "PENDING"; v.Parent = out
end
local limit = PERSUITE or 90
task.spawn(function()
	local original = RS:FindFirstChild("Shared")
	local fresh = original:Clone()
	original.Name = "Shared_original"
	fresh.Name = "Shared"
	fresh.Parent = RS
	for _, name in ipairs(SUITES) do
		local v = out[name]
		v.Value = "RUNNING"
		v:SetAttribute("Started", os.clock())
		local done = false
		task.spawn(function()
			local src = SS.Tools:FindFirstChild(name)
			if not src then v.Value = "AUSENTE"; done = true; return end
			local c = src:Clone()
			c.Source = "local ok, r = xpcall(function()\n" .. src.Source .. "\nend, debug.traceback)\nreturn (ok and '' or 'ERRO: ') .. tostring(r)"
			c.Parent = SS
			local ok, r = pcall(require, c)
			c:Destroy()
			if not done then v.Value = (ok and "" or "REQERR: ") .. tostring(r) end
			done = true
		end)
		local t0 = os.clock()
		while not done and os.clock() - t0 < limit do task.wait(0.5) end
		if not done then done = true; v.Value = "ERRO: TIMEOUT após " .. limit .. " s (suíte travada, provável WaitForChild de algo ausente)" end
		v:SetAttribute("Seconds", math.floor((os.clock() - t0) * 10) / 10)
	end
	fresh:Destroy()
	original.Name = "Shared"
	out:SetAttribute("Finished", os.time())
end)
return "agendadas " .. #SUITES
