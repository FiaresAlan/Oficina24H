-- Runner de regressão no Studio Edit; falha de require não é mais contabilizada como zero falhas.
-- Retorna resultado final de aprovação e lista de falhas/avisos para decisão de homologação.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local suites = {
	"CatalogTest", "CustomerTest", "RepairTest", "AllServiceActionFlowTest", "JobExitRulesTest", "RepairCommitGuardTest", "SnapshotCacheRulesTest", "DiagnosisEvidenceTest", "InspectionPointTest",
	"RepairPrepTest", "RepairSocketTest", "RepairPartVisualTest", "HudLayoutTest", "CompactHudTest",
	"ServiceFocusTest", "RepairOperationsTest", "WorkshopProceduresTest", "RepairActionRulesTest", "RepairReceiptTest", "SettlementLedgerTest", "SettlementDeliveryRulesTest", "SettlementClaimRulesTest", "SettlementClaimAuditRulesTest", "OwnerSettlementProofRulesTest", "OwnerProofSweepRulesTest", "WorkerSettlementProofRulesTest", "WorkerProofArchiveRulesTest", "RepairStatementTest", "CollaborationRulesTest",
	"RepairSessionTest", "LocationTest", "RivalRulesTest", "PlotTest", "PersistenceTest",
	"ProgressTest", "EquipmentUpgradeTest", "StaffAssignmentTest", "StudioPlaceAudit",
}
local output = {}
local totalPass, totalFail, totalWarn = 0, 0, 0

-- O Studio mantém require em cache; usa cópia temporária das Shared para as regras novas.
local original = ReplicatedStorage:FindFirstChild("Shared")
local fresh
if original then
	fresh = original:Clone()
	original.Name = "Shared_original"
	fresh.Name = "Shared"
	fresh.Parent = ReplicatedStorage
end

for _, name in ipairs(suites) do
	local source = ServerStorage:FindFirstChild("Tools")
	source = source and source:FindFirstChild(name)
	local successes, failures, warnings = 0, {}, {}
	if not source or not source:IsA("ModuleScript") then
		table.insert(failures, "AUSENTE: suite " .. name)
	else
		-- pcall em todos os passos: erro de compilação/execução vira uma falha explícita.
		local ok, report = pcall(function()
			local c = source:Clone()
			local text = source.Source
			c.Source = "local ok, r = xpcall(function()\n" .. text ..
				"\nend, debug.traceback)\nreturn (ok and '' or 'ERRO: ') .. tostring(r)"
			c.Parent = ServerStorage
			local success, response = pcall(require, c)
			c:Destroy()
			if not success then error(tostring(response)) end
			return tostring(response)
		end)
		if not ok then
			table.insert(failures, "ERRO: " .. tostring(report))
		else
			for line in tostring(report):gmatch("[^\n]+") do
				if line:find("^PASS") then
					successes += 1
				elseif line:find("^FAIL") or line:find("^ERRO") or line:find("^AUSENTE") then
					table.insert(failures, line)
				elseif line:find("^WARN") then
					table.insert(warnings, line)
				end
			end
			if successes == 0 and #failures == 0 then
				table.insert(failures, "ERRO: " .. name .. " não produziu resultados verificáveis")
			end
		end
	end
	totalPass += successes
	totalFail += #failures
	totalWarn += #warnings
	table.insert(output, string.format("%s: %d OK, %d FALHAS, %d AVISOS", name, successes, #failures, #warnings))
	for _, failure in ipairs(failures) do table.insert(output, "  " .. failure) end
	for _, warning in ipairs(warnings) do table.insert(output, "  " .. warning) end
end

if fresh then
	fresh:Destroy()
	original.Name = "Shared"
end

local status = totalFail == 0 and "PASSOU (somente suíte Edit)" or "REPROVADO — corrigir antes de integrar"
return string.format("%s | %d verificações OK | %d falhas | %d avisos\n", status, totalPass, totalFail, totalWarn)
	.. table.concat(output, "\n")
