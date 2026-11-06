--!strict
-- Habilidades: as 5 especializações com nível e XP do servidor, mais o nível profissional geral.
-- Só exibe: não há botão de evolução manual (o XP vem dos serviços) e os benefícios listados são os que o catálogo suporta.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Theme = require(script.Parent.Parent.Theme)
local Kit = require(script.Parent.Parent.Kit)
local Store = require(script.Parent.Parent.Store)
local HudParts = require(script.Parent.Parent.HudParts)
local PanelKit = require(script.Parent.Parent.PanelKit)

local t = Kit.t
local Skills = {}

local ICON: { [string]: string } = {
	Engine = "pn_s_motor", Suspension = "pn_s_susp", Tires = "pn_s_wheel", Electrical = "pn_s_elec", Bodywork = "pn_s_paint",
}
local ORDER = { "Engine", "Suspension", "Tires", "Electrical", "Bodywork" }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

function Skills.new(parent: Instance)
	local window = PanelKit.window(parent, {
		Name = "SkillsPanel", Title = t("sk_title"), Subtitle = t("sk_sub"), Icon = "pn_h_cap", Width = 780, Height = 560,
	})
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = window.Content
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 16), UDim.new(0, 16)
	pad.Parent = body

	local selected = "Engine"
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 0
	list.CanvasSize = UDim2.new()
	body.Parent = window.Content
	list.Parent = body
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	local detail = Instance.new("ScrollingFrame")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.BorderSizePixel = 0
	detail.ScrollBarThickness = 6
	detail.ScrollBarImageColor3 = rgb(90, 140, 210)
	detail.AutomaticCanvasSize = Enum.AutomaticSize.Y
	detail.CanvasSize = UDim2.new()
	detail.Parent = body
	local detailLayout = Instance.new("UIListLayout")
	detailLayout.Padding = UDim.new(0, 10)
	detailLayout.SortOrder = Enum.SortOrder.LayoutOrder
	detailLayout.Parent = detail

	local function clear(frame: Instance)
		for _, c in ipairs(frame:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end

	local render: () -> ()

	local function renderList(snapshot: any, compact: boolean)
		clear(list)
		listLayout.FillDirection = compact and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
		list.ScrollingDirection = compact and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
		list.AutomaticCanvasSize = compact and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
		for index, spec in ipairs(ORDER) do
			local xp = snapshot.Profile.SkillXP[spec] or 0
			local level = snapshot.SkillLevels[spec] or 1
			local into = xp % Catalog.SkillXPPerLevel
			local active = spec == selected
			local button = Instance.new("TextButton")
			button.Name = "Spec_" .. spec
			button.AutoButtonColor = false
			button.Text = ""
			button.BackgroundColor3 = Color3.new(1, 1, 1)
			button.Size = compact and UDim2.fromOffset(74, 74) or UDim2.new(1, -4, 0, 82)
			button.LayoutOrder = index
			Kit.corner(button, 14)
			HudParts.gradient(button, active and { { 0, rgb(50, 160, 255) }, { 0.5, rgb(0, 112, 228) }, { 1, rgb(0, 72, 170) } } or { { 0, rgb(28, 44, 72) }, { 1, rgb(14, 24, 44) } })
			HudParts.stroke(button, active and rgb(140, 215, 255) or rgb(58, 88, 130), 0.1, 2)
			if active then
				local mark = Instance.new("Frame")
				mark.Size = UDim2.new(0, 6, 1, -16)
				mark.Position = UDim2.fromOffset(-2, 8)
				mark.BackgroundColor3 = rgb(255, 176, 32)
				mark.BorderSizePixel = 0
				Kit.corner(mark, 3)
				mark.Parent = button
			end
			local icon = HudParts.sprite(button, ICON[spec], Vector2.new(compact and 46 or 52, compact and 46 or 52))
			icon.AnchorPoint = compact and Vector2.new(0.5, 0.5) or Vector2.new(0, 0.5)
			icon.Position = compact and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 16, 0.5, 0)
			if not compact then
				HudParts.text(button, t("spec_" .. spec), 29, { Font = Theme.FontTitle, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -86, 0, 32), Position = UDim2.fromOffset(78, 10), TextTruncate = Enum.TextTruncate.AtEnd })
				HudParts.text(button, t("sk_level", level), 22, { Font = Theme.FontSemi, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -86, 0, 24), Position = UDim2.fromOffset(78, 40) })
				local track, setFill = HudParts.progress(button, 9, { { 0, rgb(255, 226, 80) }, { 1, rgb(255, 160, 10) } })
				track.AnchorPoint = Vector2.new(0, 1)
				track.Position = UDim2.new(0, 78, 1, -9)
				track.Size = UDim2.new(1, -96, 0, 9)
				setFill(into / Catalog.SkillXPPerLevel, nil)
			end
			button.Activated:Connect(function()
				selected = spec
				render()
			end)
			button.Parent = list
		end
	end

	local function infoCard(order: number): Frame
		local card = PanelKit.card(detail, "Info")
		card.LayoutOrder = order
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.Size = UDim2.new(1, -10, 0, 0)
		local inner = Instance.new("UIPadding")
		inner.PaddingTop, inner.PaddingBottom, inner.PaddingLeft, inner.PaddingRight = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 14), UDim.new(0, 14)
		inner.Parent = card
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = card
		return card
	end

	local function renderDetail(snapshot: any)
		clear(detail)
		local spec = selected
		local xp = snapshot.Profile.SkillXP[spec] or 0
		local level = snapshot.SkillLevels[spec] or 1
		local into = xp % Catalog.SkillXPPerLevel

		-- cabeçalho: imagem relacionada + nome + descrição
		local head = PanelKit.card(detail, "Head")
		head.LayoutOrder = 1
		head.Size = UDim2.new(1, -10, 0, 150)
		local visual
		if spec == "Engine" then
			visual = HudParts.sprite(head, "pn_photo_engine", Vector2.new(150, 126))
			visual.ScaleType = Enum.ScaleType.Fit
		else
			visual = HudParts.sprite(head, ICON[spec], Vector2.new(112, 112))
			visual.ImageColor3 = rgb(190, 215, 250)
		end
		visual.AnchorPoint = Vector2.new(0, 0.5)
		visual.Position = UDim2.new(0, 14, 0.5, 0)
		local texts = Instance.new("Frame")
		texts.BackgroundTransparency = 1
		texts.Position = UDim2.fromOffset(180, 12)
		texts.Size = UDim2.new(1, -194, 1, -24)
		texts.Parent = head
		local textsLayout = Instance.new("UIListLayout")
		textsLayout.Padding = UDim.new(0, 4)
		textsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		textsLayout.Parent = texts
		HudParts.text(texts, t("spec_" .. spec), 38, { Font = Theme.FontTitle, LayoutOrder = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextTruncate = Enum.TextTruncate.AtEnd })
		HudParts.text(texts, t("sk_desc_" .. spec), 23, { Font = Theme.FontSemi, TextColor3 = rgb(190, 205, 230), LayoutOrder = 2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })

		-- próximo nível e benefícios reais
		local nextCard = infoCard(2)
		local nextHead = Instance.new("Frame")
		nextHead.BackgroundTransparency = 1
		nextHead.Size = UDim2.new(1, 0, 0, 34)
		nextHead.LayoutOrder = 1
		nextHead.Parent = nextCard
		HudParts.text(nextHead, t("sk_next"), 28, { Font = Theme.FontTitle })
		local nextLevel = HudParts.text(nextHead, t("sk_level", level + 1), 28, { Font = Theme.FontTitle, TextColor3 = rgb(70, 170, 255), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0) })
		local _ = nextLevel
		local services = {}
		for _, defect in pairs(Catalog.Defects) do
			if defect.Specialization == spec and defect.RequiredLevel == level + 1 then
				table.insert(services, Catalog.Services[defect.ServiceId] and Catalog.Services[defect.ServiceId].DisplayName or defect.DisplayName)
			end
		end
		table.sort(services)
		local benefits: { string } = {}
		for _, name in ipairs(services) do
			table.insert(benefits, t("sk_benefit_service", name))
		end
		if #services == 0 then
			table.insert(benefits, t("sk_no_services"))
		end
		table.insert(benefits, t("sk_benefit_quality"))
		for index, text in ipairs(benefits) do
			local line = Instance.new("Frame")
			line.BackgroundTransparency = 1
			line.AutomaticSize = Enum.AutomaticSize.Y
			line.Size = UDim2.new(1, 0, 0, 0)
			line.LayoutOrder = index + 1
			local lineLayout = Instance.new("UIListLayout")
			lineLayout.FillDirection = Enum.FillDirection.Horizontal
			lineLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			lineLayout.Padding = UDim.new(0, 10)
			lineLayout.Parent = line
			local check = HudParts.sprite(line, "pn_o_check", Vector2.new(26, 26))
			check.LayoutOrder = 1
			HudParts.text(line, text, 23, { Font = Theme.FontSemi, LayoutOrder = 2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -40, 0, 0) })
			line.Parent = nextCard
		end

		-- experiência da especialização
		local xpCard = infoCard(3)
		local xpHead = Instance.new("Frame")
		xpHead.BackgroundTransparency = 1
		xpHead.Size = UDim2.new(1, 0, 0, 34)
		xpHead.LayoutOrder = 1
		xpHead.Parent = xpCard
		HudParts.text(xpHead, t("sk_xp"), 28, { Font = Theme.FontTitle })
		HudParts.text(xpHead, t("hud_xp", into, Catalog.SkillXPPerLevel), 24, { Font = Theme.FontTitle, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2) })
		local track, setFill = HudParts.progress(xpCard, 18, { { 0, rgb(120, 220, 255) }, { 0.5, rgb(0, 170, 245) }, { 1, rgb(0, 120, 215) } })
		track.LayoutOrder = 2
		setFill(into / Catalog.SkillXPPerLevel, nil)

		-- nível profissional geral
		local general = infoCard(4)
		local businessLevel, total, startOfLevel, nextTotal = Catalog.BusinessProgress(snapshot.Profile.TotalEarned or 0)
		local gHead = Instance.new("Frame")
		gHead.BackgroundTransparency = 1
		gHead.Size = UDim2.new(1, 0, 0, 34)
		gHead.LayoutOrder = 1
		gHead.Parent = general
		HudParts.text(gHead, t("sk_general"), 28, { Font = Theme.FontTitle })
		HudParts.text(gHead, string.format("%02d", businessLevel), 30, { Font = Theme.FontTitle, TextColor3 = rgb(255, 190, 40), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0) })
		local gTrack, gFill = HudParts.progress(general, 16, { { 0, rgb(255, 226, 80) }, { 1, rgb(255, 160, 10) } })
		gTrack.LayoutOrder = 2
		gFill((total - startOfLevel) / math.max(1, nextTotal - startOfLevel), nil)
		HudParts.text(general, t("hud_xp", math.floor(total), math.floor(nextTotal)), 22, { Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 3 })
	end

	render = function()
		local snapshot = Store.Snapshot
		if not snapshot then
			return
		end
		local compact = window.IsCompact()
		if compact then
			list.Position = UDim2.fromOffset(0, 0)
			list.Size = UDim2.new(1, 0, 0, 82)
			detail.Position = UDim2.fromOffset(0, 92)
			detail.Size = UDim2.new(1, 0, 1, -92)
		else
			list.Position = UDim2.fromOffset(0, 0)
			list.Size = UDim2.new(0, 300, 1, 0)
			detail.Position = UDim2.fromOffset(312, 0)
			detail.Size = UDim2.new(1, -312, 1, 0)
		end
		renderList(snapshot, compact)
		renderDetail(snapshot)
	end

	-- Só atualiza quando algo que o painel mostra mudou (evita reconstruir a cada snapshot e perder cliques).
	local lastKey = ""
	Store.Changed.Event:Connect(function(snapshot: any)
		if window.IsOpen() then
			local key = game:GetService("HttpService"):JSONEncode(snapshot.Profile.SkillXP, snapshot.Profile.TotalEarned)
			if key ~= lastKey then
				lastKey = key
				render()
			end
		end
	end)
	window.OnOpen = function()
		lastKey = ""
		render()
	end
	window.OnResize = function()
		if window.IsOpen() then
			render()
		end
	end
	return window
end

return Skills
