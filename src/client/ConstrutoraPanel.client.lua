--!strict
-- Tela da Construtora: abre no prompt "Ampliar oficina" do prédio da Construtora (atributo OpensPanel = "construtora").
-- Mostra o prédio atual, o próximo nível e a lista de requisitos (verde = ok, vermelho = falta) com o botão de compra.
-- O servidor confere tudo de novo (WorkshopService.UpgradeWorkshop); aqui só se exibe o snapshot.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Store = require(script.Parent:WaitForChild("UI"):WaitForChild("Store"))

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "Construtora"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local NAVY = Color3.fromRGB(16, 24, 44)
local CARD = Color3.fromRGB(26, 38, 66)
local GREEN = Color3.fromRGB(80, 220, 120)
local RED = Color3.fromRGB(240, 90, 80)
local GOLD = Color3.fromRGB(255, 196, 40)

local function corner(inst: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font, order: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, size + 6)
	t.AutomaticSize = Enum.AutomaticSize.Y -- textos longos quebram linha sem cortar
	t.Font = font
	t.TextSize = size
	t.TextColor3 = color
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.Text = text
	t.LayoutOrder = order
	t.Parent = parent
	return t
end

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(460, 470)
frame.BackgroundColor3 = NAVY
frame.Parent = gui
corner(frame, 16)
local stroke = Instance.new("UIStroke")
stroke.Color = GOLD
stroke.Thickness = 2
stroke.Parent = frame
local scale = Instance.new("UIScale")
scale.Parent = frame
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 20), UDim.new(0, 20), UDim.new(0, 16), UDim.new(0, 16)
pad.Parent = frame
local inner = Instance.new("Frame") -- conteúdo em lista; o botão fechar fica fora dela
inner.BackgroundTransparency = 1
inner.Size = UDim2.fromScale(1, 1)
inner.Parent = frame
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = inner

local close = Instance.new("TextButton")
close.Name = "Fechar"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, 8, 0, -6)
close.Size = UDim2.fromOffset(36, 36)
close.BackgroundColor3 = CARD
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.Font = Enum.Font.GothamBlack
close.TextSize = 18
close.Parent = frame
corner(close, 10)

local body = Instance.new("Frame")
body.BackgroundTransparency = 1
body.Size = UDim2.new(1, 0, 1, -70)
body.LayoutOrder = 1
body.Parent = inner
local bodyList = Instance.new("UIListLayout")
bodyList.Padding = UDim.new(0, 6)
bodyList.SortOrder = Enum.SortOrder.LayoutOrder
bodyList.Parent = body

local buy = Instance.new("TextButton")
buy.Size = UDim2.new(1, 0, 0, 52)
buy.LayoutOrder = 2
buy.Font = Enum.Font.GothamBlack
buy.TextSize = 20
buy.TextColor3 = Color3.new(1, 1, 1)
buy.Parent = inner
corner(buy, 12)

local function render()
	for _, c in ipairs(body:GetChildren()) do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	local snap = Store.Snapshot
	local info = snap and snap.Workshop
	label(body, "CONSTRUTORA", 26, GOLD, Enum.Font.GothamBlack, 1)
	if not info then
		label(body, "Registre sua oficina para poder ampliá-la.", 18, Color3.new(1, 1, 1), Enum.Font.GothamBold, 2)
		buy.Visible = false
		return
	end
	label(body, string.format("Seu prédio: %s · %d box(es) · equipamentos %d/%d", info.Name, info.Bays, info.Equipment, info.MaxEquipment), 17, Color3.fromRGB(200, 215, 240), Enum.Font.GothamBold, 2)
	local nextInfo = info.Next
	if not nextInfo then
		label(body, "Sua oficina já é a maior do bairro!", 20, GREEN, Enum.Font.GothamBlack, 3)
		buy.Visible = false
		return
	end
	label(body, string.format("Próxima obra: %s · %d boxes%s", nextInfo.Name, nextInfo.Bays,
		nextInfo.MaxEmployees > 0 and string.format(" · até %d mecânico(s)", nextInfo.MaxEmployees) or ""), 20, Color3.new(1, 1, 1), Enum.Font.GothamBlack, 3)
	for i, row in ipairs(nextInfo.Rows or {}) do
		local line = Instance.new("Frame")
		line.Size = UDim2.new(1, 0, 0, 34)
		line.BackgroundColor3 = CARD
		line.LayoutOrder = 3 + i
		line.Parent = body
		corner(line, 8)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromOffset(12, 0)
		t.Size = UDim2.new(1, -24, 1, 0)
		t.Font = Enum.Font.GothamBold
		t.TextSize = 17
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextColor3 = row.Ok and GREEN or RED
		t.Text = string.format("%s  %s: %d / %d", row.Ok and "✔" or "✖", row.Label, math.floor(row.Have), row.Need)
		t.Parent = line
	end
	buy.Visible = true
	buy.Text = nextInfo.CanBuy and string.format("Ampliar por %d moedas", nextInfo.Cost) or "Ainda faltam requisitos"
	buy.BackgroundColor3 = nextInfo.CanBuy and Color3.fromRGB(40, 160, 80) or Color3.fromRGB(70, 76, 90)
	buy.AutoButtonColor = nextInfo.CanBuy
end

buy.Activated:Connect(function()
	local info = Store.Snapshot and Store.Snapshot.Workshop
	if info and info.Next and info.Next.CanBuy then
		Store.Act("UpgradeWorkshop", {})
	end
end)
close.Activated:Connect(function()
	gui.Enabled = false
end)

local function fit()
	local camera = workspace.CurrentCamera
	local v = camera and camera.ViewportSize or Vector2.new(1280, 720)
	scale.Scale = math.clamp(math.min(v.X / 560, v.Y / 560), 0.6, 1.2)
end

local function open()
	fit()
	Store.Refresh()
	render()
	gui.Enabled = true
end
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	if prompt:GetAttribute("OpensPanel") == "construtora" then
		open()
	end
end)
-- também abre por atributo do jogador (QA no Studio e atalhos futuros)
player:GetAttributeChangedSignal("AbrirConstrutora"):Connect(function()
	if player:GetAttribute("AbrirConstrutora") then
		player:SetAttribute("AbrirConstrutora", nil)
		open()
	end
end)
Store.Changed.Event:Connect(function()
	if gui.Enabled then
		render()
	end
end)
-- longe da Construtora a tela fecha sozinha
task.spawn(function()
	while true do
		task.wait(1)
		if gui.Enabled then
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			local areas = workspace:FindFirstChild("PublicAreas")
			local block = areas and areas:FindFirstChild("DistribuidoraEquipamentos")
			if hrp and hrp:IsA("BasePart") and block and block:IsA("BasePart") and (hrp.Position - block.Position).Magnitude > 90 then
				gui.Enabled = false
			end
		end
	end
end)
