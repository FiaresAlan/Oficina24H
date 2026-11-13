--!strict
-- Plataforma de compra por entrada, validada por posição real no SERVIDOR.
-- A permanência sobre o pad nunca compra níveis sucessivos sem sair e voltar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Levels = require(ReplicatedStorage.Shared.WorkshopLevels)
local Rules = require(ReplicatedStorage.Shared.EquipmentUpgradeRules)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local EquipmentService = require(script.Parent.EquipmentService)
local PlotService = require(script.Parent.PlotService)
local StationService = require(script.Parent.StationService)

local Pads = {}
local live: { [number]: any } = {}
local onPurchase: ((Player, string, Instance) -> ())? = nil

function Pads.SetPurchaseHandler(callback: (Player, string, Instance) -> ())
	onPurchase = callback
end

local function create(plot: Instance, id: string): BasePart
	local folder = plot:FindFirstChild("UpgradePads")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "UpgradePads"
		folder.Parent = plot
	end
	local pad = Instance.new("Part")
	pad.Name = "Upgrade_" .. id
	pad.Size = Vector3.new(3.7, 0.16, 3.0)
	pad.Anchored, pad.CanCollide, pad.CanTouch, pad.CanQuery = true, false, false, false
	pad.Material = Enum.Material.Neon
	pad.Color = Color3.fromRGB(60, 248, 128)
	pad.Transparency = 0.2
	pad.Parent = folder
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Price"
	-- Homologação V1 (G4): tamanho em studs (largura do pad) em vez de pixels fixos. Com várias máquinas lado a
	-- lado, letreiros de 215x88 px se sobrepunham a distância e ficavam ilegíveis; agora encolhem com a distância.
	billboard.Size = UDim2.fromScale(5.4, 2.2) -- pads ficam a 6 studs: sem sobreposição
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
	billboard.MaxDistance = 35
	billboard.Parent = pad
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(26, 30, 28)
	label.BackgroundTransparency = 0.12
	label.TextColor3 = Color3.fromRGB(255, 235, 145)
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	return pad
end

function Pads.Sync(player: Player, owned: any, upgrades: any)
	local plot = PlotService.GetPlot(player)
	local origin = plot and StationService.FrameOf(plot)
	if not plot or not origin then return end
	local state = live[player.UserId]
	if state and state.Plot ~= plot then
		local old = state.Plot:FindFirstChild("UpgradePads")
		if old then old:Destroy() end
		state = nil
	end
	state = state or { Plot = plot, Entries = {} }
	live[player.UserId] = state
	local slots = Levels.EquipmentSlots(StationService.LevelOf(plot))
	local index, keep = 0, {}
	for _, id in ipairs(EquipmentService.Order) do
		if owned[id] == true then
			index += 1
			local level = Rules.Level(upgrades, owned, id)
			local models = plot:FindFirstChild("Equipment")
			local model = models and models:FindFirstChild("Eq_" .. id)
			if model and model:IsA("Model") then
				model:SetAttribute("UpgradeLevel", level)
				local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
				if anchor then
					local badge = anchor:FindFirstChild("UpgradeTier")
					if level >= 2 then
						if not badge then
							badge = Instance.new("BillboardGui")
							badge.Name = "UpgradeTier"
							badge.Size = UDim2.fromScale(3.2, 0.8) -- em studs, como o letreiro do pad
							badge.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
							badge.MaxDistance = 35
							badge.Parent = anchor
							local lbl = Instance.new("TextLabel")
							lbl.Name = "Tier"
							lbl.Size = UDim2.fromScale(1, 1)
							lbl.Font = Enum.Font.GothamBold
							lbl.TextScaled = true
							lbl.BackgroundColor3 = Color3.fromRGB(28, 34, 40)
							lbl.TextColor3 = Color3.fromRGB(245, 205, 95)
							lbl.Parent = badge
						end
						local lbl = badge:FindFirstChild("Tier")
						if lbl and lbl:IsA("TextLabel") then lbl.Text = "MÁQUINA NÍVEL " .. level end
					elseif badge then
						badge:Destroy()
					end
				end
			end
			local cost = Rules.NextCost(id, level)
			if slots[index] and cost then
				keep[id] = true
				local entry = state.Entries[id]
				local pad = entry and entry.Pad or create(plot, id)
				pad.CFrame = origin * CFrame.new(slots[index].X, 0.2, slots[index].Y - 5.5)
				pad:SetAttribute("EquipmentId", id)
				pad:SetAttribute("OwnerUserId", player.UserId)
				local gui = pad:FindFirstChild("Price")
				local label = gui and gui:FindFirstChild("Label")
				if label and label:IsA("TextLabel") then
					label.Text = string.format("↓ MELHORAR\n%s · N%d\n$%d · PISE AQUI",
						Catalog.Equipment[id].DisplayName, level + 1, cost)
				end
				if not entry then
					state.Entries[id] = { Pad = pad, WasInside = false }
				end
			end
		end
	end
	for id, entry in pairs(state.Entries) do
		if not keep[id] then entry.Pad:Destroy(); state.Entries[id] = nil end
	end
end

function Pads.Clear(player: Player)
	local state = live[player.UserId]
	if state then
		local folder = state.Plot:FindFirstChild("UpgradePads")
		if folder then folder:Destroy() end
	end
	live[player.UserId] = nil
end

local function touching(root: BasePart, pad: BasePart): boolean
	local p = pad.CFrame:PointToObjectSpace(root.Position)
	return math.abs(p.X) <= pad.Size.X * 0.5
		and math.abs(p.Z) <= pad.Size.Z * 0.5
		and p.Y >= 0.8 and p.Y <= 5.5
end

function Pads.Start()
	Players.PlayerRemoving:Connect(Pads.Clear)
	task.spawn(function()
		while true do
			task.wait(0.2)
			for userId, state in pairs(live) do
				local player = Players:GetPlayerByUserId(userId)
				local character = player and player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character:FindFirstChild("HumanoidRootPart")
				for id, entry in pairs(state.Entries) do
					local inside = player ~= nil and humanoid ~= nil and humanoid.Health > 0
						and root ~= nil and root:IsA("BasePart") and entry.Pad.Parent ~= nil
						and touching(root, entry.Pad)
					if inside and not entry.WasInside and player and onPurchase then
						entry.WasInside = true -- antes da callback, inclusive em compras instantâneas
						onPurchase(player, id, state.Plot)
					else
						entry.WasInside = inside
					end
				end
			end
		end
	end)
end

return Pads
