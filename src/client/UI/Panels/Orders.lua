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
local ServiceFocusRules = require(ReplicatedStorage.Shared.ServiceFocusRules)
local RepairStatementRules = require(ReplicatedStorage.Shared.RepairStatementRules)
local V2ManagementSummaryRules = require(ReplicatedStorage.Shared.V2ManagementSummaryRules)
local V2ReceptionRules = require(ReplicatedStorage.Shared.V2ReceptionRules)
local V2ShowroomPreview = require(script.Parent.Parent.V2ShowroomPreview)

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
    local previewChoice: { [string]: string } = {} -- somente UI; nunca debita ou muda o perfil
    local financeView = "cash" -- alterna Caixa/Mercado SEM adicionar aba na HUD
	local render: () -> ()
	local tabs: PanelKit.Tabs
	tabs = PanelKit.tabs(body, {
		{ Id = "open", Label = t("or_tab_open"), Icon = "pn_o_clock" },
		{ Id = "progress", Label = t("or_tab_progress"), Icon = "pn_o_wrench" },
        { Id = "team", Label = "Equipe", Icon = "pn_p_people" },
        { Id = "finance", Label = "Caixa", Icon = "pn_t_clock" },
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
		talkTitle.Text = t("or_talk_title", (job.Vip and "★ VIP " or (job.Regular and "♥ " or (job.Fleet and "📋 " or ""))) .. (job.CustomerName or "?"))
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
		HudParts.text(info, t("or_customer", (job.Vip and "★ VIP " or (job.Regular and "♥ " or (job.Fleet and "📋 " or ""))) .. (job.CustomerName or "?")), 30, { Font = Theme.FontTitle, LayoutOrder = 1 })
		HudParts.text(info, job.VehicleName, 26, { Font = Theme.FontSemi, LayoutOrder = 2 })
        local reception = job.Reception or {}
        HudParts.text(info, (reception.Stage or "Aguardando") .. string.format(
            " · Faixa geral (estimativa): %d–%d moedas",
                reception.PriceGuideMin or 0, reception.PriceGuideMax or 0), 18, {
            Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 2,
            TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
        })
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
        local priority = PanelKit.button(actions,
            reception.Priority == 1 and "PRIORIDADE ALTA" or reception.Priority == -1
                and "PRIORIDADE BAIXA" or "PRIORIZAR FILA",
            "blue", Vector2.new(200, 42), function()
                if not Stations.IsNear("orders") then
                    Store.Message:Fire(Stations.FarText.orders, false, "")
                    Stations.Guide("orders")
                    return
                end
                local nextValue = reception.Priority == 1 and -1 or
                    reception.Priority == -1 and 0 or 1
                Store.Act("SetJobPriority", { JobId = job.Id, Priority = nextValue })
            end)
        priority.LayoutOrder = 4
        if reception.CanSchedule then
            local schedule = PanelKit.button(actions, "ATENDER EM 60 S", "dark",
                Vector2.new(200, 42), function()
                    if not Stations.IsNear("orders") then
                        Store.Message:Fire(Stations.FarText.orders, false, "")
                        Stations.Guide("orders")
                        return
                    end
                    Store.Act("ScheduleJob", { JobId = job.Id, Seconds = 60 })
                end)
            schedule.LayoutOrder = 5
        end
	end

	local function progressCard(scroll: ScrollingFrame, snapshot: any, job: any, order: number, compact: boolean)
		local _, content = card(scroll, order, Theme.Blue, "Order_" .. job.Id)
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
		HudParts.text(info, t("or_customer", (job.Vip and "★ VIP " or (job.Regular and "♥ " or (job.Fleet and "📋 " or ""))) .. (job.CustomerName or "?")), 30, { Font = Theme.FontTitle, LayoutOrder = 1 })
		HudParts.text(info, job.VehicleName, 26, { Font = Theme.FontSemi, LayoutOrder = 2 })
		local statusRow = stack(info, 8, true, 3)
		HudParts.sprite(statusRow, "pn_o_wrench", Vector2.new(28, 28))
		local goal = ServiceFocusRules.ForActive(job, snapshot.Profile)
		HudParts.text(statusRow, goal.Title, 24, {
			Font = Theme.FontTitle,
			TextColor3 = goal.Kind == "Stock" and Theme.Red or (goal.Kind == "Delegated" and Theme.Muted or Theme.Accent),
			LayoutOrder = 2,
		})
		requirement(info, job, snapshot, 4)
        if job.Procedure then
            local proc=job.Procedure
            HudParts.text(info,string.format("REPARO TÉCNICO · %d/%d etapas · %s",
                proc.Completed or 0,proc.Total or 0,proc.StepName or ""),
                19,{Font=Theme.FontSemi,TextColor3=Theme.Accent,
                    LayoutOrder=4,TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y,
                    Size=UDim2.new(1,0,0,0)})
            if not proc.Ready then
                HudParts.text(info,"Local: "..(proc.Area or "").." · Ferramenta: "..(proc.Tool or ""),
                    17,{Font=Theme.FontSemi,TextColor3=Theme.Muted,LayoutOrder=4,
                        TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y,
                        Size=UDim2.new(1,0,0,0)})
            end
        end
        if job.Mechanics then
            local mechanics = job.Mechanics
            local panelHint = not mechanics.Ready and mechanics.Next or
                (mechanics.Hood == "Open" and "Capô aberto — feche antes da saída" or
                    mechanics.WheelFL == "Detached" and "Roda dianteira esquerda removida" or
                    "Componentes prontos para o serviço")
            HudParts.text(info, "OFICINA 3D · " .. panelHint, 19, {
                Font = Theme.FontSemi, TextColor3 = Theme.Accent,
                LayoutOrder = 4, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, 0, 0, 0),
            })
        end
        local reception = job.Reception or {}
        if job.Diagnosed and reception.EstimatedPartsCost ~= nil then
            HudParts.text(info, string.format(
                "Peças (estimativa): %d · Contribuição antes salários: %d",
                    reception.EstimatedPartsCost, reception.ContributionBeforeLabor or 0),
                19, { Font = Theme.FontSemi, TextColor3 = Theme.Muted,
                    LayoutOrder = 4, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
                    Size = UDim2.new(1, 0, 0, 0) })
        end
        HudParts.text(info, "Etapa: " .. (reception.Stage or "Em andamento")
            .. ((reception.DiscountPercent or 0) > 0 and
                (" · desconto " .. tostring(reception.DiscountPercent) .. "%") or ""), 19, {
                Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 5,
                TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, 0, 0, 0),
            })
		local actions = stack(content, 8, false, 3)
		actions.Name = "Actions"
		if goal.Kind == "Delegated" then
			HudParts.text(actions, "O profissional convidado está responsável por esta OS.", 20, {
				Font = Theme.FontSemi, TextColor3 = Theme.Muted, TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromOffset(210, 0),
			})
		else
			local buttonText = goal.Target == "shop" and "IR À LOJA"
				or goal.Target == "equipment" and "LOCALIZAR MÁQUINA"
				or "IR AO VEÍCULO"
			local go = PanelKit.button(actions, buttonText, "blue", Vector2.new(210, 48), function()
				local target: BasePart? = nil
				if goal.Target == "shop" then
					target = Stations.Target("shop")
				elseif goal.Target == "equipment" and goal.EquipmentId then
					target = Stations.TargetEquipment(goal.EquipmentId)
				elseif goal.Target == "vehicle" then
					target = Stations.Vehicle(job.Id)
				end
				if target then
					window.Close()
					Stations.GuideTo(target, 18)
				else
					Store.Message:Fire("O local do serviço não está disponível. Confira o veículo ou o equipamento na oficina.", false, "")
				end
			end, "pn_o_wrench")
			go.LayoutOrder = 1
		end
		if job.Diagnosed and not job.CollaboratorUserId then
            for _, pct in ipairs({5, 10}) do
                local discount = PanelKit.button(actions, "OFERECER " .. pct .. "% DESCONTO",
                    "dark", Vector2.new(210, 42), function()
                        if not Stations.IsNear("orders") then
                            Store.Message:Fire(Stations.FarText.orders, false, "")
                            Stations.Guide("orders")
                            return
                        end
                        Store.Act("DiscountJob", { JobId = job.Id, Percent = pct })
                    end)
                discount.LayoutOrder = 5 + pct
            end
            if reception.MissingParts and next(reception.MissingParts) ~= nil then
                local supplies = PanelKit.button(actions, "ADICIONAR PEÇAS À LISTA",
                    "blue", Vector2.new(210, 42), function()
                        if not Stations.IsNear("orders") then
                            Store.Message:Fire(Stations.FarText.orders, false, "")
                            Stations.Guide("orders")
                            return
                        end
                        Store.Act("RequestJobSupplies", { JobId = job.Id })
                    end)
                supplies.LayoutOrder = 8
            end
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

    -- V2-08: relatório financeiro é leitura do snapshot do SERVIDOR.
    -- Nada neste painel debita, credita ou autoriza um valor financeiro.
    local function financialCard(scroll: ScrollingFrame,name: string,order: number,
        title: string,lines: {any}): Frame
        local panel=PanelKit.card(scroll,name)
        panel.LayoutOrder=order
        panel.AutomaticSize=Enum.AutomaticSize.Y
        panel.Size=UDim2.new(1,-10,0,0)
        local padding=Instance.new("UIPadding")
        padding.PaddingTop=UDim.new(0,12)
        padding.PaddingBottom=UDim.new(0,12)
        padding.PaddingLeft=UDim.new(0,16)
        padding.PaddingRight=UDim.new(0,16)
        padding.Parent=panel
        local layout=Instance.new("UIListLayout")
        layout.Padding=UDim.new(0,6)
        layout.SortOrder=Enum.SortOrder.LayoutOrder
        layout.Parent=panel
        HudParts.text(panel,title,23,{Font=Theme.FontTitle,TextColor3=Theme.Accent,
            LayoutOrder=0,TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y,
            Size=UDim2.new(1,0,0,0)})
        for i,line in ipairs(lines) do
            local str=type(line)=="table" and line.Text or tostring(line)
            local color=type(line)=="table" and line.Color or Theme.Text
            HudParts.text(panel,str,18,{Font=Theme.FontSemi,TextColor3=color or Theme.Text,
                LayoutOrder=i,TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y,
                Size=UDim2.new(1,0,0,0)})
        end
        return panel
    end

	local function signature(snapshot: any): string
		local parts = { tabs.Current(), tostring(inviteJobId), tostring(snapshot.HasWorkshop) }
		for _, job in ipairs(snapshot.Jobs) do
			table.insert(parts, string.format("%s.%s.%s.%s.%s.%s",
                job.Id, job.Status, tostring(job.Diagnosed), tostring(job.CollaboratorUserId),
                tostring(job.PrepComplete), tostring(job.Requirement and job.Requirement.EquipmentId)))
            local reception = job.Reception or {}
            table.insert(parts, table.concat({
                tostring(reception.Priority), tostring(reception.ScheduledUntil),
                tostring(reception.DiscountPercent), tostring(reception.Stage),
                tostring(job.Mechanics and job.Mechanics.Hood),
                tostring(job.Mechanics and job.Mechanics.WheelFL),
                tostring(job.Mechanics and job.Mechanics.Ready),
                tostring(job.Procedure and job.Procedure.Completed),
                tostring(job.Procedure and job.Procedure.StepName),
                tostring(job.EmployeeAssignedSlot),
            }, ":"))
		end
		for _, job in ipairs(snapshot.CollabJobs or {}) do
			table.insert(parts, "c" .. job.Id .. tostring(job.Diagnosed))
		end
		table.insert(parts, HttpService:JSONEncode({ snapshot.Profile.Parts, snapshot.Profile.Equipment, snapshot.Profile.SupplyRequests, snapshot.SkillLevels }))
		table.insert(parts, tostring(#(snapshot.Profile.OrderHistory or {})))
		table.insert(parts, table.concat({ tostring(snapshot.Profile.Coins), tostring(snapshot.Profile.Employees),
			tostring(snapshot.Profile.WorkshopLevel) }, ":"))
		table.insert(parts, HttpService:JSONEncode(snapshot.RecentSettlements or {}))
        table.insert(parts, HttpService:JSONEncode(snapshot.UsedMarket or {}))
        local staff=snapshot.Staff or {}
        table.insert(parts, tostring(staff.TotalPaid))
        for _,worker in ipairs(staff.Workers or {}) do
            table.insert(parts,table.concat({
                tostring(worker.Slot),tostring(worker.Mode),tostring(worker.Focus),
                tostring(worker.Completed),tostring(worker.Gross),
                tostring(worker.Status),tostring(worker.JobId),
                tostring(math.floor((worker.Progress or 0)/25)),
                tostring(worker.Queued),
            },":"))
        end
		table.insert(parts, HttpService:JSONEncode(snapshot.PendingClaimSummary or {}))
        local finance=snapshot.Finance or {}
        table.insert(parts,table.concat({
            tostring(finance.CashIn),tostring(finance.CashOut),
            tostring(finance.TransactionsCount),tostring(finance.NextPayAt),
            tostring(finance.Warning),
        },":"))
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
		table.sort(openJobs, V2ReceptionRules.QueueLess)
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
            -- V2-02: visão gerencial apenas de leitura, sem exibir margem inventada.
            local summary = type(snapshot.Management) == "table" and snapshot.Management
                or V2ManagementSummaryRules.Build(snapshot)
            local cardV2 = PanelKit.card(scroll, "V2ManagementOverview")
            cardV2.Size = UDim2.new(1, -10, 0, compact and 128 or 114)
            cardV2.LayoutOrder = -10
            HudParts.text(cardV2,
                string.format("OPERAÇÃO · %d aguardando · %d box(es) livre(s) de %d · %d mecânico(s)",
                    summary.Waiting, summary.FreeBays, summary.Bays, summary.Employees),
                compact and 18 or 21, {
                    Font = Theme.FontSemi, TextColor3 = Theme.Accent,
                    Position = UDim2.fromOffset(14, 12),
                    Size = UDim2.new(1, -28, 0, 28), TextWrapped = true,
                })
            HudParts.text(cardV2, string.format(
                "Caixa: %d · Histórico bruto (%d OS): %d · Fluxo operacional: %d",
                    summary.Coins, summary.RecentCount, summary.RecentGross,
                    snapshot.Finance and snapshot.Finance.OperatingCash or 0),
                compact and 16 or 18, {
                    Font = Theme.FontSemi, TextColor3 = Theme.Muted,
                    Position = UDim2.fromOffset(14, 42),
                    Size = UDim2.new(1, -28, 0, compact and 47 or 37),
                    TextWrapped = true,
                })
            HudParts.text(cardV2, string.format("%s · estoque %d un. · pedidos %d tipo(s) (%d moedas)",
                summary.NextAction, summary.StockUnits, summary.SupplyRequestKinds, summary.SupplyEstimatedCost),
                compact and 15 or 18, {
                Font = Theme.FontSemi, TextColor3 = Theme.Accent,
                Position = UDim2.fromOffset(14, compact and 94 or 85),
                Size = UDim2.new(1, -28, 0, 24), TextWrapped = true,
            })
            -- Próximo investimento aparece depois do primeiro atendimento, sem overlay.
            if (snapshot.Profile.RatingCount or 0) > 0
                and (snapshot.Profile.WorkshopLevel or 0) == 0 then
                local upgrade = snapshot.Workshop and snapshot.Workshop.Next
                if upgrade then
                    local guide = PanelKit.card(scroll, "V2FirstExpansion")
                    guide.LayoutOrder = -9
                    guide.Size = UDim2.new(1, -10, 0, 68)
                    HudParts.text(guide, upgrade.CanBuy and
                        ("PRÓXIMO PASSO: amplie para " .. upgrade.Name .. " na Construtora")
                        or ("META DE EXPANSÃO: " .. upgrade.Name .. " · custo "
                            .. tostring(upgrade.Cost) .. " moedas; confira os requisitos na Construtora"),
                        compact and 17 or 20, {
                        Font = Theme.FontSemi, TextColor3 = Theme.Accent,
                        Position = UDim2.fromOffset(14, 9),
                        Size = UDim2.new(1, -28, 0, 50), TextWrapped = true,
                    })
                end
            end
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
        elseif id == "finance" then
            -- Com largura compacta, separar as duas seções evita rolar por
            -- centenas de linhas do extrato antes de encontrar o mercado.
            local switch=stack(scroll,8,true,-100)
            local cashButton=PanelKit.button(switch,
                financeView=="cash" and "CAIXA · ATIVA" or "CAIXA",
                "dark",Vector2.new(compact and 145 or 220,44),function()
                    financeView="cash"
                    render()
                end)
            cashButton.LayoutOrder=1
            local marketButton=PanelKit.button(switch,
                financeView=="market" and "USADOS · ATIVA" or "USADOS",
                "dark",Vector2.new(compact and 145 or 220,44),function()
                    financeView="market"
                    render()
                end)
            marketButton.LayoutOrder=2
            if financeView=="cash" then
            local finance=snapshot.Finance
            if type(finance)~="table" then
                financialCard(scroll,"NoFinance",1,"CAIXA AINDA INDISPONÍVEL",{
                    "Abra a oficina ou atualize o extrato. O histórico financeiro fica no servidor.",
                })
            else
                local coverage=finance.LegacyWindow
                    and "HISTÓRICO PARCIAL · migração dos últimos registros disponíveis"
                    or "DESDE A ABERTURA DO LIVRO DE CAIXA"
                financialCard(scroll,"FinanceCash",1,"FLUXO DE CAIXA · "..coverage,{
                    string.format("Saldo: %d · entradas: +%d · saídas: -%d",
                        finance.Cash or 0,finance.CashIn or 0,finance.CashOut or 0),
                    string.format("Conciliação de saldo: %+d · livro iniciado em %s",
                        finance.ReconciliationGap or 0,os.date("%d/%m/%Y",finance.Since or os.time())),
                    {Text=string.format("Variação de caixa: %+d · %d movimentações",
                        finance.CashDelta or 0,finance.TransactionsCount or 0),
                        Color=(finance.CashDelta or 0)>=0 and Theme.Accent or rgb(255,128,100)},
                    string.format("Entradas de OS: %d · despesas operacionais pagas: %d",
                        finance.ServiceReceipts or 0,finance.OperatingOut or 0),
                    {Text=string.format("Fluxo operacional de caixa: %+d",
                        finance.OperatingCash or 0),
                        Color=(finance.OperatingCash or 0)>=0 and Theme.Accent or rgb(255,128,100)},
                    "Não é lucro contábil: compras de peças entram quando pagas. Estoque consumido não é descontado novamente.",
                    "Bônus, equipamentos e ampliação são mostrados separadamente.",
                })
                financialCard(scroll,"FinanceReserve",2,"RESERVA, ESTOQUE E RISCO",{
                    {Text=finance.Warning~="" and finance.Warning or "Sem alerta financeiro no período.",
                        Color=finance.Warning~="" and rgb(255,167,85) or Theme.Accent},
                    string.format("Próxima folha: %d · caixa após reservá-la: %+d",
                        finance.NextPayroll or 0,finance.AvailableAfterPayroll or 0),
                    string.format("Valor REFERENCIAL do estoque e mochila: %d moedas",
                        finance.StockReferenceValue or 0),
                    "O custo referencial é uma tabela de peças, não custo médio de aquisição de lotes antigos.",
                })
                local categoryNames={
                    Service="Serviços recebidos",Inventory="Compra de peças",
                    Payroll="Salários",Marketing="Publicidade",
                    Equipment="Equipamentos e melhorias",Building="Expansões",
                    Hiring="Contratações",Rewards="Bônus e premiações",Market="Compra e revenda de usados",Other="Outros",
                }
                local categoryOrder={"Service","Inventory","Payroll","Marketing",
                    "Equipment","Building","Hiring","Rewards","Market","Other"}
                local lines={}
                for _,name in ipairs(categoryOrder) do
                    local x=finance.Groups and finance.Groups[name]
                    if x and ((x.In or 0)>0 or (x.Out or 0)>0) then
                        table.insert(lines,string.format("%s · entradas %d · saídas %d",
                            categoryNames[name] or name,x.In or 0,x.Out or 0))
                    end
                end
                if #lines==0 then table.insert(lines,"Nenhuma movimentação categorizada neste período.") end
                financialCard(scroll,"FinanceCategories",3,"ORIGEM DAS MOVIMENTAÇÕES",lines)
                local stockAdvice=finance.Restock or {}
                local reorder={}
                for _,entry in ipairs(stockAdvice.Items or {}) do
                    table.insert(reorder,string.format(
                        "%s · %d em estoque · %d reservado(s) para OS · sugerir +%d (%d moedas)",
                        entry.Name,entry.OnHand,entry.Required,entry.Quantity,entry.Cost))
                end
                if #reorder==0 then
                    table.insert(reorder,"Estoque suficiente para as OS diagnosticadas e a demanda recente conhecida.")
                end
                table.insert(reorder,string.format(
                    "Falta para OS diagnosticadas: %d · reposição sugerida: %d · amostra: %d serviços",
                    stockAdvice.UrgentCost or 0,stockAdvice.TotalCost or 0,
                    stockAdvice.HistoryServices or 0))
                table.insert(reorder,
                    "Sugestão somente informativa. Nenhuma compra automática; use a loja física.")
                financialCard(scroll,"FinanceReorder",4,"REPOSIÇÃO E DEMANDA DE PEÇAS",reorder)
                local quotes={}
                for _,q in ipairs(finance.Quotes or {}) do
                    table.insert(quotes,string.format("%s · preço-base %d · peça ref. %d · contribuição-base %+d",
                        q.Name,q.BasePrice,q.PartsReferenceCost,q.BeforeLabor))
                end
                table.insert(quotes,"Estimativas ANTES de salários, bonificações, variação de qualidade e outros custos.")
                financialCard(scroll,"FinanceQuotes",5,"PREÇOS DOS 15 SERVIÇOS · REFERÊNCIA",quotes)
                local last={}
                local entries=finance.Recent or {}
                for i=#entries,math.max(1,#entries-15),-1 do
                    local e=entries[i]
                    table.insert(last,{Text=string.format("%+d · %s · %s",
                        e.Amount,e.Reason,ago(e.At or 0)),
                        Color=e.Amount>=0 and Theme.Accent or rgb(255,150,120)})
                end
                if #last==0 then table.insert(last,"Sem movimentações recentes.") end
                financialCard(scroll,"FinanceRecent",6,"ÚLTIMAS MOVIMENTAÇÕES",last)
            end
            end -- fim da seção Caixa; showroom usa o mesmo painel
            if financeView=="market" then
            -- V2-09/10: mercado e showroom na segunda seção da aba Caixa.
            local market = snapshot.UsedMarket
            if type(market) == "table" then
                financialCard(scroll, "UsedIntro",10,"MERCADO DE USADOS · NEGÓCIO SECUNDÁRIO",{
                    "A oficina continua focada nas OS de clientes. O carro de revenda não ocupa boxes.",
                    "Comprar: visite a Loja de Autopeças. Restaurar e vender: esteja no próprio lote.",
                    string.format("Capacidade: %d carro · operações concluídas: %d · contribuição estimada histórica: %+d",
                        market.Capacity or 1,market.TotalSales or 0,market.TotalContribution or 0),
                    {Text=market.CanBuy and "Mercado liberado para sua oficina."
                        or tostring(market.BlockedReason or "Indisponível."),
                        Color=market.CanBuy and Theme.Accent or rgb(255,167,85)},
                    "Os preços abaixo usam peças ao custo de tabela; resultado final não é lucro contábil.",
                })
                for i,offer in ipairs(market.Offers or {}) do
                    local lines={
                        string.format("Compra: %d · revisão base: %d · risco adicional: 0–%d",
                            offer.BuyPrice or 0,offer.RepairFee or 0,offer.RiskMax or 0),
                        string.format("Peças (referência): %d · revenda após restauração: %d",
                            offer.PartsReferenceCost or 0,offer.SalePrice or 0),
                        {Text=string.format("Contribuição prevista: %+d a %+d moedas",
                            offer.EstimatedContributionMin or 0,offer.EstimatedContributionMax or 0),
                            Color=(offer.EstimatedContributionMin or 0)>=0 and Theme.Accent or rgb(255,167,85)},
                    }
                    local card=financialCard(scroll,"UsedOffer_"..offer.Id,10+i,
                        string.upper(offer.Name or offer.Id),lines)
                    local thumb,setVehicle=HudParts.vehicleThumb(card,170,84)
                    thumb.LayoutOrder=12
                    setVehicle(offer.VehicleModel)
                    if market.CanBuy then
                        local buy=PanelKit.button(card,
                            string.format("COMPRAR · %d MOEDAS",offer.BuyPrice or 0),
                            "dark",Vector2.new(230,44),function()
                                Store.Act("UsedMarket",{Operation="Buy",Id=offer.Id})
                            end)
                        buy.LayoutOrder=20
                    end
                end
                for i,car in ipairs(market.Owned or {}) do
                    local name=car.Name or car.Variant
                    local stage=car.Stage or "Purchased"
                    local parts={}
                    for partId,qty in pairs(car.Parts or {}) do
                        local part=Catalog.Parts[partId]
                        table.insert(parts,string.format("%s x%d",part and part.DisplayName or partId,qty))
                    end
                    table.sort(parts)
                    local card=financialCard(scroll,"UsedOwned_"..car.Uid,20+i,
                        "SEU VEÍCULO · "..string.upper(name),{
                            "Etapa: "..stage.." · acabamento: "..tostring(car.Style),
                            string.format("Reforma total: %d (inclui risco já inspecionado: %d)",
                                car.RepairFee or 0,car.RiskFee or 0),
                            "Peças necessárias: "..(#parts>0 and table.concat(parts,", ") or "nenhuma"),
                            string.format("Venda no estado atual: %d moedas",car.SellPrice or 0),
                        })
                    local thumb,setVehicle=HudParts.vehicleThumb(card,170,84)
                    thumb.LayoutOrder=10
                    setVehicle(car.VehicleModel)
                    local nextAction=stage=="Purchased" and "Inspect"
                        or stage=="Inspected" and "Strip"
                        or stage=="Stripped" and "Restore" or nil
                    local nextLabel=stage=="Purchased" and "INSPECIONAR"
                        or stage=="Inspected" and "DESMONTAR"
                        or stage=="Stripped" and "INSTALAR E RESTAURAR" or nil
                    if nextAction and nextLabel then
                        local action=PanelKit.button(card,nextLabel,"dark",Vector2.new(240,44),function()
                            Store.Act("UsedMarket",{Operation=nextAction,Id=car.Uid})
                        end)
                        action.LayoutOrder=20
                        local scrap=PanelKit.button(card,"VENDER COMO SUCATA",
                            "dark",Vector2.new(230,44),function()
                                Store.Act("UsedMarket",{Operation="Scrap",Id=car.Uid})
                            end)
                        scrap.LayoutOrder=21
                    elseif stage=="Restored" then
                        -- V2-10: personalizações com prévia CLIENT-SIDE e
                        -- confirmação separada. A seleção nunca é paga nem enviada.
                        local choices=market.Customizations or {}
                        local staged=previewChoice[car.Uid]
                        local selection: any?=nil
                        local appearance={
                            Paint=car.Style or "Factory",
                            Finish=car.Finish or "Standard",
                            Wheels=car.Wheels or "Stock",
                        }
                        local order=12
                        for _,category in ipairs(choices) do
                            local current=appearance[category.Id]
                            local pristine=(category.Id=="Paint" and current=="Factory")
                                or (category.Id=="Finish" and current=="Standard")
                                or (category.Id=="Wheels" and current=="Stock")
                            if pristine then
                                for _,option in ipairs(category.Options or {}) do
                                    local spec=category.Id..":"..option.Id
                                    if staged==spec then selection=option end
                                    local previewButton=PanelKit.button(card,
                                        (staged==spec and "VISUALIZANDO: " or "PRÉVIA: ")
                                        ..option.Name.." · "..option.Cost.." moedas",
                                        "dark",Vector2.new(285,43),function()
                                            previewChoice[car.Uid]=spec
                                            render()
                                        end)
                                    previewButton.LayoutOrder=order
                                    order+=1
                                end
                            end
                        end
                        if staged and selection then
                            local beforeAfter=V2ShowroomPreview.Pair(
                                card,car.VehicleModel,car,staged)
                            beforeAfter.LayoutOrder=40
                            HudParts.text(card,string.format(
                                "TOTAL A PAGAR: %d · AUMENTO DE REVENDA: +%d · custo não recuperado: %d",
                                selection.Cost,selection.ResaleBonus,
                                selection.Cost-selection.ResaleBonus),18,{
                                    Font=Theme.FontSemi,LayoutOrder=41,
                                    TextColor3=Theme.Accent,TextWrapped=true,
                                    AutomaticSize=Enum.AutomaticSize.Y,
                                    Size=UDim2.new(1,0,0,0),
                                })
                            local apply=PanelKit.button(card,"CONFIRMAR PERSONALIZAÇÃO",
                                "orange",Vector2.new(285,44),function()
                                    previewChoice[car.Uid]=nil
                                    Store.Act("UsedMarket",{
                                        Operation="Customize",Id=car.Uid,Style=staged,
                                    })
                                end)
                            apply.LayoutOrder=42
                            local cancel=PanelKit.button(card,"CANCELAR PRÉVIA (GRÁTIS)",
                                "dark",Vector2.new(285,44),function()
                                    previewChoice[car.Uid]=nil
                                    render()
                                end)
                            cancel.LayoutOrder=43
                        elseif staged then
                            previewChoice[car.Uid]=nil
                        end
                        if #(market.Showroom or {}) < (market.ShowroomCapacity or 2) then
                            local exhibit=PanelKit.button(card,
                                "EXIBIR NO SHOWROOM · 0 MOEDAS",
                                "dark",Vector2.new(285,44),function()
                                    previewChoice[car.Uid]=nil
                                    Store.Act("UsedMarket",{
                                        Operation="Showcase",Id=car.Uid,
                                    })
                                end)
                            exhibit.LayoutOrder=60
                        end
                        local sell=PanelKit.button(card,
                            "VENDER · "..tostring(car.SellPrice or 0).." MOEDAS",
                            "dark",Vector2.new(285,44),function()
                                previewChoice[car.Uid]=nil
                                Store.Act("UsedMarket",{Operation="Sell",Id=car.Uid})
                            end)
                        sell.LayoutOrder=61
                    end
                end
                financialCard(scroll,"ShowroomIntro",30,"SHOWROOM · COLEÇÃO LIMITADA",{
                    string.format("%d/%d veículos expostos · %d/3 bônus únicos de reputação recebidos",
                        #(market.Showroom or {}),market.ShowroomCapacity or 2,
                        market.ShowroomReputationEarned or 0),
                    "Cada variante exposta pela primeira vez concede +1 reputação; retirar e reexibir não dá novo bônus.",
                    "Veículos no showroom são decorativos, não ocupam boxes e não podem ser dirigidos.",
                    "Retirar da exposição é gratuito; vender é irreversível e segue o preço calculado no servidor.",
                })
                for i,car in ipairs(market.Showroom or {}) do
                    local card=financialCard(scroll,"ShowroomCar_"..car.Uid,30+i,
                        "EXPOSTO · "..string.upper(car.Name or car.Variant),{
                        "Pintura: "..tostring(car.Style)
                            .." · acabamento: "..tostring(car.Finish)
                            .." · rodas: "..tostring(car.Wheels),
                        string.format("Investimento cosmético total: %d · preço final de revenda: %d",
                            car.CosmeticSpend or 0,car.SellPrice or 0),
                        "Exposição preservada entre sessões e separada do estoque para OS.",
                    })
                    local thumb,setVehicle=HudParts.vehicleThumb(card,170,84)
                    thumb.LayoutOrder=10
                    setVehicle(car.VehicleModel)
                    if #(market.Owned or {})==0 then
                        local recall=PanelKit.button(card,"RETIRAR DA VITRINE",
                            "dark",Vector2.new(260,44),function()
                                Store.Act("UsedMarket",{Operation="Recall",Id=car.Uid})
                            end)
                        recall.LayoutOrder=20
                    end
                    local sellExhibit=PanelKit.button(card,
                        "VENDER VEÍCULO EXPOSTO · "..tostring(car.SellPrice or 0),
                        "dark",Vector2.new(285,44),function()
                            Store.Act("UsedMarket",{Operation="SellExhibit",Id=car.Uid})
                        end)
                    sellExhibit.LayoutOrder=21
                end
            end
            end -- fim da seção Mercado
        elseif id == "team" then
            -- V2-05: supervisionar até dois mecânicos sem UI sobreposta ou
            -- campos financeiros/clientes privados.
            local staff=snapshot.Staff or {Workers={},Employees=0}
            HudParts.text(scroll,string.format(
                "EQUIPE · %d contratado(s) · salário %d por mecânico a cada %d min",
                staff.Employees or 0, staff.SalaryEach or 0,
                math.floor((staff.PayEvery or 300)/60)),21,{
                    Font=Theme.FontTitle,LayoutOrder=1,TextWrapped=true,
                    AutomaticSize=Enum.AutomaticSize.Y,
                    Size=UDim2.new(1,-10,0,0),
                })
            HudParts.text(scroll,string.format(
                "Folha paga: %d moedas em %d ciclos · próximo vencimento em %d min",
                staff.TotalPaid or 0,staff.PaidCount or 0,
                math.ceil((staff.DueSeconds or 0)/60)),18,{
                    Font=Theme.FontSemi,TextColor3=Theme.Muted,LayoutOrder=2,
                    TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y,
                    Size=UDim2.new(1,-10,0,0),
                })
            HudParts.text(scroll,"Altere escala e atribuições junto à TV de ordens da sua oficina. A pausa só impede novos serviços; o atual é concluído.",17,{
                Font=Theme.FontSemi,TextColor3=Theme.Muted,LayoutOrder=3,
                TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y,
                Size=UDim2.new(1,-10,0,0),
            })
            if #(staff.Workers or {})==0 then
                HudParts.text(scroll,"Contrate mecânicos na estação física da oficina nível 1 ou superior.",21,{
                    Font=Theme.FontSemi,LayoutOrder=10,TextWrapped=true,
                    Size=UDim2.new(1,-10,0,80),
                })
            end
            for _,worker in ipairs(staff.Workers or {}) do
                local card=PanelKit.card(scroll,"Staff_"..tostring(worker.Slot))
                card.LayoutOrder=10+worker.Slot
                card.Size=UDim2.new(1,-10,0,compact and 330 or 304)
                HudParts.text(card,string.format("MECÂNICO %d · %s · %s (%d%%)",
                    worker.Slot,tostring(worker.Name),
                    worker.Status or "Descansando",worker.Progress or 0),compact and 19 or 22,{
                        Font=Theme.FontTitle,TextColor3=Theme.Accent,
                        Position=UDim2.fromOffset(14,10),
                        Size=UDim2.new(1,-28,0,44),
                        TextWrapped=true,
                    })
                HudParts.text(card,string.format(
                    "Serviços %d · receita bruta %d · qualidade média %d%% · duração média %ds",
                    worker.Completed or 0,worker.Gross or 0,
                    worker.AverageQuality or 0,worker.AverageSeconds or 0),
                    compact and 16 or 18,{
                        Font=Theme.FontSemi,TextColor3=Theme.Muted,
                        Position=UDim2.fromOffset(14,60),
                        Size=UDim2.new(1,-28,0,40),TextWrapped=true,
                    })
                local modes={"Auto","Manual","Paused"}
                local modeLabels={Auto="Automático",Manual="Manual",Paused="Pausado"}
                local modeIndex=table.find(modes,worker.Mode) or 1
                local newMode=modes[modeIndex%#modes+1]
                local control=PanelKit.button(card,"Escala: "..(modeLabels[worker.Mode] or "?"),"dark",
                    Vector2.new(compact and 160 or 190,40),function()
                        Store.Act("SetStaffPolicy",{Index=worker.Slot,Key="Mode",Value=newMode})
                    end)
                control.Position=UDim2.fromOffset(14,108)
                local focuses={"Any","Tires","Engine","Electrical","Suspension","Bodywork"}
                local labels={Any="Todas",Tires="Pneus",Engine="Motor",Electrical="Elétrica",
                    Suspension="Suspensão",Bodywork="Funilaria"}
                local focusIndex=table.find(focuses,worker.Focus) or 1
                local nextFocus=focuses[focusIndex%#focuses+1]
                local focus=PanelKit.button(card,"Foco: "..(labels[worker.Focus] or "?"),"dark",
                    Vector2.new(compact and 150 or 190,40),function()
                        Store.Act("SetStaffPolicy",{Index=worker.Slot,Key="Focus",Value=nextFocus})
                    end)
                focus.Position=UDim2.fromOffset(compact and 184 or 225,108)
                HudParts.text(card,string.format("OS atual: %s · %d aguardando na fila",
                    worker.JobId or "nenhuma",worker.Queued or 0),17,{
                    Font=Theme.FontSemi,TextColor3=Theme.Muted,
                    Position=UDim2.fromOffset(14,161),
                    Size=UDim2.new(1,-28,0,28),TextWrapped=true,
                })
                local count=0
                for _,job in ipairs(progressJobs) do
                    if count>=2 then break end
                    if not job.CollaboratorUserId and job.EmployeeAssignedSlot==worker.Slot then
                        count+=1
                        local btn=PanelKit.button(card,"Retirar da fila · "..job.VehicleName,
                            "dark",Vector2.new(compact and 300 or 370,34),function()
                                Store.Act("ClearStaffJob",{JobId=job.Id})
                            end)
                        btn.Position=UDim2.fromOffset(14,190+(count-1)*44)
                    elseif not job.CollaboratorUserId and not job.EmployeeAssignedSlot
                        and worker.Mode~="Paused" then
                        count+=1
                        local btn=PanelKit.button(card,"Atribuir · "..job.VehicleName,
                            "blue",Vector2.new(compact and 300 or 370,34),function()
                                Store.Act("AssignStaffJob",{Index=worker.Slot,JobId=job.Id})
                            end)
                        btn.Position=UDim2.fromOffset(14,190+(count-1)*44)
                    end
                end
                if count==0 then
                    HudParts.text(card,"Sem OS elegível para atribuição manual.",17,{
                        Font=Theme.FontSemi,TextColor3=Theme.Muted,
                        Position=UDim2.fromOffset(14,193),Size=UDim2.new(1,-28,0,30),
                        TextWrapped=true,
                    })
                end
                local recent=worker.Recent or {}
                if #recent>0 then
                    local last=recent[1]
                    HudParts.text(card,string.format("Último: %s · %d moedas · qualidade %d%%",
                        last.Service,last.Gross,last.Quality),17,{
                        Font=Theme.FontSemi,TextColor3=Theme.Muted,
                        Position=UDim2.fromOffset(14,compact and 288 or 275),
                        Size=UDim2.new(1,-28,0,33),TextWrapped=true,
                    })
                end
            end
        elseif id == "progress" then
\t\t\tfor index, job in ipairs(progressJobs) do
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
			local statement = RepairStatementRules.Build(snapshot.RecentSettlements)
			local pending = snapshot.PendingClaimSummary or {}
			if (pending.Count or 0) > 0 then
				HudParts.text(scroll,
					string.format("%d pagamento(s) em verificação%s",
						pending.Count, (pending.Overdue or 0) > 0 and " · há pendência com mais de 24h" or ""),
					20, { Font = Theme.FontSemi, TextColor3 = rgb(255, 190, 85),
						TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
						Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 0 })
			end
			if statement.Count > 0 then
				HudParts.text(scroll, "EXTRATO DE REPAROS · ÚLTIMOS " .. statement.Count .. " CRÉDITOS", 25, {
					Font = Theme.FontTitle, TextColor3 = Theme.Accent, LayoutOrder = 0,
				})
				local totals = stack(scroll, 4, false, 1)
				HudParts.text(totals, "TOTAL CREDITADO  +" .. tostring(statement.Total) .. " MOEDAS", 27, {
					Font = Theme.FontTitle, TextColor3 = rgb(255, 200, 70), LayoutOrder = 1,
				})
				HudParts.text(totals, string.format("Sua oficina: +%d   ·   Como contratado: +%d",
					statement.OwnerEarnings, statement.WorkerEarnings), 20, {
					Font = Theme.FontSemi, TextColor3 = Theme.Muted,
					TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2,
				})
				if statement.AverageQuality then
					HudParts.text(totals, "Qualidade média dos recibos: " .. statement.AverageQuality .. "%", 19, {
						Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 3,
					})
				end
				for index, receipt in ipairs(statement.Rows) do
					local _, content = card(scroll, index + 1,
						receipt.Role == "Worker" and rgb(115, 160, 250) or rgb(75, 215, 128),
						"Receipt_" .. index)
					local info = stack(content, 4, false, 1)
					HudParts.text(info, (receipt.Service ~= "" and receipt.Service or "Serviço realizado")
						.. " · " .. (receipt.Vehicle ~= "" and receipt.Vehicle or "Veículo"), 22, {
						Font = Theme.FontTitle, TextWrapped = true, LayoutOrder = 1,
						AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
					})
					local line = stack(info, 8, not compact, 2)
					HudParts.text(line, "+" .. receipt.Amount .. " moedas", 23, {
						Font = Theme.FontTitle, TextColor3 = rgb(255, 200, 70), LayoutOrder = 1,
					})
					HudParts.text(line, receipt.Role == "Worker" and "Contratado" or "Minha oficina", 19, {
						Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 2,
					})
					if receipt.Quality then
						HudParts.text(line, receipt.Quality .. "% qualidade", 19, {
							Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 3,
						})
					end
					HudParts.text(info, ago(receipt.At), 18, {
						Font = Theme.FontSemi, TextColor3 = Theme.Muted, LayoutOrder = 3,
					})
				end
			end
			if #history == 0 and statement.Count == 0 then
				local empty = PanelKit.emptyState(scroll, "pn_car_empty", t("or_done_empty"), t("or_done_empty_sub"))
				empty.Size = UDim2.new(1, -10, 0, 280)
			elseif #history > 0 then
				HudParts.text(scroll, "HISTÓRICO DOS CLIENTES", 24, {
					Font = Theme.FontTitle, TextColor3 = Theme.Muted, LayoutOrder = 100,
				})
			end
			for index = #history, 1, -1 do
				local entry = history[index]
				local _, content = card(scroll, #history - index + 101, rgb(70, 225, 105))
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
