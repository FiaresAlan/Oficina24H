-- QA local (datamodel Server, Play): conta de QA com moedas, oficina nível máximo e XP nas 5 áreas.
-- Depois o cliente compra máquinas/peças na loja pelos remotes reais (drive_shop.luau).
-- ModuleScript: require(...)().
return function()
	local p = game.Players:GetPlayers()[1]
	local QA = game.ServerStorage:WaitForChild("QA")
	local out = {}
	table.insert(out, "coins=" .. tostring(QA:Invoke("Coins", p, 30000)))
	table.insert(out, "nivel=" .. tostring(QA:Invoke("WorkshopLevel", p, 4)))
	for _, spec in ipairs({ "Tires", "Engine", "Electrical", "Suspension", "Bodywork" }) do
		table.insert(out, spec .. "=" .. tostring(QA:Invoke("SkillXP", p, { Spec = spec, Amount = 600 })))
	end
	return table.concat(out, " ")
end
