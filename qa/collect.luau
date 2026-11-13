-- QA local: resume ServerStorage.QAResults (MAXFAIL linhas de falha por suíte; FULL = nome de suíte p/ saída completa).
local out = game:GetService("ServerStorage"):FindFirstChild("QAResults")
if not out then return "sem resultados" end
if FULL then local v = out:FindFirstChild(FULL); return v and v.Value or "?" end
local kids = out:GetChildren()
table.sort(kids, function(a, b) return a.Name < b.Name end)
local lines, tp, tf, tw = {}, 0, 0, 0
for _, v in ipairs(kids) do
	local p, f, w = 0, {}, {}
	for line in v.Value:gmatch("[^\n]+") do
		if line:find("^PASS") then p += 1
		elseif line:find("^FAIL") or line:find("^ERRO") or line:find("^AUSENTE") or line:find("^REQERR") then table.insert(f, line:sub(1, 300))
		elseif line:find("^WARN") then table.insert(w, line:sub(1, 200)) end
	end
	if v.Value == "RUNNING" or v.Value == "PENDING" then table.insert(f, v.Value) end
	if p == 0 and #f == 0 then table.insert(f, "ERRO sem resultados verificáveis") end
	tp += p; tf += #f; tw += #w
	table.insert(lines, string.format("%s: %d ok, %d falhas, %d avisos", v.Name, p, #f, #w))
	for i = 1, math.min(#f, MAXFAIL or 8) do table.insert(lines, "   " .. f[i]) end
	if SHOWWARN then for i = 1, #w do table.insert(lines, "   " .. w[i]) end end
end
return string.format("TOTAL %d ok | %d falhas | %d avisos\n", tp, tf, tw) .. table.concat(lines, "\n")
