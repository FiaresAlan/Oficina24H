--!strict
-- Diagnóstico por escolha: mostra o sintoma relatado pelo cliente e 3 candidatos; o jogador escolhe e o SERVIDOR valida
-- (ação "DiagnoseJob" com Choice). Palpite errado bloqueia a opção e reduz a qualidade do reparo; acertar libera o serviço.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Motion)
local Store = require(script.Parent.Store)
local HudParts = require(script.Parent.HudParts)
local PanelKit = require(script.Parent.PanelKit)

local t = Kit.t
local _ = ReplicatedStorage
local DiagnosisGame = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local HEIGHT = 520

function DiagnosisGame.new(gui: ScreenGui): { IsActive: () -> boolean, Fit: (number, number) -> (), Close: () -> () }
	local holder = Instance.new("Frame")
	holder.Name = "DiagnosisHolder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -140)
	holder.Size = UDim2.fromOffset(640, HEIGHT)
	holder.ZIndex = 20
	holder.Parent = gui
	local fit = Instance.new("UIScale")
	fit.Name = "Fit"
	fit.Parent = holder
	local root = HudParts.panel(holder, "DiagnosisGame")
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.ZIndex = 20
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = root

	local header = HudParts.header(root, 54)
	header.ZIndex = 21
	local title = HudParts.text(header, t("dg_title"), 32, { Font = Theme.FontTitle, Position = UDim2.fromOffset(18, 0), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -80, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 22, TextTruncate = Enum.TextTruncate.AtEnd })
	local _t = title
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseDiagnosis"
	closeButton.AutoButtonColor = false
	closeButton.Text = "X"
	closeButton.Font = Theme.FontTitle
	closeButton.TextSize = 30
	closeButton.TextColor3 = Theme.Text
	closeButton.BackgroundColor3 = rgb(20, 40, 80)
	closeButton.BorderSizePixel = 0
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, -10, 0.5, 0)
	closeButton.Size = UDim2.fromOffset(44, 40)
	closeButton.ZIndex = 23
	Kit.corner(closeButton, 12)
	closeButton.Parent = header

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 5
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Position = UDim2.fromOffset(0, 54)
	body.Size = UDim2.new(1, 0, 1, -54)
	body.ZIndex = 21
	body.Parent = root
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 12), UDim.new(0, 18), UDim.new(0, 18)
	pad.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body

	local customerLabel = HudParts.text(body, "", 24, { Font = Theme.FontSemi, TextColor3 = rgb(190, 205, 230), LayoutOrder = 1, ZIndex = 22 })
	local complaintLabel = HudParts.text(body, "", 28, { Font = Theme.FontTitle, LayoutOrder = 2, ZIndex = 22, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	HudParts.text(body, t("dg_hint"), 21, { Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 3, ZIndex = 22, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	HudParts.text(body, "INSPEÇÃO NO CARRO · use os marcadores ou selecione um exame estando ao lado da peça", 18, { Font = Theme.FontSemi, TextColor3 = rgb(190, 205, 230), LayoutOrder = 4, ZIndex = 22 })
	local exams = Instance.new("Frame")
	exams.Name = "Exams"
	exams.BackgroundTransparency = 1
	exams.Size = UDim2.new(1, 0, 0, 48)
	exams.LayoutOrder = 5
	exams.ZIndex = 22
	exams.Parent = body
	local examLayout = Instance.new("UIListLayout")
	examLayout.FillDirection = Enum.FillDirection.Horizontal
	examLayout.Padding = UDim.new(0, 6)
	examLayout.Parent = exams
	local findingLabel = HudParts.text(body, "Nenhum exame realizado.", 19, { Font = Theme.FontSemi, TextColor3 = rgb(190, 220, 240), LayoutOrder = 6, ZIndex = 22, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	local options = Instance.new("Frame")
	options.Name = "Options"
	options.BackgroundTransparency = 1
	options.Size = UDim2.new(1, 0, 0, 0)
	options.AutomaticSize = Enum.AutomaticSize.Y
	options.LayoutOrder = 7
	options.ZIndex = 22
	options.Parent = body
	local optionsLayout = Instance.new("UIListLayout")
	optionsLayout.Padding = UDim.new(0, 8)
	optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	optionsLayout.Parent = options

	local active = false
	local jobId = ""
	local sending = false

	local function close()
		if not active and not root.Visible then
			return
		end
		active = false
		Motion.scale(pop, 0.9, Motion.Close)
		task.delay(0.13, function()
			if not active then
				root.Visible = false
			end
		end)
	end

	local function show(payload: any)
		if type(payload) ~= "table" or type(payload.Options) ~= "table" then
			return
		end
		jobId = tostring(payload.JobId)
		sending = false
		customerLabel.Text = string.format("%s · %s", tostring(payload.Customer or "?"), tostring(payload.Vehicle or ""))
		complaintLabel.Text = "“" .. tostring(payload.Complaint or "") .. "”"
		local done, findings = {}, {}
		for _, finding in ipairs(payload.Findings or {}) do
			if type(finding) == "table" then
				done[finding.Id] = true
				table.insert(findings, tostring(finding.Name) .. ": " .. tostring(finding.Text))
			end
		end
		findingLabel.Text = #findings > 0 and table.concat(findings, "\n") or "Nenhum exame realizado. Testes ajudam a descartar hipóteses."
		for _, child in ipairs(exams:GetChildren()) do
			if child:IsA("GuiObject") then child:Destroy() end
		end
		for index, exam in ipairs(payload.Exams or {}) do
			local examined = done[exam.Id] == true
			local examButton = PanelKit.button(exams, examined and ("✓ " .. tostring(exam.Name)) or tostring(exam.Name), examined and "dark" or "blue", Vector2.new(190, 44), function()
				if sending then return end
				sending = true
				Store.Act("ExamineJob", { JobId = jobId, ExamId = exam.Id })
			end)
			examButton.LayoutOrder = index
			examButton.Name = "Exam_" .. tostring(exam.Id)
			if examined then examButton.Active = false end
		end
		for _, c in ipairs(options:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for index, option in ipairs(payload.Options) do
			local wrong = option.Wrong == true
			local button = PanelKit.button(options, wrong and (tostring(option.Name) .. " · " .. t("dg_discarded")) or tostring(option.Name), wrong and "dark" or "blue", Vector2.new(604, 56), function()
				if sending then
					return
				end
				sending = true
				Store.Act("DiagnoseJob", { JobId = jobId, Choice = option.Id })
			end)
			button.LayoutOrder = index
			button.Name = "Option_" .. tostring(option.Id)
			if wrong then
				button.Active = false -- opção já descartada
			end
		end
		if not active then
			active = true
			root.Visible = true
			pop.Scale = 0.9
			Motion.scale(pop, 1, Motion.Open)
		end
	end

	closeButton.Activated:Connect(close)
	Store.DiagnoseStart.Event:Connect(show)
	Store.DiagnoseDone.Event:Connect(function()
		close()
	end)
	Store.Message.Event:Connect(function(_message: string, success: boolean, action: string)
		if not success and (action == "ExamineJob" or action == "DiagnoseJob") then
			sending = false -- erro de proximidade/requisição não bloqueia a interface
		end
	end)

	return {
		IsActive = function()
			return active
		end,
		Close = close,
		Fit = function(logicalWidth: number, logicalHeight: number)
			-- Dimensionamento proporcional dos controles fixos (604 px) também no celular.
			-- Reduzir somente a largura externa cortava opções e botões de exame.
			holder.Size = UDim2.fromOffset(640, HEIGHT)
			holder.Position = UDim2.new(0.5, 0, 1, logicalHeight < 640 and -122 or -140)
			local widthScale = (logicalWidth - 24) / 640
			local heightScale = (logicalHeight - 112 - 122) / HEIGHT
			fit.Scale = math.clamp(math.min(widthScale, heightScale), 0.4, 1)
		end,
	}
end

return DiagnosisGame
