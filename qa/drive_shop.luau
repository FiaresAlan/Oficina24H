-- QA local (datamodel Client, Play): compra as 10 máquinas e as peças dos 15 serviços na Loja de Autopeças.
-- ModuleScript: require(...)().
return function()
	local lp = game.Players.LocalPlayer
	local R = game.ReplicatedStorage.OficinaRemotes
	local msgs = {}
	local conn = R.Action.OnClientEvent:Connect(function(kind, data)
		if kind == "Result" and type(data) == "table" then table.insert(msgs, tostring(data.Success) .. " " .. tostring(data.Message)) end
	end)
	lp.Character:WaitForChild("HumanoidRootPart").CFrame = CFrame.new(130, 4, -80)
	task.wait(0.8)
	for _, eq in ipairs({ "Jack", "TireMachine", "Balancer", "Scanner", "BodyworkKit", "Compressor", "ElectricalBench", "SuspensionLift", "AlignmentRig", "EngineBench" }) do
		R.Action:FireServer("BuyEquipment", { EquipmentId = eq }); task.wait(0.3)
	end
	local parts = { BodyPanel = 2, BrakePad = 2, SuspensionArm = 2, FillerPutty = 2, Fuse = 4, SparkPlug = 4, EngineKit = 2,
		TirePatch = 2, SuspensionKit = 2, Coolant = 2, PaintCan = 4, Battery = 2, WheelWeight = 2, Tire = 4 }
	for id, q in pairs(parts) do R.Action:FireServer("BuyPart", { PartId = id, Quantity = q }); task.wait(0.3) end
	task.wait(1)
	conn:Disconnect()
	local ok = 0
	for _, m in ipairs(msgs) do if m:sub(1, 4) == "true" then ok += 1 end end
	return "compras ok " .. ok .. "/" .. #msgs .. "\n" .. table.concat(msgs, "\n")
end
