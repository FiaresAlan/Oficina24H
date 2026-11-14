--!strict
-- Guia do 1º atendimento (FTUE): um objetivo por vez (até 8 palavras), um ponteiro por vez, derivado do estado REAL do
-- servidor (snapshot), então é retomável por natureza (sair e voltar continua de onde parou) e some sozinho ao terminar.
-- Termina quando o servidor conclui o 1º serviço (profile.Onboarding.Done); "Pular guia" pede confirmação.
-- Ponteiros: Highlight no cliente NPC/carro (mundo) ou contorno pulsante no botão do menu (interface).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Store = require(script.Parent.Store)
local HudParts = require(script.Parent.HudParts)
local Stations = require(script.Parent.Stations)

local t = Kit.t
local Onboarding = {}

local AMBER = Color3.fromRGB(255, 196, 40)

function Onboarding.new(gui: ScreenGui, navRoots: (string) -> { GuiObject })
	local player = Players.LocalPlayer

	local root = HudParts.panel(gui, "Onboarding")
	root.AutomaticSize = Enum.AutomaticSize.XY
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 150)
	root.ZIndex = 12
	root.Visible = false
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 16), UDim.new(0, 16), UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 14)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = root

	local stepLabel = HudParts.text(root, "", 22, { Font = Theme.FontSemi, TextColor3 = AMBER, LayoutOrder = 1, ZIndex = 13 })
	local objective = HudParts.text(root, "", 30, { Font = Theme.FontTitle, LayoutOrder = 2, ZIndex = 13 })
	local skip = Instance.new("TextButton")
	skip.Name = "SkipOnboarding"
	skip.AutoButtonColor = false
	skip.Font = Theme.FontSemi
	skip.TextSize = 22
	skip.Text = t("ob_skip")
	skip.TextColor3 = Theme.Text
	skip.BackgroundColor3 = Color3.fromRGB(20, 40, 80)
	skip.BorderSizePixel = 0
	skip.Size = UDim2.fromOffset(160, 58) -- alvo de toque >= 44 px também com o UIScale do celular (~0,77)
	skip.LayoutOrder = 3
	skip.ZIndex = 13
	Kit.corner(skip, 12)
	skip.Parent = root

	local confirming = false
	skip.Activated:Connect(function()
		if not confirming then
			confirming = true
			skip.Text = t("ob_skip_confirm")
			task.delay(3, function()
				confirming = false
				skip.Text = t("ob_skip")
			end)
			return
		end
		confirming = false
		Store.Act("SkipOnboarding", {})
		task.delay(0.3, Store.Refresh)
	end)

	-- Ponteiros ---------------------------------------------------------------------------------------------------
	local worldHighlight: Highlight? = nil
	local pulses: { UIStroke } = {}
	local currentStep = ""

	local function clearPointers()
		if worldHighlight then
			worldHighlight:Destroy()
			worldHighlight = nil
		end
		for _, stroke in ipairs(pulses) do
			stroke:Destroy()
		end
		table.clear(pulses)
	end

	local function pointWorld(target: Instance?)
		if not target then
			return
		end
		local h = Instance.new("Highlight")
		h.Name = "OnboardingHighlight"
		h.FillColor = AMBER
		h.OutlineColor = AMBER
		h.FillTransparency = 0.8
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Parent = target
		worldHighlight = h
		-- luz-guia do pé do jogador até o alvo (ajuda quando ele está fora da tela)
		local part = target:IsA("BasePart") and target or (target:IsA("Model") and (target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)))
		if part and part:IsA("BasePart") then
			Stations.GuideTo(part, 20)
		end
		if not GuiService.ReducedMotionEnabled then
			TweenService:Create(h, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { FillTransparency = 0.55 }):Play()
		end
	end

	local function pointButton(panelName: string)
		for _, button in ipairs(navRoots(panelName)) do
			local stroke = Instance.new("UIStroke")
			stroke.Name = "OnboardPulse"
			stroke.Color = AMBER
			stroke.Thickness = 4
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = button
			table.insert(pulses, stroke)
			if not GuiService.ReducedMotionEnabled then
				TweenService:Create(stroke, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 1.5 }):Play()
			end
		end
	end

	local function findWorld(jobId: string): Instance?
		local vehicles = workspace:FindFirstChild("Vehicles")
		if not vehicles then
			return nil
		end
		return vehicles:FindFirstChild("Cliente_" .. jobId) or vehicles:FindFirstChild(jobId)
	end

	local function vehicleOf(jobId: string): Instance?
		local vehicles = workspace:FindFirstChild("Vehicles")
		return vehicles and vehicles:FindFirstChild(jobId)
	end

	-- Estado -> passo atual (puro: só lê o snapshot)
	local function missingParts(job: any, profile: any): boolean
		local parts = job.Requirement and job.Requirement.Parts
		if type(parts) ~= "table" then
			return false
		end
		for partId, amount in pairs(parts) do
			if ((profile.Parts or {})[partId] or 0) < amount then
				return true
			end
		end
		return false
	end

	local function update(snapshot: any)
		local profile = snapshot and snapshot.Profile
		if not profile or not snapshot.HasWorkshop or (profile.Onboarding and profile.Onboarding.Done) then
			root.Visible = false
			clearPointers()
			currentStep = ""
			return
		end
		local active: any, available = nil, false
		for _, job in ipairs(snapshot.Jobs) do
			if job.Status == "InProgress" then
				active = job
			elseif job.Status == "Available" then
				available = true
			end
		end
		local step, text, kind, target = "", "", "", nil :: any
		if not active then
			if available then
				-- aceitar é na TV de ordens dentro da oficina
				local tv = Stations.Target("orders")
				if tv then
					step, text, kind, target = "accept", "Aceite o cliente na TV de ordens", "world", tv
				else
					step, text, kind, target = "accept", t("ob_accept"), "button", "orders"
				end
			else
				-- enquanto o 1º cliente chega, o jogador já vai para a TV (onde vai aceitar)
				local tv = Stations.Target("orders")
				if tv then
					step, text, kind, target = "wait", "Seu 1º cliente está chegando! Vá até a TV de ordens", "world", tv
				else
					step, text, kind = "wait", t("ob_wait"), "none"
				end
			end
		elseif not active.Diagnosed then
			step, text, kind, target = "talk:" .. active.Id, t("ob_talk"), "world", findWorld(active.Id)
		elseif missingParts(active, profile) then
			local shop = Stations.Target("shop")
			if shop then
				step, text, kind, target = "buy:" .. active.Id, "Compre as peças na Loja de Autopeças", "world", shop
			else
				step, text, kind, target = "buy:" .. active.Id, t("ob_buy"), "button", "shop"
			end
		elseif active.PrepRequired and not active.PrepComplete then
			step, text, kind, target = "prep:" .. active.Id, "Prepare o carro nos pontos amarelos antes do reparo", "world", vehicleOf(active.Id)
		else
			step, text, kind, target = "repair:" .. active.Id, t("ob_repair"), "world", vehicleOf(active.Id)
		end
		root.Visible = true
		objective.Text = text
		stepLabel.Text = t("ob_title")
		if step ~= currentStep or (kind == "world" and not worldHighlight and target) then
			currentStep = step
			clearPointers()
			if kind == "world" then
				pointWorld(target)
			elseif kind == "button" then
				pointButton(target :: string)
			end
		end
	end

	Store.Changed.Event:Connect(update)
	Store.DiagnoseStart.Event:Connect(function()
		root.Visible = false -- a tela de diagnóstico/reparo ocupa o foco; o guia volta no próximo snapshot
	end)
	Store.RepairStart.Event:Connect(function()
		root.Visible = false
	end)
	Store.RepairDone.Event:Connect(function(payload: any)
		if type(payload) == "table" and type(payload.Bonus) == "number" and payload.Bonus > 0 then
			task.delay(2.5, function()
				Store.Message:Fire(t("ob_next"), true, "")
			end)
		end
	end)
	local _ = player
	if Store.Snapshot then
		update(Store.Snapshot)
	end

	-- Homologação V1 (G4): o cartão do guia precisa caber no espaço LIVRE da tela.
	-- * 568x320: a linha "etapa + objetivo + Pular guia" passava de 670 px e vazava dos dois lados → empilha em coluna,
	--   com a base logo acima da barra de navegação (não cobre os botões).
	-- * 1920x1080 (PC/console): com objetivo longo a linha invadia o painel "Clientes aguardando" da coluna direita →
	--   centraliza no espaço entre a margem esquerda e a coluna direita.
	local fitTop = 150
	local watched: { [GuiObject]: boolean } = {}
	local function reflow()
		local unit = skip.AbsoluteSize.Y / 58 -- escala efetiva (UIScale do HUD)
		if unit <= 0 or gui.AbsoluteSize.X <= 0 then return end
		local leftLimit, rightLimit = 12, gui.AbsoluteSize.X - 12
		local column = gui:FindFirstChild("RightColumn")
		if column and column:IsA("GuiObject") and column.Visible and column.AbsoluteSize.X > 0 then
			rightLimit = math.min(rightLimit, column.AbsolutePosition.X - 12)
		end
		local available = rightLimit - leftLimit
		local rowWidth = stepLabel.AbsoluteSize.X + objective.AbsoluteSize.X + skip.AbsoluteSize.X
		local vertical = rowWidth + 60 * unit > available -- 60 = paddings + espaçamentos do layout
		local direction = vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
		if layout.FillDirection ~= direction then
			layout.FillDirection = direction
			layout.HorizontalAlignment = vertical and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left
		end
		local centerX = (leftLimit + rightLimit) / 2 / unit
		local nav = gui:FindFirstChild("BottomNav")
		if vertical and nav and nav:IsA("GuiObject") and nav.Visible then
			root.AnchorPoint = Vector2.new(0.5, 1)
			root.Position = UDim2.new(0, centerX, 0, math.max(0, (nav.AbsolutePosition.Y - 8) / unit))
		else
			-- Em linha: começa abaixo dos cartões do topo que ocupam a mesma faixa horizontal (objetivo compacto,
			-- resumo, barra superior), nunca acima de fitTop.
			local half = math.max(root.AbsoluteSize.X, rowWidth) / 2
			local x0, x1 = centerX * unit - half, centerX * unit + half
			local top = fitTop * unit
			for _, name in ipairs({ "TopBar", "CompactSummary", "QuickObjective" }) do
				local card = gui:FindFirstChild(name)
				if card and card:IsA("GuiObject") and card.Visible and card.AbsoluteSize.Y > 0
					and card.AbsolutePosition.X < x1 and x0 < card.AbsolutePosition.X + card.AbsoluteSize.X then
					top = math.max(top, card.AbsolutePosition.Y + card.AbsoluteSize.Y + 8)
				end
			end
			root.AnchorPoint = Vector2.new(0.5, 0)
			root.Position = UDim2.new(0, centerX, 0, top / unit)
		end
	end
	for _, item in ipairs({ stepLabel, objective, skip }) do
		item:GetPropertyChangedSignal("AbsoluteSize"):Connect(reflow)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(reflow)

	return {
		Fit = function(logicalWidth: number)
			fitTop = logicalWidth < 900 and 200 or 150
			-- cartões vizinhos podem nascer depois do guia: acompanha mudanças deles uma única vez
			for _, name in ipairs({ "TopBar", "CompactSummary", "QuickObjective", "RightColumn", "BottomNav" }) do
				local card = gui:FindFirstChild(name)
				if card and card:IsA("GuiObject") and not watched[card] then
					watched[card] = true
					card:GetPropertyChangedSignal("Visible"):Connect(reflow)
					card:GetPropertyChangedSignal("AbsoluteSize"):Connect(reflow)
				end
			end
			task.defer(reflow)
		end,
	}
end

return Onboarding
