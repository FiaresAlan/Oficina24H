--!strict
-- Estado visual de props locais: sem autoridade de reparo, recompensas ou persistência.
local RepairPrepRules = require(script.Parent.RepairPrepRules)
local RepairPartVisualRules = {}

RepairPartVisualRules.MaxRenderDistance = 90

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function RepairPartVisualRules.State(
	stage: any, parked: any, prepRequired: any, stepId: any,
	currentStep: any, completed: any, distance: any
): string?
	if stage ~= "Repair" or parked ~= true or prepRequired ~= true then return nil end
	if type(stepId) ~= "string" or RepairPrepRules.Steps[stepId] == nil then return nil end
	if not finite(distance) or distance < 0 or distance > RepairPartVisualRules.MaxRenderDistance then return nil end
	if completed == true then return "completed" end
	if stepId == currentStep then return "active" end
	return nil
end

function RepairPartVisualRules.ToolAllowed(promptName: any, activeStep: any): boolean
	local step = RepairPrepRules.FromPrompt(promptName)
	return step ~= nil and step == activeStep
end

return RepairPartVisualRules
