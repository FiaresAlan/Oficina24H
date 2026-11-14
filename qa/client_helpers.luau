-- QA local (datamodel Client, Play multi-cliente): instala _G.QAH com auxiliares para jogar pelos remotes reais.
-- Cole o conteúdo inteiro em execute_luau (Client) de CADA cliente. Não depende de ModuleScript nem de HTTP.
local H = game:GetService("HttpService")
local R = game.ReplicatedStorage:WaitForChild("OficinaRemotes")
local lp = game.Players.LocalPlayer
if _G.QAH and _G.QAH.Version == 2 then return "QAH ja instalado em " .. lp.Name end
local Q = { Version = 2, inbox = {}, notes = {} }
_G.QAH = Q
R.Action.OnClientEvent:Connect(function(kind, data) table.insert(Q.inbox, { k = kind, d = data }) end)
function Q.drain() table.clear(Q.inbox) end
function Q.take(kind, pred, timeout)
	local t0 = os.clock()
	while os.clock() - t0 < (timeout or 5) do
		for i, e in ipairs(Q.inbox) do
			if e.k == kind and (not pred or pred(e.d)) then table.remove(Q.inbox, i) return e.d end
		end
		task.wait(0.1)
	end
	return nil
end
function Q.act(name, payload, timeout)
	Q.drain()
	R.Action:FireServer(name, payload)
	return Q.take("Result", function(x) return type(x) == "table" and (x.Action == name or x.Action == nil) end, timeout or 4)
end
function Q.note(s) table.insert(Q.notes, s) end
function Q.go(pos) lp.Character:WaitForChild("HumanoidRootPart").CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0)); task.wait(0.5) end
function Q.snap() return R.GetSnapshot:InvokeServer() end
function Q.myPlot()
	for _, p in ipairs(workspace.Plots:GetChildren()) do
		if p:GetAttribute("OwnerUserId") == lp.UserId and p:GetAttribute("OwnerName") ~= nil and not p:FindFirstChild("RivalSign") then return p end
	end
	for _, p in ipairs(workspace.Plots:GetChildren()) do if p:GetAttribute("OwnerUserId") == lp.UserId then return p end end
end
function Q.coins() local s = Q.snap(); return s.Profile and s.Profile.Coins, s.Profile end
function Q.buy(part, qty)
	local shop = workspace.PublicAreas.LojaAutopecas
	Q.go(shop.Position + Vector3.new(0, 3, 0))
	return Q.act("BuyPart", { PartId = part, Quantity = qty })
end
-- Dono: aceita na TV, conversa, 9 exames e diagnostica. Devolve (ok, mensagem, carro).
function Q.ownerPrepare(jobId, defectId)
	local plot = Q.myPlot()
	local tv = plot.Estacoes.TV_Ordens.Position
	local base = plot:FindFirstChild("Base")
	local center = base and base.Position or plot:GetPivot().Position
	local flat = Vector3.new(center.X - tv.X, 0, center.Z - tv.Z)
	flat = flat.Magnitude > 0 and flat.Unit or Vector3.new(0, 0, -1)
	local floorY = base and (base.Position.Y + base.Size.Y / 2) or (tv.Y - 8)
	local stand = Vector3.new(tv.X, floorY + 0.5, tv.Z) + flat * 5
	local accepted
	for _ = 1, 40 do
		Q.go(stand)
		local r = Q.act("AcceptJob", { JobId = jobId })
		if r and r.Success then accepted = r.Message break end
		task.wait(1)
	end
	if not accepted then return false, "aceite falhou" end
	local car
	for _ = 1, 60 do
		car = workspace.Vehicles:FindFirstChild(jobId)
		if car and car:GetAttribute("Estacionado") == true then break end
		task.wait(0.5)
	end
	if not car or car:GetAttribute("Estacionado") ~= true then return false, "carro nao estacionou" end
	local npc = workspace.Vehicles:FindFirstChild("Cliente_" .. jobId)
	Q.go(npc and npc:GetPivot().Position + Vector3.new(0, 0, 2.5) or car:GetPivot().Position + Vector3.new(4, 0, 0))
	Q.act("DiagnoseJob", { JobId = jobId })
	for _, point in ipairs(car.InspectionPoints:GetChildren()) do
		Q.go(point.Position)
		Q.act("ExamineJob", { JobId = jobId, ExamId = point:GetAttribute("ExamId") })
	end
	Q.go(car:GetPivot().Position + Vector3.new(4, 0, 0))
	local r = Q.act("DiagnoseJob", { JobId = jobId, Choice = defectId })
	return r and r.Success == true, r and r.Message, car
