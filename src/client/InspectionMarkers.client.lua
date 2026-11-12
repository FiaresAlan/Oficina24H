--!strict
-- Pontos de inspeção no carro do próprio jogador: indicadores visuais locais, sem RemoteEvents.
-- Renderiza apenas após o diálogo com o cliente, com progressão server-side.
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local names = {
	TirePressure = "PNEU",
	BatteryVoltage = "BATERIA",
	CoolingTemperature = "ARREFECIMENTO",
}
local markers: { [BasePart]: BillboardGui } = {}

local function makeMarker(point: BasePart, examId: string): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "LocalInspectionMarker"
	gui.Adornee = point
	gui.Size = UDim2.fromOffset(142, 42)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0.85, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 36
	gui.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.Name = "Plate"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 39, 56)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(86, 201, 251)
	stroke.Thickness = 1.5
	stroke.Parent = frame

	local text = Instance.new("TextLabel")
	text.Name = "Status"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 17
	text.TextColor3 = Color3.fromRGB(230, 249, 255)
	text.Text = names[examId] or "EXAME"
	text.TextScaled = false
	text.Parent = frame

	gui.Parent = point
	return gui
end

local function refresh()
	local vehicles = workspace:FindFirstChild("Vehicles")
	local seen: { [BasePart]: boolean } = {}
	if vehicles then
		for _, car in ipairs(vehicles:GetChildren()) do
			if car:IsA("Model") and car:GetAttribute("OwnerUserId") == player.UserId
				and car:GetAttribute("Estacionado") == true and car:GetAttribute("Etapa") == "Diagnose"
				and car:GetAttribute("InspectionReady") == true then
				local points = car:FindFirstChild("InspectionPoints")
				if points then
					for _, point in ipairs(points:GetChildren()) do
						if point:IsA("BasePart") then
							local examId = point:GetAttribute("ExamId")
							if type(examId) == "string" and names[examId] then
								seen[point] = true
								local marker = markers[point]
								if not marker then
									marker = makeMarker(point, examId)
									markers[point] = marker
								end
								local plate = marker:FindFirstChild("Plate")
								local text = plate and plate:FindFirstChild("Status")
								local inspected = point:GetAttribute("Inspected") == true
								if plate and plate:IsA("Frame") then
									plate.BackgroundColor3 = inspected and Color3.fromRGB(26, 65, 42) or Color3.fromRGB(18, 39, 56)
								end
								if text and text:IsA("TextLabel") then
									text.Text = (inspected and "✓ " or "• ") .. names[examId]
								end
							end
						end
					end
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
	task.wait(0.75)
end
