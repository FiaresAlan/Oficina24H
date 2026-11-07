--!strict
-- Tela "Metas": recompensa diária (sequência de 7 dias), 3 missões do dia, código promocional e próxima conquista.
-- Abre pelo botão 🎯 (com bolinha vermelha quando há algo para resgatar) e sozinha ao entrar se a diária estiver
-- disponível. Também mostra a faixa da HORA DO RUSH no topo enquanto o evento está ativo.
-- O servidor decide tudo (ProgressService); aqui só se exibe o snapshot e se pedem as ações.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Store = require(script.Parent:WaitForChild("UI"):WaitForChild("Store"))

local player = Players.LocalPlayer
local NAVY = Color3.fromRGB(16, 24, 44)
local CARD = Color3.fromRGB(26, 38, 66)
local GOLD = Color3.fromRGB(255, 196, 40)
local GREEN = Color3.fromRGB(70, 200, 110)
local MUTED = Color3.fromRGB(160, 175, 205)

local gui = Instance.new("ScreenGui")
gui.Name = "Metas"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 15
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(inst: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function text(parent: Instance, value: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, size + 4)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.Font = font or Enum.Font.GothamBold
	t.TextSize = size
	t.TextColor3 = color
	t.TextWrapped = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = value
	t.Parent = parent
	return t
end

local function button(parent: Instance, label: string, color: Color3, size: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 16
	b.Text = label
	b.Parent = parent
	corner(b, 10)
	return b
end

-- Botão 🎯 ao lado do ♪
local open = button(gui, "🎯", NAVY, UDim2.fromOffset(44, 44))
open.AnchorPoint = Vector2.new(1, 0)
open.Position = UDim2.new(1, -220, 0, 70)
open.TextSize = 22
local openStroke = Instance.new("UIStroke")
openStroke.Color = GOLD
openStroke.Thickness = 1.5
openStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
openStroke.Parent = open
local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(14, 14)
dot.Position = UDim2.new(1, -8, 0, -6)
dot.BackgroundColor3 = Color3.fromRGB(235, 60, 60)
dot.Visible = false
dot.Parent = open
corner(dot, 7)

-- Painel
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(520, 560)
frame.BackgroundColor3 = NAVY
frame.Visible = false
frame.Parent = gui
corner(frame, 16)
local stroke = Instance.new("UIStroke")
stroke.Color = GOLD
stroke.Thickness = 2
stroke.Parent = frame
local scale = Instance.new("UIScale")
scale.Parent = frame
local close = button(frame, "X", CARD, UDim2.fromOffset(36, 36))
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -10, 0, 10)
local scroll = Instance.new("ScrollingFrame")
scroll.BackgroundTransparency = 1
scroll.Position = UDim2.fromOffset(18, 14)
scroll.Size = UDim2.new(1, -36, 1, -28)
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 5
scroll.BorderSizePixel = 0
scroll.Parent = frame
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 10)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroll

-- Faixas de evento empilhadas logo acima da barra de baixo (não cobrem as telas): contrato de frota e Hora do Rush.
local banners = Instance.new("Frame")
banners.AnchorPoint = Vector2.new(0.5, 1)
banners.Position = UDim2.new(0.5, 0, 1, -112)
banners.Size = UDim2.fromOffset(520, 120)
banners.BackgroundTransparency = 1
banners.Parent = gui
local bannerList = Instance.new("UIListLayout")
bannerList.VerticalAlignment = Enum.VerticalAlignment.Bottom
bannerList.HorizontalAlignment = Enum.HorizontalAlignment.Center
bannerList.Padding = UDim.new(0, 6)
bannerList.SortOrder = Enum.SortOrder.LayoutOrder
bannerList.Parent = banners

-- Faixa da Hora do Rush
local rush = Instance.new("TextLabel")
rush.LayoutOrder = 2
rush.Size = UDim2.fromOffset(460, 40)
rush.BackgroundColor3 = Color3.fromRGB(220, 70, 30)
rush.TextColor3 = Color3.new(1, 1, 1)
rush.Font = Enum.Font.GothamBlack
rush.TextSize = 20
rush.Visible = false
rush.Parent = banners
corner(rush, 12)

