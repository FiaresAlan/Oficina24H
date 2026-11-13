--!strict
-- G1/C30: executar apenas o código do projeto, nunca scripts de modelos externos.
-- Chamar imediatamente apos Clone() e antes de Parent em Workspace/ReplicatedStorage.
local AssetSafetyRules = {}

function AssetSafetyRules.StripScripts(root: Instance): number
	local removed = 0
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then
			item:Destroy()
			removed += 1
		end
	end
	return removed
end

return AssetSafetyRules
