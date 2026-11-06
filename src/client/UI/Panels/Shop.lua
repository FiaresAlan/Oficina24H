--!strict
-- Loja de Peças: catálogo real (peças e equipamentos), carrinho local e compra pelo servidor (ação "Checkout").
-- O carrinho só guarda a intenção; preço, saldo, limites e posse são revalidados no servidor, e o carrinho só é
-- limpo quando o servidor confirma a compra. Ferramentas e Acessórios ainda não existem no catálogo (estado vazio).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Theme = require(script.Parent.Parent.Theme)
local Kit = require(script.Parent.Parent.Kit)
local Store = require(script.Parent.Parent.Store)
local HudParts = require(script.Parent.Parent.HudParts)
local PanelKit = require(script.Parent.Parent.PanelKit)

local t = Kit.t
local Shop = {}

local CATEGORY_ICON: { [string]: string } = {
	Engine = "pn_c_motor", Suspension = "pn_c_susp", Electrical = "pn_c_elec", Tires = "pn_c_tire", Bodywork = "pn_c_body", Misc = "pn_c_misc",
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

type Product = { Kind: string, Id: string, Name: string, Cost: number, Category: string }

local function products(kind: string): { Product }
	local list: { Product } = {}
	if kind == "parts" then
		for id, part in pairs(Catalog.Parts) do
			table.insert(list, { Kind = "Part", Id = id, Name = part.DisplayName, Cost = part.Cost, Category = Catalog.PartCategory[id] or "Misc" })
		end
	elseif kind == "equipment" then
		for id, item in pairs(Catalog.Equipment) do
			table.insert(list, { Kind = "Equipment", Id = id, Name = item.DisplayName, Cost = item.Cost, Category = Catalog.EquipmentCategory[id] or "Misc" })
		end
	end
	local order: { [string]: number } = {}
	for index, category in ipairs(Catalog.CategoryOrder) do
		order[category] = index
	end
	table.sort(list, function(a, b)
		if order[a.Category] ~= order[b.Category] then
			return (order[a.Category] or 99) < (order[b.Category] or 99)
		end
		return a.Cost < b.Cost
	end)
	return list
end

function Shop.new(parent: Instance)
	local window = PanelKit.window(parent, {
		Name = "ShopPanel", Title = t("sh_title"), Subtitle = t("sh_sub"), Icon = "pn_h_cart", Width = 740, Height = 680,
	})
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = window.Content
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 16), UDim.new(0, 16)
	pad.Parent = body

	local cart: { [string]: number } = {} -- "Part:Id" / "Equipment:Id" -> quantidade
	local categoryFilter = "all"
	local cartOpen = false
	local refresh: () -> ()

	local tabs = PanelKit.tabs(body, {
		{ Id = "parts", Label = t("sh_tab_parts"), Icon = "pn_t_gear" },
		{ Id = "equipment", Label = t("sh_tab_equipment"), Icon = "pn_t_wrench" },
	}, function()
		categoryFilter = "all"
		refresh()
	end)

	local main = Instance.new("Frame")
	main.Name = "Main"
	main.BackgroundTransparency = 1
	main.Position = UDim2.fromOffset(0, 70)
	main.Size = UDim2.new(1, 0, 1, -70 - 78)
	main.Parent = body

	local sidebar = PanelKit.card(main, "Sidebar")
	sidebar.Size = UDim2.new(0, 190, 1, 0)
	local sideScroll = PanelKit.scroll(sidebar, "Categories")
	sideScroll.Size = UDim2.new(1, -8, 1, -8)
	sideScroll.Position = UDim2.fromOffset(4, 4)

	local compactDrop, setCompactLabel, rebuildCompact = PanelKit.dropdown(main, { { Id = "all", Label = t("sh_all") } }, function(id: string)
		categoryFilter = id
		refresh()
	end)
	compactDrop.Size = UDim2.new(1, 0, 0, 52)
	compactDrop.Visible = false
	compactDrop.ZIndex = 8
	local gridHolder = PanelKit.card(main, "GridHolder")
	local gridScroll = Instance.new("ScrollingFrame")
	gridScroll.Name = "Grid"
	gridScroll.BackgroundTransparency = 1
	gridScroll.BorderSizePixel = 0
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

	-- barra do carrinho
	local bar = PanelKit.card(body, "CartBar")
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	bar.Size = UDim2.new(1, 0, 0, 70)
	local barRow = Instance.new("Frame")
	barRow.BackgroundTransparency = 1
	barRow.Size = UDim2.fromScale(1, 1)
	barRow.Parent = bar
	local cartButton = Instance.new("TextButton")
	cartButton.Name = "CartToggle"
	cartButton.AutoButtonColor = false
	cartButton.Text = ""
	cartButton.BackgroundTransparency = 1
	cartButton.Size = UDim2.new(0.5, 0, 1, 0)
	cartButton.Parent = barRow
	local cartIcon = HudParts.sprite(cartButton, "pn_c_cart", Vector2.new(40, 40))
	cartIcon.AnchorPoint = Vector2.new(0, 0.5)
	cartIcon.Position = UDim2.new(0, 14, 0.5, 0)
	local cartLabel = HudParts.text(cartButton, "", 27, { Font = Theme.FontTitle, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 64, 0.5, -12) })
	local totalLabel = HudParts.text(cartButton, "", 23, { Font = Theme.FontSemi, TextColor3 = rgb(255, 200, 70), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 64, 0.5, 14) })
	local checkout, setCheckoutEnabled = PanelKit.button(barRow, t("sh_checkout"), "green", Vector2.new(250, 52), function()
		local items = {}
		for key, quantity in pairs(cart) do
			local kind, id = string.match(key, "^(%a+):(.+)$")
			if kind and id then
				table.insert(items, { Kind = kind, Id = id, Quantity = quantity })
			end
		end
		if #items > 0 then
			Store.Act("Checkout", { Items = items })
		end
	end, "pn_c_cart")
	checkout.AnchorPoint = Vector2.new(1, 0.5)
	checkout.Position = UDim2.new(1, -10, 0.5, 0)

	-- lista do carrinho (acima da barra)
	local cartPopup = PanelKit.card(body, "CartPopup")
	cartPopup.AnchorPoint = Vector2.new(0, 1)
	cartPopup.Position = UDim2.new(0, 0, 1, -78)
	cartPopup.Size = UDim2.new(1, 0, 0, 250)
	cartPopup.Visible = false
	cartPopup.ZIndex = 20
	cartPopup.BackgroundTransparency = 0 -- opaco: a lista não deixa a grade aparecer por baixo
	local cartScroll = PanelKit.scroll(cartPopup, "Lines")
	cartScroll.Size = UDim2.new(1, -16, 1, -16)
	cartScroll.Position = UDim2.fromOffset(8, 8)
	cartScroll.ZIndex = 21

	local function productKey(p: Product): string
		return p.Kind .. ":" .. p.Id
	end
	local function lookup(key: string): Product?
		local kind, id = string.match(key, "^(%a+):(.+)$")
		if kind == "Part" and Catalog.Parts[id] then
			return { Kind = "Part", Id = id, Name = Catalog.Parts[id].DisplayName, Cost = Catalog.Parts[id].Cost, Category = Catalog.PartCategory[id] or "Misc" }
		elseif kind == "Equipment" and Catalog.Equipment[id] then
			return { Kind = "Equipment", Id = id, Name = Catalog.Equipment[id].DisplayName, Cost = Catalog.Equipment[id].Cost, Category = Catalog.EquipmentCategory[id] or "Misc" }
		end
		return nil
	end
	local function cartTotals(): (number, number)
		local total, count = 0, 0
		for key, quantity in pairs(cart) do
			local p = lookup(key)
			if p then
				total += p.Cost * quantity
				count += quantity
			end
		end
		return total, count
	end

	local function addToCart(p: Product)
		local key = productKey(p)
		local current = cart[key] or 0
		if p.Kind == "Part" then
			cart[key] = math.min(Catalog.MaxPartPurchase, current + 1)
		else
			cart[key] = 1
		end
		refresh()
	end

	local function renderCart(snapshot: any)
		for _, c in ipairs(cartScroll:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local keys = {}
		for key in pairs(cart) do
			table.insert(keys, key)
		end
		table.sort(keys)
		if #keys == 0 then
			local empty = PanelKit.emptyState(cartScroll, "pn_c_cart", t("sh_cart_empty"), t("sh_cart_hint"))
			empty.Size = UDim2.new(1, 0, 0, 200)
			return
		end
		for index, key in ipairs(keys) do
			local p = lookup(key)
			if p then
				local line = Instance.new("Frame")
				line.Name = "Line"
				line.BackgroundTransparency = 1
				line.Size = UDim2.new(1, -8, 0, 46)
				line.LayoutOrder = index
				line.ZIndex = 22
				line.Parent = cartScroll
				HudParts.text(line, p.Name, 25, { Font = Theme.FontTitle, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -260, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 22 })
				local controls = Instance.new("Frame")
				controls.BackgroundTransparency = 1
				controls.AnchorPoint = Vector2.new(1, 0.5)
				controls.Position = UDim2.new(1, 0, 0.5, 0)
				controls.Size = UDim2.fromOffset(250, 40)
				controls.ZIndex = 22
				controls.Parent = line
				local controlsLayout = Instance.new("UIListLayout")
				controlsLayout.FillDirection = Enum.FillDirection.Horizontal
				controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
				controlsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
				controlsLayout.Padding = UDim.new(0, 6)
				controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
				controlsLayout.Parent = controls
				local minus = PanelKit.button(controls, "-", "dark", Vector2.new(40, 40), function()
					local q = (cart[key] or 0) - 1
					cart[key] = q > 0 and q or nil
					refresh()
				end)
				minus.LayoutOrder = 1
				local qty = HudParts.text(controls, string.format("%d", cart[key] or 0), 26, { Font = Theme.FontTitle, LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromOffset(40, 40), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 22 })
				local _ = qty
				local plus = PanelKit.button(controls, "+", "dark", Vector2.new(40, 40), function()
					if p.Kind == "Part" then
						cart[key] = math.min(Catalog.MaxPartPurchase, (cart[key] or 0) + 1)
						refresh()
					end
				end)
				plus.LayoutOrder = 3
				HudParts.text(controls, tostring(p.Cost * (cart[key] or 0)), 25, { Font = Theme.FontTitle, TextColor3 = rgb(255, 200, 70), LayoutOrder = 4, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromOffset(70, 40), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 22 })
			end
		end
		local clear = PanelKit.button(cartScroll, t("sh_clear"), "dark", Vector2.new(160, 44), function()
			cart = {}
			refresh()
		end)
		clear.LayoutOrder = 999
		local _ = snapshot
	end

	local function renderSidebar(kind: string)
		for _, c in ipairs(sideScroll:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local present: { [string]: boolean } = {}
		for _, p in ipairs(products(kind)) do
			present[p.Category] = true
		end
		local entries = { { Id = "all", Label = t("sh_all"), Icon = "pn_c_misc" } }
		for _, category in ipairs(Catalog.CategoryOrder) do
			if present[category] then
				table.insert(entries, { Id = category, Label = t("cat_" .. category), Icon = CATEGORY_ICON[category] })
			end
		end
		for index, entry in ipairs(entries) do
			local selected = categoryFilter == entry.Id
			local button = Instance.new("TextButton")
			button.Name = "Cat_" .. entry.Id
			button.AutoButtonColor = false
			button.Text = ""
			button.BackgroundColor3 = Color3.new(1, 1, 1)
			button.BackgroundTransparency = selected and 0 or 1
			button.Size = UDim2.new(1, -4, 0, 56)
			button.LayoutOrder = index
			Kit.corner(button, 12)
			HudParts.gradient(button, selected and { { 0, rgb(40, 150, 255) }, { 1, rgb(0, 90, 200) } } or { { 0, rgb(30, 46, 74) }, { 1, rgb(18, 30, 52) } })
			local icon = HudParts.sprite(button, entry.Icon, Vector2.new(30, 30))
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 12, 0.5, 0)
			HudParts.text(button, entry.Label, 23, { Font = Theme.FontTitle, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -56, 1, 0), Position = UDim2.fromOffset(50, 0), TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Center })
			button.Activated:Connect(function()
				categoryFilter = entry.Id
				refresh()
			end)
			button.Parent = sideScroll
		end
	end

	refresh = function()
		local snapshot = Store.Snapshot
		local kind = tabs.Current()
		local compact = window.IsCompact()
		-- layout responsivo: em tela estreita a barra lateral some e as categorias viram uma lista
		sidebar.Visible = not compact
		compactDrop.Visible = compact
		gridHolder.Position = compact and UDim2.fromOffset(0, 62) or UDim2.fromOffset(200, 0)
		gridHolder.Size = compact and UDim2.new(1, 0, 1, -62) or UDim2.new(1, -200, 1, 0)
		gridScroll.Size = UDim2.new(1, -12, 1, -12)
		gridScroll.Position = UDim2.fromOffset(6, 6)
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
		if not snapshot then
			return
		end
		renderSidebar(kind)
		local list = products(kind)
		local shown = 0
		for _, p in ipairs(list) do
			if categoryFilter == "all" or p.Category == categoryFilter then
				shown += 1
				local owned = p.Kind == "Equipment" and (snapshot.Profile.Equipment or {})[p.Id] == true
				local card = PanelKit.card(gridScroll, "Product_" .. p.Id)
				card.LayoutOrder = shown
				local inCart = cart[productKey(p)] or 0
				local stroke = card:FindFirstChildOfClass("UIStroke")
				if stroke and inCart > 0 then
					stroke.Color = rgb(70, 225, 105)
					stroke.Thickness = 3
				end
				local thumb = HudParts.itemThumb(card, 128, 96, p.Kind, p.Id)
				thumb.Position = UDim2.fromOffset(10, 10)
				HudParts.text(card, p.Name, 22, {
					Font = Theme.FontTitle, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -16, 0, 50), Position = UDim2.fromOffset(8, 108),
					TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd,
				})
				local priceRow = Instance.new("Frame")
				priceRow.BackgroundTransparency = 1
				priceRow.Size = UDim2.new(1, 0, 0, 30)
				priceRow.Position = UDim2.fromOffset(0, 162)
				priceRow.Parent = card
				local priceLayout = Instance.new("UIListLayout")
				priceLayout.FillDirection = Enum.FillDirection.Horizontal
				priceLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				priceLayout.VerticalAlignment = Enum.VerticalAlignment.Center
				priceLayout.Padding = UDim.new(0, 6)
				priceLayout.Parent = priceRow
				if owned then
					PanelKit.chip(priceRow, t("sh_installed"), rgb(70, 225, 105))
				else
					local coin = HudParts.sprite(priceRow, "dollar", Vector2.new(26, 28))
					coin.LayoutOrder = 1
					local affordable = snapshot.Profile.Coins >= p.Cost
					HudParts.text(priceRow, tostring(p.Cost), 27, { Font = Theme.FontTitle, LayoutOrder = 2, TextColor3 = affordable and Theme.Text or rgb(255, 120, 110) })
				end
				if inCart > 0 then
					local badge = HudParts.text(card, "x" .. inCart, 22, {
						Font = Theme.FontTitle, TextColor3 = rgb(10, 40, 16), BackgroundTransparency = 0, BackgroundColor3 = rgb(70, 225, 105),
						AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5,
					})
					Kit.corner(badge, 10)
					local badgePad = Instance.new("UIPadding")
					badgePad.PaddingLeft, badgePad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
					badgePad.Parent = badge
				end
				if owned then
					for _, d in ipairs(thumb:GetDescendants()) do
						if d:IsA("ViewportFrame") or d:IsA("ImageLabel") then
							d.ImageTransparency = 0.55
						end
					end
				else
					local hit = Instance.new("TextButton")
					hit.Name = "Hit"
					hit.BackgroundTransparency = 1
					hit.Text = ""
					hit.Size = UDim2.fromScale(1, 1)
					hit.ZIndex = 6
					hit.Parent = card
					hit.Activated:Connect(function()
						addToCart(p)
					end)
				end
			end
		end
		if shown == 0 then
			local empty = PanelKit.emptyState(gridHolder, "pn_empty_box", t("sh_none"), t("sh_none_sub"))
			empty.Position = UDim2.fromOffset(0, 0)
		end
		if compact then
			local present: { [string]: boolean } = {}
			for _, p in ipairs(list) do
				present[p.Category] = true
			end
			local options = { { Id = "all", Label = t("sh_all") } }
			for _, category in ipairs(Catalog.CategoryOrder) do
				if present[category] then
					table.insert(options, { Id = category, Label = t("cat_" .. category) })
				end
			end
			rebuildCompact(options)
			setCompactLabel(categoryFilter)
		end

		local total, count = cartTotals()
		cartLabel.Text = t("sh_cart", count)
		totalLabel.Text = count > 0 and (t("sh_total") .. ": " .. total) or ""
		local ok = count > 0 and snapshot.Profile.Coins >= total
		setCheckoutEnabled(ok)
		cartPopup.Visible = cartOpen
		if cartOpen then
			renderCart(snapshot)
		end
	end

	cartButton.Activated:Connect(function()
		cartOpen = not cartOpen
		refresh()
	end)

	-- O carrinho só esvazia quando o servidor confirma a compra.
	Store.Message.Event:Connect(function(_: string, success: boolean, action: string)
		if action == "Checkout" and success then
			cart = {}
			cartOpen = false
			if window.IsOpen() then
				refresh()
			end
		end
	end)
	-- Só atualiza quando algo que o painel mostra mudou (evita reconstruir a cada snapshot e perder cliques).
	local lastKey = ""
	Store.Changed.Event:Connect(function(snapshot: any)
		if window.IsOpen() then
			local key = game:GetService("HttpService"):JSONEncode(snapshot.Profile.Coins, snapshot.Profile.Parts, snapshot.Profile.Equipment)
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
			refresh()
		end
	end
	return window
end

return Shop