-- Cartão do contrato de frota: empresa, progresso (barra) e tempo restante
local contract = Instance.new("Frame")
contract.LayoutOrder = 1
contract.Size = UDim2.fromOffset(400, 52)
contract.BackgroundColor3 = Color3.fromRGB(20, 70, 120)
contract.Visible = false
contract.Parent = banners
corner(contract, 12)
local contractStroke = Instance.new("UIStroke")
contractStroke.Color = Color3.fromRGB(120, 200, 255)
contractStroke.Thickness = 1.5
contractStroke.Parent = contract
local contractText = Instance.new("TextLabel")
contractText.BackgroundTransparency = 1
contractText.Position = UDim2.fromOffset(12, 4)
contractText.Size = UDim2.new(1, -24, 0, 26)
contractText.Font = Enum.Font.GothamBlack
contractText.TextSize = 16
contractText.TextColor3 = Color3.new(1, 1, 1)
contractText.TextXAlignment = Enum.TextXAlignment.Left
contractText.TextTruncate = Enum.TextTruncate.AtEnd
contractText.Parent = contract
local contractBar = Instance.new("Frame")
contractBar.Position = UDim2.new(0, 12, 1, -16)
contractBar.Size = UDim2.new(1, -24, 0, 8)
contractBar.BackgroundColor3 = Color3.fromRGB(10, 30, 60)
contractBar.Parent = contract
corner(contractBar, 4)
local contractFill = Instance.new("Frame")
contractFill.Size = UDim2.fromScale(0, 1)
contractFill.BackgroundColor3 = GREEN
contractFill.Parent = contractBar
corner(contractFill, 4)
local contractEnds = 0
local contractInfo: any = nil

local codeBox: TextBox? = nil

