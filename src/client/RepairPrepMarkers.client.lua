--!strict
-- Marcadores de preparo mecânico dentro do mundo. Somente no carro que o jogador possui
-- ou na OS do contratante; não são ferramentas físicas importadas nem autoridade de gameplay.
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local titles: { [string]: string } = {
	WheelBolts = "RODA · PORCAS",
	JackSupport = "ELEVADOR · APOIO",
	HoodRelease = "ABRIR CAPÔ",
	BatteryBracket = "BATERIA · SUPORTE",
	DrainPan = "ARREFECIMENTO · BANDEJA",
}
local markers: { [BasePart]: BillboardGui } = {}

local function create(point: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "LocalRepairPrepMarker"
	gui.Adornee = point
	gui.Size = UDim2.fromOffset(180, 43)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0.8, 0)
	gui.MaxDistance = 35
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local background = Instance.new("Frame")
	background.Name = "Plate"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(30, 52, 75)
	background.BackgroundTransparency = 0.13
	background.BorderSizePixel = 0
	background.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = background
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.Color = Color3.fromRGB(255, 206, 76)
	stroke.Thickness = 1.5
	stroke.Parent = background
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 245, 222)
	title.TextSize = 16
	title.TextScaled = false
	title.TextWrapped = true
	title.Parent = background
	gui.Parent = point
	return gui
end

local function refresh()
	local folder = workspace:FindFirstChild("Vehicles")
	local seen: { [BasePart]: boolean } = {}
	if folder then
		for _, car in ipairs(folder:GetChildren()) do
			if not car:IsA("Model") or car:GetAttribute("Etapa") ~= "Repair"
				or car:GetAttribute("Estacionado") ~= true or car:GetAttribute("PrepRequired") ~= true then
				continue
			end
			local responsible = car:GetAttribute("AssignedRepairUserId") == player.UserId
			local owned = responsible and car:GetAttribute("OwnerUserId") == player.UserId
			local contracted = responsible and car:GetAttribute("JobId") == player:GetAttribute("CollaborationJobId")
				and car:GetAttribute("OwnerUserId") == player:GetAttribute("CollaborationOwnerUserId")
			if not owned and not contracted then continue end
			local stepId = tostring(car:GetAttribute("PrepStepId") or "")
			local points = car:FindFirstChild("RepairPrepPoints")
			if not points then continue end
			for _, point in ipairs(points:GetChildren()) do
				if not point:IsA("BasePart") then continue end
				local id = point:GetAttribute("StepId")
				local isCurrent = id == stepId and stepId ~= ""
				local done = point:GetAttribute("Completed") == true
				if type(id) ~= "string" or not titles[id] or (not isCurrent and not done) then continue end
				seen[point] = true
				local marker = markers[point]
				if not marker then marker = create(point); markers[point] = marker end
				local plate = marker:FindFirstChild("Plate")
				local text = plate and plate:FindFirstChild("Title")
				local stroke = plate and plate:FindFirstChild("Border")
				if plate and plate:IsA("Frame") then
					plate.BackgroundColor3 = done and Color3.fromRGB(30, 65, 45) or Color3.fromRGB(30, 52, 75)
				end
				if text and text:IsA("TextLabel") then
					text.Text = (done and "✓ " or "E · ") .. titles[id]
				end
				if stroke and stroke:IsA("UIStroke") then
					stroke.Color = done and Color3.fromRGB(94, 207, 144) or Color3.fromRGB(255, 206, 76)
				end
			end
		end
	end
	for point, marker in pairs(markers) do
		if not seen[point] then
			marker:Destroy()
			markers[point] = nil
		end
	end
end

while true do
	refresh()
	task.wait(0.55)
end
