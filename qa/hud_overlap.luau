-- QA local (datamodel Client, Play): mede os blocos de topo do HUD e acusa sobreposição/vazamento.
-- ModuleScript: require(...)() -> texto com retângulos e problemas.
return function()
	local lp = game.Players.LocalPlayer
	local gui = lp.PlayerGui:WaitForChild("OficinaUI")
	local vp = workspace.CurrentCamera.ViewportSize
	local names = { "Onboarding", "BottomNav", "QuickObjective", "CompactSummary", "TopBar", "RightColumn", "SideMenu", "Controls" }
	local rects, out, problems = {}, { "vp=" .. tostring(vp) }, {}
	for _, n in ipairs(names) do
		local c = gui:FindFirstChild(n)
		if c and c:IsA("GuiObject") and c.Visible and c.AbsoluteSize.X > 2 then
			local p, s = c.AbsolutePosition, c.AbsoluteSize
			rects[n] = { p.X, p.Y, p.X + s.X, p.Y + s.Y }
			table.insert(out, string.format("%s x=%d..%d y=%d..%d", n, p.X, p.X + s.X, p.Y, p.Y + s.Y))
			if p.X < -1 or p.X + s.X > vp.X + 1 then table.insert(problems, n .. " vaza na horizontal") end
		end
	end
	local ob = rects.Onboarding
	if ob then
		for n, r in pairs(rects) do
			if n ~= "Onboarding" and ob[1] < r[3] and r[1] < ob[3] and ob[2] < r[4] and r[2] < ob[4] then
				table.insert(problems, string.format("Onboarding sobrepõe %s (%dx%d px)", n,
					math.min(ob[3], r[3]) - math.max(ob[1], r[1]), math.min(ob[4], r[4]) - math.max(ob[2], r[2])))
			end
		end
	end
	local skip = gui:FindFirstChild("SkipOnboarding", true)
	if skip and skip.Visible then table.insert(out, "PularGuia=" .. math.floor(skip.AbsoluteSize.X) .. "x" .. math.floor(skip.AbsoluteSize.Y)) end
	table.insert(out, "PROBLEMAS: " .. (#problems == 0 and "nenhum" or table.concat(problems, "; ")))
	return table.concat(out, "\n")
end
