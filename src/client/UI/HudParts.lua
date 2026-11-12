--!strict
-- Componentes VISUAIS do HUD, em "unidades de referência" (a imagem de referência tem 1672x941; o HUD inteiro é
-- escalado por um UIScale). Sem regra de jogo aqui: a ligação com os dados fica em HUD.lua.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local HudAssets = require(ReplicatedStorage.Shared.HudAssets)
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Motion)

local HudParts = {}

local function color(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

function HudParts.stroke(parent: Instance, c: Color3?, transparency: number?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = c or Theme.Stroke
	s.Transparency = transparency or 0
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function HudParts.gradient(parent: Instance, points: { { number | Color3 } }, rotation: number?): UIGradient
	local keypoints = {}
	for _, p in ipairs(points) do
		table.insert(keypoints, ColorSequenceKeypoint.new(p[1] :: number, p[2] :: Color3))
	end
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(keypoints)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

-- Fundo padrão dos painéis: azul-marinho escuro com leve degradê, borda azulada com brilho.
function HudParts.panel(parent: Instance, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = Theme.PanelTransparency
	f.BorderSizePixel = 0
	Kit.corner(f, 16)
	HudParts.gradient(f, { { 0, color(28, 40, 46) }, { 1, color(15, 24, 28) } })
	HudParts.stroke(f, Theme.Stroke, 0.05, 2)
	f.Parent = parent
	return f
end

-- Faixa de título azul (Painel de ordem, Perfil da oficina).
function HudParts.header(parent: Instance, height: number): Frame
	local h = Instance.new("Frame")
	h.Name = "Header"
	h.Size = UDim2.new(1, 0, 0, height)
	h.BackgroundColor3 = Color3.new(1, 1, 1)
	h.BorderSizePixel = 0
	HudParts.gradient(h, { { 0, color(52, 72, 78) }, { 1, color(28, 43, 49) } })
	Kit.corner(h, 14)
	h.Parent = parent
	return h
end

function HudParts.sprite(parent: Instance, name: string, size: Vector2): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = "Sprite_" .. name
	i.BackgroundTransparency = 1
	i.Image = HudAssets.get(name)
	i.ScaleType = Enum.ScaleType.Fit
	i.Size = UDim2.fromOffset(size.X, size.Y)
	i.Parent = parent
	return i
end

function HudParts.text(parent: Instance, text: string, size: number, props: { [string]: any }?): TextLabel
	local merged: { [string]: any } = {
		TextSize = size,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		TextWrapped = false,
		Font = Theme.FontBold,
		TextColor3 = Theme.Text,
	}
	for k, v in pairs(props or {}) do
		merged[k] = v
	end
	local label = Kit.label(parent, text, merged)
	if merged.Font == Theme.FontTitle then
		label.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.SemiBold) -- condensada e pesada, como na referência
	end
	return label
end

-- Selo vermelho com brilho (contador de pendências).
function HudParts.badge(parent: Instance, size: number): (Frame, (number) -> ())
	local b = Instance.new("Frame")
	b.Name = "Badge"
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = color(250, 7, 5)
	b.Visible = false
	b.ZIndex = 6
	Kit.corner(b, size / 2)
	HudParts.stroke(b, color(255, 214, 214), 0.15, 2)
	local label = HudParts.text(b, "0", math.floor(size * 0.6), {
		Font = Theme.FontTitle, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 7,
	})
	local pop = Instance.new("UIScale")
	pop.Parent = b
	local last = 0
	b.Parent = parent
	return b, function(count: number)
		b.Visible = count > 0
		label.Text = count > 9 and "9+" or tostring(count)
		if count > last then
			pop.Scale = 1.35
			Motion.scale(pop, 1, Motion.Pop)
		end
		last = count
	end
end

-- Barra de progresso com trilho escuro. Retorna (trilho, definir(fração, cor?)).
function HudParts.progress(parent: Instance, height: number, fillColors: { { number | Color3 } }?): (Frame, (number, Color3?) -> ())
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = color(10, 20, 38)
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, height)
	Kit.corner(track, height / 2)
	HudParts.stroke(track, color(60, 96, 140), 0.45, 1.5)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	Kit.corner(fill, height / 2)
	local gradient = HudParts.gradient(fill, fillColors or { { 0, color(255, 226, 60) }, { 0.5, color(255, 190, 5) }, { 1, color(252, 160, 4) } })
	fill.Parent = track
	track.Parent = parent
	return track, function(fraction: number, tint: Color3?)
		Motion.play(fill, Motion.Fill, { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) })
		if tint then
			fill.BackgroundColor3 = tint
			gradient.Enabled = false
		else
			gradient.Enabled = true
		end
	end
end

