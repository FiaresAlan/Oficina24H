--!strict
-- Minijogo de reparo "Apertar na hora certa". O servidor sorteia o plano e mede o tempo; aqui só desenhamos a barra,
-- coletamos os instantes de toque (Espaço, botão A, clique ou toque no botão) e enviamos "FinishRepair".
-- Quem decide qualidade, nota, gorjeta e pagamento é o servidor (RepairRules.Score).
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local RepairRules = require(ReplicatedStorage.Shared.RepairRules)
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Motion)
local Store = require(script.Parent.Store)
local HudParts = require(script.Parent.HudParts)
local PanelKit = require(script.Parent.PanelKit)

local t = Kit.t
local RepairGame = {}

local ACTION = "OficinaRepairPress"
local FEEDBACK_PAUSE = 0.55 -- pausa depois de cada toque para mostrar o resultado da etapa

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local COLORS: { [string]: Color3 } = {
	perfect = rgb(255, 205, 60), good = rgb(70, 225, 105), miss = rgb(255, 80, 70), pending = rgb(60, 84, 120), fixed = rgb(255, 150, 40),
}

function RepairGame.new(gui: ScreenGui): { Start: (any) -> (), IsActive: () -> boolean, Cancel: () -> (), Fit: (number, number) -> () }
	-- holder: posição e escala por tela (Fit); root: o painel com a animação de entrada (Pop). Duas escalas em quadros diferentes.
	local holder = Instance.new("Frame")
	holder.Name = "RepairHolder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -140)
	holder.Size = UDim2.fromOffset(640, 330)
	holder.ZIndex = 20
	holder.Parent = gui
	local fit = Instance.new("UIScale")
	fit.Name = "Fit"
	fit.Parent = holder
	local root = HudParts.panel(holder, "RepairGame")
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.ZIndex = 20
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = root

	local header = HudParts.header(root, 54)
	header.ZIndex = 21
	local titleRow = Instance.new("Frame")
	titleRow.BackgroundTransparency = 1
	titleRow.Size = UDim2.new(1, -70, 1, 0)
	titleRow.Position = UDim2.fromOffset(14, 0)
	titleRow.ZIndex = 22
	titleRow.Parent = header
	local titleLayout = Instance.new("UIListLayout")
	titleLayout.FillDirection = Enum.FillDirection.Horizontal
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	titleLayout.Padding = UDim.new(0, 10)
	titleLayout.Parent = titleRow
	local wrench = HudParts.sprite(titleRow, "pn_o_wrench", Vector2.new(36, 36))
	wrench.ZIndex = 22
	local titleLabel = HudParts.text(titleRow, t("rp_title"), 32, { Font = Theme.FontTitle, ZIndex = 22, TextTruncate = Enum.TextTruncate.AtEnd })
	local cancelButton = Instance.new("TextButton")
	cancelButton.Name = "CancelRepair"
	cancelButton.AutoButtonColor = false
	cancelButton.Text = "X"
	cancelButton.Font = Theme.FontTitle
	cancelButton.TextSize = 30
	cancelButton.TextColor3 = Theme.Text
	cancelButton.BackgroundColor3 = rgb(20, 40, 80)
	cancelButton.BorderSizePixel = 0
	cancelButton.AnchorPoint = Vector2.new(1, 0.5)
	cancelButton.Position = UDim2.new(1, -10, 0.5, 0)
	cancelButton.Size = UDim2.fromOffset(44, 40)
	cancelButton.ZIndex = 23
	Kit.corner(cancelButton, 12)
	cancelButton.Parent = header

	-- ===== Grupo do jogo =====
	local game_ = Instance.new("Frame")
	game_.Name = "Game"
	game_.BackgroundTransparency = 1
	game_.Position = UDim2.fromOffset(0, 54)
	game_.Size = UDim2.new(1, 0, 1, -54)
	game_.ZIndex = 21
	game_.Parent = root
	local info = Instance.new("Frame")
	info.BackgroundTransparency = 1
	info.Position = UDim2.fromOffset(20, 10)
	info.Size = UDim2.new(1, -40, 0, 34)
	info.ZIndex = 21
	info.Parent = game_
	local vehicleLabel = HudParts.text(info, "", 26, { Font = Theme.FontTitle, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.5, 0, 1, 0), ZIndex = 21, TextYAlignment = Enum.TextYAlignment.Center })
	local stepLabel = HudParts.text(info, "", 24, { Font = Theme.FontSemi, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromScale(0.5, 0), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 21 })

	local feedback = HudParts.text(game_, "", 46, {
		Font = Theme.FontTitle, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 46),
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 22,
	})
	local feedbackScale = Instance.new("UIScale")
	feedbackScale.Parent = feedback

	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.BackgroundColor3 = rgb(8, 16, 30)
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0, 108)
	track.Size = UDim2.new(1, -60, 0, 56)
	track.ZIndex = 21
	Kit.corner(track, 14)
	HudParts.stroke(track, rgb(70, 120, 190), 0.1, 2)
	track.Parent = game_
	local zone = Instance.new("Frame")
	zone.Name = "Zone"
	zone.BackgroundColor3 = Color3.new(1, 1, 1)
	zone.BorderSizePixel = 0
	zone.AnchorPoint = Vector2.new(0.5, 0)
	zone.Size = UDim2.new(0.3, 0, 1, 0)
	zone.ZIndex = 22
	Kit.corner(zone, 10)
	HudParts.gradient(zone, { { 0, rgb(70, 225, 105) }, { 1, rgb(18, 150, 54) } }, 90)
	zone.Parent = track
	local core = Instance.new("Frame")
	core.Name = "Perfect"
	core.BackgroundColor3 = Color3.new(1, 1, 1)
	core.BorderSizePixel = 0
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.new(0.5, 0, 1, -8)
	core.ZIndex = 23
	Kit.corner(core, 8)
	HudParts.gradient(core, { { 0, rgb(255, 235, 120) }, { 1, rgb(255, 170, 20) } }, 90)
	core.Parent = zone
	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.BackgroundColor3 = Color3.new(1, 1, 1)
	marker.BorderSizePixel = 0
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0, 0.5)
	marker.Size = UDim2.new(0, 8, 1, 20)
	marker.ZIndex = 25
	Kit.corner(marker, 4)
	HudParts.stroke(marker, rgb(120, 200, 255), 0.2, 3)
	marker.Parent = track

	local dots = Instance.new("Frame")
	dots.Name = "Dots"
	dots.BackgroundTransparency = 1
	dots.AnchorPoint = Vector2.new(0.5, 0)
	dots.Position = UDim2.new(0.5, 0, 0, 172)
	dots.Size = UDim2.new(1, -60, 0, 18)
	dots.ZIndex = 21
	dots.Parent = game_
	local dotsLayout = Instance.new("UIListLayout")
	dotsLayout.FillDirection = Enum.FillDirection.Horizontal
	dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dotsLayout.Padding = UDim.new(0, 10)
	dotsLayout.Parent = dots

	local timeLabel = HudParts.text(game_, "", 22, { Font = Theme.FontSemi, TextColor3 = Theme.Muted, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -18), ZIndex = 21 })
	local pressButton = PanelKit.button(game_, t("rp_press"), "green", Vector2.new(300, 72), function() end)
	pressButton.AnchorPoint = Vector2.new(1, 1)
	pressButton.Position = UDim2.new(1, -20, 1, -12)
	pressButton.ZIndex = 22
	for _, d in ipairs(pressButton:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 23
		end
	end
	local hint = HudParts.text(game_, t("rp_hint_key"), 20, { Font = Theme.FontSemi, TextColor3 = Theme.Muted, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -44), ZIndex = 21 })
	local _ = hint

	-- ===== Grupo do resultado: qualidade e gorjeta à esquerda, os 6 fatores à direita =====
	local result = Instance.new("Frame")
	result.Name = "Result"
	result.BackgroundTransparency = 1
	result.Position = UDim2.fromOffset(0, 54)
	result.Size = UDim2.new(1, 0, 1, -54)
	result.Visible = false
	result.ZIndex = 21
	result.Parent = root
	local left = Instance.new("Frame")
	left.Name = "Left"
	left.BackgroundTransparency = 1
	left.Size = UDim2.new(0.46, 0, 1, 0)
	left.ZIndex = 21
	left.Parent = result
	local resultLayout = Instance.new("UIListLayout")
	resultLayout.Padding = UDim.new(0, 6)
	resultLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	resultLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	resultLayout.SortOrder = Enum.SortOrder.LayoutOrder
	resultLayout.Parent = left
	local qualityLabel = HudParts.text(left, "", 52, { Font = Theme.FontTitle, LayoutOrder = 1, ZIndex = 22 })
	local qualityTrack, setQuality = HudParts.progress(left, 14)
	qualityTrack.Size = UDim2.fromOffset(230, 14)
	qualityTrack.LayoutOrder = 2
	qualityTrack.ZIndex = 22
	local tipLabel = HudParts.text(left, "", 30, { Font = Theme.FontTitle, LayoutOrder = 3, ZIndex = 22 })
	local statLabel = HudParts.text(left, "", 20, { Font = Theme.FontSemi, TextColor3 = rgb(190, 205, 230), LayoutOrder = 4, ZIndex = 22, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -20, 0, 0), TextXAlignment = Enum.TextXAlignment.Center })
	local continueButton = PanelKit.button(left, t("rp_continue"), "blue", Vector2.new(200, 52), function() end)
	continueButton.LayoutOrder = 5
	continueButton.ZIndex = 22
	local right = Instance.new("Frame")
	right.Name = "Factors"
	right.BackgroundTransparency = 1
	right.Position = UDim2.fromScale(0.46, 0)
	right.Size = UDim2.new(0.54, -16, 1, 0)
	right.ZIndex = 21
	right.Parent = result
	local rightLayout = Instance.new("UIListLayout")
	rightLayout.Padding = UDim.new(0, 2)
	rightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rightLayout.Parent = right

	local function showFactors(breakdown: any)
		for _, c in ipairs(right:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local rows = {
			{ t("rp_f_precision"), tonumber(breakdown.Execution) or 0, false },
			{ t("rp_f_errors"), tonumber(breakdown.Errors) or 0, true },
			{ t("rp_f_skill"), tonumber(breakdown.Skill) or 0, true },
			{ t("rp_f_equipment"), tonumber(breakdown.Equipment) or 0, true },
			{ t("rp_f_part"), tonumber(breakdown.Part) or 0, true },
			{ t("rp_f_diagnosis"), tonumber(breakdown.Diagnosis) or 0, true },
		}
		HudParts.text(right, t("rp_factors"), 24, { Font = Theme.FontTitle, LayoutOrder = 0, ZIndex = 22 })
		for index, row in ipairs(rows) do
			local line = Instance.new("Frame")
			line.BackgroundTransparency = 1
			line.Size = UDim2.new(1, 0, 0, 30)
			line.LayoutOrder = index
			line.ZIndex = 22
			line.Parent = right
			HudParts.text(line, row[1] :: string, 22, { Font = Theme.FontSemi, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.6, 0, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 22 })
			local value = row[2] :: number
			local signed = row[3] :: boolean
			local color = (not signed) and Theme.Text or (value > 0 and rgb(70, 225, 105) or (value < 0 and rgb(255, 110, 100) or Theme.Muted))
			HudParts.text(line, signed and string.format("%+d", value) or tostring(value), 24, {
				Font = Theme.FontTitle, TextColor3 = color, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromScale(0.6, 0),
				TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 22,
			})
		end
	end

	-- ===== Estado =====
	local active = false
	local waitingResult = false
	local plan: RepairRules.Plan? = nil
	local jobId = ""
	local step = 1
	local phase = "base" -- "base" (etapa) | "fix" (correção depois de um erro)
	local corrections = 0
	local presses: { number } = {}
	local stepStart = 0
	local pausedUntil = 0
	local sessionStart = 0
	local heartbeat: RBXScriptConnection? = nil
	local dotFrames: { Frame } = {}
	local lastDistanceCheck = 0
	local finish: () -> ()
	local close: (boolean) -> ()

	local function markStep(index: number, outcome: string)
		local dot = dotFrames[index]
		if dot then
			dot.BackgroundColor3 = COLORS[outcome]
			if not Motion.reduced() then
				dot.Size = UDim2.fromOffset(26, 26)
				Motion.play(dot, Motion.Pop, { Size = UDim2.fromOffset(18, 18) })
			end
		end
	end

	local function showStep()
		local current = plan :: RepairRules.Plan
		local center, width = current.Centers[step], current.Width
		if phase == "fix" then
			center, width = current.CorrectionCenters[corrections], current.CorrectionWidth
		end
		stepLabel.Text = phase == "fix" and t("rp_fix") or t("rp_step", step, current.Steps)
		zone.Position = UDim2.new(center, 0, 0, 0)
		zone.Size = UDim2.new(width, 0, 1, 0)
		zone.BackgroundColor3 = phase == "fix" and COLORS.fixed or Color3.new(1, 1, 1)
		stepStart = os.clock()
	end

	local function flash(outcome: string)
		feedback.Text = outcome == "perfect" and t("rp_perfect") or (outcome == "good" and t("rp_good") or (outcome == "fixed" and t("rp_fixed") or t("rp_miss")))
		feedback.TextColor3 = COLORS[outcome]
		feedback.TextTransparency = 0
		feedbackScale.Scale = 1.4
		Motion.scale(feedbackScale, 1, Motion.Pop)
		if outcome == "miss" and not Motion.reduced() then
			local home = track.Position
			task.spawn(function()
				for _, dx in ipairs({ 10, -10, 6, -6, 0 }) do
					track.Position = home + UDim2.fromOffset(dx, 0)
					task.wait(0.04)
				end
				track.Position = home
			end)
		end
		Motion.play(feedback, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.25), { TextTransparency = 1 })
	end

	local function advance()
		local current = plan :: RepairRules.Plan
		if step >= current.Steps then
			finish()
		else
			step += 1
			task.delay(FEEDBACK_PAUSE, function()
				if active and not waitingResult then
					showStep()
				end
			end)
		end
	end

	-- Registra um toque (ou o tempo esgotado) da etapa atual. Mesma sequência que o servidor recalcula (RepairRules.Evaluate).
	local function resolve(seconds: number)
		local current = plan :: RepairRules.Plan
		presses[#presses + 1] = seconds
		pausedUntil = os.clock() + FEEDBACK_PAUSE
		if phase == "base" then
			local outcome = RepairRules.Outcome(current, step, seconds)
			markStep(step, outcome)
			flash(outcome)
			if outcome == "miss" and corrections < RepairRules.MaxCorrections then
				corrections += 1
				phase = "fix"
				task.delay(FEEDBACK_PAUSE, function()
					if active and not waitingResult then
						showStep()
					end
				end)
			else
				advance()
			end
		else
			local outcome = RepairRules.CorrectionOutcome(current, corrections, seconds)
			if outcome ~= "miss" then
				markStep(step, "fixed")
				flash("fixed")
			else
				flash("miss")
			end
			phase = "base"
			advance()
		end
	end

	local function press()
		if not active or waitingResult or os.clock() < pausedUntil or not plan then
			return
		end
		local elapsed = os.clock() - stepStart
		if elapsed < RepairRules.MinStepSeconds then
			return -- toque residual do clique anterior
		end
		resolve(elapsed)
	end

	finish = function()
		waitingResult = true
		task.delay(FEEDBACK_PAUSE, function()
			if active and waitingResult then
				Store.Act("FinishRepair", { JobId = jobId, Presses = presses })
				-- se o servidor recusar, o resultado nunca vem: fecha sozinho após alguns segundos
				task.delay(4, function()
					if active and waitingResult and root.Visible and not result.Visible then
						close(false)
					end
				end)
			end
		end)
	end

	close = function(notifyServer: boolean)
		if not active and not root.Visible then
			return
		end
		local wasPlaying = active and not result.Visible
		active = false
		waitingResult = false
		ContextActionService:UnbindAction(ACTION)
		if heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
		if notifyServer and wasPlaying then
			Store.Act("CancelRepair", {})
		end
		Motion.scale(pop, 0.9, Motion.Close)
		task.delay(0.13, function()
			if not active then
				root.Visible = false
			end
		end)
	end

	local function onFrame()
		if not active or not plan then
			return
		end
		local now = os.clock()
		if not waitingResult and now >= pausedUntil then
			local elapsed = now - stepStart
			marker.Position = UDim2.fromScale(RepairRules.MarkerPosition(plan.Speed, elapsed), 0.5)
			if elapsed >= RepairRules.MaxStepSeconds then
				resolve(RepairRules.MaxStepSeconds)
			end
		end
		timeLabel.Text = t("rp_time") .. ": " .. string.format("%.1f s", now - sessionStart)
		-- afastou-se do carro: cancela (o servidor também confere a distância ao receber)
		if now - lastDistanceCheck > 0.5 and not waitingResult then
			lastDistanceCheck = now
			local vehicles = Workspace:FindFirstChild("Vehicles")
			local car = vehicles and vehicles:FindFirstChild(jobId)
			local character = Players.LocalPlayer.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if car and car:IsA("Model") and rootPart and rootPart:IsA("BasePart") then
				local cf, size = car:GetBoundingBox()
				local relative = cf:PointToObjectSpace(rootPart.Position)
				local half = size / 2
				local d = Vector3.new(math.max(math.abs(relative.X) - half.X, 0), math.max(math.abs(relative.Y) - half.Y, 0), math.max(math.abs(relative.Z) - half.Z, 0)).Magnitude
				if d > Config.InteractDistance + 4 then
					Store.Message:Fire(t("rp_away"), false, "")
					close(true)
				end
			end
		end
	end

	local function start(payload: any)
		if type(payload) ~= "table" or type(payload.Plan) ~= "table" then
			return
		end
		close(false)
		plan = payload.Plan :: RepairRules.Plan
		jobId = tostring(payload.JobId)
		step, presses, waitingResult = 1, {}, false
		phase, corrections = "base", 0
		sessionStart = os.clock()
		pausedUntil = 0
		lastDistanceCheck = 0
		vehicleLabel.Text = tostring(payload.Vehicle or "")
		titleLabel.Text = t("rp_title") .. " · " .. tostring(payload.Service or "")
		feedback.Text = ""
		result.Visible = false
		game_.Visible = true
		for _, d in ipairs(dotFrames) do
			d:Destroy()
		end
		dotFrames = {}
		for i = 1, (plan :: RepairRules.Plan).Steps do
			local dot = Instance.new("Frame")
			dot.BackgroundColor3 = COLORS.pending
			dot.BorderSizePixel = 0
			dot.Size = UDim2.fromOffset(18, 18)
			dot.LayoutOrder = i
			dot.ZIndex = 22
			Kit.corner(dot, 9)
			dot.Parent = dots
			dotFrames[i] = dot
		end
		active = true
		root.Visible = true
		pop.Scale = 0.9
		Motion.scale(pop, 1, Motion.Open)
		showStep()
		-- Espaço / botão A do controle apertam a barra sem pular com o personagem
		ContextActionService:BindActionAtPriority(ACTION, function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				press()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		heartbeat = RunService.RenderStepped:Connect(onFrame)
	end

	local function showResult(payload: any)
		if not root.Visible then
			return
		end
		waitingResult = false
		active = false
		ContextActionService:UnbindAction(ACTION)
		if heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
		local quality = tonumber(payload.Quality) or 0
		local tip = tonumber(payload.Tip) or 0
		titleLabel.Text = t("rp_result_title")
		game_.Visible = false
		result.Visible = true
		qualityLabel.Text = string.format("%s %d%%", t("rp_quality"), quality)
		qualityLabel.TextColor3 = quality >= RepairRules.PerfectQuality and COLORS.perfect or (quality >= RepairRules.PoorQuality and COLORS.good or COLORS.miss)
		setQuality(quality / 100, qualityLabel.TextColor3)
		tipLabel.Text = tip > 0 and (t("rp_tip") .. " +" .. tip) or t("rp_none")
		tipLabel.TextColor3 = tip > 0 and COLORS.perfect or Theme.Muted
		statLabel.Text = t("rp_stat", tonumber(payload.Perfect) or 0, tonumber(payload.Good) or 0, tonumber(payload.Miss) or 0)
		if type(payload.Breakdown) == "table" then
			showFactors(payload.Breakdown)
		end
		task.delay(9, function()
			if result.Visible then
				result.Visible = false
				close(false)
			end
		end)
	end

	pressButton.Activated:Connect(press)
	cancelButton.Activated:Connect(function()
		close(true)
	end)
	continueButton.Activated:Connect(function()
		result.Visible = false
		close(false)
	end)
	Store.RepairStart.Event:Connect(start)
	Store.RepairDone.Event:Connect(showResult)
	Store.Message.Event:Connect(function(_: string, success: boolean, action: string)
		-- o servidor recusou o envio (toque inválido, peças, distância): fecha sem mostrar resultado
		if action == "FinishRepair" and not success and root.Visible and not result.Visible then
			close(false)
		end
	end)
	-- preferência de acessibilidade: barra mais lenta com "Reduzir movimento"
	Store.Act("RepairPrefs", { Assist = GuiService.ReducedMotionEnabled })

	return {
		Start = start,
		IsActive = function()
			return active
		end,
		Cancel = function()
			close(true)
		end,
		-- ajusta largura, posição e escala à tela (celular em pé, celular deitado)
		Fit = function(logicalWidth: number, logicalHeight: number)
			holder.Size = UDim2.fromOffset(math.min(640, logicalWidth - 24), 330)
			holder.Position = UDim2.new(0.5, 0, 1, logicalHeight < 640 and -122 or -140)
			fit.Scale = math.clamp((logicalHeight - 112 - 122) / 330, 0.7, 1)
		end,
	}
end

return RepairGame
