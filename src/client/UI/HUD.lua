--!strict
-- HUD: monta o layout fiel à imagem de referência (HudParts) e liga aos dados reais do servidor (Store).
-- A interface só EXIBE e SOLICITA ações; dinheiro, ordens, reputação e XP são decididos no servidor.
-- Unidades = pixels da imagem de referência (1672x941); um UIScale ajusta à tela.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local CustomerRules = require(ReplicatedStorage.Shared.CustomerRules)
local Theme = require(script.Parent.Theme)
local HudLayoutRules = require(ReplicatedStorage.Shared.HudLayoutRules)
local CompactHUD = require(script.Parent.CompactHUD)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Motion)
local Store = require(script.Parent.Store)
local HudParts = require(script.Parent.HudParts)
local Orders = require(script.Parent.Panels.Orders)
local Skills = require(script.Parent.Panels.Skills)
local Shop = require(script.Parent.Panels.Shop)
local Profile = require(script.Parent.Panels.Profile)
local Stock = require(script.Parent.Panels.Stock)
local Ranking = require(script.Parent.Panels.Ranking)
local Notifications = require(script.Parent.Panels.Notifications)
local RepairGame = require(script.Parent.RepairGame)
local OperationRepairGame = require(script.Parent.OperationRepairGame)
local DiagnosisGame = require(script.Parent.DiagnosisGame)
local Onboarding = require(script.Parent.Onboarding)
local Stations = require(script.Parent.Stations)

local t = Kit.t
local HUD = {}

