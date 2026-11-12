--!strict
-- Componentes dos cinco painéis (janela com cabeçalho, abas, busca, filtro, cartões, botões, estado vazio).
-- Unidades de referência como no HUD; sem regra de jogo aqui.
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Motion)
local HudParts = require(script.Parent.HudParts)

local PanelKit = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local HEADER_HEIGHT = 86

export type Window = {
	Root: Frame, -- também exposto como Overlay para o gerenciador de painéis do HUD
	Overlay: Frame,
	Content: Frame,
	Open: () -> (),
	Close: () -> (),
	IsOpen: () -> boolean,
	SetMinimized: (boolean) -> (),
	Fit: (number, number) -> (),
	IsCompact: () -> boolean,
	OnClose: (() -> ())?,
	OnOpen: (() -> ())?,
	OnResize: (() -> ())?,
}

export type WindowSpec = {
	Name: string,
	Title: string,
	Subtitle: string,
	Icon: string,
	IconTint: Color3?,
	Width: number,
	Height: number,
}

local function listLayout(parent: Instance, gap: number, horizontal: boolean): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if horizontal then
		l.FillDirection = Enum.FillDirection.Horizontal
	end
	l.Parent = parent
	return l
end

-- Botão pequeno do cabeçalho (fechar / minimizar). O degradê fica em um quadro filho: UIGradient num TextButton
-- também tingiria o texto.
local function headerButton(parent: Instance, name: string, text: string, order: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(50, 50)
	b.LayoutOrder = order
	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.BorderSizePixel = 0
	Kit.corner(bg, 14)
	HudParts.gradient(bg, { { 0, rgb(30, 52, 92) }, { 1, rgb(12, 24, 48) } })
	local stroke = HudParts.stroke(bg, rgb(70, 110, 170), 0.2, 2)
	bg.Parent = b
	local label = HudParts.text(b, text, 34, { Font = Theme.FontTitle, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 2 })
	local pop = Instance.new("UIScale")
	pop.Parent = b
	b:GetPropertyChangedSignal("Text"):Connect(function()
		if b.Text ~= "" then
			label.Text = b.Text
			b.Text = ""
		end
	end)
	b.MouseEnter:Connect(function()
		Motion.scale(pop, 1.08, Motion.Hover)
		stroke.Color = rgb(130, 180, 240)
	end)
	b.MouseLeave:Connect(function()
		Motion.scale(pop, 1, Motion.Release)
		stroke.Color = rgb(70, 110, 170)
	end)
	b.MouseButton1Down:Connect(function()
		Motion.scale(pop, 0.92, Motion.Press)
	end)
	b.MouseButton1Up:Connect(function()
		Motion.scale(pop, 1.08, Motion.Release)
	end)
	b.Parent = parent
	return b
end

function PanelKit.window(parent: Instance, spec: WindowSpec): Window
	local root = HudParts.panel(parent, spec.Name)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(spec.Width, spec.Height)
	root.ClipsDescendants = true
	root.Visible = false
	root.ZIndex = 10
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = root

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.BorderSizePixel = 0
	HudParts.gradient(header, { { 0, rgb(44, 62, 69) }, { 1, rgb(20, 36, 42) } })
	header.Parent = root
	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 0, 2)
	line.AnchorPoint = Vector2.new(0, 1)
	line.Position = UDim2.fromScale(0, 1)
	line.BackgroundColor3 = Theme.Accent
	line.BackgroundTransparency = 0.35
	line.BorderSizePixel = 0
	line.Parent = header

	local icon = HudParts.sprite(header, spec.Icon, Vector2.new(62, 62))
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 22, 0.5, 0)
	if spec.IconTint then
		icon.ImageColor3 = spec.IconTint
	end
	local titles = Instance.new("Frame")
	titles.BackgroundTransparency = 1
	titles.AnchorPoint = Vector2.new(0, 0.5)
	titles.Position = UDim2.new(0, 98, 0.5, 0)
	titles.Size = UDim2.new(1, -250, 0, 66)
	titles.Parent = header
	listLayout(titles, 0, false).VerticalAlignment = Enum.VerticalAlignment.Center
	local title = HudParts.text(titles, spec.Title, 40, { Font = Theme.FontTitle, TextTruncate = Enum.TextTruncate.AtEnd, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 1 })
	local subtitle = HudParts.text(titles, spec.Subtitle, 22, { Font = Theme.FontSemi, TextColor3 = rgb(190, 205, 230), TextTruncate = Enum.TextTruncate.AtEnd, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2 })
	local _ = { title, subtitle }

	local buttons = Instance.new("Frame")
	buttons.Name = "HeaderButtons"
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(1, 0.5)
	buttons.Position = UDim2.new(1, -16, 0.5, 0)
	buttons.AutomaticSize = Enum.AutomaticSize.XY
	buttons.Size = UDim2.new()
	listLayout(buttons, 8, true)
	buttons.Parent = header
	local minimizeButton = headerButton(buttons, "MinimizeButton", "-", 1)
	local closeButton = headerButton(buttons, "CloseButton", "X", 2)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(0, HEADER_HEIGHT)
	content.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
	content.Parent = root

	local isOpen, minimized = false, false
	local fittedWidth, fittedHeight = spec.Width, spec.Height
	local window: Window
	local function applySize()
		root.Size = UDim2.fromOffset(fittedWidth, minimized and HEADER_HEIGHT or fittedHeight)
		content.Visible = not minimized
	end
	window = {
		Root = root,
		Overlay = root,
		Content = content,
		OnClose = nil,
		OnOpen = nil,
		OnResize = nil,
		IsOpen = function()
			return isOpen
		end,
		Open = function()
			if isOpen then
				return
			end
			isOpen = true
			root.Visible = true
			pop.Scale = 0.92
			Motion.scale(pop, 1, Motion.Open)
			if window.OnOpen then
				window.OnOpen()
			end
		end,
		Close = function()
			if not isOpen then
				return
			end
			isOpen = false
			Motion.scale(pop, 0.94, Motion.Close)
			task.delay(0.13, function()
				if not isOpen then -- reabrir durante o fechamento mantém o painel visível
					root.Visible = false
				end
			end)
			if window.OnClose then
				window.OnClose()
			end
		end,
		SetMinimized = function(value: boolean)
			minimized = value
			applySize()
		end,
		Fit = function(logicalWidth: number, logicalHeight: number)
			-- Desktop: janela lateral, preservando o centro do gameplay.
			-- Celular/tablet: folha inferior, sem overlay escuro e acima do dock.
			if logicalWidth < 1180 then
				root.AnchorPoint = Vector2.new(0.5, 1)
				root.Position = UDim2.new(0.5, 0, 1, logicalHeight < 640 and -94 or -105)
				fittedWidth = math.min(spec.Width, logicalWidth - 28)
				fittedHeight = math.min(spec.Height, math.max(220, math.min(logicalHeight * 0.72, logicalHeight - 170)))
			else
				root.AnchorPoint = Vector2.new(1, 0.5)
				root.Position = UDim2.new(1, -24, 0.5, 0)
				fittedWidth = math.min(spec.Width, logicalWidth * 0.56)
				fittedHeight = math.min(spec.Height, logicalHeight - 40)
			end
			applySize()
			if window.OnResize then
				window.OnResize()
			end
		end,
		IsCompact = function()
			return fittedWidth < 640
		end,
	}
	closeButton.Activated:Connect(function()
		window.Close()
	end)
	minimizeButton.Activated:Connect(function()
		window.SetMinimized(not minimized)
		minimizeButton.Text = minimized and "+" or "-"
	end)
	root.Parent = parent
	return window
