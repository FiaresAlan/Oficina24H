-- QA local (datamodel Client, Play): joga UMA ordem inteira pelos remotes reais do HUD.
-- Entrada: JOB (id), DEFECT (id). Saída em LocalPlayer.QADrive_<JOB> (StringValue) com cada etapa.
-- O gabarito abaixo é conhecimento de QA (copiado de src/server/WorkshopProcedures.lua e RepairOperations.lua);
-- se o servidor recusar, a etapa aparece como falha no relatório.
-- ModuleScript: require(...)(JOB, DEFECT).
return function(JOB, DEFECT)
	local lp = game.Players.LocalPlayer
	local H = game:GetService("HttpService")
	local R = game.ReplicatedStorage.OficinaRemotes
	local jobId, defectId = JOB, DEFECT
	local report = lp:FindFirstChild("QADrive_" .. jobId) or Instance.new("StringValue")
	report.Name = "QADrive_" .. jobId
	report.Value = "INICIO " .. defectId
	report.Parent = lp
	local function log(s) report.Value = report.Value .. "\n" .. s end

	local SEQ = {
		WornTire = { "Lift", "Loosen", "Fit", "Balance" }, LooseSuspension = { "Support", "Inspect", "Torque", "RoadTest" },
		BrakeWear = { "Lift", "Caliper", "Pads", "BedIn" }, BrokenArm = { "Support", "RemoveArm", "InstallArm", "Geometry" },
		EngineOverhaul = { "Drain", "Disassemble", "Measure", "Rebuild", "Compression" },
	}
	local CIRCUIT = { EngineMisfire = { "C2", "Plug" }, ElectricalFault = { "Accessories", "Fuse" } }
	local SURFACE = { Dent = { Top = 2, Center = 3, Bottom = 1 }, BodyDamage = { Top = 3, Center = 2, Bottom = 1 },
		PaintJob = { Top = 3, Center = 2, Bottom = 1 } }

	-- Captura de eventos do servidor (só deste roteiro).
	local inbox = {}
	local conn = R.Action.OnClientEvent:Connect(function(kind, data)
		table.insert(inbox, { Kind = kind, Data = data })
	end)
	local function waitEvent(kind, pred, timeout)
		local t0 = os.clock()
		while os.clock() - t0 < (timeout or 5) do
			for i, e in ipairs(inbox) do
				if e.Kind == kind and (not pred or pred(e.Data)) then
					table.remove(inbox, i)
					return e.Data
				end
			end
			task.wait(0.1)
		end
		return nil
	end
	local function result(action, timeout)
		local d = waitEvent("Result", function(x) return type(x) == "table" and (x.Action == action or x.Action == nil) end, timeout or 4)
		return d
	end
	local function hrp() return lp.Character:WaitForChild("HumanoidRootPart") end
	local function go(pos: Vector3) hrp().CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0)); task.wait(0.5) end
	local function act(name, payload, timeout)
		table.clear(inbox)
		R.Action:FireServer(name, payload)
		return result(name, timeout)
	end

	local ok, err = pcall(function()
		local plot
		for _, p in ipairs(workspace.Plots:GetChildren()) do
			if p:GetAttribute("OwnerUserId") == lp.UserId then plot = p end
		end
		local tv = plot.Estacoes.TV_Ordens.Position
		-- 1) chegada + aceite na TV
		local accepted
		for _ = 1, 40 do
			go(tv + Vector3.new(0, -5, -6))
			local r = act("AcceptJob", { JobId = jobId })
			if r and r.Success then accepted = r.Message break end
			task.wait(1)
		end
		if not accepted then error("AcceptJob nunca aceitou") end
		log("ACEITE " .. accepted)
		local car
		for _ = 1, 60 do
			car = workspace.Vehicles:FindFirstChild(jobId)
			if car and car:GetAttribute("Estacionado") == true then break end
			task.wait(0.5)
		end
		if not car or car:GetAttribute("Estacionado") ~= true then error("carro não estacionou") end
		log("ESTACIONADO " .. tostring(car:GetPivot().Position))
		-- 2) conversa + 9 exames + diagnóstico
		local npc = workspace.Vehicles:FindFirstChild("Cliente_" .. jobId)
		go(npc and npc:GetPivot().Position + Vector3.new(0, 0, 2.5) or car:GetPivot().Position + Vector3.new(4, 0, 0))
		local r = act("DiagnoseJob", { JobId = jobId })
		log("CONVERSA " .. tostring(r and r.Success) .. " " .. tostring(r and r.Message))
		local examsOk = 0
		for _, point in ipairs(car.InspectionPoints:GetChildren()) do
			go(point.Position + Vector3.new(0, 0, 0))
			local er = act("ExamineJob", { JobId = jobId, ExamId = point:GetAttribute("ExamId") })
			if er and er.Success then examsOk += 1 end
		end
		log("EXAMES ok=" .. examsOk .. "/" .. #car.InspectionPoints:GetChildren())
		go(car:GetPivot().Position + Vector3.new(4, 0, 0))
		r = act("DiagnoseJob", { JobId = jobId, Choice = defectId })
		log("DIAGNOSTICO " .. tostring(r and r.Success) .. " " .. tostring(r and r.Message))
		if not (r and r.Success) then error("diagnóstico recusado") end
		-- 3) preparo físico
		task.wait(0.5)
		local prepSteps = 0
		for _ = 1, 8 do
			local stepId = car:GetAttribute("PrepStepId")
			if car:GetAttribute("PrepRequired") ~= true or car:GetAttribute("PrepComplete") == true or not stepId or stepId == "" then break end
			local point = car.RepairPrepPoints:FindFirstChild("Prep_" .. stepId)
			go(point.Position + Vector3.new(0, 0, 2))
			local prompt = point:FindFirstChildOfClass("ProximityPrompt")
			table.clear(inbox)
			prompt:InputHoldBegin(); task.wait(prompt.HoldDuration + 0.25); prompt:InputHoldEnd()
			local pr = waitEvent("Result", nil, 3)
			prepSteps += 1
			log("PREPARO " .. stepId .. " " .. tostring(pr and pr.Message))
		end
		log("PREPARO total=" .. prepSteps .. " completo=" .. tostring(car:GetAttribute("PrepComplete")))
		-- 4) iniciar reparo (no carro ou na máquina)
		local snap = R.GetSnapshot:InvokeServer()
		local job
		for _, j in ipairs(snap.Jobs) do if j.Id == jobId then job = j end end
		local eq = job and job.Requirement and job.Requirement.EquipmentId
		if eq and eq ~= "BasicToolset" then
			local target
			for _, d in ipairs(plot:GetDescendants()) do
				if d:IsA("Model") and (d.Name == eq or d.Name == "Eq_" .. eq or d:GetAttribute("EquipmentId") == eq) then target = d break end
			end
			if not target then error("máquina " .. eq .. " não encontrada no lote") end
			go(target:GetPivot().Position + Vector3.new(0, 0, 4))
			log("MAQUINA " .. eq .. " @" .. tostring(target:GetPivot().Position))
		else
			go(car:GetPivot().Position + Vector3.new(4, 0, 0))
		end
		table.clear(inbox)
		R.Action:FireServer("CompleteJob", { JobId = jobId })
		local start = waitEvent("RepairStart", function(x) return x.JobId == jobId end, 5)
		if not start then
			local why = waitEvent("Result", nil, 1)
			error("RepairStart não veio: " .. tostring(why and why.Message))
		end
		local plan, token = start.Plan, start.Token
		log("PLANO " .. plan.Mode .. " " .. H:JSONEncode(plan):sub(1, 300))
		local revision = 0
		local function cmd(kind, id, value)
			table.clear(inbox)
			R.Action:FireServer("RepairAction", { JobId = jobId, Token = token, Command = { Revision = revision, Kind = kind, Id = id, Value = value } })
			local ack = waitEvent("RepairActionAck", function(x) return x.RequestRevision == revision end, 4)
			if not ack or not ack.Accepted then error("comando recusado " .. kind .. " " .. tostring(id) .. "=" .. tostring(value) .. ": " .. tostring(ack and ack.Message)) end
			revision = ack.Revision
			task.wait(0.12)
		end
		local mode = plan.Mode
		if mode == "Tire" then
			cmd("Spot", nil, plan.Hint:find("INTERNO") and "Inner" or plan.Hint:find("CENTRO") and "Center" or "Outer")
			cmd("Pressure", nil, 30); cmd("Pressure", nil, 32)
		elseif mode == "Battery" then
			for _, s in ipairs({ "OffNegative", "OffPositive", "OnPositive", "OnNegative" }) do cmd("Step", nil, s) end
		elseif mode == "Cooling" then
			cmd("Fluid", nil, 1.75); cmd("Fluid", nil, 2); cmd("Bleed", nil, 1); cmd("Bleed", nil, 2); cmd("Fan", nil, true)
		elseif mode == "Sequence" then
			for _, s in ipairs(SEQ[defectId]) do cmd("Step", nil, s) end
		elseif mode == "Calibration" then
			for _, f in ipairs(plan.Fields) do
				local v = f.Initial
				local dir = f.Target > v and 1 or -1
				while math.abs(v - f.Target) > 0.0001 do v += dir * f.Step; cmd("Measure", f.Id, v) end
			end
		elseif mode == "Circuit" then
			cmd("Source", nil, CIRCUIT[defectId][1]); cmd("Action", nil, CIRCUIT[defectId][2])
		elseif mode == "Surface" then
			for zoneId, target in pairs(SURFACE[defectId]) do for lv = 1, target do cmd("Level", zoneId, lv) end end
		end
		log("COMANDOS aceitos revisao=" .. revision)
		task.wait((tonumber(plan.MinSeconds) or 2) + 0.4)
		table.clear(inbox)
		R.Action:FireServer("FinishRepair", { JobId = jobId, Presses = { Token = token } })
		local done = waitEvent("RepairDone", function(x) return x.JobId == jobId end, 8)
		local fr = waitEvent("Result", nil, 2)
		if not done then error("RepairDone não veio: " .. tostring(fr and fr.Message)) end
		log(string.format("CONCLUIDO qualidade=%s preço=%s gorjeta=%s xp=%s estrelas=%s | %s", tostring(done.Quality), tostring(done.Price),
			tostring(done.Tip), tostring(done.XP), tostring(done.Stars), tostring(fr and fr.Message)))
		-- 5) replay do FinishRepair não pode pagar de novo
		local coins = R.GetSnapshot:InvokeServer().Profile.Coins
		table.clear(inbox)
		R.Action:FireServer("FinishRepair", { JobId = jobId, Presses = { Token = token } })
		local rr = waitEvent("Result", nil, 4)
		task.wait(0.5)
		local coins2 = R.GetSnapshot:InvokeServer().Profile.Coins
		log("REPLAY " .. tostring(rr and rr.Message) .. " saldo " .. coins .. "->" .. coins2 .. (coins == coins2 and " OK" or " DUPLICOU!"))
	end)
	conn:Disconnect()
	log(ok and "FIM OK" or ("FIM ERRO " .. tostring(err)))
	return true
end