-- Pílula laranja (ex.: "1 aguardando").
function HudParts.pill(parent: Instance, text: string, textSize: number): TextLabel
	local p = HudParts.text(parent, text, textSize, {
		Font = Theme.FontTitle, TextColor3 = color(36, 20, 2), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	HudParts.gradient(p, { { 0, color(255, 190, 40) }, { 0.5, color(252, 159, 0) }, { 1, color(249, 140, 0) } })
	Kit.corner(p, 12)
	HudParts.stroke(p, color(255, 220, 120), 0.3, 1.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = p
	return p
end

-- Anel de seleção do gamepad (SelectionImageObject).
local function selectionRing(): Frame
	local ring = Instance.new("Frame")
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromScale(1, 1)
	Kit.corner(ring, 16)
	HudParts.stroke(ring, Color3.new(1, 1, 1), 0, 3)
	return ring
end

export type NavButton = {
	Root: TextButton,
	SetSelected: (boolean) -> (),
	SetBadge: (number) -> (),
	SetEnabled: (boolean) -> (),
	SetCompact: (boolean, number?) -> (),
}

export type NavSpec = {
	Name: string,
	Label: string,
	Icon: string,
	IconSelected: string?,
	Layout: string, -- "side" (ícone + texto na horizontal, fundo laranja ao selecionar) | "bottom" (ícone sobre o texto, azul)
	Width: number,
	Height: number,
}

-- Botão de menu com 5 estados (normal, hover, pressionado, selecionado, indisponível) e animações.
function HudParts.navButton(spec: NavSpec, onClick: () -> ()): NavButton
	local side = spec.Layout == "side"
	local b = Instance.new("TextButton")
	b.Name = "Nav_" .. spec.Name
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(spec.Width, spec.Height)
	b.SelectionImageObject = selectionRing()

	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = b

	local radius = side and 18 or 20
	-- fundo normal
	local normal = Instance.new("Frame")
	normal.Name = "Normal"
	normal.Size = UDim2.fromScale(1, 1)
	normal.BackgroundColor3 = Color3.new(1, 1, 1)
	normal.BorderSizePixel = 0
	Kit.corner(normal, radius)
	HudParts.gradient(normal, { { 0, color(32, 45, 51) }, { 1, color(16, 26, 31) } })
	local normalStroke = HudParts.stroke(normal, color(58, 88, 130), 0, 2)
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.AnchorPoint = Vector2.new(0.5, 1)
	lip.Position = UDim2.new(0.5, 0, 1, -3)
	lip.Size = UDim2.new(1, -radius, 0, 4)
	lip.BackgroundColor3 = Theme.Lip
	lip.BorderSizePixel = 0
	Kit.corner(lip, 2)
	lip.Parent = normal
	normal.Parent = b

	-- fundo selecionado (aparece por transparência)
	local selected = Instance.new("Frame")
	selected.Name = "Selected"
	selected.Size = UDim2.fromScale(1, 1)
	selected.BackgroundColor3 = Color3.new(1, 1, 1)
	selected.BackgroundTransparency = 1
	selected.BorderSizePixel = 0
	Kit.corner(selected, radius)
	if side then
		HudParts.gradient(selected, { { 0, color(91, 77, 51) }, { 1, color(48, 50, 45) } })
	else
		HudParts.gradient(selected, { { 0, color(65, 80, 78) }, { 1, color(31, 48, 54) } })
	end
	local selectedStroke = HudParts.stroke(selected, side and Theme.OrangeEdge or color(70, 190, 255), 1, 3)
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.new(1, -8, 1, -8)
	inner.BackgroundTransparency = 1
	Kit.corner(inner, radius - 4)
	local innerStroke = HudParts.stroke(inner, side and color(255, 217, 18) or color(210, 245, 255), 1, 2)
	inner.Parent = selected
	local glow = HudParts.stroke(selected, side and Theme.Orange or color(8, 130, 220), 1, 9)
	selected.Parent = b

	-- conteúdo
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.ZIndex = 3
	content.Parent = b
	local iconSize = side and 54 or 56
	local icon = HudParts.sprite(content, spec.Icon, Vector2.new(iconSize, iconSize))
	icon.ZIndex = 3
	local label = HudParts.text(content, spec.Label, side and 36 or 26, {
		Font = Theme.FontTitle, AutomaticSize = Enum.AutomaticSize.None, ZIndex = 3,
		TextXAlignment = side and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local shortNames: { [string]: string } = {
		B_Ordens = "OS", B_Habilidades = "Hab.", B_Loja = "Loja",
		B_Estoque = "Peças", B_Ranking = "Rank", B_Perfil = "Perfil",
	}
	local function placeContent(compact: boolean)
		-- No celular, ícone sem legenda gera ambiguidade: mantém rótulo curto no dock.
		label.Visible = not compact or not side
		if side then
			icon.Size = UDim2.fromOffset(iconSize, iconSize)
			icon.AnchorPoint = Vector2.new(compact and 0.5 or 0, 0.5)
			icon.Position = compact and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 22, 0.5, 0)
			label.Position = UDim2.new(0, 22 + iconSize + 18, 0, 0)
			label.Size = UDim2.new(1, -(22 + iconSize + 24), 1, 0)
		else
			icon.Size = UDim2.fromOffset(compact and 34 or iconSize, compact and 34 or iconSize)
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, compact and 4 or 10)
			label.Text = compact and (shortNames[spec.Name] or spec.Label) or spec.Label
			label.TextSize = compact and 16 or 26
			label.Position = UDim2.new(0, 0, 1, compact and -24 or -34)
			label.Size = UDim2.new(1, 0, 0, compact and 20 or 30)
		end
	end
	placeContent(false)

	local badgeFrame, setBadge = HudParts.badge(b, 38)
	badgeFrame.Position = UDim2.new(1, -6, 0, 6)

	local isSelected, isEnabled, hover, pressed = false, true, false, false
	local stopPulse: (() -> ())? = nil
	local function paint()
		local hi = isSelected and 0 or 1
		Motion.play(selected, Motion.Hover, { BackgroundTransparency = hi })
		Motion.play(selectedStroke, Motion.Hover, { Transparency = hi })
		Motion.play(innerStroke, Motion.Hover, { Transparency = isSelected and 0.15 or 1 })
		normalStroke.Transparency = isSelected and 1 or 0
		lip.Visible = not isSelected
		if isSelected and not stopPulse then
			stopPulse = Motion.loop(glow, "Transparency", 0.55, 0.85)
		elseif not isSelected and stopPulse then
			stopPulse()
			stopPulse = nil
			glow.Transparency = 1
		end
		if spec.IconSelected then
			icon.Image = HudAssets.get(isSelected and spec.IconSelected or spec.Icon)
		end
		local target = 1
		if not isEnabled then
			target = 1
		elseif pressed then
			target = 0.96
		elseif hover then
			target = 1.04
		end
		Motion.scale(pop, target, pressed and Motion.Press or (hover and Motion.Hover or Motion.Release))
		icon.ImageTransparency = isEnabled and 0 or 0.6
		label.TextTransparency = isEnabled and 0 or 0.6
		normal.BackgroundTransparency = isSelected and 1 or (isEnabled and 0 or 0.5)
	end
	b.MouseEnter:Connect(function() hover = true paint() end)
	b.MouseLeave:Connect(function() hover, pressed = false, false paint() end)
	b.MouseButton1Down:Connect(function() pressed = true paint() end)
	b.MouseButton1Up:Connect(function() pressed = false paint() end)
	b.SelectionGained:Connect(function() hover = true paint() end)
	b.SelectionLost:Connect(function() hover = false paint() end)
	b.Activated:Connect(function()
		if isEnabled then
			onClick()
		end
	end)
	paint()

	return {
		Root = b,
		SetSelected = function(value: boolean) isSelected = value paint() end,
		SetBadge = setBadge,
		SetEnabled = function(value: boolean) isEnabled = value b.Active = value paint() end,
		SetCompact = function(value: boolean, height: number?)
			local h = height or spec.Height
			placeContent(value)
			b.Size = UDim2.fromOffset(value and h or spec.Width, h)
		end,
	}
end

-- Botão quadrado de ícone (sino, engrenagem, sair).
function HudParts.iconButton(parent: Instance, name: string, sprite: string, size: number, onClick: (() -> ())?): (TextButton, (boolean) -> (), (number) -> ())
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = Theme.PanelTransparency
	b.BorderSizePixel = 0
	b.Size = UDim2.fromOffset(size, size)
	b.SelectionImageObject = selectionRing()
	Kit.corner(b, 16)
	HudParts.gradient(b, { { 0, color(24, 38, 60) }, { 1, color(8, 15, 28) } })
	local stroke = HudParts.stroke(b, color(58, 88, 130), 0, 2)
	local pop = Instance.new("UIScale")
	pop.Parent = b
	local icon = HudParts.sprite(b, sprite, Vector2.new(size * 0.62, size * 0.62))
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	local badge, setBadge = HudParts.badge(b, 30)
	badge.Position = UDim2.new(1, -4, 0, 6)
	b.Parent = parent
	local enabled = true
	b.MouseEnter:Connect(function()
		if enabled then
			Motion.scale(pop, 1.06, Motion.Hover)
			stroke.Color = color(110, 170, 230)
		end
	end)
	b.MouseLeave:Connect(function()
		Motion.scale(pop, 1, Motion.Release)
		stroke.Color = color(58, 88, 130)
	end)
	b.MouseButton1Down:Connect(function()
		if enabled then
			Motion.scale(pop, 0.94, Motion.Press)
		end
	end)
	b.MouseButton1Up:Connect(function()
		Motion.scale(pop, 1.06, Motion.Release)
	end)
	b.Activated:Connect(function()
		if enabled and onClick then
			onClick()
		end
	end)
	return b,
		function(value: boolean)
			enabled = value
			icon.ImageTransparency = value and 0 or 0.65
			b.BackgroundTransparency = value and Theme.PanelTransparency or 0.4
		end,
		setBadge
end

-- Miniatura 3D de veículo: moldura com céu em degradê + ViewportFrame transparente com o modelo real
-- (ReplicatedStorage.VehiclePreviews). Retorna (moldura, definirModelo).
function HudParts.vehicleThumb(parent: Instance, width: number, height: number): (Frame, (string?) -> ())
	local holder = Instance.new("Frame")
	holder.Name = "VehicleThumb"
	holder.Size = UDim2.fromOffset(width, height)
	holder.BackgroundColor3 = Color3.new(1, 1, 1)
	holder.BorderSizePixel = 0
	Kit.corner(holder, 12)
	HudParts.gradient(holder, { { 0, color(120, 185, 245) }, { 0.6, color(70, 130, 215) }, { 1, color(150, 150, 160) } })
	HudParts.stroke(holder, color(230, 240, 255), 0.1, 3)
	holder.Parent = parent
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Viewport"
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.BorderSizePixel = 0
	vp.Ambient = color(190, 195, 215)
	vp.LightColor = color(255, 250, 240)
	vp.LightDirection = Vector3.new(-1, -1.5, -1)
	vp.Parent = holder
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.Parent = vp
	vp.CurrentCamera = camera
	local current: Model? = nil
	local currentName: string? = nil
	return holder, function(modelName: string?)
		if modelName == currentName then
			return
		end
		currentName = modelName
		if current then
			current:Destroy()
			current = nil
		end
		local folder = ReplicatedStorage:FindFirstChild("VehiclePreviews")
		local template = modelName and folder and folder:FindFirstChild(modelName)
		if not template or not template:IsA("Model") then
			return
		end
		local clone = template:Clone()
		clone.Parent = vp
		local cf, size = clone:GetBoundingBox()
		local distance = math.max(size.X, size.Y, size.Z) * 1.85
		local center = cf.Position
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0.75, 0.32, 0.9).Unit * distance, center)
		current = clone
	end
end

-- Miniatura de produto (Loja e Estoque): foto recortada da referência quando a peça é exatamente a mesma do catálogo
-- (Bateria, Vela de ignição); senão um ViewportFrame com o modelo 3D real (PartModels / EquipmentPreviews).
local PHOTO_FOR_PART: { [string]: string } = { Battery = "pn_prod_battery", SparkPlug = "pn_prod_plug" }

function HudParts.itemThumb(parent: Instance, width: number, height: number, kind: string, id: string): Frame
	local holder = Instance.new("Frame")
	holder.Name = "ItemThumb"
	holder.Size = UDim2.fromOffset(width, height)
	holder.BackgroundColor3 = Color3.new(1, 1, 1)
	holder.BorderSizePixel = 0
	Kit.corner(holder, 12)
	HudParts.gradient(holder, { { 0, color(30, 46, 72) }, { 1, color(11, 20, 36) } })
	holder.ClipsDescendants = true
	local photo = kind == "Part" and PHOTO_FOR_PART[id]
	if photo then
		local image = HudParts.sprite(holder, photo, Vector2.new(width, height))
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromScale(1, 1)
		holder.Parent = parent
		return holder
	end
	local template: Instance? = nil
	if kind == "Part" then
		local PartModels = require(ReplicatedStorage.Shared.PartModels)
		template = PartModels.Build(id)
	else
		local folder = ReplicatedStorage:FindFirstChild("EquipmentPreviews")
		local source = folder and folder:FindFirstChild(id)
		template = source and source:Clone()
	end
	if template and template:IsA("Model") then
		local vp = Instance.new("ViewportFrame")
		vp.Name = "Viewport"
		vp.Size = UDim2.fromScale(1, 1)
		vp.BackgroundTransparency = 1
		vp.Ambient = color(170, 178, 200)
		vp.LightColor = color(255, 250, 240)
		vp.LightDirection = Vector3.new(-1, -1.4, -0.8)
		vp.Parent = holder
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.Parent = vp
		vp.CurrentCamera = camera
		template.Parent = vp
		local cf, size = template:GetBoundingBox()
		local distance = math.max(size.X, size.Y, size.Z) * 2.2
		camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0.7, 0.5, 1).Unit * distance, cf.Position)
	elseif template then
		template:Destroy()
	end
	holder.Parent = parent
	return holder
end

HudParts.ReducedMotion = function(): boolean
	return GuiService.ReducedMotionEnabled
end

return HudParts
