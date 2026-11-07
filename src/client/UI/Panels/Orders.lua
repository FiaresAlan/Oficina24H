--!strict
-- Ordens de Serviço: Em Aberto / Em Andamento / Concluídas. Mantém todas as ações do sistema existente (aceitar, dispensar,
-- abandonar, diagnosticar, concluir, mecânico NPC, convidar profissional, colaboração); o servidor valida tudo.
-- O defeito técnico NUNCA aparece no cartão: só depois do diagnóstico o servidor envia Requirement.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local CustomerRules = require(ReplicatedStorage.Shared.CustomerRules)
local Theme = require(script.Parent.Parent.Theme)
local Kit = require(script.Parent.Parent.Kit)
local Store = require(script.Parent.Parent.Store)
local HudParts = require(script.Parent.Parent.HudParts)
local PanelKit = require(script.Parent.Parent.PanelKit)
local Stations = require(script.Parent.Parent.Stations)

local t = Kit.t
local Orders = {}

local INVITE_SPLIT = 25

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
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

local function stack(parent: Instance, gap: number, horizontal: boolean, order: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.Size = UDim2.new()
	f.LayoutOrder = order or 0
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if horizontal then
		l.FillDirection = Enum.FillDirection.Horizontal
		l.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	l.Parent = f
	f.Parent = parent
	return f
end

function Orders.new(parent: Instance)
	local window = PanelKit.window(parent, {
		Name = "OrdersPanel", Title = t("or_title"), Subtitle = t("or_sub"), Icon = "pn_h_clip", Width = 860, Height = 640,
	})
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = window.Content
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 16), UDim.new(0, 16)
	pad.Parent = body

	local inviteJobId: string? = nil
	local render: () -> ()
	local tabs: PanelKit.Tabs
	tabs = PanelKit.tabs(body, {
		{ Id = "open", Label = t("or_tab_open"), Icon = "pn_o_clock" },
		{ Id = "progress", Label = t("or_tab_progress"), Icon = "pn_o_wrench" },
		{ Id = "done", Label = t("or_tab_done"), Icon = "pn_o_check" },
	}, function()
		render()
	end)
	local pages = Instance.new("Frame")
	pages.Name = "Pages"
	pages.BackgroundTransparency = 1
	pages.Position = UDim2.fromOffset(0, 70)
	pages.Size = UDim2.new(1, 0, 1, -70)
	pages.Parent = body

	-- diálogo "Conversar": mostra a reclamação do cliente (o defeito real só vem do diagnóstico)
	local dialog = Instance.new("Frame")
	dialog.Name = "TalkDialog"
	dialog.Visible = false
	dialog.ZIndex = 30
	dialog.BackgroundColor3 = Color3.new(0, 0, 0)
	dialog.BackgroundTransparency = 0.45
	dialog.Size = UDim2.fromScale(1, 1)
	dialog.Parent = window.Content
	local dialogSink = Instance.new("TextButton")
	dialogSink.Text = ""
	dialogSink.BackgroundTransparency = 1
	dialogSink.Size = UDim2.fromScale(1, 1)
	dialogSink.ZIndex = 30
	dialogSink.Parent = dialog
	local talkCard = PanelKit.card(dialog, "TalkCard")
	talkCard.AnchorPoint = Vector2.new(0.5, 0.5)
	talkCard.Position = UDim2.fromScale(0.5, 0.5)
	talkCard.Size = UDim2.new(1, -60, 0, 0)
	talkCard.AutomaticSize = Enum.AutomaticSize.Y
	talkCard.ZIndex = 31
	local talkPad = Instance.new("UIPadding")
	talkPad.PaddingTop, talkPad.PaddingBottom, talkPad.PaddingLeft, talkPad.PaddingRight = UDim.new(0, 16), UDim.new(0, 16), UDim.new(0, 18), UDim.new(0, 18)
	talkPad.Parent = talkCard
	local talkLayout = Instance.new("UIListLayout")
	talkLayout.Padding = UDim.new(0, 10)
	talkLayout.SortOrder = Enum.SortOrder.LayoutOrder
	talkLayout.Parent = talkCard
	local talkTitle = HudParts.text(talkCard, "", 30, { Font = Theme.FontTitle, LayoutOrder = 1, ZIndex = 32 })
	local talkText = HudParts.text(talkCard, "", 28, { Font = Theme.FontSemi, LayoutOrder = 2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), ZIndex = 32 })
	local talkHint = HudParts.text(talkCard, t("or_talk_hint"), 21, { Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 3, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), ZIndex = 32 })
	local _ = talkHint
	local talkClose = PanelKit.button(talkCard, t("or_talk_close"), "blue", Vector2.new(180, 48), function()
		dialog.Visible = false
	end)
	talkClose.LayoutOrder = 4
	talkClose.ZIndex = 32
	local function talkTo(job: any)
		talkTitle.Text = t("or_talk_title", (job.Vip and "★ VIP " or "") .. (job.CustomerName or "?"))
		talkText.Text = "“" .. tostring(job.Complaint) .. "”"
		dialog.Visible = true
	end

	-- linhas vivas (tempo de espera e paciência) atualizadas a cada segundo sem reconstruir o cartão
	type LiveRow = { Job: any, Wait: TextLabel, Percent: TextLabel, SetBar: (number, Color3?) -> () }
	local liveRows: { LiveRow } = {}
	local function patience(job: any): (number, number)
		local elapsed = (job.WaitSeconds or 0) + (os.clock() - Store.SnapshotClock)
		local limit = math.max(1, job.PatienceSeconds or 300)
		return elapsed, math.clamp(1 - elapsed / limit, 0, 1)
	end
	local function refreshLive()
		for _, r in ipairs(liveRows) do
			local elapsed, remaining = patience(r.Job)
			r.Wait.Text = t("or_wait", clock(elapsed))
			r.Wait.TextColor3 = remaining < 0.25 and rgb(255, 80, 70) or Theme.Text
			r.Percent.Text = string.format("%d%%", math.floor(remaining * 100 + 0.5))
			r.SetBar(remaining, nil)
		end
	end
	task.spawn(function()
		while window.Root.Parent do
			if window.IsOpen() then
				refreshLive()
			end
			task.wait(1)
		end
	end)

	local function card(scroll: ScrollingFrame, order: number, accent: Color3, name: string?): (Frame, Frame)
		local c = PanelKit.card(scroll, name or "Order")
		c.LayoutOrder = order
		c.AutomaticSize = Enum.AutomaticSize.Y
		c.Size = UDim2.new(1, -10, 0, 0)
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(0, 8, 1, 0)
		stripe.BackgroundColor3 = accent
		stripe.BorderSizePixel = 0
		stripe.Parent = c
		local content = Instance.new("Frame")
		content.Name = "Content"
		content.BackgroundTransparency = 1
		content.Position = UDim2.fromOffset(18, 0)
		content.Size = UDim2.new(1, -28, 0, 0)
		content.AutomaticSize = Enum.AutomaticSize.Y
		local inner = Instance.new("UIPadding")
		inner.PaddingTop, inner.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
		inner.Parent = content
		content.Parent = c
		return c, content
	end

	local function requirement(parentFrame: Instance, job: any, snapshot: any, order: number)
		local req = job.Requirement
		if not req then
			return
		end
		local owned = snapshot.Profile.Equipment[req.EquipmentId] == true
		local level = snapshot.SkillLevels[req.Specialization] or 1
		local ok = owned and level >= req.Level
		local lines = stack(parentFrame, 2, false, order)
		HudParts.text(lines, t("orders_service", job.ServiceName or ""), 24, { Font = Theme.FontTitle, LayoutOrder = 1 })
		HudParts.text(lines, t("orders_requires", t("spec_" .. req.Specialization), req.Level, Catalog.Equipment[req.EquipmentId].DisplayName), 21, {
			Font = Theme.FontSemi, TextColor3 = ok and rgb(80, 230, 110) or rgb(255, 120, 110), LayoutOrder = 2,
		})
		local partTexts, partsOk = {}, true
		for partId, need in pairs(req.Parts or {}) do
			local have = snapshot.Profile.Parts and snapshot.Profile.Parts[partId] or 0
			partsOk = partsOk and have >= need
			table.insert(partTexts, string.format("%s %d/%d", Catalog.Parts[partId].DisplayName, have, need))
		end
		table.sort(partTexts)
		if #partTexts > 0 then
			HudParts.text(lines, t("orders_parts", table.concat(partTexts, ", ")), 21, { Font = Theme.FontSemi, TextColor3 = partsOk and rgb(80, 230, 110) or rgb(255, 120, 110), LayoutOrder = 3 })
		end
		HudParts.text(lines, t("orders_reward", req.Reward, req.XP), 21, { Font = Theme.FontSemi, TextColor3 = rgb(255, 200, 70), LayoutOrder = 4 })
	end

	local function openCard(scroll: ScrollingFrame, job: any, order: number, compact: boolean)
		local _, content = card(scroll, order, rgb(255, 176, 32), "Order_" .. job.Id)
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 14)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.FillDirection = compact and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Parent = content
		local thumb, setModel = HudParts.vehicleThumb(content, 190, 124)
		thumb.LayoutOrder = 1
		setModel(job.VehicleModel)
		local info = stack(content, 3, false, 2)
		info.Name = "Info"
		HudParts.text(info, t("or_customer", (job.Vip and "★ VIP " or "") .. (job.CustomerName or "?")), 30, { Font = Theme.FontTitle, LayoutOrder = 1 })
		HudParts.text(info, job.VehicleName, 26, { Font = Theme.FontSemi, LayoutOrder = 2 })
		local status = stack(info, 8, true, 3)
		HudParts.sprite(status, "pn_o_clock", Vector2.new(28, 28))
		HudParts.text(status, t("or_waiting"), 24, { Font = Theme.FontSemi, LayoutOrder = 2 })
		local waitLabel = HudParts.text(info, "", 23, { Font = Theme.FontSemi, LayoutOrder = 4 })
		local barRow = stack(info, 8, true, 5)
		HudParts.text(barRow, t("or_patience"), 23, { Font = Theme.FontSemi })
		local track, setBar = HudParts.progress(barRow, 16)
		track.Size = UDim2.fromOffset(150, 16)
		local percent = HudParts.text(barRow, "", 24, { Font = Theme.FontTitle })
		table.insert(liveRows, { Job = job, Wait = waitLabel, Percent = percent, SetBar = setBar })
		local actions = stack(content, 8, false, 3)
		actions.Name = "Actions"
		local talk = PanelKit.button(actions, t("or_talk"), "blue", Vector2.new(200, 48), function()
			talkTo(job)
		end, "pn_chat")
		talk.LayoutOrder = 1
		local accept = PanelKit.button(actions, t("or_accept"), "green", Vector2.new(200, 48), function()
			-- aceitar é só na TV de ordens dentro da oficina: longe dela, guia até lá
			if not Stations.IsNear("orders") then
				Store.Message:Fire(Stations.FarText.orders, false, "")
				Stations.Guide("orders")
				return
			end
			Store.Act("AcceptJob", { JobId = job.Id })
		end, "pn_o_check")
		accept.LayoutOrder = 2
		local decline = PanelKit.button(actions, t("or_decline"), "dark", Vector2.new(200, 40), function()
			Store.Act("DeclineJob", { JobId = job.Id })
		end)
		decline.LayoutOrder = 3
	end

	local function progressCard(scroll: ScrollingFrame, snapshot: any, job: any, order: number, compact: boolean)
		local _, content = card(scroll, order, rgb(70, 170, 255), "Order_" .. job.Id)
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 14)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.FillDirection = compact and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		layout.Parent = content
		local thumb, setModel = HudParts.vehicleThumb(content, 190, 124)
		thumb.LayoutOrder = 1
		setModel(job.VehicleModel)
		local info = stack(content, 3, false, 2)
		info.Name = "Info"
		info.AutomaticSize = Enum.AutomaticSize.XY
		HudParts.text(info, t("or_customer", (job.Vip and "★ VIP " or "") .. (job.CustomerName or "?")), 30, { Font = Theme.FontTitle, LayoutOrder = 1 })
		HudParts.text(info, job.VehicleName, 26, { Font = Theme.FontSemi, LayoutOrder = 2 })
		local statusRow = stack(info, 8, true, 3)
		HudParts.sprite(statusRow, "pn_o_wrench", Vector2.new(28, 28))
		HudParts.text(statusRow, job.Diagnosed and t("or_ready_repair") or t("or_need_diagnose"), 24, {
			Font = Theme.FontTitle, TextColor3 = job.Diagnosed and rgb(80, 230, 110) or rgb(255, 200, 70), LayoutOrder = 2,
		})
		requirement(info, job, snapshot, 4)
		local actions = stack(content, 8, false, 3)
		actions.Name = "Actions"
		if not job.Diagnosed then
			local diagnose = PanelKit.button(actions, t("orders_diagnose"), "blue", Vector2.new(210, 48), function()
				Store.Act("DiagnoseJob", { JobId = job.Id })
			end, "pn_o_wrench")
			diagnose.LayoutOrder = 1
		else
			local complete = PanelKit.button(actions, t("orders_complete"), "green", Vector2.new(210, 48), function()
				Store.Act("CompleteJob", { JobId = job.Id })
			end, "pn_o_check")
			complete.LayoutOrder = 1
			local npc = PanelKit.button(actions, t("orders_hire_npc"), "dark", Vector2.new(210, 42), function()
				Store.Act("HireNpc", { JobId = job.Id })
			end)
			npc.LayoutOrder = 2
			local invite = PanelKit.button(actions, t("orders_invite"), "dark", Vector2.new(210, 42), function()
				inviteJobId = (inviteJobId == job.Id) and nil or job.Id
				render()
			end)
			invite.LayoutOrder = 3
		end
		if not job.CollaboratorUserId then
			local abandon = PanelKit.button(actions, t("orders_abandon"), "dark", Vector2.new(210, 40), function()
				Store.Act("DeclineJob", { JobId = job.Id })
			end)
			abandon.LayoutOrder = 4
		end
		if inviteJobId == job.Id then
			local others = {}
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= Players.LocalPlayer then
					table.insert(others, other)
				end
			end
			local list = stack(info, 6, false, 5)
			if #others == 0 then
				HudParts.text(list, t("orders_no_players"), 22, { Font = Theme.FontSemi, TextColor3 = Theme.Muted })
			end
			for _, other in ipairs(others) do
				PanelKit.button(list, other.DisplayName .. " · " .. t("orders_invite_split", INVITE_SPLIT), "dark", Vector2.new(280, 40), function()
					Store.Act("InviteWorker", { WorkerUserId = other.UserId, JobId = job.Id, SplitPercent = INVITE_SPLIT })
					inviteJobId = nil
					render()
				end)
			end
		end
	end

	local HttpService = game:GetService("HttpService")
	local lastSignature = ""
	-- Só reconstrói quando algo que o painel mostra mudou (o tempo de espera é animado à parte): evita perder cliques.
	local function signature(snapshot: any): string
		local parts = { tabs.Current(), tostring(inviteJobId), tostring(snapshot.HasWorkshop) }
		for _, job in ipairs(snapshot.Jobs) do
			table.insert(parts, string.format("%s.%s.%s.%s", job.Id, job.Status, tostring(job.Diagnosed), tostring(job.CollaboratorUserId)))
		end
		for _, job in ipairs(snapshot.CollabJobs or {}) do
			table.insert(parts, "c" .. job.Id .. tostring(job.Diagnosed))
		end
		table.insert(parts, HttpService:JSONEncode({ snapshot.Profile.Parts, snapshot.Profile.Equipment, snapshot.SkillLevels }))
		table.insert(parts, tostring(#(snapshot.Profile.OrderHistory or {})))
		return table.concat(parts, "|")
	end

	local scrolls: { [string]: ScrollingFrame } = {}
	render = function()
		local snapshot = Store.Snapshot
		if snapshot then
			lastSignature = signature(snapshot)
		end
		local id = tabs.Current()
		local previous = scrolls[id]
		local position = previous and previous.CanvasPosition or Vector2.new()
		for _, child in ipairs(pages:GetChildren()) do
			child:Destroy()
		end
		liveRows = {}
		local scroll = PanelKit.scroll(pages, "Page_" .. id)
		scroll.Size = UDim2.fromScale(1, 1)
		scrolls[id] = scroll
		if not snapshot then
			HudParts.text(scroll, t("loading"), 26, { Font = Theme.FontSemi, TextColor3 = Theme.Muted })
			return
		end
		local compact = window.IsCompact()
		local openJobs, progressJobs = {}, {}
		for _, job in ipairs(snapshot.Jobs) do
			if job.Status == "Available" then
				table.insert(openJobs, job)
			elseif job.Status == "InProgress" then
				table.insert(progressJobs, job)
			end
		end
		table.sort(openJobs, function(a, b)
			return (a.WaitSeconds or 0) > (b.WaitSeconds or 0)
		end)
		local history = snapshot.Profile.OrderHistory or {}
		tabs.SetLabel("open", t("or_tab_open") .. (#openJobs > 0 and (" (" .. #openJobs .. ")") or ""))
		tabs.SetLabel("progress", t("or_tab_progress") .. (#progressJobs > 0 and (" (" .. #progressJobs .. ")") or ""))

		if not snapshot.HasWorkshop then
			local c = PanelKit.card(scroll, "Register")
			c.Size = UDim2.new(1, -10, 0, 150)
			HudParts.text(c, t("orders_no_workshop"), 28, { Font = Theme.FontTitle, Position = UDim2.fromOffset(18, 18) })
			local register = PanelKit.button(c, t("orders_register"), "orange", Vector2.new(260, 52), function()
				Store.Act("ClaimWorkshop")
			end)
			register.Position = UDim2.fromOffset(18, 76)
			return
		end

		if id == "open" then
			local top = stack(scroll, 10, true, 0)
			local flyers = PanelKit.button(top, t("orders_new_customer"), "orange", Vector2.new(240, 48), function()
				Store.Act("GenerateCustomer")
			end)
			flyers.LayoutOrder = 1
			HudParts.text(top, snapshot.WorkshopName or "", 23, { Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 2 })
			for index, job in ipairs(openJobs) do
				openCard(scroll, job, index, compact)
			end
			if #openJobs == 0 then
				local empty = PanelKit.emptyState(scroll, "pn_car_empty", t("or_empty"), t("or_empty_sub"))
				empty.LayoutOrder = 50
				empty.Size = UDim2.new(1, -10, 0, 250)
			end
			refreshLive()
		elseif id == "progress" then
			for index, job in ipairs(progressJobs) do
				progressCard(scroll, snapshot, job, index, compact)
			end
			local collab = snapshot.CollabJobs or {}
			if #collab > 0 then
				HudParts.text(scroll, t("orders_collab_title"), 28, { Font = Theme.FontTitle, LayoutOrder = 100 })
				for index, job in ipairs(collab) do
					local _, content = card(scroll, 100 + index, rgb(190, 120, 240))
					local info = stack(content, 4, false, 1)
					HudParts.text(info, job.VehicleName, 28, { Font = Theme.FontTitle, LayoutOrder = 1 })
					HudParts.text(info, t("orders_collab_info", job.OwnerName, job.SplitPercent), 22, { Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 2 })
					local finish, setFinish = PanelKit.button(info, t("orders_finish_collab"), "green", Vector2.new(220, 46), function()
						Store.Act("CompleteCollaborativeJob", { JobId = job.Id })
					end)
					finish.LayoutOrder = 3
					setFinish(job.Diagnosed == true)
				end
			end
			if #progressJobs == 0 and #collab == 0 then
				local empty = PanelKit.emptyState(scroll, "pn_car_empty", t("or_empty"), t("or_empty_sub"))
				empty.LayoutOrder = 50
				empty.Size = UDim2.new(1, -10, 0, 250)
			end
		else
			if #history == 0 then
				local empty = PanelKit.emptyState(scroll, "pn_car_empty", t("or_done_empty"), t("or_done_empty_sub"))
				empty.Size = UDim2.new(1, -10, 0, 280)
			end
			for index = #history, 1, -1 do
				local entry = history[index]
				local _, content = card(scroll, #history - index + 1, rgb(70, 225, 105))
				local layout = Instance.new("UIListLayout")
				layout.Padding = UDim.new(0, 14)
				layout.FillDirection = Enum.FillDirection.Horizontal
				layout.VerticalAlignment = Enum.VerticalAlignment.Center
				layout.SortOrder = Enum.SortOrder.LayoutOrder
				layout.Parent = content
				local thumb, setModel = HudParts.vehicleThumb(content, 130, 86)
				thumb.LayoutOrder = 1
				setModel(Catalog.VehicleModels[entry.Vehicle])
				local info = stack(content, 2, false, 2)
				HudParts.text(info, t("or_customer", entry.Customer ~= "" and entry.Customer or "?"), 26, { Font = Theme.FontTitle, LayoutOrder = 1 })
				HudParts.text(info, entry.Vehicle .. " · " .. entry.Service, 22, { Font = Theme.FontSemi, LayoutOrder = 2 })
				local line = stack(info, 8, true, 3)
				HudParts.text(line, "+" .. entry.Price, 24, { Font = Theme.FontTitle, TextColor3 = rgb(255, 200, 70), LayoutOrder = 1 })
				HudParts.text(line, CustomerRules.StarsText(entry.Stars), 24, { Font = Theme.FontTitle, TextColor3 = rgb(255, 200, 40), LayoutOrder = 2 })
				HudParts.text(line, ago(entry.At or 0), 21, { Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 3 })
			end
		end
		task.defer(function()
			scroll.CanvasPosition = position
		end)
	end

	Store.Changed.Event:Connect(function(snapshot: any)
		if window.IsOpen() and signature(snapshot) ~= lastSignature then
			render()
		end
	end)
	window.OnOpen = render
	window.OnResize = function()
		tabs.SetCompact(window.IsCompact())
		if window.IsOpen() then
			render()
		end
	end
	return window
end

return Orders
