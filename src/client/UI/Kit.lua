--!strict
-- Componentes visuais reutilizáveis (botão, cartão, rótulo, painel modal).
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Locale = require(game:GetService("ReplicatedStorage").Shared.Locale)

local Kit = {}

function Kit.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

function Kit.padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop, p.PaddingBottom = UDim.new(0, px), UDim.new(0, px)
	p.PaddingLeft, p.PaddingRight = UDim.new(0, px), UDim.new(0, px)
	p.Parent = parent
	return p
end

function Kit.list(parent: Instance, gap: number?, horizontal: boolean?)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap or 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if horizontal then
		l.FillDirection = Enum.FillDirection.Horizontal
		l.Wraps = true
	end
	l.Parent = parent
	return l
end

function Kit.label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Theme.Font
	l.TextSize = 14
	l.TextColor3 = Theme.Text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	for k, v in pairs(props or {}) do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

function Kit.card(parent: Instance, order: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Theme.Surface
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = order or 0
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Theme.Stroke
	cardStroke.Thickness = 1
	cardStroke.Transparency = 0.6
	cardStroke.Parent = f
	Kit.corner(f, 10)
	Kit.padding(f, 12)
	Kit.list(f, 6)
	f.Parent = parent
	return f
end

-- kind: "primary" | "secondary" | "danger" | "success"
function Kit.button(parent: Instance, text: string, callback: (() -> ())?, kind: string?, enabled: boolean?): TextButton
	local b = Instance.new("TextButton")
	local palette = {
		primary = { Theme.Accent, Theme.AccentText },
		secondary = { Theme.Surface2, Theme.Text },
		danger = { Theme.Red, Theme.Text },
		success = { Theme.Green, Theme.AccentText },
	}
	local colors = palette[kind or "secondary"] or palette.secondary
	local isEnabled = enabled ~= false
	b.AutoButtonColor = false
	b.BackgroundColor3 = colors[1]
	b.BackgroundTransparency = isEnabled and 0 or 0.65
	b.TextColor3 = colors[2]
	b.Font = Theme.FontSemi
	b.TextSize = 14
	b.Text = text
	b.Size = UDim2.new(0, 0, 0, Theme.touchTarget())
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Active = isEnabled
	Kit.corner(b, 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	pad.Parent = b
	if isEnabled then
		b.MouseEnter:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.1), { BackgroundTransparency = 0.12 }):Play()
		end)
		b.MouseLeave:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.1), { BackgroundTransparency = 0 }):Play()
		end)
		if callback then
			b.MouseButton1Click:Connect(callback)
		end
	end
	b.Parent = parent
	return b
end

function Kit.chip(parent: Instance, text: string, color: Color3): TextLabel
	local c = Kit.label(parent, text, {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(0, 0, 0, 22),
		BackgroundTransparency = 0.8,
		BackgroundColor3 = color,
		TextColor3 = color,
		Font = Theme.FontSemi,
		TextSize = 12,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Kit.corner(c, 11)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = c
	return c
end

function Kit.bar(parent: Instance, fraction: number, color: Color3?): Frame
	local track = Instance.new("Frame")
	track.BackgroundColor3 = Theme.Surface2
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, 8)
	Kit.corner(track, 4)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = color or Theme.Accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	Kit.corner(fill, 4)
	fill.Parent = track
	track.Parent = parent
	return track
end

-- Painel modal centralizado, responsivo (92% x 82% da tela, limitado a 620x560).
export type PanelObject = {
	Overlay: Frame,
	Body: ScrollingFrame,
	Open: () -> (),
	Close: () -> (),
	IsOpen: () -> boolean,
	Clear: () -> (),
	OnClose: (() -> ())?,
}

function Kit.panel(parent: Instance, titleText: string): PanelObject
	local overlay = Instance.new("Frame") -- Não escurece nem captura cliques no gameplay.
	overlay.BackgroundTransparency = 1
	overlay.Active = false
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.ZIndex = 10
	overlay.Parent = parent

	local win = Instance.new("Frame")
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Position = UDim2.fromScale(0.5, 0.5)
	win.Size = UDim2.fromScale(0.92, 0.82)
	win.BackgroundColor3 = Theme.Bg
	win.BorderSizePixel = 0
	win.ZIndex = 11
	Kit.corner(win, 14)
	local winStroke = Instance.new("UIStroke")
	winStroke.Color = Theme.Stroke
	winStroke.Thickness = 1.5
	winStroke.Transparency = 0.25
	winStroke.Parent = win
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(620, 560)
	limit.MinSize = Vector2.new(280, 260)
	limit.Parent = win
	win.Parent = overlay

	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 56)
	header.ZIndex = 12
	header.Parent = win
	local title = Kit.label(header, titleText, {
		Font = Theme.FontTitle,
		TextSize = 30,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -70, 1, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 12,
	})
	local _ = title

	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(0, 56)
	body.Size = UDim2.new(1, 0, 1, -56)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 5
	body.ZIndex = 12
	Kit.padding(body, 12)
	Kit.list(body, 8)
	body.Parent = win

	local object: PanelObject
	local function close()
		overlay.Visible = false
		if object.OnClose then
			object.OnClose()
		end
	end
	local closeButton = Kit.button(header, "X", close, "secondary")
	closeButton.Name = "CloseButton"
	closeButton.AutomaticSize = Enum.AutomaticSize.None
	closeButton.Size = UDim2.fromOffset(Theme.touchTarget(), Theme.touchTarget())
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, -12, 0.5, 0)
	closeButton.ZIndex = 13

	object = {
		Overlay = overlay,
		Body = body,
		Open = function()
			overlay.Visible = true
		end,
		Close = close,
		IsOpen = function()
			return overlay.Visible
		end,
		Clear = function()
			for _, child in ipairs(body:GetChildren()) do
				if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
					child:Destroy()
				end
			end
		end,
		OnClose = nil,
	}
	-- Cliques dentro da janela não fecham o painel.
	local sink = Instance.new("TextButton")
	sink.Text, sink.BackgroundTransparency = "", 1
	sink.Size = UDim2.fromScale(1, 1)
	sink.ZIndex = 11
	sink.AutoButtonColor = false
	sink.Parent = win
	return object
end

function Kit.t(key: string, ...: any): string
	return Locale.t(key, ...)
end

return Kit