end

----------------------------------------------------------------------------------------------------------------
-- Abas
----------------------------------------------------------------------------------------------------------------
export type TabDef = { Id: string, Label: string, Icon: string?, Enabled: boolean? }
export type Tabs = {
	Root: Frame,
	Select: (string) -> (),
	Current: () -> string,
	SetLabel: (string, string) -> (),
	SetCompact: (boolean) -> (), -- tela estreita: esconde os ícones e reduz o texto das abas
}

function PanelKit.tabs(parent: Instance, defs: { TabDef }, onSelect: (string) -> ()): Tabs
	local holder = Instance.new("Frame")
	holder.Name = "Tabs"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 58)
	listLayout(holder, 8, true)
	holder.Parent = parent
	local gap = 8
	local count = #defs
	local buttons: { [string]: { Button: TextButton, Normal: Frame, Selected: Frame, Label: TextLabel, Icon: ImageLabel? } } = {}
	local current = defs[1].Id

	local function paint()
		for id, b in pairs(buttons) do
			local active = id == current
			Motion.play(b.Selected, Motion.Hover, { BackgroundTransparency = active and 0 or 1 })
			b.Normal.BackgroundTransparency = active and 1 or 0
		end
	end

	for index, def in ipairs(defs) do
		local enabled = def.Enabled ~= false
		local button = Instance.new("TextButton")
		button.Name = "Tab_" .. def.Id
		button.AutoButtonColor = false
		button.Text = ""
		button.BackgroundTransparency = 1
		button.Size = UDim2.new(1 / count, -gap * (count - 1) / count, 1, 0)
		button.LayoutOrder = index
		button.Active = enabled
		local pop = Instance.new("UIScale")
		pop.Parent = button
		local normal = Instance.new("Frame")
		normal.Size = UDim2.fromScale(1, 1)
		normal.BackgroundColor3 = Color3.new(1, 1, 1)
		normal.BorderSizePixel = 0
		Kit.corner(normal, 14)
		HudParts.gradient(normal, { { 0, rgb(24, 40, 68) }, { 1, rgb(10, 20, 38) } })
		HudParts.stroke(normal, rgb(58, 88, 130), 0.1, 2)
		normal.Parent = button
		local selected = Instance.new("Frame")
		selected.Size = UDim2.fromScale(1, 1)
		selected.BackgroundColor3 = Color3.new(1, 1, 1)
		selected.BackgroundTransparency = 1
		selected.BorderSizePixel = 0
		Kit.corner(selected, 14)
		HudParts.gradient(selected, { { 0, rgb(40, 150, 255) }, { 0.5, rgb(0, 110, 225) }, { 1, rgb(0, 72, 170) } })
		HudParts.stroke(selected, rgb(130, 210, 255), 0.1, 2)
		selected.Parent = button
		local content = Instance.new("Frame")
		content.BackgroundTransparency = 1
		content.Size = UDim2.fromScale(1, 1)
		content.ZIndex = 3
		content.Parent = button
		local layout = listLayout(content, 8, true)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		local iconLabel: ImageLabel? = nil
		if def.Icon then
			iconLabel = HudParts.sprite(content, def.Icon, Vector2.new(30, 30))
			iconLabel.LayoutOrder = 1
			iconLabel.ZIndex = 3
		end
		local label = HudParts.text(content, def.Label, 27, { Font = Theme.FontTitle, LayoutOrder = 2, ZIndex = 3 })
		if not enabled then
			label.TextTransparency = 0.55
			if iconLabel then
				iconLabel.ImageTransparency = 0.55
			end
		end
		button.MouseEnter:Connect(function()
			if enabled then
				Motion.scale(pop, 1.03, Motion.Hover)
			end
		end)
		button.MouseLeave:Connect(function()
			Motion.scale(pop, 1, Motion.Release)
		end)
		button.MouseButton1Down:Connect(function()
			if enabled then
				Motion.scale(pop, 0.96, Motion.Press)
			end
		end)
		button.MouseButton1Up:Connect(function()
			Motion.scale(pop, 1.03, Motion.Release)
		end)
		button.Activated:Connect(function()
			if enabled and current ~= def.Id then
				current = def.Id
				paint()
				onSelect(def.Id)
			end
		end)
		button.Parent = holder
		buttons[def.Id] = { Button = button, Normal = normal, Selected = selected, Label = label, Icon = iconLabel }
	end
	paint()
	return {
		Root = holder,
		Select = function(id: string)
			if buttons[id] then
				current = id
				paint()
				onSelect(id)
			end
		end,
		Current = function()
			return current
		end,
		SetLabel = function(id: string, text: string)
			local b = buttons[id]
			if b then
				b.Label.Text = text
			end
		end,
		SetCompact = function(value: boolean)
			for _, b in pairs(buttons) do
				if b.Icon then
					b.Icon.Visible = not value
				end
				b.Label.TextSize = value and 22 or 27
			end
		end,
	}
