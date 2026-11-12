--!strict
-- B2b: feedback 3D LOCAL dos passos no carro (não gera recompensas ou física autoritativa).
-- Representações industriais leves são placeholders substituíveis por malhas com sockets
-- OficinaSocket_<StepId> no modelo. Nenhuma peça aqui afeta colisão, estoque ou física do servidor.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualRules = require(ReplicatedStorage.Shared.RepairPartVisualRules)
local player = Players.LocalPlayer

type Visual = {
	Model: Model,
	StepId: string,
	State: string,
	Parts: { BasePart },
}
type Tool = { Model: Model, Parts: { BasePart }, Began: number }
local visuals: { [BasePart]: Visual } = {}
local tools: { [ProximityPrompt]: Tool } = {}

local IRON = Color3.fromRGB(100, 113, 122)
local STEEL = Color3.fromRGB(159, 169, 176)
local YELLOW = Color3.fromRGB(221, 165, 55)
local DARK = Color3.fromRGB(36, 49, 56)

local function part(parent: Model, name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Shape = shape or Enum.PartType.Block
	p.Material = Enum.Material.Metal
	p.Anchored = true
	p.CastShadow = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

local function build(point: BasePart, stepId: string, state: string): Visual
	local model = Instance.new("Model")
	model.Name = "LocalRepairFeedback_" .. stepId
	local parts: { BasePart } = {}
	local function add(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
		local p = part(model, name, size, color, shape)
		table.insert(parts, p)
		return p
	end
	if stepId == "WheelBolts" then
		for n = 1, 5 do
			add("Bolt" .. n, Vector3.new(0.16, 0.22, 0.22), STEEL, Enum.PartType.Cylinder)
		end
	elseif stepId == "JackSupport" then
		add("Foot", Vector3.new(1.18, 0.18, 1.0), DARK)
		add("Piston", Vector3.new(0.24, 0.8, 0.24), STEEL)
		add("Saddle", Vector3.new(0.88, 0.13, 0.72), YELLOW)
	elseif stepId == "HoodRelease" then
		add("Catch", Vector3.new(0.8, 0.22, 0.34), DARK)
		add("Handle", Vector3.new(0.5, 0.12, 0.18), STEEL)
	elseif stepId == "BatteryBracket" then
		add("Bracket", Vector3.new(1.08, 0.12, 0.20), STEEL)
		add("FastenerL", Vector3.new(0.18, 0.20, 0.18), IRON, Enum.PartType.Cylinder)
		add("FastenerR", Vector3.new(0.18, 0.20, 0.18), IRON, Enum.PartType.Cylinder)
	elseif stepId == "DrainPan" then
		add("PanBase", Vector3.new(1.65, 0.12, 1.1), DARK)
		add("LipF", Vector3.new(1.65, 0.18, 0.10), IRON)
		add("LipB", Vector3.new(1.65, 0.18, 0.10), IRON)
		add("LipL", Vector3.new(0.10, 0.18, 1.1), IRON)
		add("LipR", Vector3.new(0.10, 0.18, 1.1), IRON)
	end
	model.Parent = point
	return { Model = model, StepId = stepId, State = state, Parts = parts }
end

local function updateGeometry(point: BasePart, visual: Visual)
	local cf = point.CFrame
	local p = visual.Parts
	local done = visual.State == "completed"
	local alpha = done and 0.06 or 0.34
	for _, item in ipairs(p) do
		item.Transparency = alpha
	end
	if visual.StepId == "WheelBolts" then
		for i, bolt in ipairs(p) do
			local angle = (i - 1) * math.pi * 2 / #p
			bolt.CFrame = cf * CFrame.new(done and -0.28 or -0.03, math.cos(angle) * 0.48, math.sin(angle) * 0.48)
				* CFrame.Angles(0, 0, math.pi / 2 + (done and 0.22 or 0))
		end
	elseif visual.StepId == "JackSupport" then
		p[1].CFrame = cf * CFrame.new(0, -0.64, 0)
		p[2].CFrame = cf * CFrame.new(0, done and 0.08 or -0.17, 0)
		p[3].CFrame = cf * CFrame.new(0, done and 0.55 or 0.29, 0)
	elseif visual.StepId == "HoodRelease" then
		p[1].CFrame = cf
		p[2].CFrame = cf * CFrame.new(0, 0.15, -0.15)
			* CFrame.Angles(done and -math.rad(40) or 0, 0, 0)
	elseif visual.StepId == "BatteryBracket" then
		p[1].CFrame = cf * CFrame.new(0, done and 0.5 or 0, 0)
			* CFrame.Angles(0, 0, done and math.rad(40) or 0)
		p[2].CFrame = cf * CFrame.new(-0.43, 0.02, 0)
		p[3].CFrame = cf * CFrame.new(0.43, 0.02, 0)
	elseif visual.StepId == "DrainPan" then
		local shift = done and Vector3.new(0, -0.10, 0) or Vector3.zero
		p[1].CFrame = cf * CFrame.new(shift)
		p[2].CFrame = cf * CFrame.new(shift + Vector3.new(0, 0.12, -0.5))
		p[3].CFrame = cf * CFrame.new(shift + Vector3.new(0, 0.12, 0.5))
		p[4].CFrame = cf * CFrame.new(shift + Vector3.new(-0.77, 0.12, 0))
		p[5].CFrame = cf * CFrame.new(shift + Vector3.new(0.77, 0.12, 0))
	end
end

local function newTool(prompt: ProximityPrompt): Tool
	local model = Instance.new("Model")
	model.Name = "LocalMechanicTool"
	local handle = part(model, "Handle", Vector3.new(0.15, 1.25, 0.15), DARK)
	local head = part(model, "Head", Vector3.new(0.55, 0.18, 0.24), STEEL)
	model.Parent = prompt.Parent
	return { Model = model, Parts = { handle, head }, Began = os.clock() }
end

local function releaseTool(prompt: ProximityPrompt)
	local tool = tools[prompt]
	if tool then
		tools[prompt] = nil
		tool.Model:Destroy()
	end
end

local function candidate(prompt: ProximityPrompt): boolean
	local point = prompt.Parent
	if not point or not point:IsA("BasePart") then return false end
	local folder = point.Parent
	local car = folder and folder.Parent
	if not folder or folder.Name ~= "RepairPrepPoints" or not car or not car:IsA("Model") then return false end
	if car:GetAttribute("AssignedRepairUserId") ~= player.UserId or car:GetAttribute("Etapa") ~= "Repair" then return false end
	return VisualRules.ToolAllowed(prompt.Name, car:GetAttribute("PrepStepId"))
end

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
	if not candidate(prompt) then return end
	releaseTool(prompt)
	tools[prompt] = newTool(prompt)
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(releaseTool)
ProximityPromptService.PromptTriggered:Connect(releaseTool)

local function redraw()
	local folder = workspace:FindFirstChild("Vehicles")
	local camera = workspace.CurrentCamera
	local seen: { [BasePart]: boolean } = {}
	if folder and camera then
		for _, car in ipairs(folder:GetChildren()) do
			if not car:IsA("Model") or not car.PrimaryPart then continue end
			local distance = (car.PrimaryPart.Position - camera.CFrame.Position).Magnitude
			if distance > VisualRules.MaxRenderDistance then continue end
			local prep = car:FindFirstChild("RepairPrepPoints")
			if not prep then continue end
			for _, point in ipairs(prep:GetChildren()) do
				if not point:IsA("BasePart") then continue end
				local id = point:GetAttribute("StepId")
				local state = VisualRules.State(
					car:GetAttribute("Etapa"), car:GetAttribute("Estacionado"), car:GetAttribute("PrepRequired"),
					id, car:GetAttribute("PrepStepId"), point:GetAttribute("Completed"), distance
				)
				if not state or type(id) ~= "string" then continue end
				seen[point] = true
				local visual = visuals[point]
				if not visual or visual.StepId ~= id or not visual.Model.Parent then
					if visual then visual.Model:Destroy() end
					visual = build(point, id, state)
					visuals[point] = visual
				end
				visual.State = state
				updateGeometry(point, visual)
			end
		end
	end
	for point, visual in pairs(visuals) do
		if not seen[point] then
			visual.Model:Destroy()
			visuals[point] = nil
		end
	end
	for prompt, tool in pairs(tools) do
		if not prompt.Parent or not candidate(prompt) or os.clock() - tool.Began > 3 then
			releaseTool(prompt)
		else
			local point = prompt.Parent :: BasePart
			local angle = math.sin((os.clock() - tool.Began) * 16) * 0.24
			local pose = point.CFrame * CFrame.new(0, 0.65, -0.3) * CFrame.Angles(0, 0, angle)
			tool.Parts[1].CFrame = pose
			tool.Parts[2].CFrame = pose * CFrame.new(0, 0.52, 0)
		end
	end
end

-- Baixo custo: máximo de cinco pequenos conjuntos por carro próximo; atualização limitada.
local accum = 0
RunService.RenderStepped:Connect(function(dt: number)
	accum += dt
	if accum < 0.12 then return end
	accum = 0
	redraw()
end)