end
-- Quem repara (dono ou contratado): preparo físico + comandos + entrega. Devolve (RepairDone, Result, log).
function Q.repair(jobId, defectId, token0)
	local log = {}
	local function L(s) table.insert(log, s) end
	local car = workspace.Vehicles:FindFirstChild(jobId)
	if not car then return nil, nil, { "sem carro" } end
	for _ = 1, 8 do
		local stepId = car:GetAttribute("PrepStepId")
		if car:GetAttribute("PrepRequired") ~= true or car:GetAttribute("PrepComplete") == true or not stepId or stepId == "" then break end
		local point = car.RepairPrepPoints:FindFirstChild("Prep_" .. stepId)
		Q.go(point.Position + Vector3.new(0, 0, 2))
		local prompt = point:FindFirstChildOfClass("ProximityPrompt")
		Q.drain()
		prompt:InputHoldBegin(); task.wait(prompt.HoldDuration + 0.25); prompt:InputHoldEnd()
		local pr = Q.take("Result", nil, 3)
		L("PREPARO " .. stepId .. " " .. tostring(pr and pr.Message))
	end
	L("PREPARO completo=" .. tostring(car:GetAttribute("PrepComplete")))
	Q.go(car:GetPivot().Position + Vector3.new(4, 0, 0))
	Q.drain()
	R.Action:FireServer("CompleteJob", { JobId = jobId })
	local start = Q.take("RepairStart", function(x) return x.JobId == jobId end, 5)
	if not start then
		local why = Q.take("Result", nil, 1)
		return nil, why, log
	end
	local plan, token = start.Plan, start.Token
	L("PLANO " .. plan.Mode)
	local revision = 0
	local function cmd(kind, id, value)
		Q.drain()
		R.Action:FireServer("RepairAction", { JobId = jobId, Token = token, Command = { Revision = revision, Kind = kind, Id = id, Value = value } })
		local ack = Q.take("RepairActionAck", function(x) return x.RequestRevision == revision end, 4)
		if not ack or not ack.Accepted then error("comando recusado " .. kind .. ": " .. tostring(ack and ack.Message)) end
		revision = ack.Revision
		task.wait(0.12)
	end
	local mode = plan.Mode
	if mode == "Tire" then
		cmd("Spot", nil, plan.Hint:find("INTERNO") and "Inner" or plan.Hint:find("CENTRO") and "Center" or "Outer")
		cmd("Pressure", nil, 30); cmd("Pressure", nil, 32)
	elseif mode == "Battery" then
		for _, s in ipairs({ "OffNegative", "OffPositive", "OnPositive", "OnNegative" }) do cmd("Step", nil, s) end
	end
	L("COMANDOS revisao=" .. revision .. " token=" .. token:sub(1, 8))
	Q.lastToken = token
	if token0 == "stop" then return nil, nil, log, token end -- para antes de entregar (teste de saída)
	task.wait((tonumber(plan.MinSeconds) or 2) + 0.4)
	Q.drain()
	R.Action:FireServer("FinishRepair", { JobId = jobId, Presses = { Token = token } })
	local done = Q.take("RepairDone", function(x) return x.JobId == jobId end, 8)
	local res = Q.take("Result", nil, 3)
	return done, res, log, token
end
return "QAH instalado em " .. lp.Name .. " id=" .. lp.UserId