local WARNING_FRACTION = 0.25 -- paciência restante abaixo disso mostra o aviso de desistência
local MAX_NOTIFICATIONS = 40

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function thousands(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if formatted:sub(1, 1) == "." then
		formatted = formatted:sub(2)
	end
	return formatted
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
end

local function list(parent: Instance, gap: number, horizontal: boolean): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if horizontal then
		l.FillDirection = Enum.FillDirection.Horizontal
	end
	l.Parent = parent
	return l
end

local function frame(parent: Instance, name: string, order: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.Size = UDim2.new()
	f.LayoutOrder = order or 0
	f.Parent = parent
	return f
end

local function row(parent: Instance, gap: number, order: number?, name: string?): Frame
	local f = frame(parent, name or "Row", order)
	list(f, gap, true).VerticalAlignment = Enum.VerticalAlignment.Center
	return f
end

local function column(parent: Instance, gap: number, order: number?, name: string?): Frame
	local f = frame(parent, name or "Column", order)
	list(f, gap, false)
	return f
end

local function pad(parent: Instance, top: number, right: number, bottom: number, left: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop, p.PaddingRight, p.PaddingBottom, p.PaddingLeft = UDim.new(0, top), UDim.new(0, right), UDim.new(0, bottom), UDim.new(0, left)
	p.Parent = parent
end

local function divider(parent: Instance, order: number): Frame
	local d = Instance.new("Frame")
	d.Name = "Divider"
	d.BackgroundColor3 = Color3.new(1, 1, 1)
	d.BackgroundTransparency = 0.35
	d.BorderSizePixel = 0
	d.Size = UDim2.fromOffset(2, 62)
	d.LayoutOrder = order
	d.Parent = parent
	return d
end

local function clearChildren(f: Instance)
	for _, c in ipairs(f:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

function HUD.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "OficinaUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- tudo que se toca fica na área segura (abaixo da barra do Roblox)
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local scale = Instance.new("UIScale")
	scale.Name = "Fit"
	scale.Parent = gui

	----------------------------------------------------------------------------------------------------------------
	-- Barra superior: logo, nível e XP, saldo, reputação
	----------------------------------------------------------------------------------------------------------------
	local topBar = HudParts.panel(gui, "TopBar")
	topBar.AutomaticSize = Enum.AutomaticSize.XY
	topBar.Position = UDim2.fromOffset(22, 14)
	pad(topBar, 9, 20, 9, 18)
	local topLayout = list(topBar, 14, true)
	topLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local logo = row(topBar, 10, 1, "Logo")
	HudParts.sprite(logo, "logo", Vector2.new(52, 52))
	local logoText = column(logo, -6)
	HudParts.text(logoText, "OFICINA", 24, { Font = Theme.FontTitle })
	HudParts.text(logoText, "24H", 37, { Font = Theme.FontTitle, TextColor3 = rgb(255, 176, 32) })
	local logoDivider = divider(topBar, 2)

	local levelBlock = row(topBar, 12, 3, "Level")
	HudParts.sprite(levelBlock, "star_level", Vector2.new(42, 42))
	local levelColumn = column(levelBlock, 0)
	local levelCaption = HudParts.text(levelColumn, t("hud_level_pro"), 18, { Font = Theme.FontTitle })
	local levelRow = row(levelColumn, 10)
	local levelValue = HudParts.text(levelRow, "01", 36, { Font = Theme.FontTitle })
	local xpColumn = column(levelRow, 4)
	local xpValue = HudParts.text(xpColumn, "0 / 0 XP", 16, { Font = Theme.FontTitle })
	local xpTrack, setXp = HudParts.progress(xpColumn, 9, { { 0, rgb(120, 220, 255) }, { 0.5, rgb(0, 170, 245) }, { 1, rgb(0, 120, 215) } })
	xpTrack.Size = UDim2.fromOffset(125, 9)
	divider(topBar, 4)

	local balanceBlock = row(topBar, 12, 5, "Balance")
	HudParts.sprite(balanceBlock, "dollar", Vector2.new(42, 44))
	local balanceColumn = column(balanceBlock, 0)
	local balanceCaption = HudParts.text(balanceColumn, t("hud_balance"), 18, { Font = Theme.FontTitle })
	local coinsValue = HudParts.text(balanceColumn, "0", 36, { Font = Theme.FontTitle })
	divider(topBar, 6)

	local repBlock = row(topBar, 12, 7, "Reputation")
	HudParts.sprite(repBlock, "trophy_top", Vector2.new(42, 42))
	local repColumn = column(repBlock, 0)
	local repCaption = HudParts.text(repColumn, t("hud_rep_title"), 18, { Font = Theme.FontTitle })
	local repRow = row(repColumn, 8)
	local repValue = HudParts.text(repRow, "0", 36, { Font = Theme.FontTitle })
	local repStar = HudParts.sprite(repRow, "star_gold", Vector2.new(24, 24))
	local ratingValue = HudParts.text(repRow, "", 20, { Font = Theme.FontTitle, TextColor3 = rgb(255, 200, 40) })

	----------------------------------------------------------------------------------------------------------------
	-- Controles superiores
	----------------------------------------------------------------------------------------------------------------
	local controls = frame(gui, "Controls")
	controls.AnchorPoint = Vector2.new(1, 0)
	controls.Position = UDim2.new(1, -19, 0, 14)
	list(controls, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Right
	local infoToggle = HudParts.iconButton(controls, "InfoToggle", "chart", 56, nil)
	infoToggle.LayoutOrder = 1
	local bell, _, setBellBadge = HudParts.iconButton(controls, "BellButton", "bell", 56, nil)
	bell.LayoutOrder = 2
	-- Configurações e Sair não existem no jogo: sem botões decorativos.
	local compactHUD = CompactHUD.new(gui, function()
		HUD.openPanel("orders")
	end)

	----------------------------------------------------------------------------------------------------------------
	-- Menu lateral
	----------------------------------------------------------------------------------------------------------------
	local sideMenu = Instance.new("Frame")
	sideMenu.Name = "SideMenu"
	sideMenu.BackgroundTransparency = 1
	sideMenu.AutomaticSize = Enum.AutomaticSize.XY
	sideMenu.Size = UDim2.new()
	sideMenu.Position = UDim2.fromOffset(22, 135)
	list(sideMenu, 10, false)
	sideMenu.Parent = gui

	local menuToggle = Instance.new("TextButton")
	menuToggle.Name = "MenuToggle"
	menuToggle.AutoButtonColor = false
	menuToggle.Text = ""
	menuToggle.BackgroundTransparency = 1
	menuToggle.Size = UDim2.fromOffset(224, 44)
	menuToggle.LayoutOrder = 0
	local menuToggleBg = Instance.new("Frame") -- o degradê fica num quadro filho: num TextButton ele tingiria o texto
	menuToggleBg.Name = "Bg"
	menuToggleBg.Size = UDim2.fromScale(1, 1)
	menuToggleBg.BackgroundColor3 = Color3.new(1, 1, 1)
	menuToggleBg.BorderSizePixel = 0
	Kit.corner(menuToggleBg, 14)
	HudParts.gradient(menuToggleBg, { { 0, rgb(24, 38, 60) }, { 1, rgb(8, 15, 28) } })
	HudParts.stroke(menuToggleBg, rgb(58, 88, 130), 0, 2)
	menuToggleBg.Parent = menuToggle
	local menuToggleLabel = HudParts.text(menuToggle, "<  " .. string.upper(t("hud_menu_toggle")), 26, {
		Font = Theme.FontTitle, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 2,
	})
	menuToggle.Parent = sideMenu

	----------------------------------------------------------------------------------------------------------------
	-- Coluna direita: clientes aguardando, painel de ordem, perfil da oficina
	----------------------------------------------------------------------------------------------------------------
	local rightColumn = Instance.new("ScrollingFrame") -- contextual; recolhido em telas compactas
	rightColumn.Name = "RightColumn"
	rightColumn.BackgroundTransparency = 1
	rightColumn.BorderSizePixel = 0
	rightColumn.ScrollBarThickness = 0
	rightColumn.ScrollingDirection = Enum.ScrollingDirection.Y
	rightColumn.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rightColumn.CanvasSize = UDim2.new()
	rightColumn.Size = UDim2.fromOffset(454, 600)
	rightColumn.AnchorPoint = Vector2.new(1, 0)
	rightColumn.Position = UDim2.new(1, -19, 0, 112)
	local rightLayout = list(rightColumn, 20, false)
	rightColumn.Parent = gui

	local function card(order: number, name: string): Frame
		local f = HudParts.panel(rightColumn, name)
		f.AutomaticSize = Enum.AutomaticSize.Y
		f.Size = UDim2.new(1, 0, 0, 0)
		f.LayoutOrder = order
		return f
	end

	-- Clientes aguardando
	local customersCard = card(1, "Customers")
	pad(customersCard, 14, 14, 14, 14)
	list(customersCard, 8, false)
	local customersHeader = Instance.new("Frame")
	customersHeader.Name = "Header"
	customersHeader.BackgroundTransparency = 1
	customersHeader.Size = UDim2.new(1, 0, 0, 42)
	customersHeader.LayoutOrder = 1
	customersHeader.Parent = customersCard
	HudParts.text(customersHeader, t("customers_title"), 32, {
		Font = Theme.FontTitle, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.62, 0, 1, 0), TextYAlignment = Enum.TextYAlignment.Center,
	})
	local customersCount = HudParts.pill(customersHeader, "", 24)
	customersCount.AnchorPoint = Vector2.new(1, 0.5)
	customersCount.Position = UDim2.new(1, 0, 0.5, 0)
	local customersList = Instance.new("Frame")
	customersList.Name = "List"
	customersList.BackgroundTransparency = 1
	customersList.Size = UDim2.new(1, 0, 0, 0)
	customersList.AutomaticSize = Enum.AutomaticSize.Y
	customersList.LayoutOrder = 2
	list(customersList, 10, false)
	customersList.Parent = customersCard

	-- Painel de ordem
	local orderCard = card(2, "OrderPanel")
	list(orderCard, 0, false)
	local orderHeader = HudParts.header(orderCard, 56)
	orderHeader.LayoutOrder = 1
	do
		local h = row(orderHeader, 12, 1)
		h.AnchorPoint = Vector2.new(0, 0.5)
		h.Position = UDim2.new(0, 16, 0.5, 0)
		HudParts.sprite(h, "car_icon", Vector2.new(46, 34))
		HudParts.text(h, t("order_title"), 32, { Font = Theme.FontTitle })
	end
	local orderBody = Instance.new("Frame")
	orderBody.Name = "Body"
	orderBody.BackgroundTransparency = 1
	orderBody.Size = UDim2.new(1, 0, 0, 0)
	orderBody.AutomaticSize = Enum.AutomaticSize.Y
	orderBody.LayoutOrder = 2
	pad(orderBody, 12, 8, 12, 16)
	orderBody.Parent = orderCard
	local orderPhoto = HudParts.sprite(orderBody, "photo_hood", Vector2.new(168, 168))
	orderPhoto.AnchorPoint = Vector2.new(1, 0)
	orderPhoto.Position = UDim2.new(1, 0, 0, 0)
	orderPhoto.ScaleType = Enum.ScaleType.Crop
	Kit.corner(orderPhoto, 10)
	local orderText = Instance.new("Frame")
	orderText.Name = "Text"
	orderText.BackgroundTransparency = 1
	orderText.Size = UDim2.new(1, -182, 0, 0)
	orderText.AutomaticSize = Enum.AutomaticSize.Y
	list(orderText, 8, false)
	orderText.Parent = orderBody
	local orderMin = Instance.new("Frame") -- garante a altura da foto
	orderMin.BackgroundTransparency = 1
	orderMin.Size = UDim2.fromOffset(1, 168)
	orderMin.Parent = orderBody

	-- Perfil da oficina
	local shopCard = card(3, "ShopCard")
	shopCard.Visible = false -- perfil e gestão vivem no painel próprio, não ocupam o gameplay
	list(shopCard, 0, false)
	local shopHeader = HudParts.header(shopCard, 56)
	shopHeader.LayoutOrder = 1
	do
		local h = row(shopHeader, 12, 1)
		h.AnchorPoint = Vector2.new(0, 0.5)
		h.Position = UDim2.new(0, 16, 0.5, 0)
		HudParts.sprite(h, "people", Vector2.new(46, 40))
		HudParts.text(h, t("shopcard_title"), 32, { Font = Theme.FontTitle })
	end
	local detailsButton = HudParts.text(shopHeader, t("shopcard_details") .. " ›", 24, {
		Font = Theme.FontTitle, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
	})
	local detailsHit = Instance.new("TextButton")
	detailsHit.Name = "DetailsHit"
	detailsHit.BackgroundTransparency = 1
	detailsHit.Text = ""
	detailsHit.Size = UDim2.new(1, 24, 1, 16)
	detailsHit.Position = UDim2.fromOffset(-12, -8)
	detailsHit.Parent = detailsButton
	local shopBody = Instance.new("Frame")
	shopBody.Name = "Body"
	shopBody.BackgroundTransparency = 1
	shopBody.Size = UDim2.new(1, 0, 0, 0)
	shopBody.AutomaticSize = Enum.AutomaticSize.Y
	shopBody.LayoutOrder = 2
	pad(shopBody, 12, 14, 12, 14)
	shopBody.Parent = shopCard
	local shopPhoto = HudParts.sprite(shopBody, "photo_shop", Vector2.new(160, 112))
	shopPhoto.ScaleType = Enum.ScaleType.Crop
	Kit.corner(shopPhoto, 10)
	local shopTexts = Instance.new("Frame")
	shopTexts.Name = "Texts"
	shopTexts.BackgroundTransparency = 1
	shopTexts.Position = UDim2.fromOffset(176, 0)
	shopTexts.Size = UDim2.new(1, -250, 0, 0)
	shopTexts.AutomaticSize = Enum.AutomaticSize.Y
	list(shopTexts, 2, false)
	shopTexts.Parent = shopBody
	local shopMin = Instance.new("Frame")
	shopMin.BackgroundTransparency = 1
	shopMin.Size = UDim2.fromOffset(1, 112)
	shopMin.Parent = shopBody
	local shopChart = HudParts.sprite(shopBody, "chart", Vector2.new(64, 100))
	shopChart.AnchorPoint = Vector2.new(1, 0)
	shopChart.Position = UDim2.new(1, 0, 0, 6)
	local shopName = HudParts.text(shopTexts, "", 24, { Font = Theme.FontTitle, LayoutOrder = 1, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	local shopLevelRow = row(shopTexts, 8, 2)
	HudParts.sprite(shopLevelRow, "star_level", Vector2.new(34, 34))
	local shopLevel = HudParts.text(shopLevelRow, "", 34, { Font = Theme.FontTitle })
	local shopRating = HudParts.text(shopTexts, "", 24, { Font = Theme.FontTitle, LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextWrapped = true })
	local shopServed = HudParts.text(shopTexts, "", 24, { Font = Theme.FontTitle, LayoutOrder = 4, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextWrapped = true })

	----------------------------------------------------------------------------------------------------------------
	-- Avisos (toasts) e notificação de avaliação
	----------------------------------------------------------------------------------------------------------------
	local toasts = frame(gui, "Toasts")
	toasts.AutomaticSize = Enum.AutomaticSize.Y
	toasts.AnchorPoint = Vector2.new(0.5, 0)
	toasts.Position = UDim2.new(0.5, 0, 0, 130)
	toasts.Size = UDim2.fromOffset(620, 0)
	list(toasts, 8, false).HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function toast(text: string, success: boolean)
		if text == "" then
			return
		end
		local box = HudParts.panel(toasts, "Toast")
		box.AutomaticSize = Enum.AutomaticSize.XY
		box.Size = UDim2.new()
		pad(box, 12, 22, 12, 22)
		local stroke = box:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = success and Theme.Green or Theme.Red
			stroke.Thickness = 2.5
		end
		local narrow = gui:GetAttribute("CompactLayout") == true
		local label = HudParts.text(box, text, narrow and 20 or 24, {
			Font = Theme.FontSemi, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.XY,
		})
		local limit = Instance.new("UISizeConstraint")
		local width = tonumber(gui:GetAttribute("HudLogicalWidth")) or 1672
		limit.MaxSize = Vector2.new(math.max(180, math.min(510, width - 72)), math.huge)
		limit.Parent = label
		box.BackgroundTransparency = 1
		Motion.play(box, Motion.Slide, { BackgroundTransparency = Theme.PanelTransparency })
		task.delay(3.4, function()
			if box.Parent then
				Motion.play(box, Motion.Fade, { BackgroundTransparency = 1 })
				Motion.play(label, Motion.Fade, { TextTransparency = 1 })
				if stroke then
					Motion.play(stroke, Motion.Fade, { Transparency = 1 })
				end
				task.delay(0.25, function()
					box:Destroy()
				end)
			end
		end)
		local boxes = {}
		for _, c in ipairs(toasts:GetChildren()) do
			if c:IsA("Frame") then
				table.insert(boxes, c)
			end
		end
		while #boxes > 4 do
			table.remove(boxes, 1):Destroy()
		end
	end

	local ratedToast: Frame? = nil
	local function showRated(info: any)
		if ratedToast then
			ratedToast:Destroy()
			ratedToast = nil
		end
		local box = HudParts.panel(gui, "RatedToast")
		box.AutomaticSize = Enum.AutomaticSize.XY
		box.AnchorPoint = Vector2.new(0, 1)
		pad(box, 14, 22, 14, 18)
		list(box, 16, true).VerticalAlignment = Enum.VerticalAlignment.Center
		local narrow = gui:GetAttribute("CompactLayout") == true
		local stars = tonumber(info.Stars) or 0
		local check = HudParts.sprite(box, "check_ok", narrow and Vector2.new(42, 42) or Vector2.new(64, 64))
		check.LayoutOrder = 1
		if stars < 3 then
			check.ImageColor3 = rgb(255, 120, 90)
		end
		local texts = column(box, 2, 2)
		HudParts.text(texts, t("rated_title"), narrow and 21 or 30, {
			Font = Theme.FontTitle, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromOffset(narrow and 224 or 320, 0),
		})
		local starRow = row(texts, 4)
		for i = 1, 5 do
			local star = HudParts.sprite(starRow, "star_gold",
				narrow and Vector2.new(22, 22) or Vector2.new(32, 32))
			star.ImageTransparency = i <= stars and 0 or 0.75
		end
		HudParts.text(texts, "“" .. t(tostring(info.CommentKey or "rating_comment_ok")) .. "”", narrow and 17 or 24, {
			Font = Theme.FontSemi, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromOffset(narrow and 224 or 320, 0),
		})
		local delta = tonumber(info.ReputationDelta) or 0
		HudParts.text(texts, t("rated_rep", delta), narrow and 18 or 26, {
			Font = Theme.FontTitle, TextColor3 = delta >= 0 and Theme.Green or Theme.Red,
		})
		local chevron = HudParts.text(box, "›", 54, { Font = Theme.FontTitle, LayoutOrder = 3 })
		chevron.TextColor3 = Theme.Muted
		chevron.Visible = not narrow
		ratedToast = box
		-- entra deslizando da esquerda
		local targetY = narrow and -(tonumber(gui:GetAttribute("HudDockHeight")) or 70) - 34 or -40
		box.Position = UDim2.new(0, -520, 1, targetY)
		if Motion.reduced() then
			box.Position = UDim2.new(0, 22, 1, targetY)
		else
			Motion.play(box, Motion.Slide, { Position = UDim2.new(0, 22, 1, targetY) })
		end
		local function dismiss()
			if box.Parent then
				box:Destroy()
				if ratedToast == box then
					ratedToast = nil
				end
			end
		end
		box.Active = true -- clicar na notificação abre o Perfil (o próprio quadro recebe o clique)
		box.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dismiss()
				HUD.openPanel("profile")
			end
		end)
		task.delay(7, dismiss)
	end

	----------------------------------------------------------------------------------------------------------------
	-- Prompt contextual de interação (ProximityPrompt do carro, desenhado pelo HUD)
	----------------------------------------------------------------------------------------------------------------
	local prompt = HudParts.panel(gui, "InteractPrompt")
	prompt.AutomaticSize = Enum.AutomaticSize.XY
	prompt.AnchorPoint = Vector2.new(0.5, 1)
	prompt.Position = UDim2.new(0.5, 0, 1, -170)
	prompt.Visible = false
	pad(prompt, 10, 24, 10, 12)
	list(prompt, 14, true).VerticalAlignment = Enum.VerticalAlignment.Center
	local promptPop = Instance.new("UIScale")
	promptPop.Parent = prompt
	local keyButton = Instance.new("TextButton")
	keyButton.Name = "Key"
	keyButton.AutoButtonColor = false
	keyButton.Text = "E"
	keyButton.Font = Theme.FontTitle
	keyButton.TextSize = 40
	keyButton.TextColor3 = rgb(20, 32, 52)
	keyButton.BackgroundColor3 = Color3.new(1, 1, 1)
	keyButton.BorderSizePixel = 0
	keyButton.Size = UDim2.fromOffset(60, 60)
	keyButton.LayoutOrder = 1
	Kit.corner(keyButton, 12)
	HudParts.gradient(keyButton, { { 0, rgb(255, 255, 255) }, { 1, rgb(196, 214, 238) } })
	HudParts.stroke(keyButton, rgb(120, 150, 190), 0, 2)
	keyButton.Parent = prompt
	local promptTexts = column(prompt, 0, 2)
	local promptAction = HudParts.text(promptTexts, "", 30, { Font = Theme.FontTitle })
	local promptObject = HudParts.text(promptTexts, "", 22, { Font = Theme.FontTitle, TextColor3 = rgb(210, 222, 240) })
	local activePrompt: ProximityPrompt? = nil
	local diagnosisRefFit: ((number, number) -> ())? = nil
	local onboardingFit: ((number) -> ())? = nil
	local repairGameRef: { IsActive: () -> boolean, Fit: (number, number) -> () }? = nil -- minijogo legado
	local operationGameRef: { IsActive: () -> boolean, Fit: (number, number) -> () }? = nil -- reparos pilotos
	local promptHoldTween: Tween? = nil
	local promptFill = Instance.new("Frame")
	promptFill.Name = "HoldFill"
	promptFill.AnchorPoint = Vector2.new(0, 1)
	promptFill.Position = UDim2.new(0, 14, 1, -4)
	promptFill.Size = UDim2.new(0, 0, 0, 6)
	promptFill.BackgroundColor3 = rgb(255, 190, 40)
	promptFill.BorderSizePixel = 0
	promptFill.Visible = false
	Kit.corner(promptFill, 3)
	promptFill.Parent = prompt

	local function keyLabel(p: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
		if inputType == Enum.ProximityPromptInputType.Gamepad then
			return "X"
		elseif inputType == Enum.ProximityPromptInputType.Touch then
			return "●"
		end
		return p.KeyboardKeyCode.Name
	end
	ProximityPromptService.PromptShown:Connect(function(p: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
		if p.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		activePrompt = p
		if (repairGameRef and repairGameRef.IsActive()) or (operationGameRef and operationGameRef.IsActive()) then
			activePrompt = nil
			return
		end
		-- só o dono vê o prompt do próprio carro (o servidor já recusa ações de outros jogadores)
		local car = p:FindFirstAncestorOfClass("Model")
		local ownerId = p:GetAttribute("OwnerUserId") or (car and car:GetAttribute("OwnerUserId"))
		-- Uma OS delegada não deve convidar o dono a executar as etapas do contratado.
		if car and (p.Name == "Repair" or string.sub(p.Name, 1, 5) == "Prep_") then
			local assigned = car:GetAttribute("AssignedRepairUserId")
			if type(assigned) == "number" and assigned ~= player.UserId then
				activePrompt = nil
				return
			end
		end
		if type(ownerId) == "number" and ownerId ~= player.UserId then
			-- Permite apenas o carro da OS contratada ou as máquinas do dono dessa OS.
			-- O servidor valida novamente job, local, habilidade e inventário.
			local hiredJob = player:GetAttribute("CollaborationJobId")
			local hiredOwner = player:GetAttribute("CollaborationOwnerUserId")
			local isContractedCar = type(hiredJob) == "string"
				and car ~= nil and car:GetAttribute("JobId") == hiredJob
			local isContractedMachine = type(hiredOwner) == "number" and ownerId == hiredOwner
				and type(p:GetAttribute("EquipmentId")) == "string"
			if not isContractedCar and not isContractedMachine then
				activePrompt = nil
				return
			end
		end
		promptAction.Text = p.ActionText
		promptObject.Text = p.ObjectText
		keyButton.Text = keyLabel(p, inputType)
		promptFill.Visible = false
		prompt.Visible = true
		promptPop.Scale = 0.85
		Motion.scale(promptPop, 1, Motion.Open)
	end)
	ProximityPromptService.PromptHidden:Connect(function(p: ProximityPrompt)
		if activePrompt == p then
			activePrompt = nil
			prompt.Visible = false
		end
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(p: ProximityPrompt)
		if activePrompt == p and p.HoldDuration > 0 then
			promptFill.Size = UDim2.new(0, 0, 0, 6)
			promptFill.Visible = true
			if promptHoldTween then
				promptHoldTween:Cancel()
			end
			local full = prompt.AbsoluteSize.X / scale.Scale - 28
			promptHoldTween = Motion.play(promptFill, TweenInfo.new(p.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, math.max(full, 40), 0, 6) })
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(p: ProximityPrompt)
		if activePrompt == p then
			promptFill.Visible = false
			if promptHoldTween then
				promptHoldTween:Cancel()
			end
		end
	end)
	-- Toque/mouse na tecla do prompt: segura pelo tempo do prompt (o teclado já é tratado pelo serviço)
	keyButton.Activated:Connect(function()
		local p = activePrompt
		if not p then
			return
		end
		p:InputHoldBegin()
		task.delay(p.HoldDuration + 0.05, function()
			p:InputHoldEnd()
		end)
	end)

	----------------------------------------------------------------------------------------------------------------
	-- Painéis e navegação
	----------------------------------------------------------------------------------------------------------------
	local entries: { Notifications.Entry } = {}
	local panels: { [string]: any } = {}
	local navButtons: { [string]: { HudParts.NavButton } } = {}
	local selectedName: string? = nil
	local refreshInfoVisibility: (() -> ())? = nil
	local previousSelection: GuiObject? = nil

	local function updateBell()
		local unread = 0
		for _, e in ipairs(entries) do
			if not e.Read then
				unread += 1
			end
		end
		setBellBadge(unread)
	end

	local function paintSelection()
		for name, buttons in pairs(navButtons) do
			for _, b in ipairs(buttons) do
				b.SetSelected(selectedName == name)
			end
		end
	end

	panels.orders = Orders.new(gui)
	panels.skills = Skills.new(gui)
	panels.shop = Shop.new(gui)
	panels.profile = Profile.new(gui)
	panels.stock = Stock.new(gui)
	panels.ranking = Ranking.new(gui)
	panels.notifications = Notifications.new(gui, function()
		return entries
	end, function()
		for _, e in ipairs(entries) do
			e.Read = true
		end
		updateBell()
		panels.notifications.Render()
	end)
	for name, p in pairs(panels) do
		p.OnClose = function()
			if selectedName == name then
				selectedName = nil
				paintSelection()
				GuiService.SelectedObject = previousSelection -- devolve o foco do gamepad
			end
		end
	end

	function HUD.openPanel(name: string)
		local panel = panels[name]
		if not panel then
			return
		end
		local wasOpen = panel.IsOpen()
		for _, p in pairs(panels) do
			if p.IsOpen() then
				p.Close()
			end
		end
		if wasOpen then
			selectedName = nil
		else
			previousSelection = GuiService.SelectedObject
			selectedName = name
			panel.Open()
			Store.Refresh()
			if name == "notifications" then
				for _, e in ipairs(entries) do
					e.Read = true
				end
				updateBell()
			end
			-- com gamepad, o foco vai para o botão de fechar do painel
			local closeButton = panel.Overlay:FindFirstChild("CloseButton", true)
			if closeButton and closeButton:IsA("GuiObject") and GuiService.SelectedObject ~= nil then
				GuiService.SelectedObject = closeButton
			end
		end
		paintSelection()
		if refreshInfoVisibility then refreshInfoVisibility() end
	end

	-- Botão B do gamepad fecha o painel aberto
	-- Minijogo de reparo: ao começar, fecha o painel aberto para liberar a tela.
	repairGameRef = RepairGame.new(gui)
	repairGameRef.Fit(1672, 941)
	operationGameRef = OperationRepairGame.new(gui)
	operationGameRef.Fit(1672, 941)
	local diagnosisRef = DiagnosisGame.new(gui)
	diagnosisRef.Fit(1672, 941)
	diagnosisRefFit = diagnosisRef.Fit
	local onboardingRef = Onboarding.new(gui, function(name: string): { GuiObject }
		local roots = {}
		for _, b in ipairs(navButtons[name] or {}) do
			-- Não guiar o tutorial para botões no trilho invisível.
			if b.Root.Parent and b.Root.Parent:IsA("GuiObject") and b.Root.Parent.Visible then
				table.insert(roots, b.Root)
			end
		end
		return roots
	end)
	onboardingFit = onboardingRef.Fit
	Store.DiagnoseStart.Event:Connect(function()
		prompt.Visible = false
		if selectedName and panels[selectedName] then
			panels[selectedName].Close()
		end
	end)
	Store.RepairStart.Event:Connect(function()
		prompt.Visible = false
		if selectedName and panels[selectedName] then
			panels[selectedName].Close()
		end
	end)

	-- Botão B do gamepad e Escape (PC) fecham o painel aberto. (No Roblox, Escape também abre o menu do jogo.)
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if (input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Escape) and selectedName and panels[selectedName] then
			panels[selectedName].Close()
		end
	end)
	-- A loja física do bairro (prompt "Abrir loja") abre a Loja de Peças.
	ProximityPromptService.PromptTriggered:Connect(function(triggered: ProximityPrompt)
		local target = triggered:GetAttribute("OpensPanel")
		if type(target) == "string" and panels[target] and selectedName ~= target then
			HUD.openPanel(target)
		end
	end)

	local function addNav(parent: Instance, spec: HudParts.NavSpec, panelName: string, order: number): HudParts.NavButton
		local b = HudParts.navButton(spec, function()
			-- Estoque e Loja são lugares físicos: longe deles, o botão guia até lá (a lista de ordens abre de qualquer lugar).
			if (panelName == "stock" or panelName == "shop") and selectedName ~= panelName and not Stations.IsNear(panelName) then
				Store.Message:Fire(Stations.FarText[panelName], false, "")
				Stations.Guide(panelName)
				return
			end
			HUD.openPanel(panelName)
		end)
		b.Root.LayoutOrder = order
		b.Root.Parent = parent
		b.SetEnabled(false) -- habilita quando o primeiro snapshot chegar
		navButtons[panelName] = navButtons[panelName] or {}
		table.insert(navButtons[panelName], b)
		return b
	end

	local function sideSpec(name: string, label: string, icon: string, iconSelected: string?): HudParts.NavSpec
		return { Name = name, Label = label, Icon = icon, IconSelected = iconSelected, Layout = "side", Width = 224, Height = 80 }
	end
	local sideButtons = {
		addNav(sideMenu, sideSpec("Ordens", t("nav_orders"), "b_clipboard", "clipboard"), "orders", 1),
		addNav(sideMenu, sideSpec("Habilidades", t("nav_skills"), "cap", nil), "skills", 2),
		addNav(sideMenu, sideSpec("Loja", t("nav_shop"), "store", nil), "shop", 3),
		addNav(sideMenu, sideSpec("Estoque", t("nav_stock"), "box", nil), "stock", 4),
		addNav(sideMenu, sideSpec("Perfil", t("nav_profile"), "person", nil), "profile", 5),
	}
	local ordersSideButton = sideButtons[1]

	local bottomNav = HudParts.panel(gui, "BottomNav")
	bottomNav.AutomaticSize = Enum.AutomaticSize.XY
	bottomNav.AnchorPoint = Vector2.new(0.5, 1)
	bottomNav.Position = UDim2.new(0.5, 0, 1, -22)
	pad(bottomNav, 8, 8, 8, 8)
	list(bottomNav, 6, true)
	local function bottomSpec(name: string, label: string, icon: string, width: number): HudParts.NavSpec
		return { Name = name, Label = label, Icon = icon, IconSelected = nil, Layout = "bottom", Width = width, Height = 98 }
	end
	local bottomButtons = {
		addNav(bottomNav, bottomSpec("B_Ordens", t("nav_orders"), "b_clipboard", 124), "orders", 1),
		addNav(bottomNav, bottomSpec("B_Habilidades", t("nav_skills"), "b_cap", 160), "skills", 2),
		addNav(bottomNav, bottomSpec("B_Loja", t("nav_shop"), "b_cart", 108), "shop", 3),
		addNav(bottomNav, bottomSpec("B_Estoque", t("nav_stock"), "b_box", 134), "stock", 4),
		addNav(bottomNav, bottomSpec("B_Ranking", t("nav_ranking"), "b_trophy", 142), "ranking", 5),
		addNav(bottomNav, bottomSpec("B_Perfil", t("nav_profile"), "person", 126), "profile", 6),
	}
	local ordersBottomButton = bottomButtons[1]

	bell.Activated:Connect(function()
		HUD.openPanel("notifications")
	end)
	detailsHit.Activated:Connect(function()
		HUD.openPanel("profile")
	end)

	----------------------------------------------------------------------------------------------------------------
	-- Responsividade e minimização
	----------------------------------------------------------------------------------------------------------------
	local compact, tight = false, false
	local logicalWidth, logicalHeight = 1672, 941
	local dockSize, dockHeight = 70, 70
	local menuMinimized: boolean? = nil
	local infoVisible: boolean? = nil

	local function applyMenu()
		-- Desktop tem menu lateral discreto; mobile tem apenas o dock inferior.
		local minimized = menuMinimized
		if minimized == nil then minimized = true end
		menuToggleLabel.Text = minimized and "›" or ("‹  " .. string.upper(t("hud_menu_toggle")))
		menuToggle.Size = UDim2.fromOffset(minimized and 76 or 208, 40)
		sideMenu.Visible = not compact
		bottomNav.Visible = compact
		local sideHeight = logicalHeight < 720 and 56 or 68
		for _, button in ipairs(sideButtons) do
			button.SetCompact(minimized :: boolean, sideHeight)
		end
		for _, button in ipairs(bottomButtons) do
			button.SetCompact(compact, compact and dockSize or 86)
		end
	end

	local function applyInfo()
		local visible = infoVisible
		if visible == nil then visible = not compact end
		-- Painel de gestão substitui o quadro de contexto; nada empilha sobre o outro.
		rightColumn.Visible = visible == true and selectedName == nil
		infoToggle.BackgroundColor3 = rightColumn.Visible and Theme.Surface2 or Theme.Surface
		compactHUD.Fit(logicalWidth, compact, rightColumn.Visible or selectedName ~= nil)
	end
	refreshInfoVisibility = applyInfo

	local function fitRightColumn()
		local top = compact and 166 or 108
		local maxHeight = math.max(100, logicalHeight - top - (compact and dockHeight + 36 or 18))
		local contentHeight = rightLayout.AbsoluteContentSize.Y / math.max(scale.Scale, 0.01)
		rightColumn.Size = UDim2.fromOffset(math.min(454, logicalWidth - 28),
			math.max(100, math.min(contentHeight, maxHeight)))
		rightColumn.ScrollBarThickness = contentHeight > maxHeight and 5 or 0
	end
	rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		task.defer(fitRightColumn)
	end)

	local function updateLayout()
		local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1672, 941)
		local override = gui:GetAttribute("ViewportOverride") -- testes de layout em diferentes resoluções
		if typeof(override) == "Vector2" then viewport = override end
		local layout = HudLayoutRules.Plan(viewport, UserInputService.TouchEnabled)
		scale.Scale = layout.Scale
		logicalWidth, logicalHeight = layout.Width, layout.Height
		compact, tight = layout.Compact, layout.Tight
		gui:SetAttribute("HudLogicalWidth", logicalWidth)
		gui:SetAttribute("CompactLayout", compact)
		gui:SetAttribute("HudDockHeight", layout.DockHeight)
		dockSize, dockHeight = layout.DockSize, layout.DockHeight
		topBar.Visible = not compact
		logo.Visible = not compact
		logoDivider.Visible = not compact
		levelCaption.Visible = not tight
		xpValue.Visible = not tight
		balanceCaption.Visible = not tight
		repCaption.Visible = not tight
		ratingValue.Visible = not tight
		repStar.Visible = not tight and ratingValue.Text ~= ""
		xpTrack.Size = UDim2.fromOffset(125, 9)
		topLayout.Padding = UDim.new(0, 14)
		-- O menu e a coluna ocupam trilhos; o centro do carro fica desimpedido.
		sideMenu.Position = UDim2.fromOffset(16, 105)
		rightColumn.Position = UDim2.new(1, -14, 0, layout.DetailsTop)
		bottomNav.Position = UDim2.new(0.5, 0, 1, -14)
		controls.Position = UDim2.new(1, -14, 0, 14)
		prompt.Position = UDim2.new(0.5, 0, 1, compact and -(dockHeight + 40) or -110)
		toasts.Position = UDim2.new(0.5, 0, 0, compact and 175 or 108)
		toasts.Size = UDim2.fromOffset(math.min(600, logicalWidth - 32), 0)
		shopCard.Visible = false
		applyMenu()
		applyInfo()
		fitRightColumn()
		if repairGameRef then repairGameRef.Fit(logicalWidth, logicalHeight) end
		if operationGameRef then operationGameRef.Fit(logicalWidth, logicalHeight) end
		if diagnosisRefFit then diagnosisRefFit(logicalWidth, logicalHeight) end
		if onboardingFit then onboardingFit(logicalWidth) end
		for _, panel in pairs(panels) do
			if panel.Fit then panel.Fit(logicalWidth, logicalHeight) end
		end
	end
	updateLayout()
	gui:GetAttributeChangedSignal("ViewportOverride"):Connect(updateLayout)
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
	end

	menuToggle.Activated:Connect(function()
		local minimized = menuMinimized
		if minimized == nil then minimized = true end
		menuMinimized = not minimized
		applyMenu()
	end)
	infoToggle.Activated:Connect(function()
		local visible = infoVisible
		if visible == nil then
			visible = not compact
		end
		infoVisible = not visible
		applyInfo()
	end)

	----------------------------------------------------------------------------------------------------------------
	-- Atualização com dados reais
	----------------------------------------------------------------------------------------------------------------
	Store.Message.Event:Connect(function(text: string, success: boolean)
		toast(text, success)
		if text ~= "" then
			table.insert(entries, { Text = text, Success = success, At = os.time(), Read = selectedName == "notifications" })
			while #entries > MAX_NOTIFICATIONS do
				table.remove(entries, 1)
			end
			updateBell()
		end
	end)
	Store.Rated.Event:Connect(showRated)

	-- Número flutuante ao ganhar/gastar moedas
	local lastCoins: number? = nil
	local function floatDelta(delta: number)
		local label = Kit.label(gui, string.format("%+d", delta), {
			AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), TextWrapped = false,
			Font = Theme.FontTitle, TextSize = 40, TextColor3 = delta > 0 and Theme.Green or Theme.Red,
			AnchorPoint = Vector2.new(0.5, 0), ZIndex = 20,
		})
		local abs = balanceBlock.AbsolutePosition
		local size = balanceBlock.AbsoluteSize
		local topLeft = gui.AbsolutePosition
		label.Position = UDim2.fromOffset((abs.X - topLeft.X + size.X / 2) / scale.Scale, (abs.Y - topLeft.Y + size.Y) / scale.Scale)
		local tween = Motion.play(label, TweenInfo.new(1.2), { Position = label.Position + UDim2.fromOffset(0, 50), TextTransparency = 1 })
		tween.Completed:Connect(function()
			label:Destroy()
		end)
	end

	type CustomerRow = {
		Job: any,
		Wait: TextLabel,
		Percent: TextLabel,
		Warning: Frame,
		SetBar: (number, Color3?) -> (),
	}
	local customerRows: { CustomerRow } = {}

	local function patienceState(job: any): (number, number)
		local elapsed = (job.WaitSeconds or 0) + (os.clock() - Store.SnapshotClock)
		local patience = math.max(1, job.PatienceSeconds or 300)
		return elapsed, math.clamp(1 - elapsed / patience, 0, 1)
	end

	local function refreshCustomerTimes()
		for _, r in ipairs(customerRows) do
			local elapsed, remaining = patienceState(r.Job)
			r.Wait.Text = clock(elapsed)
			r.Wait.TextColor3 = remaining < WARNING_FRACTION and rgb(255, 40, 40) or Theme.Text
			r.Percent.Text = string.format("%d%%", math.floor(remaining * 100 + 0.5))
			r.SetBar(remaining, nil)
			r.Warning.Visible = remaining < WARNING_FRACTION
		end
	end

	local lastCustomersKey = ""
	local function renderCustomers(snapshot: any)
		local waiting = {}
		for _, job in ipairs(snapshot.Jobs) do
			if job.Status == "Available" then
				table.insert(waiting, job)
			end
		end
		table.sort(waiting, function(a, b)
			return (a.WaitSeconds or 0) > (b.WaitSeconds or 0)
		end)
		-- Mesmo cliente no cartão: só atualiza os dados (sem recriar a miniatura 3D a cada snapshot)
		local key = #waiting .. ":" .. tostring(waiting[1] and waiting[1].Id)
		if key == lastCustomersKey and #customerRows > 0 then
			customersCount.Text = t("customers_count", #waiting)
			customerRows[1].Job = waiting[1]
			return
		end
		lastCustomersKey = key
		clearChildren(customersList)
		customerRows = {}
		customersCount.Text = t("customers_count", #waiting)
		customersCount.Visible = #waiting > 0
		if #waiting == 0 then
			HudParts.text(customersList, t("customers_none"), 24, { Font = Theme.FontTitle, TextColor3 = Theme.Muted })
			return
		end
		for index = 1, math.min(1, #waiting) do -- como na referência: o cliente mais urgente; os demais entram na contagem
			local job = waiting[index]
			local entry = Instance.new("Frame")
			entry.Name = "Customer" .. index
			entry.BackgroundTransparency = 1
			entry.Size = UDim2.new(1, 0, 0, 0)
			entry.AutomaticSize = Enum.AutomaticSize.Y
			entry.LayoutOrder = index
			list(entry, 8, false)
			entry.Parent = customersList
			local top = row(entry, 14, 1)
			local _, setModel = HudParts.vehicleThumb(top, 164, 125)
			setModel(job.VehicleModel)
			local info = column(top, 2, 2)
			HudParts.text(info, job.VehicleName, 32, { Font = Theme.FontTitle })
			HudParts.text(info, t("customers_customer", (job.Vip and "★ VIP " or (job.Regular and "♥ " or (job.Fleet and "📋 " or ""))) .. (job.CustomerName or "?")), 24, { Font = Theme.FontTitle })
			local waitRow = row(info, 8)
			HudParts.text(waitRow, t("customers_wait_label"), 24, { Font = Theme.FontTitle })
			local waitLabel = HudParts.text(waitRow, "", 24, { Font = Theme.FontTitle })
			local barRow = row(info, 8)
			HudParts.text(barRow, t("customers_patience"), 22, { Font = Theme.FontTitle })
			local track, setBar = HudParts.progress(barRow, 16)
			track.Size = UDim2.fromOffset(92, 16)
			local percent = HudParts.text(barRow, "", 26, { Font = Theme.FontTitle })
			local warning = row(entry, 10, 2, "Warning")
			warning.Visible = false
			local mark = HudParts.text(warning, "!", 26, {
				Font = Theme.FontTitle, TextColor3 = rgb(30, 20, 4), BackgroundTransparency = 0, BackgroundColor3 = rgb(255, 190, 20),
				AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromOffset(34, 34), TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			})
			Kit.corner(mark, 17)
			HudParts.text(warning, t("customers_warning"), 26, { Font = Theme.FontTitle, TextColor3 = rgb(255, 196, 20) })
			table.insert(customerRows, { Job = job, Wait = waitLabel, Percent = percent, Warning = warning, SetBar = setBar })
		end
		refreshCustomerTimes()
	end

	local function renderOrder(snapshot: any)
		clearChildren(orderText)
		local active: any = nil
		for _, job in ipairs(snapshot.Jobs) do
			if job.Status == "InProgress" then
				active = job
				break
			end
		end
		if not active then
			HudParts.text(orderText, t("order_none"), 25, { Font = Theme.FontTitle, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
			return
		end
		local intro = active.Diagnosed and t("order_intro_repair") or t("order_intro_diagnose")
		if active.Diagnosed and active.PrepRequired and not active.PrepComplete then
			intro = "Siga os marcadores amarelos no carro para preparar o serviço."
		end
		HudParts.text(orderText, intro, 25, {
			Font = Theme.FontTitle, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
		})
		-- O preparo do carro é uma etapa própria, antes de abrir o minijogo de execução.
		local steps = { { t("order_step_diagnose"), active.Diagnosed == true } }
		if active.PrepRequired then
			table.insert(steps, { "Preparar o veículo", active.PrepComplete == true })
		end
		table.insert(steps, { t("order_step_repair"), false })
		table.insert(steps, { t("order_step_deliver"), false })
		local currentFound = false
		for index, step in ipairs(steps) do
			local done = step[2] :: boolean
			local isCurrent = not done and not currentFound
			if isCurrent then
				currentFound = true
			end
			local line = row(orderText, 12, index + 1)
			local box = Instance.new("TextLabel")
			box.Size = UDim2.fromOffset(32, 32)
			box.BackgroundColor3 = done and rgb(46, 214, 82) or Theme.Bg
			box.BackgroundTransparency = done and 0 or 0.3
			box.Text = done and "✓" or ""
			box.TextColor3 = Color3.new(1, 1, 1)
			box.Font = Theme.FontTitle
			box.TextSize = 24
			Kit.corner(box, 8)
			HudParts.stroke(box, isCurrent and rgb(255, 190, 40) or Color3.new(1, 1, 1), 0.1, 2.5)
			box.Parent = line
			HudParts.text(line, step[1] :: string, 25, {
				Font = isCurrent and Theme.FontTitle or Theme.FontTitle,
				TextColor3 = isCurrent and rgb(255, 205, 80) or Theme.Text,
			})
		end
	end

	local function renderShop(snapshot: any)
		local p = snapshot.Profile
		local level = Catalog.BusinessLevel(p.TotalEarned or 0)
		shopName.Text = snapshot.WorkshopName or t("profile_workshop_none")
		shopLevel.Text = string.format("%s %02d", t("shopcard_level_word"), level)
		local count = p.RatingCount or 0
		if count > 0 then
			local average = CustomerRules.AverageRating(p.RatingSum or 0, count)
			shopRating.Text = string.format("★ %.1f (%d %s)", average, count, t("shopcard_ratings_word"))
			shopRating.TextColor3 = rgb(255, 205, 60)
		else
			shopRating.Text = t("hud_rep_none")
			shopRating.TextColor3 = Theme.Muted
		end
		shopServed.Text = t("shopcard_served", count) -- cada serviço concluído recebe uma avaliação
	end

	Store.Changed.Event:Connect(function(snapshot: any)
		local p = snapshot.Profile
		if lastCoins and p.Coins ~= lastCoins then
			floatDelta(p.Coins - lastCoins)
		end
		lastCoins = p.Coins

		local level, total, startOfLevel, nextLevel = Catalog.BusinessProgress(p.TotalEarned or 0)
		levelValue.Text = string.format("%02d", level)
		xpValue.Text = t("hud_xp", math.floor(total), math.floor(nextLevel))
		setXp((total - startOfLevel) / math.max(1, nextLevel - startOfLevel), nil)
		coinsValue.Text = thousands(p.Coins)
		compactHUD.SetStats(p.Coins, level, p.Reputation)
		compactHUD.SetObjective(snapshot)
		repValue.Text = tostring(p.Reputation)
		local ratings = p.RatingCount or 0
		if ratings > 0 then
			ratingValue.Text = string.format("%.1f", CustomerRules.AverageRating(p.RatingSum or 0, ratings))
			repStar.Visible = not tight
		else
			ratingValue.Text = ""
			repStar.Visible = false
		end

		local waiting = 0
		for _, job in ipairs(snapshot.Jobs) do
			if job.Status == "Available" then
				waiting += 1
			end
		end
		ordersSideButton.SetBadge(waiting) -- clientes aguardando atendimento (dado real)
		ordersBottomButton.SetBadge(waiting)

		renderCustomers(snapshot)
		renderOrder(snapshot)
		renderShop(snapshot)

		for _, buttons in pairs(navButtons) do
			for _, b in ipairs(buttons) do
				b.SetEnabled(true)
			end
		end
	end)

	task.spawn(function()
		while gui.Parent do
			refreshCustomerTimes()
			task.wait(1)
		end
	end)

	-- Convite de trabalho recebido
	local inviteCard: Frame? = nil
	Store.Invite.Event:Connect(function(payload: any)
		if inviteCard then
			inviteCard:Destroy()
		end
		local box = HudParts.panel(gui, "Invite")
		box.AutomaticSize = Enum.AutomaticSize.XY
		box.AnchorPoint = Vector2.new(0.5, 1)
		box.Position = UDim2.new(0.5, 0, 1, -140)
		pad(box, 16, 20, 16, 20)
		list(box, 12, false)
		local text = HudParts.text(box, t("invite_text", payload.OwnerName, payload.SplitPercent), 26, { Font = Theme.FontTitle, TextWrapped = true })
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(560, math.huge)
		limit.Parent = text
		local buttons = row(box, 10, 2)
		local function answer(accepted: boolean)
			Store.Act("RespondInvite", { InviteId = payload.InviteId, Accepted = accepted })
			box:Destroy()
			inviteCard = nil
		end
		local accept = Kit.button(buttons, t("invite_accept"), function() answer(true) end, "success")
		accept.TextSize = 24
		local decline = Kit.button(buttons, t("invite_decline"), function() answer(false) end, "secondary")
		decline.TextSize = 24
		inviteCard = box
		task.delay(30, function()
			if inviteCard == box then
				box:Destroy()
				inviteCard = nil
			end
		end)
	end)
end

return HUD