end

----------------------------------------------------------------------------------------------------------------
-- Busca, filtro, botões, cartões, estado vazio
----------------------------------------------------------------------------------------------------------------
function PanelKit.searchBox(parent: Instance, placeholder: string, onChanged: (string) -> ()): (Frame, TextBox)
	local holder = Instance.new("Frame")
	holder.Name = "Search"
	holder.BackgroundColor3 = Color3.new(1, 1, 1)
	holder.BorderSizePixel = 0
	holder.Size = UDim2.new(1, 0, 0, 52)
	Kit.corner(holder, 14)
	HudParts.gradient(holder, { { 0, rgb(18, 30, 52) }, { 1, rgb(8, 16, 30) } })
	local stroke = HudParts.stroke(holder, rgb(58, 88, 130), 0.1, 2)
	local icon = HudParts.sprite(holder, "pn_search", Vector2.new(28, 28))
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 14, 0.5, 0)
	local box = Instance.new("TextBox")
	box.Name = "Input"
	box.BackgroundTransparency = 1
	box.ClearTextOnFocus = false
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = rgb(140, 158, 190)
	box.Text = ""
	box.TextColor3 = Theme.Text
	box.Font = Theme.FontTitle
	box.TextSize = 25
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Position = UDim2.fromOffset(56, 0)
	box.Size = UDim2.new(1, -66, 1, 0)
	box.Parent = holder
	box.Focused:Connect(function()
		stroke.Color = rgb(70, 170, 255)
	end)
	box.FocusLost:Connect(function()
		stroke.Color = rgb(58, 88, 130)
	end)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		onChanged(box.Text)
	end)
	holder.Parent = parent
	return holder, box
