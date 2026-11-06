--!strict
-- Estoque: peças e equipamentos que a oficina possui (somente leitura; compras na Loja, consumo no servidor ao reparar).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Theme = require(script.Parent.Parent.Theme)
local Kit = require(script.Parent.Parent.Kit)
local Store = require(script.Parent.Parent.Store)
local HudParts = require(script.Parent.Parent.HudParts)
local PanelKit = require(script.Parent.Parent.PanelKit)

local t = Kit.t
local Stock = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function sortedIds(items: { [string]: any }, categoryOf: { [string]: string }): { string }
	local order: { [string]: number } = {}
	for index, category in ipairs(Catalog.CategoryOrder) do
		order[category] = index
	end
	local ids = {}
	for id in pairs(items) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local ca, cb = order[categoryOf[a]] or 99, order[categoryOf[b]] or 99
		if ca ~= cb then
			return ca < cb
		end
		return items[a].Cost < items[b].Cost
	end)
	return ids
end

function Stock.new(parent: Instance)
	local window = PanelKit.window(parent, {
		Name = "StockPanel", Title = t("st_title"), Subtitle = t("st_sub"), Icon = "pn_h_box", Width = 560, Height = 660,
	})
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = window.Content
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 16), UDim.new(0, 16)
	pad.Parent = body

	local searchText, filterId = "", "all"
	local selectedId: string? = nil
	local refresh: () -> ()

	local tabs = PanelKit.tabs(body, {
		{ Id = "parts", Label = t("st_tab_parts"), Icon = "pn_t_gear" },
		{ Id = "equipment", Label = t("st_tab_equipment"), Icon = "pn_t_wrench" },
	}, function()
		selectedId = nil
		refresh()
	end)

	local tools = Instance.new("Frame")
	tools.Name = "Tools"
	tools.BackgroundTransparency = 1
	tools.Position = UDim2.fromOffset(0, 70)
	tools.Size = UDim2.new(1, 0, 0, 52)
	tools.ZIndex = 5
	tools.Parent = body
	local searchHolder = PanelKit.searchBox(tools, t("st_search"), function(text: string)
		searchText = string.lower(text)
		refresh()
	end)
	searchHolder.Size = UDim2.new(1, -244, 0, 52)
	local filterOptions: { { Id: string, Label: string } } = { { Id = "all", Label = t("st_filter_all") }, { Id = "stock", Label = t("st_filter_stock") } }
	for _, category in ipairs(Catalog.CategoryOrder) do
		table.insert(filterOptions, { Id = category, Label = t("cat_" .. category) })
	end
	local dropdown = PanelKit.dropdown(tools, filterOptions, function(id: string)
		filterId = id
		refresh()
	end)
	dropdown.AnchorPoint = Vector2.new(1, 0)
	dropdown.Position = UDim2.new(1, 0, 0, 0)
	dropdown.Size = UDim2.fromOffset(230, 52)

	local gridHolder = PanelKit.card(body, "GridHolder")
	gridHolder.Position = UDim2.fromOffset(0, 134)
	gridHolder.Size = UDim2.new(1, 0, 1, -134 - 132)
	local gridScroll = Instance.new("ScrollingFrame")
	gridScroll.Name = "Grid"
	gridScroll.BackgroundTransparency = 1
	gridScroll.BorderSizePixel = 0
	gridScroll.Size = UDim2.new(1, -12, 1, -12)
	gridScroll.Position = UDim2.fromOffset(6, 6)
	gridScroll.ScrollBarThickness = 6
	gridScroll.ScrollBarImageColor3 = rgb(90, 140, 210)
	gridScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gridScroll.CanvasSize = UDim2.new()
	gridScroll.Parent = gridHolder
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(148, 196)
	gridLayout.CellPadding = UDim2.fromOffset(10, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.Parent = gridScroll

	local detail = PanelKit.card(body, "Detail")
	detail.AnchorPoint = Vector2.new(0, 1)
	detail.Position = UDim2.fromScale(0, 1)
	detail.Size = UDim2.new(1, 0, 0, 118)
	local detailPad = Instance.new("UIPadding")
	detailPad.PaddingTop, detailPad.PaddingBottom, detailPad.PaddingLeft, detailPad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 14), UDim.new(0, 14)
	detailPad.Parent = detail

	local function usedIn(partId: string): string
		local names = {}
		for _, defect in pairs(Catalog.Defects) do
			if defect.Parts and defect.Parts[partId] then
				table.insert(names, defect.DisplayName)
			end
		end
		table.sort(names)
		return table.concat(names, ", ")
	end
	local function unlocks(equipmentId: string): string
		local names = {}
		for _, defect in pairs(Catalog.Defects) do
			if defect.RequiredEquipment == equipmentId then
				table.insert(names, defect.DisplayName)
			end
		end
		table.sort(names)
		return table.concat(names, ", ")
	end

	local function renderDetail(snapshot: any, kind: string)
		for _, c in ipairs(detail:GetChildren()) do
			if not c:IsA("UIPadding") and not c:IsA("UICorner") and not c:IsA("UIStroke") and not c:IsA("UIGradient") then
				c:Destroy()
			end
		end
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 2)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = detail
		if not selectedId then
			HudParts.text(detail, t("st_select"), 24, { Font = Theme.FontSemi, TextColor3 = Theme.Muted, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
			return
		end
		local id = selectedId
		if kind == "parts" then
			local part = Catalog.Parts[id]
			if not part then
				return
			end
			local qty = (snapshot.Profile.Parts or {})[id] or 0
			HudParts.text(detail, part.DisplayName, 30, { Font = Theme.FontTitle, LayoutOrder = 1 })
			HudParts.text(detail, t("st_detail_category", t("cat_" .. (Catalog.PartCategory[id] or "Misc"))) .. "   ·   " .. (qty > 0 and t("st_qty", qty) or t("st_out")), 22, { Font = Theme.FontSemi, TextColor3 = qty > 0 and rgb(80, 230, 110) or Theme.Muted, LayoutOrder = 2 })
			HudParts.text(detail, t("st_detail_used", usedIn(id)) .. "   ·   " .. t("st_detail_cost", part.Cost), 21, { Font = Theme.FontSemi, TextColor3 = rgb(180, 198, 225), LayoutOrder = 3, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
		else
			local equipment = Catalog.Equipment[id]
			if not equipment then
				return
			end
			HudParts.text(detail, equipment.DisplayName, 30, { Font = Theme.FontTitle, LayoutOrder = 1 })
			HudParts.text(detail, t("st_detail_category", t("cat_" .. (Catalog.EquipmentCategory[id] or "Misc"))) .. "   ·   " .. t("st_installed"), 22, { Font = Theme.FontSemi, TextColor3 = rgb(80, 230, 110), LayoutOrder = 2 })
			HudParts.text(detail, t("st_detail_unlocks", unlocks(id) ~= "" and unlocks(id) or "-"), 21, { Font = Theme.FontSemi, TextColor3 = rgb(180, 198, 225), LayoutOrder = 3, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
		end
	end

	refresh = function()
		local snapshot = Store.Snapshot
		for _, c in ipairs(gridScroll:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for _, c in ipairs(gridHolder:GetChildren()) do
			if c.Name == "EmptyState" then
				c:Destroy()
			end
		end
		local kind = tabs.Current()
		if not snapshot then
			return
		end
		local entries: { { Id: string, Name: string, Category: string, Qty: number } } = {}
		if kind == "parts" then
			for _, id in ipairs(sortedIds(Catalog.Parts, Catalog.PartCategory)) do
				local qty = (snapshot.Profile.Parts or {})[id] or 0
				table.insert(entries, { Id = id, Name = Catalog.Parts[id].DisplayName, Category = Catalog.PartCategory[id] or "Misc", Qty = qty })
			end
		elseif kind == "equipment" then
			for _, id in ipairs(sortedIds(Catalog.Equipment, Catalog.EquipmentCategory)) do
				if (snapshot.Profile.Equipment or {})[id] then
					table.insert(entries, { Id = id, Name = Catalog.Equipment[id].DisplayName, Category = Catalog.EquipmentCategory[id] or "Misc", Qty = 1 })
				end
			end
		end
		local shown = 0
		for _, entry in ipairs(entries) do
			local matchesSearch = searchText == "" or string.find(string.lower(entry.Name), searchText, 1, true) ~= nil
			local matchesFilter = filterId == "all" or (filterId == "stock" and entry.Qty > 0) or entry.Category == filterId
			if matchesSearch and matchesFilter then
				shown += 1
				local card = PanelKit.card(gridScroll, "Item_" .. entry.Id)
				card.LayoutOrder = shown
				local selected = selectedId == entry.Id
				local stroke = card:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = selected and rgb(255, 190, 40) or rgb(50, 78, 120)
					stroke.Thickness = selected and 3 or 2
				end
				local thumb = HudParts.itemThumb(card, 128, 96, kind == "parts" and "Part" or "Equipment", entry.Id)
				thumb.Position = UDim2.fromOffset(10, 10)
				if entry.Qty == 0 and kind == "parts" then
					for _, d in ipairs(thumb:GetDescendants()) do
						if d:IsA("ImageLabel") then
							d.ImageTransparency = 0.6
						elseif d:IsA("ViewportFrame") then
							d.ImageTransparency = 0.6
						end
					end
				end
				local name = HudParts.text(card, entry.Name, 23, {
					Font = Theme.FontTitle, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -16, 0, 54), Position = UDim2.fromOffset(8, 110),
					TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd,
				})
				local _ = name
				local qtyLabel = HudParts.text(card, kind == "equipment" and t("st_installed") or (entry.Qty > 0 and t("st_qty", entry.Qty) or t("st_out")), 22, {
					Font = Theme.FontTitle, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 164),
					TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = entry.Qty > 0 and rgb(80, 230, 110) or Theme.Muted,
				})
				local _2 = qtyLabel
				local hit = Instance.new("TextButton")
				hit.Name = "Hit"
				hit.BackgroundTransparency = 1
				hit.Text = ""
				hit.Size = UDim2.fromScale(1, 1)
				hit.ZIndex = 6
				hit.Parent = card
				hit.Activated:Connect(function()
					selectedId = entry.Id
					refresh()
				end)
			end
		end
		if shown == 0 then
			local empty
			if kind == "consumables" then
				empty = PanelKit.emptyState(gridHolder, "pn_empty_box", t("st_cons_empty"), t("st_cons_empty_sub"))
			else
				empty = PanelKit.emptyState(gridHolder, "pn_empty_box", t("st_empty"), t("st_empty_sub"))
			end
			empty.Position = UDim2.fromOffset(0, 0)
		end
		renderDetail(snapshot, kind)
	end

	-- Só atualiza quando algo que o painel mostra mudou (evita reconstruir a cada snapshot e perder cliques).
	local lastKey = ""
	Store.Changed.Event:Connect(function(snapshot: any)
		if window.IsOpen() then
			local key = game:GetService("HttpService"):JSONEncode(snapshot.Profile.Parts, snapshot.Profile.Equipment)
			if key ~= lastKey then
				lastKey = key
				refresh()
			end
		end
	end)
	window.OnOpen = function()
		lastKey = ""
		refresh()
	end
	window.OnResize = function()
		tabs.SetCompact(window.IsCompact())
		if window.IsOpen() then
			local width = window.Content.AbsoluteSize.X
			refresh()
			local _ = width
		end
	end
	return window
end

return Stock