local function render()
	local snap = Store.Snapshot
	local progress = snap and snap.Progress
	for _, c in ipairs(scroll:GetChildren()) do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	if not progress then
		text(scroll, "Carregando...", 18, MUTED)
		return
	end
	local function section(title: string, order: number): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = CARD
		f.Size = UDim2.new(1, -6, 0, 0)
		f.AutomaticSize = Enum.AutomaticSize.Y
		f.LayoutOrder = order
		f.Parent = scroll
		corner(f, 12)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 10), UDim.new(0, 12)
		pad.Parent = f
		local l = Instance.new("UIListLayout")
		l.Padding = UDim.new(0, 6)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = f
		text(f, title, 20, GOLD, Enum.Font.GothamBlack).LayoutOrder = 0
		return f
	end
	text(scroll, "METAS", 26, GOLD, Enum.Font.GothamBlack).LayoutOrder = 0
	-- Diária
	local daily = progress.Daily
	local d = section(string.format("Recompensa diária · sequência: %d dia(s)", daily.Streak), 1)
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(1, 0, 0, 56)
	strip.LayoutOrder = 1
	strip.Parent = d
	local sl = Instance.new("UIListLayout")
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.Padding = UDim.new(0, 5)
	sl.Parent = strip
	for i, reward in ipairs(daily.Rewards) do
		local cell = Instance.new("TextLabel")
		cell.Size = UDim2.new(1 / 7, -5, 1, 0)
		local done = (daily.CanClaim and i < daily.Day) or (not daily.CanClaim and i <= daily.Day)
		local current = daily.CanClaim and i == daily.Day
		cell.BackgroundColor3 = current and GOLD or (done and Color3.fromRGB(50, 110, 70) or Color3.fromRGB(40, 54, 86))
		cell.TextColor3 = current and NAVY or Color3.new(1, 1, 1)
		cell.Font = Enum.Font.GothamBlack
		cell.TextSize = 13
		cell.TextWrapped = true
		cell.Text = string.format("Dia %d\n%d%s", i, reward.Coins, reward.Big and "★" or "")
		cell.Parent = strip
		corner(cell, 8)
	end
	local claim = button(d, daily.CanClaim and string.format("Pegar recompensa do dia %d", daily.Day) or "Volte amanhã para o próximo dia",
		daily.CanClaim and GREEN or Color3.fromRGB(70, 76, 90), UDim2.new(1, 0, 0, 40))
	claim.LayoutOrder = 2
	claim.Activated:Connect(function()
		if daily.CanClaim then
			Store.Act("ClaimDaily", {})
		end
	end)
	-- Missões
	local m = section("Missões de hoje", 2)
	for i, mission in ipairs(progress.Missions) do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.LayoutOrder = i
		row.Parent = m
		-- coluna da esquerda em lista: texto (pode quebrar linha), barra e contagem nunca se sobrepõem
		local left = Instance.new("Frame")
		left.BackgroundTransparency = 1
		left.Size = UDim2.new(1, -120, 0, 0)
		left.AutomaticSize = Enum.AutomaticSize.Y
		left.Parent = row
		local ll = Instance.new("UIListLayout")
		ll.Padding = UDim.new(0, 4)
		ll.SortOrder = Enum.SortOrder.LayoutOrder
		ll.Parent = left
		local t = text(left, string.format("%s  ·  +%d moedas", mission.Text, mission.Coins), 16, Color3.new(1, 1, 1))
		t.LayoutOrder = 1
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, 0, 0, 12)
		bar.BackgroundColor3 = Color3.fromRGB(40, 54, 86)
		bar.LayoutOrder = 2
		bar.Parent = left
		corner(bar, 6)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(math.clamp(mission.Progress / mission.Target, 0, 1), 1)
		fill.BackgroundColor3 = mission.Claimed and Color3.fromRGB(90, 100, 120) or GREEN
		fill.Parent = bar
		corner(fill, 6)
		local count = text(left, string.format("%d/%d", math.min(mission.Progress, mission.Target), mission.Target), 13, MUTED)
		count.LayoutOrder = 3
		local ready = mission.Progress >= mission.Target and not mission.Claimed
		local b = button(row, mission.Claimed and "Feito ✔" or (ready and "Resgatar" or "..."), ready and GOLD or Color3.fromRGB(70, 76, 90), UDim2.fromOffset(110, 40))
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, 0, 0, 6)
		b.TextColor3 = ready and NAVY or Color3.new(1, 1, 1)
		b.Activated:Connect(function()
			if ready then
				Store.Act("ClaimMission", { Id = mission.Id })
			end
		end)
	end
	-- Liga semanal
	local league = progress.League
	if league then
		local ends = tonumber(league.EndsIn) or 0
		local lg = section(string.format("Liga semanal · termina em %dd %dh", math.floor(ends / 86400), math.floor(ends % 86400 / 3600)), 3)
		text(lg, league.Tier and string.format("%s Liga %s · %d pontos", league.TierIcon, league.Tier, league.Points)
			or string.format("Sem faixa ainda · %d pontos", league.Points), 18, Color3.new(1, 1, 1), Enum.Font.GothamBlack).LayoutOrder = 1
		local nextTier = league.Next
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, 0, 0, 12)
		bar.BackgroundColor3 = Color3.fromRGB(40, 54, 86)
		bar.LayoutOrder = 2
		bar.Parent = lg
		corner(bar, 6)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(nextTier and math.clamp(league.Points / nextTier.Points, 0, 1) or 1, 1)
		fill.BackgroundColor3 = GOLD
		fill.Parent = bar
		corner(fill, 6)
		text(lg, nextTier and string.format("Faltam %d pontos para %s %s (+%d moedas na segunda-feira)", nextTier.Points - league.Points, nextTier.Icon, nextTier.Id, nextTier.Coins)
			or "Você está no topo: Liga Ouro!", 15, MUTED).LayoutOrder = 3
		local tiers = {}
		for _, tier in ipairs(league.Tiers or {}) do
			table.insert(tiers, string.format("%s %d pts = %d", tier.Icon, tier.Points, tier.Coins))
		end
		text(lg, table.concat(tiers, "   ·   "), 14, Color3.new(1, 1, 1)).LayoutOrder = 4
		text(lg, "Pontos: 1 por estrela do cliente, +2 reparo 90%+, +2 VIP, +15 contrato de frota.", 13, MUTED).LayoutOrder = 5
		if league.Top and #league.Top > 0 then
			local rows = {}
			for i, entry in ipairs(league.Top) do
				if i > 5 then
					break
				end
				table.insert(rows, string.format("%d. %s — %d", i, entry.Name, entry.Points))
			end
			text(lg, "Melhores de todos os servidores esta semana:\n" .. table.concat(rows, "\n"), 14, Color3.new(1, 1, 1)).LayoutOrder = 6
		end
	end
	-- Conquistas
	local a = section(string.format("Conquistas: %d de %d", progress.Achievements.Owned, progress.Achievements.Total), 4)
	local nextAch = progress.Achievements.Next
	text(a, nextAch and string.format("Próxima: %s (%d/%d) · +%d moedas", nextAch.Title, nextAch.Have, nextAch.Need, nextAch.Coins) or "Você conquistou tudo!", 16, Color3.new(1, 1, 1)).LayoutOrder = 1
	-- Código
	local c = section("Código promocional", 5)
	local rowCode = Instance.new("Frame")
	rowCode.BackgroundTransparency = 1
	rowCode.Size = UDim2.new(1, 0, 0, 40)
	rowCode.LayoutOrder = 1
	rowCode.Parent = c
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -130, 1, 0)
	box.BackgroundColor3 = Color3.fromRGB(12, 18, 34)
	box.TextColor3 = Color3.new(1, 1, 1)
	box.PlaceholderText = "Digite o código"
	box.PlaceholderColor3 = MUTED
	box.Font = Enum.Font.GothamBold
	box.TextSize = 16
	box.Text = codeBox and codeBox.Text or ""
	box.ClearTextOnFocus = false
	box.Parent = rowCode
	corner(box, 8)
	codeBox = box
	local redeem = button(rowCode, "Resgatar", GREEN, UDim2.new(0, 120, 1, 0))
	redeem.AnchorPoint = Vector2.new(1, 0)
	redeem.Position = UDim2.fromScale(1, 0)
	redeem.Activated:Connect(function()
		if box.Text ~= "" then
			Store.Act("RedeemCode", { Code = box.Text })
			box.Text = ""
		end
	end)
