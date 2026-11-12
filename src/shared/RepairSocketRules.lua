--!strict
-- Adaptador dos pontos de ferramenta para modelos 3D.
-- O artista pode incluir Attachments "OficinaSocket_<StepId>" em qualquer BasePart do carro.
-- Sem eles, a preparação mantém os offsets genéricos da fase B2a.
local RepairPrepRules = require(script.Parent.RepairPrepRules)
local RepairSocketRules = {}

RepairSocketRules.Prefix = "OficinaSocket_"

function RepairSocketRules.Name(stepId: any): string?
	if type(stepId) ~= "string" or RepairPrepRules.Steps[stepId] == nil then
		return nil
	end
	return RepairSocketRules.Prefix .. stepId
end

function RepairSocketRules.Resolve(car: Model, root: BasePart, stepId: string, fallbackOffset: Vector3): (CFrame, string)
	local name = RepairSocketRules.Name(stepId)
	if name then
		local native = car:FindFirstChild(name, true)
		if native and native:IsA("Attachment") and native:IsDescendantOf(car)
			and native.Parent and native.Parent:IsA("BasePart") then
			return native.WorldCFrame, "ModelAttachment"
		end
	end
	return root.CFrame * CFrame.new(fallbackOffset), "DimensionFallback"
end

return RepairSocketRules
