--!strict
-- Perfil da Oficina: Visão Geral, Avaliações, Histórico (Conquistas ainda não existem: aba desabilitada).
-- Tudo vem do snapshot do servidor; só o controle de preço envia uma ação (SetPrice, validada no servidor).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local CustomerRules = require(ReplicatedStorage.Shared.CustomerRules)
local V2Credits = require(ReplicatedStorage.Shared.V2Credits)
local Theme = require(script.Parent.Parent.Theme)
local Kit = require(script.Parent.Parent.Kit)
local Store = require(script.Parent.Parent.Store)
local HudParts = require(script.Parent.Parent.HudParts)
local PanelKit = require(script.Parent.Parent.PanelKit)

local t = Kit.t
local Profile = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function ago(at: number): string
	local seconds = math.max(0, os.time() - at)
	if seconds < 60 then
		return t("pf_ago_now")
	elseif seconds < 3600 then
		return t("pf_ago_min", seconds // 60)
	elseif seconds < 86400 then
		return t("pf_ago_hour", seconds // 3600)
	end
	return t("pf_ago_day", seconds // 86400)
end

local function column(parent: Instance, gap: number, order: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.Size = UDim2.new()
	f.LayoutOrder = order or 0
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = f
	f.Parent = parent
	return f
end

local function row(parent: Instance, gap: number, order: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.Size = UDim2.new()
	f.LayoutOrder = order or 0
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap)
	l.FillDirection = Enum.FillDirection.Horizontal
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = f
	f.Parent = parent
	return f
end

local function starRow(parent: Instance, stars: number, size: number, order: number?): Frame
	local r = row(parent, 3, order)
	for i = 1, 5 do
		local s = HudParts.sprite(r, "star_gold", Vector2.new(size, size))
		s.ImageTransparency = i <= stars and 0 or 0.78
		s.LayoutOrder = i
	end
	return r
end

function Profile.new(parent: Instance)
	local window = PanelKit.window(parent, {
		Name = "ProfilePanel", Title = t("pf_title"), Subtitle = t("pf_sub"), Icon = "pn_h_store", Width = 640, Height = 640,
	})
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = window.Content
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 16), UDim.new(0, 16)
	pad.Parent = body

	local tabs: PanelKit.Tabs
	local render: () -> ()
	tabs = PanelKit.tabs(body, {
		{ Id = "overview", Label = t("tab_overview"), Icon = "pn_t_home" },
		{ Id = "reviews", Label = t("tab_reviews"), Icon = "pn_t_star" },
		{ Id = "history", Label = t("tab_history"), Icon = "pn_t_clock" },
        { Id = "credits", Label = "Créditos", Icon = "pn_t_home" },
	}, function()
		render()
	end)
	local pages = Instance.new("Frame")
	pages.Name = "Pages"
	pages.BackgroundTransparency = 1
	pages.Position = UDim2.fromOffset(0, 70)
	pages.Size = UDim2.new(1, 0, 1, -70)
	pages.Parent = body

	local function stat(parent2: Instance, sprite: string, caption: string, order: number): (Frame, Frame)
		local line = row(parent2, 12, order)
		local icon = HudParts.sprite(line, sprite, Vector2.new(44, 44))
		icon.LayoutOrder = 1
		local texts = column(line, 0, 2)
		HudParts.text(texts, caption, 26, { Font = Theme.FontTitle, LayoutOrder = 1 })
		return line, texts
	end

	local function overview(scroll: ScrollingFrame, snapshot: any)
		local p = snapshot.Profile
		local compact = window.IsCompact()
		local level, total, startOfLevel, nextLevel = Catalog.BusinessProgress(p.TotalEarned or 0)
		local ratings = p.RatingCount or 0
		local average = ratings > 0 and CustomerRules.AverageRating(p.RatingSum or 0, ratings) or 0

		local top = Instance.new("Frame")
		top.Name = "Top"
		top.BackgroundTransparency = 1
		top.AutomaticSize = Enum.AutomaticSize.Y
		top.Size = UDim2.new(1, -10, 0, 0)
		top.LayoutOrder = 1
		local topLayout = Instance.new("UIListLayout")
		topLayout.Padding = UDim.new(0, 14)
		topLayout.FillDirection = compact and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
		topLayout.SortOrder = Enum.SortOrder.LayoutOrder
		topLayout.Parent = top
		top.Parent = scroll

		local photo = HudParts.sprite(top, "pn_photo_shop", Vector2.new(compact and 300 or 220, compact and 170 or 230))
		photo.ScaleType = Enum.ScaleType.Crop
		photo.LayoutOrder = 1
		Kit.corner(photo, 14)
		HudParts.stroke(photo, rgb(120, 170, 230), 0.2, 2)

		local stats = column(top, 12, 2)
		stats.AutomaticSize = Enum.AutomaticSize.XY
		local levelLine = row(stats, 12, 1)
		HudParts.sprite(levelLine, "star_level", Vector2.new(60, 60))
		local levelTexts = column(levelLine, 2, 2)
		HudParts.text(levelTexts, t("pf_level"), 26, { Font = Theme.FontTitle })
		local levelRow = row(levelTexts, 10)
		HudParts.text(levelRow, string.format("%02d", level), 48, { Font = Theme.FontTitle, TextColor3 = rgb(255, 190, 40) })
		local xpColumn = column(levelRow, 4)
		local track, setFill = HudParts.progress(xpColumn, 14, { { 0, rgb(120, 220, 255) }, { 0.5, rgb(0, 170, 245) }, { 1, rgb(0, 120, 215) } })
		track.Size = UDim2.fromOffset(compact and 150 or 210, 14)
		setFill((total - startOfLevel) / math.max(1, nextLevel - startOfLevel), nil)
		HudParts.text(xpColumn, t("hud_xp", math.floor(total), math.floor(nextLevel)), 22, { Font = Theme.FontSemi })

		local _, repTexts = stat(stats, "pn_p_star", t("pf_rep"), 2)
		local repRow = row(repTexts, 10, 2)
		HudParts.text(repRow, tostring(p.Reputation), 40, { Font = Theme.FontTitle })
		if ratings > 0 then
			HudParts.text(repRow, string.format("★ %.1f", average), 28, { Font = Theme.FontTitle, TextColor3 = rgb(255, 200, 40) })
			local repTrack, setRep = HudParts.progress(repRow, 14)
			repTrack.Size = UDim2.fromOffset(compact and 80 or 120, 14)
			setRep(average / 5, nil)
		else
			HudParts.text(repRow, t("hud_rep_none"), 22, { Font = Theme.FontSemi, TextColor3 = Theme.Muted })
		end
		local _, servedTexts = stat(stats, "pn_p_people", t("pf_served"), 3)
		HudParts.text(servedTexts, tostring(ratings), 40, { Font = Theme.FontTitle, LayoutOrder = 2 })

		-- Desempenho: barras com as últimas avaliações reais (altura = estrelas / 5)
		local perf = PanelKit.card(scroll, "Performance")
		perf.LayoutOrder = 2
		perf.AutomaticSize = Enum.AutomaticSize.Y
		perf.Size = UDim2.new(1, -10, 0, 0)
		local perfPad = Instance.new("UIPadding")
		perfPad.PaddingTop, perfPad.PaddingBottom, perfPad.PaddingLeft, perfPad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 14), UDim.new(0, 14)
		perfPad.Parent = perf
		local perfLayout = Instance.new("UIListLayout")
		perfLayout.Padding = UDim.new(0, 8)
		perfLayout.SortOrder = Enum.SortOrder.LayoutOrder
		perfLayout.Parent = perf
		local recent = p.RecentRatings or {}
		local head = row(perf, 10, 1)
		HudParts.text(head, t("pf_perf"), 28, { Font = Theme.FontTitle })
		if #recent > 0 then
			HudParts.text(head, t("pf_perf_last", #recent), 21, { Font = Theme.FontSemi, TextColor3 = Theme.Muted })
		end
		if #recent == 0 then
			HudParts.text(perf, t("pf_perf_none"), 24, { Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
		else
			local chart = Instance.new("Frame")
			chart.BackgroundTransparency = 1
			chart.Size = UDim2.new(1, 0, 0, 90)
			chart.LayoutOrder = 2
			local chartLayout = Instance.new("UIListLayout")
			chartLayout.FillDirection = Enum.FillDirection.Horizontal
			chartLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
			chartLayout.Padding = UDim.new(0, 8)
			chartLayout.Parent = chart
			chart.Parent = perf
			for index, entry in ipairs(recent) do
				local bar = Instance.new("Frame")
				bar.Size = UDim2.fromOffset(26, math.max(10, 90 * entry.Stars / 5))
				bar.BackgroundColor3 = Color3.new(1, 1, 1)
				bar.BorderSizePixel = 0
				bar.LayoutOrder = index
				Kit.corner(bar, 5)
				local good = entry.Stars >= 4
				HudParts.gradient(bar, good and { { 0, rgb(120, 255, 90) }, { 1, rgb(20, 170, 40) } } or entry.Stars == 3 and { { 0, rgb(255, 220, 80) }, { 1, rgb(230, 150, 20) } } or { { 0, rgb(255, 130, 110) }, { 1, rgb(200, 40, 40) } })
				bar.Parent = chart
			end
			local note = average >= 4 and t("pf_perf_good") or (average >= 3.2 and t("pf_perf_ok") or t("pf_perf_bad"))
			HudParts.text(perf, note, 24, { Font = Theme.FontTitle, TextColor3 = average >= 4 and rgb(60, 235, 90) or Theme.Text, LayoutOrder = 3 })
		end

		-- Preço da oficina (controle existente, validado no servidor)
		local price = p.PriceMultiplier or 1
		local priceCard = PanelKit.card(scroll, "Price")
		priceCard.LayoutOrder = 3
		priceCard.AutomaticSize = Enum.AutomaticSize.Y
		priceCard.Size = UDim2.new(1, -10, 0, 0)
		local priceInner = Instance.new("UIPadding")
		priceInner.PaddingTop, priceInner.PaddingBottom, priceInner.PaddingLeft, priceInner.PaddingRight = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 14), UDim.new(0, 14)
		priceInner.Parent = priceCard
		local priceLayout = Instance.new("UIListLayout")
		priceLayout.Padding = UDim.new(0, 8)
		priceLayout.SortOrder = Enum.SortOrder.LayoutOrder
		priceLayout.Parent = priceCard
		HudParts.text(priceCard, t("profile_price"), 28, { Font = Theme.FontTitle, LayoutOrder = 1 })
		HudParts.text(priceCard, t("profile_price_info", math.floor(price * 100 + 0.5)), 24, { Font = Theme.FontTitle, TextColor3 = rgb(255, 190, 40), LayoutOrder = 2 })
		HudParts.text(priceCard, t("profile_price_hint"), 21, { Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 3, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
		local buttons = row(priceCard, 10, 4)
		local minus = PanelKit.button(buttons, "-5%", "dark", Vector2.new(110, 48), function()
			Store.Act("SetPrice", { Multiplier = price - CustomerRules.PriceStep })
		end)
		minus.LayoutOrder = 1
		local plus = PanelKit.button(buttons, "+5%", "dark", Vector2.new(110, 48), function()
			Store.Act("SetPrice", { Multiplier = price + CustomerRules.PriceStep })
		end)
		plus.LayoutOrder = 2
	end

	local function reviews(scroll: ScrollingFrame, snapshot: any)
		local recent = snapshot.Profile.RecentRatings or {}
		if #recent == 0 then
			PanelKit.emptyState(scroll, "pn_star_o", t("pf_reviews_empty"), t("pf_reviews_empty_sub")).Size = UDim2.new(1, -10, 0, 280)
			return
		end
		for index = #recent, 1, -1 do
			local entry = recent[index]
			local card = PanelKit.card(scroll, "Review")
			card.LayoutOrder = #recent - index + 1
			card.AutomaticSize = Enum.AutomaticSize.Y
			card.Size = UDim2.new(1, -10, 0, 0)
			local inner = Instance.new("UIPadding")
			inner.PaddingTop, inner.PaddingBottom, inner.PaddingLeft, inner.PaddingRight = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 14), UDim.new(0, 14)
			inner.Parent = card
			local layout = Instance.new("UIListLayout")
			layout.Padding = UDim.new(0, 4)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = card
			local head = row(card, 14, 1)
			starRow(head, entry.Stars, 30, 1)
			HudParts.text(head, ago(entry.At or 0), 22, { Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 2 })
			local commentKey = entry.CommentKey ~= "" and entry.CommentKey or nil
			if commentKey then
				HudParts.text(card, "“" .. t(commentKey) .. "”", 25, { Font = Theme.FontTitle, LayoutOrder = 2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
			end
			local who = entry.Customer ~= "" and (entry.Customer .. " · " .. entry.Service) or entry.Service
			HudParts.text(card, who, 22, { Font = Theme.FontSemi, TextColor3 = rgb(170, 190, 220), LayoutOrder = 3 })
		end
	end

	local function history(scroll: ScrollingFrame, snapshot: any)
		local p = snapshot.Profile
		local orders = p.OrderHistory or {}
		local transactions = p.Transactions or {}
		if #orders == 0 and #transactions == 0 then
			PanelKit.emptyState(scroll, "pn_empty_box", t("pf_history_empty"), t("pf_history_empty_sub")).Size = UDim2.new(1, -10, 0, 280)
			return
		end
		local function section(title: string, order: number): Frame
			local card = PanelKit.card(scroll, "Section")
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
			HudParts.text(card, title, 28, { Font = Theme.FontTitle, LayoutOrder = 0 })
			return card
		end
		if #orders > 0 then
			local card = section(t("pf_history_orders"), 1)
			for index = #orders, math.max(1, #orders - 11), -1 do
				local e = orders[index]
				local line = HudParts.text(card, string.format("%s  ·  %s  ·  +%d  ·  %s", e.Vehicle, e.Service, e.Price, ago(e.At or 0)), 22, {
					Font = Theme.FontSemi, LayoutOrder = #orders - index + 1, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
				})
				local _ = line
			end
		end
		if #transactions > 0 then
			local card = section(t("pf_history_money"), 2)
			for index = #transactions, math.max(1, #transactions - 11), -1 do
				local e = transactions[index]
				HudParts.text(card, string.format("%+d  ·  %s  ·  %s", e.Amount, e.Reason, ago(e.At or 0)), 22, {
					Font = Theme.FontSemi, TextColor3 = e.Amount >= 0 and rgb(70, 225, 105) or rgb(255, 120, 110), LayoutOrder = #transactions - index + 1,
					TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
				})
			end
		end
	end

    -- V2-15: créditos em local acessível, sem link para catálogo privado.
    -- Não declarar que itens pendentes possuem permissão comercial.
    local function credits(scroll: ScrollingFrame)
        local card=PanelKit.card(scroll,"Credits")
        card.LayoutOrder=1
        card.Size=UDim2.new(1,-10,0,0)
        card.AutomaticSize=Enum.AutomaticSize.Y
        local padding=Instance.new("UIPadding")
        padding.PaddingTop=UDim.new(0,14)
        padding.PaddingBottom=UDim.new(0,14)
        padding.PaddingLeft=UDim.new(0,16)
        padding.PaddingRight=UDim.new(0,16)
        padding.Parent=card
        local layout=Instance.new("UIListLayout")
        layout.Padding=UDim.new(0,9)
        layout.SortOrder=Enum.SortOrder.LayoutOrder
        layout.Parent=card
        HudParts.text(card,"CRÉDITOS E FONTES DOS ASSETS",26,{
            Font=Theme.FontTitle,LayoutOrder=1,TextColor3=Theme.Accent,
            AutomaticSize=Enum.AutomaticSize.Y,
            Size=UDim2.new(1,0,0,0),TextWrapped=true,
        })
        HudParts.text(card,
            "Atribuições conforme inventário do projeto. A disponibilidade de um asset público não substitui a checagem de licença.",
            18,{Font=Theme.FontSemi,TextColor3=Theme.Muted,
                LayoutOrder=2,TextWrapped=true,
                AutomaticSize=Enum.AutomaticSize.Y,
                Size=UDim2.new(1,0,0,0)})
        for i,item in ipairs(V2Credits.Entries) do
            HudParts.text(card,string.format(
                "%s · %s\nAutor: %s\nFonte: %s",
                item.Group,item.Name,item.Author,item.Source),17,{
                Font=Theme.FontSemi,TextColor3=Theme.Text,
                LayoutOrder=10+i,TextWrapped=true,
                AutomaticSize=Enum.AutomaticSize.Y,
                Size=UDim2.new(1,0,0,0),
            })
        end
        HudParts.text(card,
            "PENDÊNCIAS LEGAIS A RESOLVER ANTES DE PUBLICAR",21,{
            Font=Theme.FontTitle,TextColor3=rgb(255,178,91),
            LayoutOrder=100,TextWrapped=true,
            AutomaticSize=Enum.AutomaticSize.Y,
            Size=UDim2.new(1,0,0,0)})
        for i,item in ipairs(V2Credits.Pending) do
            HudParts.text(card,"• "..item,17,{
                Font=Theme.FontSemi,TextColor3=rgb(255,190,112),
                LayoutOrder=101+i,TextWrapped=true,
                AutomaticSize=Enum.AutomaticSize.Y,
                Size=UDim2.new(1,0,0,0)})
        end
    end

	local scrolls: { [string]: ScrollingFrame } = {}
	render = function()
		local snapshot = Store.Snapshot
		local id = tabs.Current()
		local previous = scrolls[id]
		local position = previous and previous.CanvasPosition or Vector2.new()
		for _, child in ipairs(pages:GetChildren()) do
			child:Destroy()
		end
		local scroll = PanelKit.scroll(pages, "Page_" .. id)
		scroll.Size = UDim2.fromScale(1, 1)
		scrolls[id] = scroll
		if not snapshot then
			HudParts.text(scroll, t("loading"), 26, { Font = Theme.FontSemi, TextColor3 = Theme.Muted })
			return
		end
		if id == "overview" then
			overview(scroll, snapshot)
		elseif id == "reviews" then
			reviews(scroll, snapshot)
		elseif id == "history" then
			history(scroll, snapshot)
        elseif id == "credits" then
            credits(scroll)
		end
		task.defer(function()
			scroll.CanvasPosition = position
		end)
	end

	-- Só atualiza quando algo que o painel mostra mudou (evita reconstruir a cada snapshot e perder cliques).
	local lastKey = ""
	Store.Changed.Event:Connect(function(snapshot: any)
		if window.IsOpen() then
			local key = game:GetService("HttpService"):JSONEncode(snapshot.Profile)
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
		tabs.SetCompact(window.IsCompact())
		if window.IsOpen() then
			render()
		end
	end
	return window
end

return Profile
