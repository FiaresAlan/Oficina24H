--!strict
-- HUD de serviço em foco para telas compactas. Sem overlay, sem informação de moedas fictícia.
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local HudParts = require(script.Parent.HudParts)

local CompactHUD = {}

local function label(parent: Instance, name: string, text: string, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Theme.FontSemi
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Size = UDim2.fromOffset(100, 30)
	l.Parent = parent
	return l
end

local function num(n: number): string
	local str = tostring(math.floor(n))
	return str:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
end

function CompactHUD.new(gui: ScreenGui, onOpenOrders: () -> ())
	local summary = HudParts.panel(gui, "CompactSummary")
	summary.Size = UDim2.fromOffset(250, 70)
	summary.Position = UDim2.fromOffset(12, 12)
	summary.ZIndex = 2
	summary.Visible = false
	local icon = label(summary, "Wordmark", "24H", 20, Theme.Accent)
	icon.Font = Theme.FontTitle
	icon.Size = UDim2.fromOffset(45, 30)
	icon.Position = UDim2.fromOffset(12, 7)
	local coinsTitle = label(summary, "CoinsCaption", "SALDO", 13, Theme.Muted)
	coinsTitle.Position = UDim2.fromOffset(60, 8)
	coinsTitle.Size = UDim2.fromOffset(150, 18)
	local coins = label(summary, "Coins", "$ 0", 29, Theme.Text)
	coins.Font = Theme.FontBold
	coins.Position = UDim2.fromOffset(60, 25)
	coins.Size = UDim2.new(1, -70, 0, 34)
	local level = label(summary, "Level", "NV 01", 15, Theme.Muted)
	level.Position = UDim2.fromOffset(12, 44)
	level.Size = UDim2.fromOffset(48, 20)
	local objective = Instance.new("TextButton")
	objective.Name = "QuickObjective"
	objective.BackgroundTransparency = 1
	objective.AutoButtonColor = false
	objective.Text = ""
	objective.Size = UDim2.fromOffset(360, 74)
	objective.Position = UDim2.fromOffset(12, 90)
	objective.Visible = false
	objective.ZIndex = 2
	objective.Parent = gui
	local bg = HudParts.panel(objective, "Plate")
	bg.Size = UDim2.fromScale(1, 1)
	bg.ZIndex = 2
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.BackgroundColor3 = Theme.Accent
	accent.BorderSizePixel = 0
	accent.Size = UDim2.new(0, 4, 1, -18)
	accent.Position = UDim2.fromOffset(10, 9)
	accent.ZIndex = 3
	Kit.corner(accent, 2)
	accent.Parent = objective
	local heading = label(objective, "Action", "AGUARDANDO CLIENTE", 21, Theme.Text)
	heading.Font = Theme.FontBold
	heading.Position = UDim2.fromOffset(26, 10)
	heading.Size = UDim2.new(1, -48, 0, 28)
	heading.ZIndex = 3
	local description = label(objective, "Detail", "Novos serviços aparecerão aqui", 16, Theme.Muted)
	description.Position = UDim2.fromOffset(26, 40)
	description.Size = UDim2.new(1, -45, 0, 25)
	description.ZIndex = 3
	local arrow = label(objective, "Open", "›", 28, Theme.Accent)
	arrow.Size = UDim2.fromOffset(18, 40)
	arrow.AnchorPoint = Vector2.new(1, 0.5)
	arrow.Position = UDim2.new(1, -10, 0.5, 0)
	arrow.ZIndex = 3
	objective.Activated:Connect(onOpenOrders)

	return {
		Root = summary,
		Objective = objective,
		Fit = function(width: number, compact: boolean, hasDrawer: boolean)
			summary.Visible = compact
			objective.Visible = compact and not hasDrawer
			summary.Size = UDim2.fromOffset(math.min(250, width - 158), 70)
			objective.Size = UDim2.fromOffset(math.min(360, width - 26), 74)
		end,
		SetStats = function(coinsValue: number, businessLevel: number, reputation: number)
			coins.Text = "$ " .. num(coinsValue)
			level.Text = string.format("NV %02d", businessLevel)
			-- Reputação detalhada fica em Perfil, sem comprimir o contador principal.
			summary:SetAttribute("ReputationValue", reputation)
		end,
		SetObjective = function(snapshot: any)
			local active
			local waiting
			for _, job in ipairs(snapshot.Jobs or {}) do
				if job.Status == "InProgress" then active = job break end
				if job.Status == "Available" and not waiting then waiting = job end
			end
			if active then
				if not active.Diagnosed then
					heading.Text = "DIAGNOSTICAR"
					description.Text = tostring(active.VehicleName or "Veículo") .. " · converse com o cliente"
				elseif active.PrepRequired and not active.PrepComplete then
					heading.Text = "PREPARAR VEÍCULO"
					description.Text = tostring(active.VehicleName or "Veículo") .. " · siga os marcadores"
				else
					heading.Text = "EXECUTAR REPARO"
					description.Text = tostring(active.ServiceName or active.VehicleName or "Serviço") .. " · abra a OS"
				end
				accent.BackgroundColor3 = Theme.Accent
			elseif waiting then
				heading.Text = "CLIENTE AGUARDANDO"
				description.Text = tostring(waiting.VehicleName or "Veículo") .. " · ver ordem de serviço"
				accent.BackgroundColor3 = Theme.Blue
			else
				heading.Text = "OFICINA DISPONÍVEL"
				description.Text = "Acompanhe os próximos atendimentos"
				accent.BackgroundColor3 = Theme.Green
			end
		end,
	}
end

return CompactHUD