end

-- Filtro em lista (abre uma lista de opções abaixo do botão).
function PanelKit.dropdown(parent: Instance, options: { { Id: string, Label: string } }, onSelect: (string) -> ()): (TextButton, (string) -> (), ({ { Id: string, Label: string } }) -> ())
	local button = Instance.new("TextButton")
	button.Name = "Dropdown"
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BorderSizePixel = 0
	button.Size = UDim2.new(0, 230, 0, 52)
	Kit.corner(button, 14)
	HudParts.gradient(button, { { 0, rgb(24, 40, 68) }, { 1, rgb(10, 20, 38) } })
	HudParts.stroke(button, rgb(58, 88, 130), 0.1, 2)
	local label = HudParts.text(button, options[1].Label, 25, {
		Font = Theme.FontTitle, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -52, 1, 0), Position = UDim2.fromOffset(16, 0),
		TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Center,
	})
	local chevron = HudParts.sprite(button, "pn_chev", Vector2.new(24, 24))
	chevron.AnchorPoint = Vector2.new(1, 0.5)
	chevron.Position = UDim2.new(1, -14, 0.5, 0)
	local list = Instance.new("Frame")
	list.Name = "Options"
	list.Visible = false
	list.ZIndex = 30
	list.BackgroundColor3 = rgb(10, 20, 38)
	list.BorderSizePixel = 0
	list.AnchorPoint = Vector2.new(0, 0)
	list.Position = UDim2.new(0, 0, 1, 6)
	list.Size = UDim2.new(1, 0, 0, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	Kit.corner(list, 14)
	HudParts.stroke(list, rgb(90, 140, 210), 0, 2)
	listLayout(list, 2, false)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = list
	list.Parent = button
	local optionLabels: { [string]: string } = {}
	local function build(opts: { { Id: string, Label: string } })
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		optionLabels = {}
		for index, option in ipairs(opts) do
			optionLabels[option.Id] = option.Label
			local item = Instance.new("TextButton")
			item.AutoButtonColor = false
			item.Text = option.Label
			item.Font = Theme.FontTitle
			item.TextSize = 24
			item.TextColor3 = Theme.Text
			item.BackgroundColor3 = rgb(30, 52, 92)
			item.BackgroundTransparency = 1
			item.Size = UDim2.new(1, 0, 0, 44)
			item.LayoutOrder = index
			item.ZIndex = 31
			Kit.corner(item, 10)
			item.MouseEnter:Connect(function()
				item.BackgroundTransparency = 0
			end)
			item.MouseLeave:Connect(function()
				item.BackgroundTransparency = 1
			end)
			item.Activated:Connect(function()
				label.Text = option.Label
				list.Visible = false
				onSelect(option.Id)
			end)
			item.Parent = list
		end
	end
	build(options)
	button.Activated:Connect(function()
		list.Visible = not list.Visible
	end)
	button.Parent = parent
	return button, function(id: string)
		label.Text = optionLabels[id] or label.Text
	end, build
end

-- Botão de ação. kind: "blue" | "green" | "orange" | "dark"
function PanelKit.button(parent: Instance, text: string, kind: string, size: Vector2, onClick: () -> (), iconSprite: string?): (TextButton, (boolean) -> ())
	local palettes: { [string]: { { { number | Color3 } } } } = {
		blue = { { { 0, rgb(70, 175, 255) }, { 0.5, rgb(20, 130, 240) }, { 1, rgb(0, 90, 205) } } },
		green = { { { 0, rgb(70, 225, 105) }, { 0.5, rgb(34, 190, 70) }, { 1, rgb(18, 140, 50) } } },
		orange = { { { 0, rgb(255, 215, 70) }, { 0.5, rgb(255, 168, 20) }, { 1, rgb(235, 125, 0) } } },
		dark = { { { 0, rgb(34, 54, 90) }, { 1, rgb(14, 26, 48) } } },
	}
	local b = Instance.new("TextButton")
	b.Name = "Btn_" .. text
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BorderSizePixel = 0
	b.Size = UDim2.fromOffset(size.X, size.Y)
	Kit.corner(b, 14)
	HudParts.gradient(b, (palettes[kind] or palettes.dark)[1])
	local edge = kind == "green" and rgb(150, 255, 175) or kind == "orange" and rgb(255, 235, 150) or kind == "blue" and rgb(150, 215, 255) or rgb(70, 110, 170)
	HudParts.stroke(b, edge, 0.25, 2)
	local pop = Instance.new("UIScale")
	pop.Parent = b
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = b
	local layout = listLayout(row, 8, true)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	if iconSprite then
		local icon = HudParts.sprite(row, iconSprite, Vector2.new(30, 30))
		icon.LayoutOrder = 1
	end
	local label = HudParts.text(row, text, 26, { Font = Theme.FontTitle, LayoutOrder = 2, TextColor3 = kind == "orange" and rgb(40, 22, 4) or Theme.Text })
	local enabled = true
	b.MouseEnter:Connect(function()
		if enabled then
			Motion.scale(pop, 1.04, Motion.Hover)
		end
	end)
	b.MouseLeave:Connect(function()
		Motion.scale(pop, 1, Motion.Release)
	end)
	b.MouseButton1Down:Connect(function()
		if enabled then
			Motion.scale(pop, 0.95, Motion.Press)
		end
	end)
	b.MouseButton1Up:Connect(function()
		Motion.scale(pop, 1.04, Motion.Release)
	end)
	b.Activated:Connect(function()
		if enabled then
			onClick()
		end
	end)
	b.Parent = parent
	return b, function(value: boolean)
		enabled = value
		b.Active = value
		label.TextTransparency = value and 0 or 0.55
		b.BackgroundTransparency = value and 0 or 0.45
	end
end

function PanelKit.card(parent: Instance, name: string?): Frame
	local f = Instance.new("Frame")
	f.Name = name or "Card"
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.05
	f.BorderSizePixel = 0
	Kit.corner(f, 14)
	HudParts.gradient(f, { { 0, rgb(20, 36, 62) }, { 1, rgb(11, 21, 38) } })
	HudParts.stroke(f, rgb(50, 78, 120), 0.1, 2)
	f.Parent = parent
	return f
end

function PanelKit.emptyState(parent: Instance, sprite: string, title: string, subtitle: string): Frame
	local f = Instance.new("Frame")
	f.Name = "EmptyState"
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 1, 0)
	local layout = listLayout(f, 4, false)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local icon = HudParts.sprite(f, sprite, Vector2.new(84, 84))
	icon.LayoutOrder = 1
	icon.ImageTransparency = 0.15
	HudParts.text(f, title, 34, { Font = Theme.FontTitle, TextColor3 = rgb(120, 170, 235), LayoutOrder = 2, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -40, 0, 0) })
	HudParts.text(f, subtitle, 23, { Font = Theme.FontSemi, TextColor3 = rgb(170, 188, 215), LayoutOrder = 3, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -40, 0, 0) })
	f.Parent = parent
	return f
end

-- Rolagem vertical com lista (corpo de aba).
function PanelKit.scroll(parent: Instance, name: string): (ScrollingFrame, UIListLayout)
	local s = Instance.new("ScrollingFrame")
	s.Name = name
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.ScrollBarImageColor3 = rgb(90, 140, 210)
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	local layout = listLayout(s, 10, false)
	s.Parent = parent
	return s, layout
end

-- Pequeno rótulo em pílula (categoria, estado).
function PanelKit.chip(parent: Instance, text: string, tint: Color3): TextLabel
	local chip = HudParts.text(parent, text, 21, { Font = Theme.FontTitle, TextColor3 = tint, BackgroundTransparency = 0.8, BackgroundColor3 = tint, TextXAlignment = Enum.TextXAlignment.Center })
	Kit.corner(chip, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 2), UDim.new(0, 2)
	pad.Parent = chip
	return chip
end

return PanelKit
