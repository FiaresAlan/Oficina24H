#!/usr/bin/env python3
"""Fast, dependency-free repository contract checks.

This is NOT a Luau interpreter and does not replace Studio RunAllTests.
It catches missing mappings, sync paths and test registrations before a Rojo build.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHARED = ROOT / "src" / "shared"
CLIENT = ROOT / "src" / "client"
TOOLS = ROOT / "tools"
failures: list[str] = []
passed = 0


def check(label: str, condition: bool) -> None:
    global passed
    if condition:
        passed += 1
        print(f"PASS {label}")
    else:
        failures.append(label)
        print(f"FAIL {label}")


def text(path: Path) -> str:
    if not path.is_file():
        failures.append(f"Missing file: {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8")


project = json.loads(text(ROOT / "default.project.json"))
check("Rojo mapping: ReplicatedStorage.Shared", project["tree"]["ReplicatedStorage"]["Shared"]["$path"] == "src/shared")
check("Rojo mapping: ServerScriptService.Server", project["tree"]["ServerScriptService"]["Server"]["$path"] == "src/server")
check("Rojo mapping: StarterPlayerScripts.Client", project["tree"]["StarterPlayer"]["StarterPlayerScripts"]["Client"]["$path"] == "src/client")
check("Rojo mapping: Studio Tools", project["tree"]["ServerStorage"]["Tools"]["$path"] == "tools")

catalog = text(SHARED / "Catalog.lua")
block = catalog.split("Catalog.Defects = {", 1)[-1].split("\nCatalog.Services = {", 1)[0]
ids = re.findall(r"^ {4}([A-Za-z0-9]+) = \{", block, flags=re.MULTILINE)
check("catalogue defines 15 unique defects", len(ids) == len(set(ids)) == 15)

evidence = text(SHARED / "DiagnosisEvidence.lua")
inspection = text(SHARED / "InspectionPointRules.lua")
procedures = text(ROOT / "src" / "server" / "WorkshopProcedures.lua")
operations = text(ROOT / "src" / "server" / "RepairOperations.lua")
ui = text(CLIENT / "UI" / "OperationRepairGame.lua")
for defect in ids:
    check(f"{defect}: has diagnosis mapping", re.search(rf"\b{defect}\s*=", evidence) is not None)
    check(f"{defect}: has repair procedure", defect in procedures or defect in operations)

exam_ids = [
    "TirePressure", "BatteryVoltage", "CoolingTemperature", "WheelInspection",
    "BrakeInspection", "ChassisInspection", "EngineScan", "CircuitTest", "BodySurface",
]
for exam in exam_ids:
    check(f"{exam}: evidence + inspection", exam in evidence and exam in inspection)

for mode in ("Tire", "Battery", "Cooling", "Sequence", "Calibration", "Circuit", "Surface"):
    check(f"{mode}: client + server", f'Mode == "{mode}"' in ui and mode in operations + procedures)

check("diagnosis must require evidence", "HasRelevantExam" in text(ROOT / "src" / "server" / "WorkshopService.lua"))
check("server evaluates new repair families", "WorkshopProcedures.Evaluate" in operations)
# Homologação V1: gabaritos dos minijogos não podem ficar em ReplicatedStorage (exploit lê o módulo).
check("repair answer keys stay server-only (not in src/shared)",
      not (SHARED / "WorkshopProcedures.lua").exists() and not (SHARED / "RepairOperations.lua").exists())
check("client never requires the server answer-key modules",
      all("WorkshopProcedures" not in f.read_text(encoding="utf-8") and "RepairOperations" not in f.read_text(encoding="utf-8")
          for f in (ROOT / "src" / "client").rglob("*.lua")))
check("unvalidated remote finish removed from Orders panel", 'Store.Act("CompleteJob"' not in text(CLIENT / "UI" / "Panels" / "Orders.lua"))
runner = text(TOOLS / "RunAllTests.luau")
suite_ids = re.findall(r'"([A-Za-z0-9_]+Test|StudioPlaceAudit)"', runner)
check("runner references registered suites", len(suite_ids) >= 18)
check("runner has no duplicate suite names", len(set(suite_ids)) == len(suite_ids))
for suite in suite_ids:
    check(f"tool exists: {suite}", (TOOLS / f"{suite}.luau").is_file())
check("runner includes StudioPlaceAudit", "StudioPlaceAudit" in suite_ids)
snapshot_rules = text(SHARED / "SnapshotCacheRules.lua")
main_src = text(ROOT / "src" / "server" / "Main.server.lua")
check("C27: generation-aware snapshot cache avoids stale second copy",
      "function Cache.Invalidate" in snapshot_rules
      and "function Cache.Get" in snapshot_rules
      and "state.Generation == generation" in snapshot_rules
      and "SnapshotCacheRules.Get(snapshotStates" in main_src
      and "lastSnapshotBuild" not in main_src)
check("C27: prompts/actions/upgrades and logout invalidate snapshot",
      main_src.count("invalidateSnapshot(player.UserId)") >= 6
      and "SnapshotCacheRules.Clear(snapshotStates, player.UserId)" in main_src)
check("C27: snapshot coherence regression registered",
      '"SnapshotCacheRulesTest"' in runner
      and (TOOLS / "SnapshotCacheRulesTest.luau").is_file())
check("V1 G5: RepairAction and snapshot rebuilds have per-second budgets, ACK echo sanitized",
      "RequestBudgetRules.Take(repairActionBudget" in main_src
      and "RequestBudgetRules.Take(snapshotBuildBudget" in main_src
      and "RequestBudgetRules.EchoString(payload.JobId)" in main_src
      and "RequestBudgetRules.Clear(repairActionBudget, player.UserId)" in main_src
      and '"RequestBudgetRulesTest"' in runner
      and (TOOLS / "RequestBudgetRulesTest.luau").is_file())
guard = text(SHARED / "RepairCommitGuard.lua")
workshop_c28 = text(ROOT / "src" / "server" / "WorkshopService.lua")
check("C28: revalidate same job/actor after worker claim Save yield",
      "currentJob ~= expectedJob" in guard
      and "CollaborationRules.IsAuthorized(currentJob, actorUserId)" in guard
      and "currentJob.CollaborationSplitPercent == expectedSplit" in guard
      and "RepairCommitGuard.CanSettle(job, Jobs[jobId]" in workshop_c28
      and workshop_c28.index("if not DataService.Save(player) then") < workshop_c28.index("RepairCommitGuard.CanSettle(job, Jobs[jobId]") < workshop_c28.index("DataService.SettleRepairOwnerOnce(workshopOwner, jobId")
      and "job.Status = \"Completed\"" in workshop_c28)
check("C28: orphan claim cleanup on save failure and removed owner",
      workshop_c28.count("DataService.DiscardWorkerClaim(player, jobId, session.Token)") >= 3
      and "task.spawn(DataService.Save, player)" in workshop_c28)
check("C28: guard unit suite registered",
      '"RepairCommitGuardTest"' in runner
      and (TOOLS / "RepairCommitGuardTest.luau").is_file())
scene = text(SHARED / "VehicleSceneRules.lua")
arrival_c29 = text(ROOT / "src" / "server" / "CustomerArrivalService.lua")
vehicle_c29 = text(ROOT / "src" / "server" / "VehicleService.lua")
check("C29: cancelled arrivals do not spawn late vehicles",
      "function Rules.IsCurrentArrival" in scene
      and "if not VehicleSceneRules.IsCurrentArrival(states, job.Id, state) then return end" in arrival_c29
      and "if npc then npc:Destroy() end" in arrival_c29
      and "car:Destroy()" in arrival_c29)
check("C29: lingering curb scenes are cleared for owner on disconnect",
      "for key, entry in pairs(lingering) do" in arrival_c29
      and "VehicleSceneRules.IsOwnedBy(entry, ownerUserId)" in arrival_c29
      and "entry.Car.Parent == arrivals" in arrival_c29)
check("C29: departing workshop cars are tracked and cleared",
      "local departing:" in vehicle_c29
      and "departing[car] = {" in vehicle_c29
      and "for car, scene in pairs(departing) do" in vehicle_c29
      and "VehicleSceneRules.IsOwnedBy(scene, userId)" in vehicle_c29
      and "scene.Bay:SetAttribute(\"JobId\", nil)" in vehicle_c29)
check("C29: lifecycle regressions registered",
      '"VehicleSceneRulesTest"' in runner
      and (TOOLS / "VehicleSceneRulesTest.luau").is_file())
check("C29: departing curb cars tracked beyond slot reservation",
      "local curbDeparting:" in arrival_c29
      and "curbDeparting[car] = {" in arrival_c29
      and "for car, scene in pairs(curbDeparting) do" in arrival_c29
      and "curbDeparting[car] = nil" in arrival_c29)
check("C29: QA guide for arrival and departure present",
      (ROOT / "docs" / "TESTE_C29_CENAS_CLIENTES_DESCONEXAO_2026-11-13.md").is_file()
      and "VehicleSceneRules" in text(ROOT / "docs" / "TESTE_C29_CENAS_CLIENTES_DESCONEXAO_2026-11-13.md"))
check("C28: QA and release gates documented",
      (ROOT / "docs" / "TESTE_C28_GUARDA_REPARO_COLABORATIVO_2026-11-13.md").is_file()
      and (ROOT / "docs" / "PORTOES_FINALIZACAO_V1_2026-11-13.md").is_file())
check("C27: snapshot coherence QA guide exists",
      (ROOT / "docs" / "TESTE_C27_CACHE_SNAPSHOT_HUD_2026-11-13.md").is_file()
      and "lastSnapshotBuild" in text(ROOT / "docs" / "TESTE_C27_CACHE_SNAPSHOT_HUD_2026-11-13.md"))
job_exit = text(SHARED / "JobExitRules.lua")
service_flow = text(TOOLS / "AllServiceActionFlowTest.luau")
check("C26: logout never leaves owner jobs available without a vehicle",
      "function JobExitRules.Action" in job_exit
      and 'return "RemoveOwner"' in job_exit
      and "JobExitRules.Action(job, userId)" in text(ROOT / "src" / "server" / "WorkshopService.lua")
      and 'job.Status = "Available"' not in text(ROOT / "src" / "server" / "WorkshopService.lua").split(
          "function WorkshopService.PlayerLeft", 1)[-1].split("function WorkshopService.DispatchCustomers", 1)[0])
check("C26: 15 real incremental action paths tested",
      "for defectId, defect in pairs(Catalog.Defects)" in service_flow
      and "Actions.Apply(plan, state, cmd)" in service_flow
      and "Actions.FinalInput(plan, state)" in service_flow
      and "Operations.Evaluate(plan, input, time, mods)" in service_flow
      and "count == 15" in service_flow)
check("C26: gameplay and job-exit suites registered",
      '"AllServiceActionFlowTest"' in runner and '"JobExitRulesTest"' in runner
      and (TOOLS / "AllServiceActionFlowTest.luau").is_file()
      and (TOOLS / "JobExitRulesTest.luau").is_file())
check("C26: real QA guide for all 15 service modes exists",
      (ROOT / "docs" / "TESTE_C26_CICLO_OS_15_SERVICOS_2026-11-13.md").is_file()
      and "| Overheating |" in text(ROOT / "docs" / "TESTE_C26_CICLO_OS_15_SERVICOS_2026-11-13.md")
      and "| EngineOverhaul |" in text(ROOT / "docs" / "TESTE_C26_CICLO_OS_15_SERVICOS_2026-11-13.md"))
# Repair C5: the operation UI must not pay from an unrecorded final form.
action_rules = text(SHARED / "RepairActionRules.lua")
workshop = text(ROOT / "src" / "server" / "WorkshopService.lua")
main = text(ROOT / "src" / "server" / "Main.server.lua")
store = text(CLIENT / "UI" / "Store.lua")
check("incremental repair rules exist", "function RepairActionRules.Apply" in action_rules)
check("server reconstructs final input", "RepairActionRules.FinalInput(session.Plan, session.Progress)" in workshop)
check("server issues session token", 'GenerateGUID(false)' in workshop)
check("server validates repair actions", "function WorkshopService.RepairAction" in workshop)
check("remote sends revision acknowledgements", '"RepairActionAck"' in main and '"RepairAction"' in main)
check("client receives server ack", "Store.RepairActionAck.Event:Connect" in ui)
check("operation UI attaches session token", "input.Token = sessionToken" in ui)
check("timing repair remains supported with durable session token",
      "RepairRules.Evaluate(session.Plan, presses, elapsed, mods)" in workshop
      and "Token = game:GetService(\"HttpService\"):GenerateGUID(false)" in workshop
      and "input.Token = sessionToken" in text(CLIENT / "UI" / "RepairGame.lua"))

# C6: a mesma ação aceita pode ser reenviada com segurança sob alta latência.
session_rules = text(SHARED / "RepairSessionRules.lua")
check("replay de operação disponível", "function RepairActionRules.IsReplay" in action_rules)
check("replay não é reaplicado pelo servidor", "RepairActionRules.IsReplay(session.Progress, command)" in workshop)
check("servidor verifica proximidade antes de ACK repetido",
      workshop.find("checkRepairable(player, jobId)", workshop.find("function WorkshopService.RepairAction"))
      < workshop.find("RepairActionRules.IsReplay(session.Progress, command)", workshop.find("function WorkshopService.RepairAction")))
check("cancelamento exige identificação válida", "RepairSessionRules.CanCancel(session, jobId, token)" in workshop)
check("remoto encaminha token ao cancelamento", "CancelRepair(player, payload.JobId, payload.Token)" in main)
check("ACK identifica revisão da solicitação", "RequestRevision" in main and "payload.RequestRevision ~= pendingAction.Revision" in ui)
check("cliente faz retransmissão idempotente", "local function transmit(attempt: number)" in ui)
check("cliente envia token ao cancelar", 'Store.Act("CancelRepair", { JobId = jobId, Token = sessionToken })' in ui)
check("regressões de rede registradas", (TOOLS / "RepairActionRulesTest.luau").is_file()
      and (TOOLS / "RepairSessionTest.luau").is_file())

# C7: recuperar resultado é uma leitura privada, nunca uma segunda liquidação.
receipt_rules = text(SHARED / "RepairReceiptRules.lua")
check("receipt bounded by time and per-user count",
      "RepairReceiptRules.TtlSeconds" in receipt_rules and "RepairReceiptRules.MaxPerPlayer" in receipt_rules)
check("receipt returns defensive copy", "return clonePayload(entry.Payload)" in receipt_rules)
check("receipt tests in runner", '"RepairReceiptTest"' in runner
      and (TOOLS / "RepairReceiptTest.luau").is_file())
check("server keeps receipt before delivering after durable save",
      "RepairReceiptRules.Remember(receipts, jobId, session.Token, receiptPayload" in workshop
      and 'entry.Receipt = receiptPayload' not in workshop
      and 'entry.Delegated, entry.Receipt = delegated, receiptPayload' in workshop
      and "return confirmDelivery(entry)" in workshop
      and 'eventSender(entry.Worker, "RepairDone", entry.Receipt)' in workshop)
check("server duplicate FinishRepair returns receipt without settlement",
      "Entrega já concluída. Comprovante recuperado." in workshop)
check("server read-only outcome query",
      "function WorkshopService.CheckRepairOutcome" in workshop
      and "RepairReceiptRules.Lookup(RepairReceipts[userId]" in workshop)
check("server queries do not call FinishRepair",
      'action == "CheckRepairResult"' in main and '"RepairOutcome"' in main)
check("client consumes private repair outcome", "Store.RepairOutcome.Event:Connect" in ui
      and "Store.RepairOutcome:Fire(payload)" in store)
check("both repair modes validate session tokens before consuming parts",
      "RepairSessionRules.MatchesFinish(session, jobId, presses)" in workshop
      and "function RepairSessionRules.MatchesFinish" in session_rules)
check("timing UI correlates results and queries durable outcome",
      'Store.Act("CheckRepairResult", { JobId = jobId, Token = sessionToken })'
      in text(CLIENT / "UI" / "RepairGame.lua")
      and 'payload.Token ~= sessionToken' in text(CLIENT / "UI" / "RepairGame.lua"))
check("both repair modes use durable delivery path, no direct coin fallback",
      'local ownerSaved = DataService.Save(workshopOwner)' not in workshop
      and 'DataService.AddCoins(player, actorPay' not in workshop)
check("client checks receipt before resending a finish",
      'Store.Act("CheckRepairResult"' in ui
      and 'payload.Status == "Completed"' in ui and 'payload.Status == "Active"' in ui)
check("client result correlated with job and token",
      "payload.JobId ~= jobId or payload.Token ~= sessionToken" in ui)
# C8: per-profile persistent settlement idempotency (NOT multi-user atomicity).
ledger = text(SHARED / "SettlementLedgerRules.lua")
data_service = text(ROOT / "src" / "server" / "DataService.lua")
check("ledger bounded and sanitized", "SettlementLedgerRules.MaxEntries" in ledger and "function SettlementLedgerRules.Sanitize" in ledger)
check("ledger persists across additive profile schema v12", "local SCHEMA_VERSION = 13" in data_service
      and "RepairLedger = {}" in data_service
      and "SettlementLedgerRules.Sanitize(data.RepairLedger)" in data_service)
check("ledger credit idempotency", "function DataService.CreditRepairOnce" in data_service
      and "SettlementLedgerRules.Record(profile.RepairLedger" in data_service)
check("credited repair state recoverable", "function DataService.GetRepairReceipt" in data_service
      and "DataService.GetRepairReceipt(player, jobId, token)" in workshop)
check("server uses guarded repair credit", "DataService.CreditRepairOnce(player, jobId, session.Token" in workshop)
check("server attaches receipt to credited entry",
      "DataService.AttachRepairReceipt(player, jobId, session.Token" in workshop)
check("server gates repair delivery on both profile saves",
      "SettlementDeliveryRules.Ready(entry)" in workshop
      and 'SettlementDeliveryRules.MarkSaved(entry, "Owner", DataService.Save(entry.Owner))' in workshop
      and "DataService.Save(entry.Worker)" in workshop
      and 'eventSender(entry.Worker, "RepairDone", entry.Receipt)' in workshop)
check("processing outcome takes priority over uncommitted in-memory receipt",
      'if SettlementDeliveryRules.Matches(settling, jobId, token) then' in workshop
      and workshop.index('if SettlementDeliveryRules.Matches(settling, jobId, token) then')
      < workshop.index("RepairReceiptRules.Lookup(RepairReceipts[userId]"))
check("failed persistence does not emit completed result",
      'retryDelivery(entry)' in workshop and 'return false, "Pagamento em processamento' in workshop)
check("missing profile does not claim saved",
      'if not Profiles[userId] then' in data_service and "return false" in data_service)
check("recovery state tests in runner",
      '"SettlementDeliveryRulesTest"' in runner
      and (TOOLS / "SettlementDeliveryRulesTest.luau").is_file())
check("ledger test is registered", '"SettlementLedgerTest"' in runner
      and (TOOLS / "SettlementLedgerTest.luau").is_file())
# C9: financial statement in Orders shows credited values, without exposing tokens.
statement = text(SHARED / "RepairStatementRules.lua")
orders = text(CLIENT / "UI" / "Panels" / "Orders.lua")
check("profile snapshot does not replicate ledger tokens",
      "profileView.RepairLedger = nil" in workshop)
check("snapshot returns sanitized last settlements",
      "RecentSettlements = DataService.RecentRepairSettlements(player, 12)" in workshop)
check("statement categorizes own and worker income",
      "WorkerEarnings = worker" in statement and "OwnerEarnings = own" in statement)
check("UI uses statement module for completed orders",
      "RepairStatementRules.Build(snapshot.RecentSettlements)" in orders)
check("UI separates paid receipts and customer history",
      "EXTRATO DE REPAROS" in orders and "HISTÓRICO DOS CLIENTES" in orders)
check("UI adapts receipt row to mobile compact",
      "stack(info, 8, not compact, 2)" in orders)
check("statement test connected to runner",
      '"RepairStatementTest"' in runner and (TOOLS / "RepairStatementTest.luau").is_file())

# C12/C13: pending worker claims are persisted before money/parts and verified
# using the owner's durable ledger before an idempotent recovery credit.
claim = text(SHARED / "SettlementClaimRules.lua")
check("C25: claim recovery requires worker-bound owner proof, never legacy ledger alone",
      "Claims.MaxPending = 64" in claim
      and "function Claims.EvidenceStatus" in claim
      and 'return "LegacyUnverified"' in claim
      and "Claims.EvidenceStatus(claim, ownerLedger, ownerProofs, workerId) == \"Verified\"" in claim)
check("schema v6 keeps private pending claims",
      "PendingClaims = {}" in data_service
      and "SettlementClaimRules.Sanitize(data.PendingClaims)" in data_service
      and "profileView.PendingClaims = nil" in workshop)
check("server persists worker claim before consuming inventory",
      'DataService.StageWorkerClaim(player, workshopOwner.UserId,' in workshop
      and workshop.index("DataService.StageWorkerClaim(player, workshopOwner.UserId,")
      < workshop.index('DataService.SettleRepairOwnerOnce(workshopOwner, jobId, session.Token'))
check("C25: recovery checks exact owner proof and identifies ambiguous legacy cases",
      "SettlementClaimRules.EvidenceStatus(claim," in data_service
      and 'verified = evidenceStatus == "Verified"' in data_service
      and "Store:GetAsync(keyFor(claim.OwnerUserId))" in data_service)
check("claim recovery persisted before clearing",
      "if DataService.HasRepairCredit(worker, claim.JobId, claim.Token)" in data_service
      and "and DataService.Save(worker) then" in data_service
      and "SettlementClaimRules.Remove(profile.PendingClaims, claim.JobId, claim.Token)" in data_service)
audit = text(SHARED / "SettlementClaimAuditRules.lua")
check("C25: audit persisted privately without creating or dropping credits",
      "function Audit.Mark" in audit and "function Audit.Sanitize" in audit
      and "SettlementClaimAuditRules.Mark(profile.PendingClaimAudits," in data_service
      and "SettlementClaimAuditRules.Remove(profile.PendingClaimAudits, claim.JobId, claim.Token)" in data_service
      and "data.PendingClaimAudits = SettlementClaimAuditRules.Sanitize(" in data_service
      and "profileView.PendingClaimAudits = nil" in workshop)
check("C25: claim audit only exposes counters to HUD",
      "summary.NeedsReview = audit.Count" in data_service
      and "summary.LegacyUnverified = audit.LegacyUnverified" in data_service)
check("C25: auditoria suite registered",
      '"SettlementClaimAuditRulesTest"' in runner
      and (TOOLS / "SettlementClaimAuditRulesTest.luau").is_file())
check("C25: QA guide included",
      (ROOT / "docs" / "TESTE_C25_AUDITORIA_CLAIMS_LEGADAS_2026-11-13.md").is_file()
      and "Schema v11" in text(ROOT / "docs" / "TESTE_C25_AUDITORIA_CLAIMS_LEGADAS_2026-11-13.md"))
check("claim reconciliation runs on load and autosave",
      "task.spawn(DataService.ReconcileWorkerClaims, player)" in data_service)
check("claim tests registered",
      '"SettlementClaimRulesTest"' in runner and (TOOLS / "SettlementClaimRulesTest.luau").is_file())

# C14/C15: a prova do dono tem retenção independente e o resgate só roda
# após janela de segurança; resumos de pendências não expõem tokens.
proof = text(SHARED / "OwnerSettlementProofRules.lua")
check("archive compact proofs for 1024 collaboration payments",
      "Proofs.MaxEntries = 1024" in proof and "function Proofs.Sanitize" in proof)
check("C21: owner proofs never evict unresolved claims at capacity",
      "function Proofs.CanAdd" in proof and "function Proofs.Remove" in proof
      and "while #raw > Proofs.MaxEntries" not in proof)
check("C21: capacity verified before consuming collaborative repair parts",
      "DataService.HasOwnerProofCapacity(workshopOwner)" in workshop
      and "OwnerSettlementProofRules.CanAdd(profile.OwnerSettlementProofs, proof)" in data_service)
check("C21: owner shares and parts settle with rollback after the claim Save yield",
      "function DataService.SettleRepairOwnerOnce" in data_service
      and 'DataService.SettleRepairOwnerOnce(workshopOwner, jobId, session.Token' in workshop
      and 'DataService.AddParts(owner, partId, count)' in data_service
      and 'local workerCredited = true' in workshop)
check("C21: worker credit and XP confirmed before worker account save",
      'if not DataService.HasRepairCredit(entry.Worker, entry.JobId, entry.Token)' in workshop
      and 'DataService.AddSkillXP(entry.Worker, entry.Spec, entry.XP)' in workshop
      and 'entry.WorkerXpApplied = workerCredited' in workshop
      and 'DataService.AttachRepairReceipt(entry.Worker, entry.JobId, entry.Token, entry.Receipt)' in workshop)
check("C21: owner proof released only after worker claim cleanup saved",
      "DataService.DiscardWorkerClaim(entry.Worker, entry.JobId, entry.Token)" in workshop
      and "if not DataService.Save(entry.Worker) then" in workshop
      and "DataService.DiscardConfirmedOwnerProof(" in workshop)
check("owner archive is private and saved with the profile",
      "OwnerSettlementProofs = {}" in data_service
      and "OwnerSettlementProofRules.Sanitize(data.OwnerSettlementProofs)" in data_service
      and "profileView.OwnerSettlementProofs = nil" in workshop)
check("owner credit creates archive bound to worker",
      'delegated and player.UserId or nil, delegated and actorPay or nil)' in workshop
      and '"Owner", service, vehicle, workerUserId, workerPay)' in data_service)
check("recovery verifies owner proof",
      "ownerRaw.OwnerSettlementProofs, userId)" in data_service
      and "OwnerProofs.Authorizes(proof, claim, workerId)" in claim)
check("claim grace prevents in-flight double payment",
      "Claims.RecoveryGraceSeconds = 600" in claim
      and "SettlementClaimRules.Recoverable(claim, os.time())" in data_service)
check("pending claims only expose aggregate counts",
      "function Claims.Summary" in claim
      and "PendingClaimSummary = DataService.PendingClaimSummary(player)" in workshop
      and "snapshot.PendingClaimSummary" in orders)
check("archive tests registered",
      '"OwnerSettlementProofRulesTest"' in runner
      and (TOOLS / "OwnerSettlementProofRulesTest.luau").is_file())
sweep = text(SHARED / "OwnerProofSweepRules.lua")
check("C22: owner cleanup requires saved worker ledger and absent pending claim",
      "function Sweep.CanRelease" in sweep
      and 'credit.Role == "Worker"' in sweep
      and "Claims.Find(workerRaw.PendingClaims, proof.JobId, proof.Token)" in sweep
      and "credit.Amount == proof.WorkerPay" in sweep)
check("C22: offline sweep reads only persisted worker profile and limits rate",
      "Store:GetAsync(keyFor(proof.WorkerUserId))" in data_service
      and "OwnerProofSweepRules.MinIntervalSeconds" in data_service
      and "Sweep.MaxReadsPerPass = 4" in sweep)
check("C22: owner sweep runs after load and autosave",
      "task.delay(15, function()" in data_service
      and "task.spawn(DataService.ReconcileOwnerProofs, player)" in data_service)
check("C22: sweep tests in runner",
      '"OwnerProofSweepRulesTest"' in runner
      and (TOOLS / "OwnerProofSweepRulesTest.luau").is_file())
paid = text(SHARED / "WorkerSettlementProofRules.lua")
check("C23: worker paid confirmation archive validates and never silently rotates",
      "Paid.MaxEntries = 2048" in paid and "function Paid.FromLedger" in paid
      and "function Paid.CanAdd" in paid and "function Paid.Matches" in paid
      and "while #raw > Paid.MaxEntries" not in paid)
check("C23: worker confirmation survives schema v12",
      "local SCHEMA_VERSION = 13" in data_service
      and "WorkerSettlementProofs = {}" in data_service
      and "WorkerSettlementProofRules.FromLedger" in data_service
      and "WorkerSettlementProofRules.Add(profile.WorkerSettlementProofs, workerProof)" in data_service
      and "DataService.AddCoins(player, amount" in data_service)
check("C23: payouts idempotent even after ledger rotates",
      "WorkerSettlementProofRules.Find(profile.WorkerSettlementProofs, jobId, token)" in data_service
      and "DataService.HasWorkerProofCapacity(player)" in workshop)
check("C23: owner can verify durable paid marker without exposing it to clients",
      "WorkerProofs.Matches(proof, marker)" in sweep
      and "profileView.WorkerSettlementProofs = nil" in workshop)
check("C23: recovery does not discard claim after credit failure",
      "if DataService.HasRepairCredit(worker, claim.JobId, claim.Token)" in data_service
      and "and DataService.Save(worker) then" in data_service)
check("C23: test suite registered",
      '"WorkerSettlementProofRulesTest"' in runner
      and (TOOLS / "WorkerSettlementProofRulesTest.luau").is_file())
archive = text(SHARED / "WorkerProofArchiveRules.lua")
tombs = text(SHARED / "WorkerPaidTombstoneRules.lua")
check("C24: compact credit markers retain permanent replay tombstone",
      "Tombstones.MaxEntries = 8192" in tombs
      and "function Tombstones.Compact" in tombs
      and "table.insert(raw, { JobId = jobId, Token = token })" in tombs
      and "WorkerPaidTombstoneRules.Find(profile.WorkerPaidTombstones, jobId, token)" in data_service)
check("C24: no compaction while worker has claim or owner still has proof",
      "function Archive.CanCompact" in archive
      and "Claims.Find(workerPending, marker.JobId, marker.Token)" in archive
      and "OwnerProofs.Find(ownerRaw.OwnerSettlementProofs, marker.JobId, marker.Token) == nil" in archive)
check("C24: verify durable owner data, with limited reads and two worker saves",
      "Store:GetAsync(keyFor(marker.OwnerUserId))" in data_service
      and "WorkerProofArchiveRules.MinIntervalSeconds" in data_service
      and "Archive.MaxReadsPerPass = 4" in archive
      and "WorkerPaidTombstoneRules.Compact(proofs, profile.WorkerPaidTombstones," in data_service)
check("C24: schema v12 preserves v11 private tombstones and schedules reconciliation",
      "local SCHEMA_VERSION = 13" in data_service
      and "WorkerPaidTombstones = {}" in data_service
      and "WorkerPaidTombstoneRules.Sanitize(data.WorkerPaidTombstones)" in data_service
      and "data.RepairLedger, data.WorkerPaidTombstones)" in data_service
      and "profileView.WorkerPaidTombstones = nil" in workshop
      and "task.spawn(DataService.ReconcileWorkerProofs, player)" in data_service)
check("C24: test suite registered",
      '"WorkerProofArchiveRulesTest"' in runner
      and (TOOLS / "WorkerProofArchiveRulesTest.luau").is_file())
check("C24: QA document included",
      (ROOT / "docs" / "TESTE_C24_COMPACTACAO_QUITACOES_2026-11-13.md").is_file()
      and "Schema v10" in text(ROOT / "docs" / "TESTE_C24_COMPACTACAO_QUITACOES_2026-11-13.md"))
# C16/C17: upgrades persistentes e pads físicos autorizados no servidor.
equipment_rules = text(SHARED / "EquipmentUpgradeRules.lua")
pad_service = text(ROOT / "src" / "server" / "EquipmentUpgradePads.lua")
staff_rules = text(SHARED / "StaffAssignmentRules.lua")
check("equipment tiers persisted in schema v8",
      "EquipmentLevels = { BasicToolset = 1 }" in data_service
      and "EquipmentUpgradeRules.Sanitize(data.EquipmentLevels" in data_service
      and "function DataService.UpgradeOwnedEquipment" in data_service)
check("upgrade costs and economy are server-authoritative",
      "function Rules.NextCost" in equipment_rules
      and 'DataService.AddCoins(player, -cost, "Melhoria:' in data_service)
check("floor pads use server root position and one purchase on entry",
      "function Pads.Sync" in pad_service and "PointToObjectSpace(root.Position)" in pad_service
      and "if inside and not entry.WasInside" in pad_service
      and "entry.WasInside = true" in pad_service)
check("upgrade server verifies plot ownership",
      "PlotService.GetPlot(player) ~= sourcePlot" in workshop
      and "sourcePlot:GetAttribute(\"OwnerUserId\")" in workshop)
check("paid equipment level benefits repairs and employee speed",
      "EquipmentUpgradeRules.RewardMultiplier(ownerLevel)" in workshop
      and "EquipmentUpgradeRules.EmployeeSeconds" in workshop)
check("employee physically walks before working",
      "walkEmployee(npc,target,animator,valid)" in workshop
      and "V2StaffNavigator.Travel" in workshop
      and "PathfindingService:CreatePath" in text(ROOT / "src" / "server" / "V2StaffNavigator.lua"))
check("staff starts at 2 bays and waits 25 seconds for one car",
      "MaxEmployees = 1" in text(SHARED / "WorkshopLevels.lua")
      and "StaffAssignmentRules.ShouldDispatch" in workshop
      and "Rules.SoloWaitSeconds = 25" in staff_rules)
check("NPC reservation is created before asynchronous work and enforced at interaction entry",
      "StaffAssignmentRules.TryReserve(entry.Busy,candidate.Id)" in workshop
      and "function Rules.TryReserve" in staff_rules
      and "if employeeReserved(job) then" in workshop
      and 'or (Repairs[owner.UserId] and Repairs[owner.UserId].JobId == job.Id)' in workshop)
check("NPC failure releases busy slot and restores vehicle state",
      'xpcall(function()' in workshop
      and 'StaffAssignmentRules.Release(entry.Busy,candidate.Id)' in workshop
      and 'VehicleService.SetRepairing(candidate.Id,false)' in workshop)
check("NPC payouts use per-owner idempotent ledger and confirmed save",
      "function DataService.SettleNpcRepairOnce" in data_service
      and "DataService.CreditRepairOnce(player, jobId, token" in data_service
      and 'DataService.SettleNpcRepairOnce(owner, job.Id, token, price' in workshop
      and 'DataService.SettleNpcRepairOnce(player, job.Id, token, price - npcCost' in workshop
      and "confirmNpcSave(owner, job.Id, token" in workshop)
check("new suites registered",
      '"EquipmentUpgradeTest"' in runner and '"StaffAssignmentTest"' in runner
      and (TOOLS / "EquipmentUpgradeTest.luau").is_file()
      and (TOOLS / "StaffAssignmentTest.luau").is_file())
check("V1 asset guide exists and covers Roblox storage paths",
      (ROOT / "docs" / "GUIA_UNICO_ASSETS_V1.md").is_file()
      and "ServerStorage.Assets.Veiculos" in text(ROOT / "docs" / "GUIA_UNICO_ASSETS_V1.md")
      and "StudioPlaceAudit" in text(ROOT / "docs" / "GUIA_UNICO_ASSETS_V1.md"))
check("readme links project checklist", "issues/15" in text(ROOT / "README.md"))

# C30 / G1: clones de assets importados devem ser sanitizados antes de entrar no mundo.
asset_safety = text(SHARED / "AssetSafetyRules.lua")
check("C30: sanitizacao nao deixa Script, LocalScript ou ModuleScript",
      'function AssetSafetyRules.StripScripts' in asset_safety
      and 'item:IsA("Script")' in asset_safety
      and 'item:IsA("LocalScript")' in asset_safety
      and 'item:IsA("ModuleScript")' in asset_safety)
for relative, cloned_name in (
    ("src/server/CustomerArrivalService.lua", "car"),
    ("src/server/NpcKit.lua", "npc"),
    ("src/server/EquipmentModels.lua", "copy"),
    ("src/server/VehicleService.lua", "copy"),
):
    content = text(ROOT / relative)
    check(f"C30: {relative} sanitiza clone antes do Parent",
          f"AssetSafetyRules.StripScripts({cloned_name})" in content
          and content.index(f"AssetSafetyRules.StripScripts({cloned_name})") > content.index(f"local {cloned_name} = ")
          and "AssetSafetyRules" in content)
check("C30: regressao de sanitizacao registrada no runner",
      '"AssetSafetyRulesTest"' in runner and (TOOLS / "AssetSafetyRulesTest.luau").is_file())

# C31 / G1: estrutura dos modelos reais e validada pelo StudioPlaceAudit.
asset_integrity = text(SHARED / "AssetIntegrityRules.lua")
place_audit = text(TOOLS / "StudioPlaceAudit.luau")
check("C31: estrutural de veiculo, NPC e equipamento",
      "function Rules.Vehicle" in asset_integrity
      and "function Rules.Customer" in asset_integrity
      and "function Rules.Equipment" in asset_integrity)
check("C31: dimensoes, colisao, R15, genero e sockets",
      all(x in asset_integrity for x in ("Largura", "Comprimento", "Altura",
          "Motorista", "Casco", "HumanoidRootPart", "RigType", "Genero",
          "OficinaSocket_", "Anchored")))
check("C31: auditoria do place usa regras em 21 veiculos, NPCs e equipamentos",
      "AssetIntegrityRules.Vehicle(model)" in place_audit
      and "AssetIntegrityRules.Customer(npc)" in place_audit
      and "AssetIntegrityRules.Equipment(template)" in place_audit
      and "listed == 21" in place_audit)
check("C31: suite nao destrutiva registrada",
      '"AssetIntegrityRulesTest"' in runner
      and (TOOLS / "AssetIntegrityRulesTest.luau").is_file())

# V2-00/01/02: contratos minimos de integração e suítes registradas.
v2_compatibility = text(SHARED / "V2CompatibilityRules.lua")
v2_pilots = text(SHARED / "V2VehiclePilotRules.lua")
v2_management = text(SHARED / "V2ManagementSummaryRules.lua")
check("V2-00 preflight sem alterar schema ou perfis",
      "function Rules.Profile" in v2_compatibility and "MinSchema = 12" in v2_compatibility
      and "function Rules.Snapshot" in v2_compatibility)
check("V2-00 nao replica segredos", all(k in v2_compatibility for k in
      ("RepairLedger", "PendingClaims", "WorkerPaidTombstones", "OwnerSettlementProofs")))
check("V2-01 tres pilotos no catalogo V1", all(k in v2_pilots for k in
      ("Veiculo_Hatch_MG3", "Veiculo_Sedan_Civic", "Veiculo_Picape_S10",
       "AssetIntegrityRules", "V2Pivot_Hood", "function Rules.Resolve")))
check("V2-01 auditoria Studio disponivel", (TOOLS / "V2PilotPlaceAudit.luau").is_file()
      and (ROOT / "docs" / "GUIA_UNICO_ASSETS_V2.md").is_file())
check("V2-02 resumo nao inventa lucro", "NetProfitAvailable = false" in v2_management
      and "OrderHistory" in v2_management
      and "V2ManagementSummaryRules.Build(snapshot)" in text(CLIENT / "UI" / "Panels" / "Orders.lua"))
check("V2-00/01/02 suites Luau registradas",
      all(f'"{name}"' in runner and (TOOLS / (name + ".luau")).is_file()
          for name in ("V2FoundationTest", "V2PilotRigTest", "V2ManagementSummaryTest")))

# V2-00/01/02: contratos reais de fila, migracao e rig gerado em clones.
v2_reception = text(SHARED / "V2ReceptionRules.lua")
v2_supply = text(SHARED / "V2SupplyRules.lua")
data_service = text(ROOT / "src" / "server" / "DataService.lua")
workshop = text(ROOT / "src" / "server" / "WorkshopService.lua")
server = text(ROOT / "src" / "server" / "Main.server.lua")
arrival = text(ROOT / "src" / "server" / "CustomerArrivalService.lua")
ui_orders = text(CLIENT / "UI" / "Panels" / "Orders.lua")
check("V2-00: migracao aditiva schema v12 com lista persistente",
    "SCHEMA_VERSION = 13" in data_service and "V2SupplyRules.Sanitize" in data_service
    and "SupplyRequests = {}" in data_service and "SupplyRequests" in v2_compatibility)
check("V2-02: compra no estoque desconta lista sem debitar pedido",
    "V2SupplyRules.OnPurchase" in data_service
    and "function DataService.RequestSupply" in data_service
    and "function Rules.OnPurchase" in v2_supply)
check("V2-02: prioridade e agenda validadas no servidor, nao no cliente",
    all(x in workshop for x in ("function WorkshopService.SetJobPriority",
       "function WorkshopService.ScheduleJob", "function WorkshopService.DiscountJob",
       "function WorkshopService.RequestJobSupplies", "nearReception(player)",
       "ScheduleUsed", "V2ReceptionRules.BuildVisible"))
    and all(x in v2_reception for x in ("ValidPriority", "ValidAppointment", "ValidDiscount", "MissingParts")))
check("V2-02: remotes V2 registrados e ligados",
    all(x in server for x in ('"SetJobPriority"', '"ScheduleJob"',
        '"DiscountJob"', '"RequestJobSupplies"')))
check("V2-01: pivots apenas nos clones de carros pilotados",
    "V2PilotRigBuilder.Attach(car, job.VehicleName)" in arrival
    and "function Rules.Attach" in text(SHARED / "V2PilotRigBuilder.lua"))
check("V2-02: recepcao fisica, painel, sinais de cliente e desconto",
    '"RecepcaoBalcao"' in text(ROOT / "src" / "server" / "StationService.lua")
    and all(x in ui_orders for x in ('Store.Act("SetJobPriority"',
      'Store.Act("ScheduleJob"', 'Store.Act("DiscountJob"', 'Store.Act("RequestJobSupplies"',
      'V2ReceptionRules.QueueLess')))
check("V2: testes de novos contratos integrados",
    all(f'"{name}"' in runner and (TOOLS / (name + ".luau")).is_file()
       for name in ("V2ReceptionRulesTest", "V2SupplyRulesTest", "V2PilotRigBuilderTest")))

check("V2-01: LOD leve e teste visual registrados",
    (CLIENT / "V2PilotLOD.client.lua").is_file()
    and "LocalTransparencyModifier" in text(CLIENT / "V2PilotLOD.client.lua")
    and "function Rules.Show" in text(SHARED / "V2VisualBudgetRules.lua")
    and "function Rules.Apply" in text(SHARED / "V2PilotArtProfiles.lua")
    and (TOOLS / "V2AuthorPilotRigs.luau").is_file()
    and (TOOLS / "V2VisualBudgetTest.luau").is_file()
    and '"V2VisualBudgetTest"' in runner)
check("V2-02: descontos exibidos e vagas livres consideram bay real",
    "DiscountPercent = job.DiscountPercent or 0" in workshop
    and "VehicleService.GetFreeBayCount" in workshop
    and "FreeBays = freeBays" in v2_management)
check("V2-02: wishlist so limpa em pagamento confirmado",
    "function DataService.FulfillSupplyRequest" in data_service
    and "DataService.FulfillSupplyRequest(player, partId, quantity)" in workshop
    and "V2SupplyRules.OnPurchase(profile.SupplyRequests" in data_service)

check("V2-02: compras concorrentes somadas sem revelar OS nao diagnosticada",
    "function Rules.AggregateMissing" in v2_reception
    and "V2ReceptionRules.AggregateMissing(Jobs, player.UserId, profile.Parts)" in workshop)
check("V2-02: pedido cancelavel sem custo via autorizacao servidor",
    'function DataService.ClearSupplyRequests' in data_service
    and 'function WorkshopService.ClearSupplyRequests' in workshop
    and '"ClearSupplyRequests"' in server
    and 'Store.Act("ClearSupplyRequests"' in text(CLIENT / "UI" / "Panels" / "Shop.lua"))

# V2-03: interações físicas são prompts de servidor, sem RemoteEvent novo.
v2_components = text(SHARED / "V2ComponentRules.lua")
v2_vehicle = text(ROOT / "src" / "server" / "VehicleService.lua")
v2_visual = text(CLIENT / "VehicleFx.client.lua")
v2_articulations = text(CLIENT / "V2ArticulationFx.client.lua")
check("V2-03: oito articulacoes e regras de seguranca",
    all(x in v2_components for x in (
      '"Hood"', '"DoorLeft"', '"DoorRight"', '"Trunk"',
      '"WheelFL"', '"WheelFR"', '"WheelRL"', '"WheelRR"',
      "function Rules.Next", "function Rules.ReadyToRepair", "function Rules.IsNear",
      "function Rules.MayDrive")))
check("V2-03: prompts ligados a pivot e distancia verificada no servidor",
    all(x in v2_vehicle for x in (
      "addComponentPrompts", "V2PilotRules.Resolve", "V2ComponentRules.IsNear",
      "V2ComponentRules.Next", "V2ComponentPoints", "prompt.Triggered:Connect",
      'root, anchor', "resetComponents(car)")))
check("V2-03: fluxo de reparo e permissao do mecanico responsavel",
    all(x in workshop for x in (
      "function WorkshopService.ToggleVehicleComponent", "V2ComponentRules.FromPrompt",
      "V2ComponentRules.ReadyToRepair", "CollaborationRules.IsAuthorized",
      "VehicleService.ToggleComponent", "WheelSupportReady",
      "employeeReserved(job)"))
    and "V2_" in text(CLIENT / "UI" / "HUD.lua"))
check("V2-03: animações de rodas e capo por estado servidor",
    all(x in v2_visual for x in (
      "V2State_", '"Detached"', '"Open"', "V2ProxyHood",
      "V2Proxy_", "V2Removed", "V2GeneratedVisual")))
check("V2-03: portas/porta-malas com malha nativa e fallback sem colisao",
    all(x in v2_articulations for x in (
      "V2MovingComponent", "V2ArticulationProxy_", "V2State_",
      "CanCollide", "CanQuery", "CanTouch", "ReducedMotionEnabled",
      "MAX_DISTANCE")))
check("V2-03: auditoria de Studio e regras puras no runner",
    (TOOLS / "V2ComponentRulesTest.luau").is_file()
    and (TOOLS / "V2ComponentPlaceAudit.luau").is_file()
    and '"V2ComponentRulesTest"' in runner
    and '"V2ComponentPlaceAudit"' in runner)

check("V2-03: cofre do motor com fallback 5 componentes e LOD",
    (CLIENT / "V2EngineBayFx.client.lua").is_file()
    and all(x in text(CLIENT / "V2EngineBayFx.client.lua") for x in (
      '"EngineBlock"', '"Battery"', '"Coolant"', '"Intake"', '"Alternator"',
      "V2EngineBayRole", "V2State_Hood", "CanCollide", "MAX_DISTANCE")))
check("V2-03: peças nativas explícitas e integridade das rodas",
    'V2MovingComponent' in v2_visual
    and all(x in v2_visual for x in ('WheelFL = "LF"', 'WheelFR = "RF"',
        'WheelRL = "LB"', 'WheelRR = "RB"'))
    and "V2MovingComponent" in v2_articulations)
check("V2-03: mecânica visível após diagnóstico e saída segura",
    "entry.Mechanics =" in workshop
    and "not V2ComponentRules.MayDrive(states)" in v2_vehicle
    and "resetComponents(car)" in v2_vehicle
    and "job.Mechanics" in ui_orders)

# V2-04: 15 sequências físicas dirigidas por servidor e proteção financeira intacta.
v2_procs = text(SHARED / "V2ServiceProcedureRules.lua")
v2_procs_test = text(TOOLS / "V2ServiceProcedureRulesTest.luau")
v2_procfx = text(CLIENT / "V2ProcedureFx.client.lua")
operation_game = text(CLIENT / "UI" / "OperationRepairGame.lua")
check("V2-04: 15 receitas mapeadas a todo catalogo de defeitos",
    all(k in v2_procs for k in (
      "FlatTire","WornTire","WeakBattery","LooseSuspension","EngineMisfire",
      "ElectricalFault","Dent","BodyDamage","PaintJob","WheelImbalance",
      "Misalignment","BrakeWear","BrokenArm","EngineOverhaul","Overheating"))
    and 'count~=15' in v2_procs and "function Rules.ValidateCatalog" in v2_procs)
check("V2-04: executor autorizado e sequencia fisica verificada",
    all(k in workshop for k in (
      "function WorkshopService.DoProcedureStep", "V2ServiceProcedureRules.Advance",
      "VehicleService.IsNearProcedureStep", "DataService.HasParts(owner",
      "ownsEquipment(workshop", "V2ServiceProcedureRules.Ready", "job.V2ProcedureIndex"))
    and "function Rules.Advance" in v2_procs
    and "ctx.Authorized" in v2_procs and "step.UsesPart" in v2_procs)
check("V2-04: prompts so apos diagnostico em pivôs da V2-03",
    all(k in v2_vehicle for k in (
      "function VehicleService.SetServiceProcedure", "V2PilotRules.Resolve",
      "V2ProcedurePoints", "Proc_", "function VehicleService.IsNearProcedureStep",
      "function VehicleService.MarkProcedureFinished"))
    and "VehicleService.SetServiceProcedure(job.Id,job.DefectId,job.V2ProcedureIndex)" in workshop)
check("V2-04: sem pagamentos antecipados e credito pela V1",
    "job.Status = \"Completed\"" in workshop
    and "VehicleService.MarkProcedureFinished(job.Id,result.Quality)" in workshop
    and "DataService.HasRepairCredit" in workshop and "RepairActionRules.FinalInput" in workshop)
check("V2-04: erro e recomeço confirmados no servidor",
    'submit("Reset",nil,nil' in operation_game
    and 'Store.Act("CancelRepair"' in operation_game
    and "REFAZER SEM COBRAR" in operation_game
    and 'mode == "Battery" or mode == "Sequence"' in text(SHARED / "RepairActionRules.lua"))
check("V2-04: feedback visual apos diagnostico e jogo acessivel",
    "V2RepairStage" in v2_procfx and "V2ProcedureStepId" in v2_procfx
    and "V2ProcedureFamily" in v2_procfx and "RANGE = 120" in v2_procfx
    and 'job.Procedure' in ui_orders
    and 'string.sub(p.Name,1,5)=="Proc_"' in text(CLIENT / "UI" / "HUD.lua"))
check("V2-04: teste adversarial por serviço no runner",
    (TOOLS / "V2ServiceProcedureRulesTest.luau").is_file()
    and "test(\"15 receitas completas" in v2_procs_test
    and '"V2ServiceProcedureRulesTest"' in runner)

check("V2-04: integração de 15 serviços com todos sete modos de minijogo",
    (TOOLS / "V2ProcedureIntegrationTest.luau").is_file()
    and '"V2ProcedureIntegrationTest"' in runner
    and "Modes.Sequence" not in text(TOOLS / "V2ProcedureIntegrationTest.luau")
    and 'modes.Tire==1' in text(TOOLS / "V2ProcedureIntegrationTest.luau")
    and "Operations.BuildPlan" in text(TOOLS / "V2ProcedureIntegrationTest.luau"))
check("V2-04: resultado de qualidade explica erros e retrabalho seguro",
    "payload.Miss" in operation_game and
    "Verificação final" in operation_game
    and "REFAZER SEM COBRAR" in operation_game
    and "CancelRepair" in text(ROOT / "src" / "server" / "Main.server.lua"))

check("V2-04: apoio fisico estavel exigido para roda e rollback seguro",
    "function VehicleService.SetSupport" in v2_vehicle
    and "function VehicleService.SupportIsStable" in v2_vehicle
    and "StationService.IsLifted(bay)" in v2_vehicle
    and 'VehicleService.SupportIsStable(jobId)' in workshop
    and 'string.sub(id,1,5)=="Wheel"' in workshop
    and "V2SupportReadyAt" in v2_vehicle)

# V2-05: supervisor and payroll remain subordinate to original V1 credits.
staff_v2=text(SHARED / "V2StaffRules.lua")
nav_v2=text(ROOT / "src" / "server" / "V2StaffNavigator.lua")
orders_v2=text(CLIENT / "UI" / "Panels" / "Orders.lua")
server_v2=text(ROOT / "src" / "server" / "Main.server.lua")
check("V2-05: schema v13 preserves all V1 financial evidence",
    "SCHEMA_VERSION = 13" in data_service
    and "StaffSlots = V2StaffRules.Sanitize(nil)" in data_service
    and "data.StaffSlots = V2StaffRules.Sanitize" in data_service
    and "RepairLedger = {}" in data_service and "PendingClaims = {}" in data_service)
check("V2-05: payroll due once per profile, no duplicate debit",
    "function DataService.ChargeStaffPayrollOnce" in data_service
    and "profile.NextPayAt~=dueAt" in data_service
    and "DataService.AddCoins(player,-due" in data_service
    and "function DataService.DeferStaffPayroll" in data_service
    and "DataService.ChargeStaffPayrollOnce(owner,dueAt" in workshop)
check("V2-05: two employees, specialization, deterministic queue",
    all(x in staff_v2 for x in (
      "Rules.MaxEmployees = 2", "function Rules.Sanitize",
      "function Rules.Order", "function Rules.Record", "function Rules.Update",
      "function Rules.CanHandle"))
    and "V2StaffRules.Order(thisSlot,slot,os.time())" in workshop
    and "StaffAssignmentRules.TryReserve(entry.Busy,candidate.Id)" in workshop)
check("V2-05: bounded cancellable pathfinding and no unsafe teleport",
    "function Nav.Travel" in nav_v2 and "Nav.MaxRetries=2" in nav_v2
    and "PathfindingService:CreatePath" in nav_v2
    and "NpcKit.Place" not in nav_v2
    and "V2StaffNavigator.Travel" in workshop
    and 'npc:SetAttribute("V2WorkState","Buscando peças")' in workshop)
check("V2-05: manual assignment and pause guarded at orders TV",
    all(x in workshop for x in (
      "function WorkshopService.SetStaffPolicy",
      "function WorkshopService.AssignStaffJob",
      "function WorkshopService.ClearStaffJob",
      'StationService.IsNear(player,plot,"Orders")',
      "employeeReserved(job)"))
    and all(x in server_v2 for x in (
      '"SetStaffPolicy"', '"AssignStaffJob"', '"ClearStaffJob"'))
    and all(x in orders_v2 for x in (
      'Id = "team"', 'Store.Act("SetStaffPolicy"',
      'Store.Act("AssignStaffJob"', 'Store.Act("ClearStaffJob"')))
check("V2-05: performance recorded only after validated NPC settlement",
    "DataService.SettleNpcRepairOnce" in workshop
    and "DataService.RecordStaffJob(owner,index,job.Id" in workshop
    and workshop.index("DataService.RecordStaffJob(owner,index,job.Id")
        > workshop.index("if not DataService.SettleNpcRepairOnce")
    and 'job.Status = "Completed"' in workshop)
check("V2-05: suites for policy, 0/1/2 worker dispatch and persistence",
    (TOOLS / "V2StaffRulesTest.luau").is_file()
    and (TOOLS / "V2StaffDispatchTest.luau").is_file()
    and '"V2StaffRulesTest"' in runner and '"V2StaffDispatchTest"' in runner)

check("V2-05: Studio auditoria de avatar e zonas registrada",
    (TOOLS / "V2StaffPlaceAudit.luau").is_file()
    and '"V2StaffPlaceAudit"' in runner
    and "function CustomerNpcService.Position" in text(ROOT / "src" / "server" / "CustomerNpcService.lua")
    and 'profileView.StaffSlots = nil' in workshop
    and 'profileView.StaffPayroll = nil' in workshop)
check("V2-05: waypoint no plano horizontal e prioridade com sinal",
    "function Nav.HorizontalDistance" in text(ROOT/"src"/"server"/"V2StaffNavigator.lua")
    and text(ROOT/"src"/"server"/"V2StaffNavigator.lua").count("Nav.HorizontalDistance") >= 5
    and "local function signedPriority" in text(SHARED/"V2StaffRules.lua")
    and 'ranked[3].Id=="low"' in text(TOOLS/"V2StaffRulesTest.luau"))

check("V2-05: rejeita telemetria não finita sem contaminar estatísticas",
    "local function finite" in text(SHARED/"V2StaffRules.lua")
    and "not finite(gross)" in text(SHARED/"V2StaffRules.lua")
    and "not finite(quality)" in text(SHARED/"V2StaffRules.lua")
    and "not finite(seconds)" in text(SHARED/"V2StaffRules.lua")
    and "rejeita NaN/inf" in text(TOOLS/"V2StaffRulesTest.luau"))

check("V2-05: teste proprio de waypoint planar registrado no Studio",
    (TOOLS/"V2StaffNavigatorTest.luau").is_file()
    and '"V2StaffNavigatorTest"' in runner
    and "Nav.HorizontalDistance" in text(TOOLS/"V2StaffNavigatorTest.luau"))

print(f"\nStatic checks: {passed} passed, {len(failures)} failed")
if failures:
    raise SystemExit(1)
print("Note: Roblox runtime tests, asset licenses, visuals and performance remain unverified.")