end

local function claimable(progress: any): boolean
	if not progress then
		return false
	end
	if progress.Daily.CanClaim then
		return true
	end
	for _, mission in ipairs(progress.Missions) do
		if mission.Progress >= mission.Target and not mission.Claimed then
			return true
		end
	end
	return false
end

local function fit()
	local camera = workspace.CurrentCamera
	local v = camera and camera.ViewportSize or Vector2.new(1280, 720)
	scale.Scale = math.clamp(math.min(v.X / 620, v.Y / 640), 0.55, 1.15)
end

local function show(visible: boolean)
	frame.Visible = visible
	if visible then
		fit()
		render()
	end
end

open.Activated:Connect(function()
	show(not frame.Visible)
end)
close.Activated:Connect(function()
	show(false)
end)

local autoOpened = false
local rushEnds = 0
Store.Changed.Event:Connect(function(snap: any)
	local progress = snap and snap.Progress
	dot.Visible = claimable(progress)
	if progress and progress.Rush then
		rushEnds = progress.Rush.Active and (os.clock() + progress.Rush.EndsIn) or 0
	end
	local c = snap and snap.Contract
	if c and c.Active then
		local changed = not contractInfo or contractInfo.Done ~= c.Done
		contractInfo = c
		contractEnds = os.clock() + (tonumber(c.EndsIn) or 0)
		TweenService:Create(contractFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(c.Done / math.max(c.Target, 1), 0, 1), 1) }):Play()
		if changed then
			contract.Size = UDim2.fromOffset(440, 58)
			TweenService:Create(contract, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(400, 52) }):Play()
		end
	else
		contractInfo = nil
		contractEnds = 0
	end
	if frame.Visible and not (codeBox and codeBox:IsFocused()) then
		render()
	end
	-- ao entrar, com a diária disponível, a tela abre sozinha uma vez (lembrete de voltar todo dia)
	if not autoOpened and progress and progress.Daily.CanClaim and snap.HasWorkshop then
		autoOpened = true
		task.delay(4, function()
			show(true)
		end)
	end
end)

-- faixa do Rush com contagem regressiva
task.spawn(function()
	while true do
		local left = rushEnds - os.clock()
		if left > 0 then
			rush.Visible = true
			rush.Text = string.format("🔥 HORA DO RUSH · clientes em dobro · +50%% · %d:%02d", math.floor(left / 60), math.floor(left % 60))
		else
			rush.Visible = false
		end
		local cleft = contractEnds - os.clock()
		if contractInfo and cleft > 0 then
			contract.Visible = true
			-- curto para caber no celular: empresa, progresso e tempo (o detalhe do pedido veio no aviso)
			contractText.Text = string.format("📋 %s  %d/%d  ⏱ %d:%02d", contractInfo.Name, contractInfo.Done, contractInfo.Target,
				math.floor(cleft / 60), math.floor(cleft % 60))
		else
			contract.Visible = false
		end
		task.wait(0.5)
	end
end)
local actionEvent = game:GetService("ReplicatedStorage"):WaitForChild("OficinaRemotes"):WaitForChild("Action") :: RemoteEvent
actionEvent.OnClientEvent:Connect(function(kind: string, payload: any)
	if kind == "Rush" and type(payload) == "table" and payload.Active then
		rushEnds = os.clock() + (tonumber(payload.EndsIn) or 0)
		rush.Size = UDim2.fromOffset(520, 46)
		TweenService:Create(rush, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(460, 40) }):Play()
	end
end)
