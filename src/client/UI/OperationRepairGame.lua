--!strict
-- Quinze serviços com interações distintas por especialidade: três pilotos e doze receitas.
-- O servidor avalia todos os valores, fases e consequências; esta UI apenas coleta decisões.
-- O minijogo legado permanece como fallback para defeitos desconhecidos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Store = require(script.Parent.Store)
local HudParts = require(script.Parent.HudParts)
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)

local OperationRepairGame = {}

local WIDTH, HEIGHT = 620, 380
local function label(parent: Instance, text: string, y: number, height: number, fontSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = Theme.Text
	l.Font = Theme.FontSemi
	l.TextSize = fontSize
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Size = UDim2.new(1, -32, 0, height)
	l.Position = UDim2.fromOffset(16, y)
	l.ZIndex = 32
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, x: number, y: number, w: number, h: number, click: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Action_" .. text
	b.Text = text
	b.Font = Theme.FontTitle
	b.TextSize = 22
	b.TextColor3 = Color3.fromRGB(245, 250, 255)
	b.TextWrapped = true
	b.AutoButtonColor = true
	b.BackgroundColor3 = Color3.fromRGB(24, 77, 135)
	b.BorderSizePixel = 0
	b.Size = UDim2.fromOffset(w, h)
	b.Position = UDim2.fromOffset(x, y)
	b.ZIndex = 33
	Kit.corner(b, 10)
	b.Activated:Connect(click)
	b.Parent = parent
	return b
end

function OperationRepairGame.new(gui: ScreenGui)
	local holder = Instance.new("Frame")
	holder.Name = "OperationRepairHolder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -140)
	holder.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	holder.ZIndex = 30
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local root = HudParts.panel(holder, "OperationRepair")
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 30
	root.Visible = false
	local pop = Instance.new("UIScale")
	pop.Parent = root

	local header = HudParts.header(root, 58)
	local title = label(header, "PROCEDIMENTO MECÂNICO", 0, 58, 26)
	title.Size = UDim2.new(1, -78, 1, 0)
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(0, 58)
	content.Size = UDim2.new(1, 0, 1, -58)
	content.ZIndex = 31
	content.Parent = root

	local active, waiting, showingResult = false, false, false
	local jobId, currentPlan = "", nil :: any
	local sessionToken = ""
	local revision = 0
	local pendingAction: any = nil
	local statusRef: TextLabel? = nil
	local finishPacket: any = nil
	local finishRetries, outcomeChecks = 0, 0
	local startedAt = 0
	local pressure, spot, sequence = 28, nil :: string?, {} :: { string }
	local fluid, bleed, fan = 1.5, 0, false
	local measures: { [string]: number } = {}
	local zoneLevels: { [string]: number } = {}
	local sourceId: string? = nil
	local actionId: string? = nil
	local close: (boolean) -> ()

	local function clear()
		for _, child in ipairs(content:GetChildren()) do
			if child:IsA("GuiObject") then child:Destroy() end
		end
	end

	close = function(cancelServer: boolean)
		if not root.Visible then return end
		local notify = cancelServer and active and not showingResult
		active, waiting, showingResult = false, false, false
		pendingAction = nil
		statusRef = nil
		finishPacket = nil
		if notify then
			Store.Act("CancelRepair", { JobId = jobId, Token = sessionToken })
		end
		Motion.scale(pop, 0.9, Motion.Close)
		task.delay(0.13, function()
			if not active and not showingResult then
				root.Visible = false
			end
		end)
	end

	-- Esta consulta nunca solicita pagamento: apenas lê o comprovante privado do servidor.
	-- A UI permanece aberta enquanto o resultado estiver incerto.
	local function queryOutcome(force: boolean?)
		if not active or not waiting or sessionToken == "" then return end
		if outcomeChecks >= 6 and not force then return end
		outcomeChecks += 1
		if statusRef then statusRef.Text = "Consultando a entrega no servidor..." end
		Store.Act("CheckRepairResult", { JobId = jobId, Token = sessionToken })
	end

	local function requestAfter(seconds: number)
		local token, requestedJob = sessionToken, jobId
		task.delay(seconds, function()
			if active and waiting and not showingResult and token == sessionToken and requestedJob == jobId then
				queryOutcome(false)
			end
		end)
	end

	local function start(payload: any)
		if type(payload) ~= "table" or type(payload.Plan) ~= "table" or payload.Plan.Kind ~= "Operations" then
			return
		end
		close(false)
		clear()
		jobId = tostring(payload.JobId)
		currentPlan = payload.Plan
		sessionToken = tostring(payload.Token or "")
		revision = 0
		pendingAction = nil
		finishPacket = nil
		finishRetries, outcomeChecks = 0, 0
		active, waiting, showingResult = true, false, false
		startedAt = os.clock()
		pressure, spot, sequence = 28, nil, {}
		fluid, bleed, fan = 1.5, 0, false
		measures, zoneLevels = {}, {}
		sourceId, actionId = nil, nil
		title.Text = tostring(payload.Service or "Reparo") .. " · procedimento"
		local status = label(content, "", 72, 36, 20)
		statusRef = status
		if sessionToken == "" then
			active = false
			status.Text = "Sessão sem identificador; tente iniciar o reparo novamente."
			Store.Act("CancelRepair", { JobId = jobId, Token = sessionToken })
			return
		end

		local function submit(kind: string, id: string?, value: any, apply: () -> ())
			if not active or waiting or pendingAction then return end
			pendingAction = {
				Apply = apply, JobId = jobId, Token = sessionToken,
				Revision = revision,
			}
			local requested = pendingAction
			local request = {
				JobId = jobId, Token = sessionToken,
				Command = { Revision = revision, Kind = kind, Id = id, Value = value },
			}
			-- Retransmitimos a MESMA revisão. O servidor responde à repetição
			-- sem reaplicar a etapa ou duplicar resultados.
			local function transmit(attempt: number)
				if pendingAction ~= requested or not active then return end
				Store.Act("RepairAction", request)
				task.delay(attempt == 1 and 2.5 or 3, function()
					if pendingAction ~= requested or not active then return end
					if attempt < 3 then
						status.Text = "Conexão lenta: reconfirmando a etapa (" .. attempt .. "/2)..."
						transmit(attempt + 1)
					else
						pendingAction = nil
						Store.Message:Fire("Sem resposta do servidor. Reabra o reparo para continuar com segurança.", false, "RepairAction")
						close(true)
					end
				end)
			end
			transmit(1)
		end

		local function update()
			if currentPlan.Mode == "Tire" then
				status.Text = string.format("Remendo: %s  ·  Pressão: %d psi", spot or "não selecionado", pressure)
			elseif currentPlan.Mode == "Battery" then
				status.Text = string.format("Terminais: %d/4 · %s", #sequence, table.concat(sequence, " → "))
			elseif currentPlan.Mode == "Cooling" then
				status.Text = string.format("Fluido: %.2f L · Sangria: %d ciclos · Ventoinha: %s", fluid, bleed, fan and "testada" or "pendente")
			elseif currentPlan.Mode == "Sequence" then
				status.Text = string.format("Etapas executadas: %d/%d", #sequence, #(currentPlan.Options or {}))
			elseif currentPlan.Mode == "Calibration" then
				local words = {}
				for _, field in ipairs(currentPlan.Fields or {}) do
					table.insert(words, tostring(field.Name) .. " " .. tostring(measures[field.Id]) .. tostring(field.Unit))
				end
				status.Text = table.concat(words, " · ")
			elseif currentPlan.Mode == "Circuit" then
				status.Text = "Circuito: " .. tostring(sourceId or "?") .. " · Ação: " .. tostring(actionId or "?")
			elseif currentPlan.Mode == "Surface" then
				local words = {}
				for _, zone in ipairs(currentPlan.Zones or {}) do
					table.insert(words, tostring(zone.Name) .. " " .. tostring(zoneLevels[zone.Id] or 0))
				end
				status.Text = "Intensidade 0–3: " .. table.concat(words, " · ")
			end
		end

		if currentPlan.Mode == "Tire" then
			label(content, tostring(currentPlan.Hint or "") .. " Repare no ponto correto e calibre a " .. tostring(currentPlan.PressureTarget or 32) .. " psi.", 5, 62, 22)
			for i, item in ipairs({ { "Ombro interno", "Inner" }, { "Centro", "Center" }, { "Ombro externo", "Outer" } }) do
				button(content, item[1], 16 + (i - 1) * 200, 120, 190, 48, function()
					submit("Spot", nil, item[2], function()
						spot = item[2]
						update()
					end)
				end)
			end
			label(content, "Ajustar a pressão", 184, 38, 22)
			button(content, "− 2 psi", 340, 188, 112, 40, function()
				local value = math.max(0, pressure - 2)
				if value ~= pressure then
					submit("Pressure", nil, value, function() pressure = value update() end)
				end
			end)
			button(content, "+ 2 psi", 468, 188, 112, 40, function()
				local value = math.min(44, pressure + 2)
				if value ~= pressure then
					submit("Pressure", nil, value, function() pressure = value update() end)
				end
			end)
		elseif currentPlan.Mode == "Battery" then
			label(content, tostring(currentPlan.Hint or ""), 5, 60, 22)
			for i, op in ipairs({
				{ "Soltar negativo (−)", "OffNegative" },
				{ "Soltar positivo (+)", "OffPositive" },
				{ "Ligar positivo (+)", "OnPositive" },
				{ "Ligar negativo (−)", "OnNegative" },
			}) do
				local col = (i - 1) % 2
				local row = math.floor((i - 1) / 2)
				button(content, op[1], 16 + col * 302, 116 + row * 57, 286, 48, function()
					if waiting or #sequence >= 4 then return end
					submit("Step", nil, op[2], function()
						table.insert(sequence, op[2])
						update()
					end)
				end)
			end
			button(content, "Refazer sequência", 16, 265, 244, 48, function()
				submit("Reset", nil, nil, function()
					sequence = {}
					update()
				end)
			end)
		elseif currentPlan.Mode == "Cooling" then
			label(content, tostring(currentPlan.Hint or ""), 5, 60, 22)
			label(content, "Volume do fluido", 113, 40, 22)
			button(content, "− 0,25 L", 330, 112, 116, 40, function()
				local value = math.max(0, fluid - 0.25)
				if value ~= fluid then
					submit("Fluid", nil, value, function() fluid = value update() end)
				end
			end)
			button(content, "+ 0,25 L", 466, 112, 116, 40, function()
				local value = math.min(3, fluid + 0.25)
				if value ~= fluid then
					submit("Fluid", nil, value, function() fluid = value update() end)
				end
			end)
			label(content, "Ciclos de sangria", 172, 40, 22)
			button(content, "− 1", 330, 173, 116, 40, function()
				local value = math.max(0, bleed - 1)
				if value ~= bleed then
					submit("Bleed", nil, value, function() bleed = value update() end)
				end
			end)
			button(content, "+ 1", 466, 173, 116, 40, function()
				local value = math.min(5, bleed + 1)
				if value ~= bleed then
					submit("Bleed", nil, value, function() bleed = value update() end)
				end
			end)
			button(content, "Testar ventoinha", 16, 265, 244, 48, function()
				local value = not fan
				submit("Fan", nil, value, function() fan = value update() end)
			end)
		elseif currentPlan.Mode == "Sequence" then
			label(content, tostring(currentPlan.Hint or ""), 5, 60, 21)
			for i, op in ipairs(currentPlan.Options or {}) do
				local col = (i - 1) % 2
				local row = math.floor((i - 1) / 2)
				button(content, tostring(op.Name), 16 + col * 300, 116 + row * 47, 285, 42, function()
					if waiting or #sequence >= #(currentPlan.Options or {}) then return end
					if table.find(sequence, op.Id) then return end
					submit("Step", nil, tostring(op.Id), function()
						table.insert(sequence, tostring(op.Id))
						update()
					end)
				end)
			end
			button(content, "RECOMEÇAR ORDEM", 16, 265, 250, 48, function()
				if waiting then return end
				sequence = {}
				update()
			end)
		elseif currentPlan.Mode == "Calibration" then
			label(content, tostring(currentPlan.Hint or ""), 5, 60, 21)
			for index, field in ipairs(currentPlan.Fields or {}) do
				measures[field.Id] = field.Initial
				local y = 113 + (index - 1) * 61
				label(content, tostring(field.Name) .. " · alvo " .. tostring(field.Target) .. tostring(field.Unit), y, 44, 20)
				button(content, "− " .. tostring(field.Step), 345, y, 108, 43, function()
					local value = math.max(field.Min, math.round((measures[field.Id] - field.Step) * 100) / 100)
					if value ~= measures[field.Id] then
						submit("Measure", field.Id, value, function() measures[field.Id] = value update() end)
					end
				end)
				button(content, "+ " .. tostring(field.Step), 471, y, 108, 43, function()
					local value = math.min(field.Max, math.round((measures[field.Id] + field.Step) * 100) / 100)
					if value ~= measures[field.Id] then
						submit("Measure", field.Id, value, function() measures[field.Id] = value update() end)
					end
				end)
			end
		elseif currentPlan.Mode == "Circuit" then
			label(content, tostring(currentPlan.Hint or ""), 5, 60, 20)
			for i, source in ipairs(currentPlan.Sources or {}) do
				button(content, tostring(source.Name), 16 + (i - 1) * 145, 118, 136, 45, function()
					submit("Source", nil, source.Id, function() sourceId = source.Id update() end)
				end)
			end
			label(content, "Selecione o reparo do componente", 173, 30, 20)
			for i, action in ipairs(currentPlan.Actions or {}) do
				button(content, tostring(action.Name), 16 + (i - 1) * 197, 209, 185, 44, function()
					submit("Action", nil, action.Id, function() actionId = action.Id update() end)
				end)
			end
		elseif currentPlan.Mode == "Surface" then
			label(content, tostring(currentPlan.Hint or ""), 5, 60, 20)
			for i, zone in ipairs(currentPlan.Zones or {}) do
				zoneLevels[zone.Id] = 0
				local y = 113 + (i - 1) * 51
				label(content, tostring(zone.Name) .. " · " .. tostring(zone.Reading), y, 43, 19)
				button(content, "−", 346, y, 106, 43, function()
					local value = math.max(0, zoneLevels[zone.Id] - 1)
					if value ~= zoneLevels[zone.Id] then
						submit("Level", zone.Id, value, function() zoneLevels[zone.Id] = value update() end)
					end
				end)
				button(content, "+", 470, y, 106, 43, function()
					local value = math.min(3, zoneLevels[zone.Id] + 1)
					if value ~= zoneLevels[zone.Id] then
						submit("Level", zone.Id, value, function() zoneLevels[zone.Id] = value update() end)
					end
				end)
			end
		else
			active = false
			return
		end
		update()
		local finishButton: TextButton? = nil
		finishButton = button(content, "CONCLUIR SERVIÇO", 316, 265, 286, 48, function()
			if not active or pendingAction then return end
			if waiting then
				queryOutcome(true)
				return
			end
			local input
			if currentPlan.Mode == "Tire" then
				if not spot then
					status.Text = "Escolha primeiro onde aplicar o remendo."
					return
				end
				input = { Spot = spot, Pressure = pressure }
			elseif currentPlan.Mode == "Battery" then
				if #sequence ~= 4 then
					status.Text = "Complete as quatro operações nos terminais."
					return
				end
				input = { Steps = table.clone(sequence) }
			elseif currentPlan.Mode == "Cooling" then
				input = { Fluid = fluid, BleedCycles = bleed, FanChecked = fan }
			elseif currentPlan.Mode == "Sequence" then
				if #sequence ~= #(currentPlan.Options or {}) then
					status.Text = "Conclua todas as etapas antes de entregar."
					return
				end
				input = { Steps = table.clone(sequence) }
			elseif currentPlan.Mode == "Calibration" then
				input = { Values = table.clone(measures) }
			elseif currentPlan.Mode == "Circuit" then
				if not sourceId or not actionId then
					status.Text = "Selecione o circuito e a ação de reparo."
					return
				end
				input = { Source = sourceId, Action = actionId }
			elseif currentPlan.Mode == "Surface" then
				input = { Levels = table.clone(zoneLevels) }
			else
				return
			end
			local minSeconds = tonumber(currentPlan.MinSeconds) or 0
			local remaining = minSeconds - (os.clock() - startedAt)
			if remaining > 0 then
				status.Text = string.format("Revise o procedimento: aguarde mais %.1f s antes de finalizar.", remaining)
				return
			end
			waiting = true
			status.Text = "Enviando entrega para validação..."
			if finishButton then finishButton.Text = "VERIFICAR ENTREGA" end
			input.Token = sessionToken
			finishPacket = { JobId = jobId, Presses = input }
			finishRetries, outcomeChecks = 0, 0
			Store.Act("FinishRepair", finishPacket)
			-- Sem confirmação, primeiro consulte o resultado. Não cancele e não
			-- faça novo pagamento simplesmente por perder um pacote de rede.
			requestAfter(5)
		end)
		root.Visible = true
		pop.Scale = 0.9
		Motion.scale(pop, 1, Motion.Open)
	end

	local function showResult(payload: any)
		if type(payload) ~= "table" or not active or not root.Visible
			or payload.JobId ~= jobId or payload.Token ~= sessionToken then return end
		active, waiting, showingResult = false, false, true
		clear()
		title.Text = "SERVIÇO ENTREGUE"
		local quality = tonumber(payload.Quality) or 0
		label(content, string.format("Qualidade final: %d%%", quality), 20, 54, 34)
		label(content, string.format("Pagamento: +%d · Gorjeta: +%d · XP: +%d",
			tonumber(payload.Price) or 0, tonumber(payload.Tip) or 0, tonumber(payload.XP) or 0), 95, 70, 24)
		local b = payload.Breakdown or {}
		label(content, string.format("Execução %d · Habilidade %+d · Equipamento %+d · Peça %+d · Diagnóstico %+d",
			tonumber(b.Execution) or 0, tonumber(b.Skill) or 0, tonumber(b.Equipment) or 0,
			tonumber(b.Part) or 0, tonumber(b.Diagnosis) or 0), 180, 56, 20)
		button(content, "CONTINUAR", 340, 262, 250, 48, function() close(false) end)
		task.delay(9, function()
			if showingResult then close(false) end
		end)
	end

	local closeButton = button(header, "X", 560, 7, 46, 42, function() close(true) end)
	closeButton.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
	Store.RepairStart.Event:Connect(start)
	Store.RepairDone.Event:Connect(showResult)
	Store.RepairOutcome.Event:Connect(function(payload: any)
		if type(payload) ~= "table" or not active or not waiting
			or payload.JobId ~= jobId or payload.Token ~= sessionToken then return end
		if payload.Status == "Completed" and type(payload.Result) == "table" then
			showResult(payload.Result)
		elseif payload.Status == "Processing" then
			if statusRef then statusRef.Text = "O servidor está finalizando a OS. Não reenvie o pagamento." end
			requestAfter(2.5)
		elseif payload.Status == "Active" then
			-- A entrega ainda não foi recebida: repetir o MESMO pacote é seguro.
			-- O servidor usa sessão única e comprovante para impedir pagamento duplo.
			if finishPacket and finishRetries < 2 then
				finishRetries += 1
				if statusRef then statusRef.Text = "Reenviando entrega sem duplicar cobrança..." end
				Store.Act("FinishRepair", finishPacket)
				requestAfter(4)
			else
				if statusRef then statusRef.Text = "Serviço ainda em aberto. Toque em VERIFICAR ENTREGA." end
			end
		else
			if statusRef then
				statusRef.Text = "Sem confirmação desta sessão. Consulte Ordens antes de iniciar outro reparo."
			end
		end
	end)
	Store.RepairActionAck.Event:Connect(function(payload: any)
		if type(payload) ~= "table" or not active or payload.JobId ~= jobId
			or payload.Token ~= sessionToken or not pendingAction
			or payload.RequestRevision ~= pendingAction.Revision then return end
		local action = pendingAction
		pendingAction = nil
		if payload.Accepted == true and type(payload.Revision) == "number"
			and payload.Revision == revision + 1 then
			revision = payload.Revision
			action.Apply()
		else
			if statusRef then
				statusRef.Text = tostring(payload.Message or "Ação não confirmada.")
			end
			if type(payload.Revision) ~= "number" or payload.Revision ~= revision then
				Store.Message:Fire("Sessão dessincronizada. Inicie um novo reparo.", false, "RepairAction")
				close(true)
			end
		end
	end)
	Store.Message.Event:Connect(function(_text: string, success: boolean, action: string)
		if action == "FinishRepair" and not success and active and waiting then
			-- Até um erro pode competir com uma conclusão em processamento:
			-- verificar o comprovante antes de encerrar a janela.
			requestAfter(0.35)
		end
	end)

	return {
		IsActive = function() return active or showingResult end,
		Cancel = function() close(true) end,
		Fit = function(logicalWidth: number, logicalHeight: number)
			holder.Size = UDim2.fromOffset(WIDTH, HEIGHT)
			holder.Position = UDim2.new(0.5, 0, 1, logicalHeight < 640 and -122 or -140)
			scale.Scale = math.clamp(math.min((logicalWidth - 24) / WIDTH, (logicalHeight - 112 - 122) / HEIGHT), 0.42, 1)
		end,
	}
end

return OperationRepairGame
