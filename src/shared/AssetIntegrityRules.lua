--!strict
-- G1/C31: regras de verificacao de assets. Apenas leitura; nao modifica o place.
local RepairPrepRules = require(script.Parent.RepairPrepRules)
local Rules = {}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Rules.Vehicle(instance: Instance?): ({ string }, { string })
	local errors, warnings = {}, {}
	if not instance or not instance:IsA("Model") then
		table.insert(errors, "modelo ausente ou nao e Model")
		return errors, warnings
	end
	local model = instance :: Model
	local root = model.PrimaryPart
	if not root or root.Name ~= "Raiz" or not root:IsDescendantOf(model) then
		table.insert(errors, "PrimaryPart deve ser a BasePart Raiz dentro do carro")
	elseif not root.Anchored then
		table.insert(errors, "Raiz deve estar Anchored (LotPath move a raiz por CFrame)")
	end

	local hull = model:FindFirstChild("Casco")
	if not hull or not hull:IsA("BasePart") then
		table.insert(errors, "Casco deve ser BasePart filha direta do modelo")
	elseif not hull.CanCollide then
		table.insert(errors, "Casco sem CanCollide; jogadores atravessariam o carro")
	end

	for key, low, high in ipairs({ "Largura", "Comprimento", "Altura" }) do
		local minValues = { 4, 8, 2 }
		local maxValues = { 14, 32, 9 }
		local v = model:GetAttribute(key)
		if not finite(v) or v < minValues[low] or v > maxValues[low] then
			table.insert(errors, key .. " ausente ou fora do intervalo " .. minValues[low] .. "-" .. maxValues[low])
		end
	end
	if typeof(model:GetAttribute("Motorista")) ~= "Vector3" then
		table.insert(errors, "atributo Motorista deve ser Vector3 (posicao do banco)")
	end

	local parts, joints, anchoredExtra = 0, 0, 0
	local usedSockets = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			parts += 1
			if item ~= root and item.Anchored then anchoredExtra += 1 end
		elseif item:IsA("WeldConstraint") or item:IsA("Weld") or item:IsA("Motor6D") or item:IsA("RigidConstraint") then
			joints += 1
		end
		if item.Name:sub(1, 14) == "OficinaSocket_" then
			local stepId = item.Name:sub(15)
			if RepairPrepRules.Steps[stepId] == nil then
				table.insert(warnings, "socket desconhecido: " .. item.Name)
			elseif not item:IsA("Attachment") or not item.Parent or not item.Parent:IsA("BasePart") then
				table.insert(errors, "socket " .. stepId .. " deve ser Attachment dentro de BasePart")
			elseif usedSockets[stepId] then
				table.insert(errors, "socket duplicado: " .. item.Name)
			else
				usedSockets[stepId] = true
			end
		end
	end
	if anchoredExtra > 0 then
		table.insert(errors, tostring(anchoredExtra) .. " partes extras Anchored (nao acompanham a Raiz)")
	end
	if parts > 1 and joints == 0 then
		table.insert(errors, "modelo com varias partes e nenhuma junta rigida")
	end
	if next(usedSockets) == nil then
		table.insert(warnings, "sem sockets nativos; preparo usara offsets dimensionais")
	end
	return errors, warnings
end

function Rules.Customer(instance: Instance?): { string }
	local errors = {}
	if not instance or not instance:IsA("Model") then
		return { "NPC ausente ou nao e Model" }
	end
	local model = instance :: Model
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid then
		table.insert(errors, "Humanoid ausente")
	elseif humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		table.insert(errors, "NPC deve ser R15")
	end
	if not root or not root:IsA("BasePart") or model.PrimaryPart ~= root then
		table.insert(errors, "PrimaryPart deve ser HumanoidRootPart")
	end
	local gender = model:GetAttribute("Genero")
	if gender ~= "M" and gender ~= "F" then
		table.insert(errors, "atributo Genero deve ser M ou F")
	end
	return errors
end

function Rules.Equipment(instance: Instance?): { string }
	if not instance or not instance:IsA("Model") then
		return { "equipamento nao e Model" }
	end
	if not instance.PrimaryPart then
		return { "equipamento importado sem PrimaryPart" }
	end
	return {}
end

return Rules
