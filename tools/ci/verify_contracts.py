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
procedures = text(SHARED / "WorkshopProcedures.lua")
operations = text(SHARED / "RepairOperations.lua")
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
check("ledger persists across additive profile schema v12", "local SCHEMA_VERSION = 15" in data_service
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
      "local SCHEMA_VERSION = 15" in data_service
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
      "local SCHEMA_VERSION = 15" in data_service
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
check("V2-06: floor pads never charge on physical entry",
      "function Pads.Interact" in pad_service
      and "prompt.Triggered:Connect" in pad_service
      and "Quotes.Step" in pad_service
      and "entry.Pending=nextPending" in pad_service
      and "if onPurchase then onPurchase(player,id,plot,target,price) end" in pad_service
      and "entry.WasInside" not in pad_service
      and "touching(root" not in pad_service)
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
    "SCHEMA_VERSION = 15" in data_service and "V2SupplyRules.Sanitize" in data_service
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
    "SCHEMA_VERSION = 15" in data_service
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

# V2-06: compra explícita, sem side effects de caminhar em pads e sem ROI inventado.
quote = text(SHARED/"V2UpgradePurchaseRules.lua")
construction = text(CLIENT/"ConstrutoraPanel.client.lua")
visuals = text(ROOT/"src"/"server"/"V2ExpansionVisuals.lua")
station_v2 = text(ROOT/"src"/"server"/"StationService.lua")
check("V2-06: dois atos intencionais para comprar prédio e equipamento",
    "function Rules.Step" in quote
    and "Rules.ConfirmSeconds = 14" in quote
    and "pendingBuildings[player.UserId]" in workshop
    and "confirm == true" in workshop
    and "payload.Confirm == true" in server_v2
    and "SetNoticeHandler" in server_v2
    and "Quotes.Step(entry.Pending,quote,os.clock())" in pad_service)
check("V2-06: tarifa, nível e fonte rejeitam replay",
    "left.Target==right.Target" in quote
    and "left.Cost==right.Cost" in quote
    and "left.Source==right.Source" in quote
    and "PlotService.GetPlot(player)~=plot" in pad_service
    and "entry.Pending=nextPending" in pad_service)
check("V2-06: benefícios e confirmação explícitos na UI sem compras acidentais",
    "Benefits = V2UpgradePurchaseRules.Benefits" in workshop
    and 'Store.Act("UpgradeWorkshop",{Confirm=confirmed})' in construction
    and "CONFIRMAR %d moedas" in construction
    and "AutomaticCanvasSize = Enum.AutomaticSize.Y" in construction
    and "EXTRA" not in quote)
check("V2-06: expansão visual conforme os 4 níveis de verdade e sem colisão",
    "function Visuals.Apply" in visuals
    and "V2ExpansionVisuals.Apply(plot, root, level)" in station_v2
    and all(k in visuals for k in ("BoxSign_","ReceptionTier","StockTier","StaffTier","CanCollide",
      "CanTouch","CanQuery","MaxPieces")))
check("V2-06: suites Luau para compras e visual no runner",
    all((TOOLS/(p+".luau")).is_file() and ('"'+p+'"') in runner
       for p in ("V2UpgradePurchaseRulesTest","V2ExpansionVisualsTest")))

check("V2-06: compra de maquina revalida nivel/preco no mesmo perfil debitado",
    "onPurchase(player,id,plot,target,price)" in pad_service
    and "expectedTarget: number" in server_v2
    and "expectedTarget, expectedCost)" in workshop
    and "expectedTarget ~= current + 1" in data_service
    and "expectedCost ~= cost" in data_service)

# V2-07: simulação cliente de baixo custo; não criar tráfego server-sided nem duplicar cliente V1.
world_rules=text(SHARED/"V2NeighborhoodRules.lua")
ambient_client=text(CLIENT/"V2NeighborhoodAmbient.client.lua")
ambient_publish=text(ROOT/"src"/"server"/"V2NeighborhoodAssets.lua")
world_test=text(TOOLS/"V2NeighborhoodRulesTest.luau")
world_audit=text(TOOLS/"V2NeighborhoodPlaceAudit.luau")
check("V2-07: rotas da cidade em calçadas/faixas e limites mobile/PC",
    all(k in world_rules for k in (
        "Rules.Routes={", "ped_n_center", "ped_s_center", "veh_side_a",
        "Rules.MaxPedestrians=6", "Rules.MaxVehicles=3", "Rules.MaxActive=9",
        "function Rules.Budget", "function Rules.Select", "function Rules.Distance",
        "function Rules.Validate", "Rules.DeliverySeconds=14")))
check("V2-07: pool global de malhas e culling com fps/players",
    all(k in ambient_client for k in (
        "local live:", "local pool:", "Rules.Budget(UserInputService.TouchEnabled,fps",
        "Rules.Select(focus,budget)", "local function totalPooled",
        "totalPooled()<Rules.MaxPooled", "local function release",
        "if dis>range+42", "Workspace:Raycast", "Camera",
    )) and "CanCollide=false" in ambient_client and "CanTouch=false" in ambient_client
    and "CanQuery=false" in ambient_client)
check("V2-07: usa veículos 3D existentes e publica só avatares autorizados",
    all(k in ambient_client for k in (
        "VehiclePreviews", "V2PedestrianPreviews", "Animations.Walk",
        '"Veiculo_Hatch_MG3"', '"Veiculo_Sedan_Civic"',
        "vehicleConflict(point)", "V2AmbientOnly"))
    and all(k in ambient_publish for k in (
        "Service.MaxTemplates=3", "AssetSafetyRules.StripScripts",
        "ServerStorage:FindFirstChild", "Clientes",
        "node.CanCollide=false", "node.CanTouch=false"))
    and "V2NeighborhoodAssets.Publish()" in server_v2)
check("V2-07: entrega visual só após compra real, nunca altera saldo",
    '"V2NeighborhoodCourier"' in workshop
    and 'if delivered>0 and eventSender then' in workshop
    and 'DataService.FulfillSupplyRequest' in workshop
    and 'if eventSender then' in workshop
    and '"V2NeighborhoodCourier"' in ambient_client
    and "deliveryUntil=now+Rules.DeliverySeconds" in ambient_client
    and not any(k in ambient_client for k in (
        "DataService.AddCoins", "DataService.AddParts", "FireServer")))
check("V2-07: não modifica os reais veículos/atendimentos e limpa na saída",
    all(k in ambient_client for k in (
        "V2NeighborhoodAmbient", "model:PivotTo", "model.Parent=nil",
        "ambient:Destroy()", "player.AncestryChanged",
        '"Vehicles","Arrivals","RivalVehicles"', "vehicleConflict"))
    and not any(k in ambient_client for k in (
        "VehicleService.Spawn", "CustomerArrivalService.Arrive", "SetNetworkOwner")))
check("V2-07: suite de rotas e auditoria Studio registradas",
    all((TOOLS/(name+".luau")).is_file() and ('"'+name+'"') in runner
        for name in ("V2NeighborhoodRulesTest","V2NeighborhoodPlaceAudit"))
    and "nenhuma rota repetida" in world_test and "fps baixo" in world_test
    and "WARN" in world_audit and "Map.Ground" in world_audit)

# V2-08: cada atualização real de saldo produz uma única categoria
# persistente; uma migração legada sempre indica cobertura parcial.
finance=text(SHARED/"V2FinancialRules.lua")
finance_test=text(TOOLS/"V2FinancialRulesTest.luau")
finance_persistence=text(TOOLS/"PersistenceTest.luau")
finance_ui=text(CLIENT/"UI"/"Panels"/"Orders.lua")
check("V2-08/09: esquema 15 preserva o ledger v14 e inicia caixa categorizado",
    "SCHEMA_VERSION = 15" in data_service
    and "FinanceLedger = V2FinancialRules.New" in data_service
    and "V2FinancialRules.Bootstrap" in data_service
    and "V2FinancialRules.Sanitize" in data_service
    and "SettlementLedgerRules.Sanitize(data.RepairLedger)" in data_service)
check("V2-08: só DataService.AddCoins escreve receita e despesa contabilizadas",
    "V2FinancialRules.Apply(" in data_service
    and 'profile.FinanceLedger.LegacyWindow=true' in data_service
    and "Category = category" in data_service
    and "FinanceLedger = nil" in workshop
    and "V2FinancialRules.Snapshot" in workshop
    and 'profile.FinanceLedger,profile,os.time(),Config.EmployeeSalary,jobs' in workshop)
check("V2-08: compras mistas separadas em peças/capital sem dupla cobrança",
    "local partSpend, equipmentSpend = 0, 0" in workshop
    and 'if partSpend > 0 then DataService.AddCoins(player, -partSpend, "Loja de peças") end' in workshop
    and 'if equipmentSpend > 0 then DataService.AddCoins(player, -equipmentSpend, "Compra: equipamentos na loja") end' in workshop
    and "Rules.Category" in finance)
check("V2-08: painel apresenta caixa sem alegar lucro contábil",
    '{ Id = "finance", Label = "Caixa"' in finance_ui
    and '"FINANCEIRO"' not in finance_ui
    and "Fluxo operacional" in finance_ui
    and "Não é lucro contábil" in finance_ui
    and "AccountingProfitAvailable=false" in finance
    and "Orders" in (CLIENT/"UI"/"Panels"/"Orders.lua").name)
check("V2-08: recomendações de reposição só após diagnóstico",
    "function Rules.Restock" in finance
    and 'job.Diagnosed==true' in finance
    and "job.Requirement.Parts" in finance
    and "UrgentCost" in finance
    and "status financeiro" not in finance)
check("V2-08: estudos de margem e risco de folha com custo referencial",
    "function Rules.ServiceQuotes" in finance
    and "function Rules.PartCost" in finance
    and "OperatingCash=operatingCash" in finance
    and "AvailableAfterPayroll" in finance
    and '"FinanceQuotes"' in finance_ui and '"FinanceReorder"' in finance_ui)
check("V2-08: suites e migração/replay/reconexão cobertos",
    (TOOLS/"V2FinancialRulesTest.luau").is_file()
    and '"V2FinancialRulesTest"' in runner
    and "liquidação comprova receita uma vez" in finance_persistence
    and "migração v13 para v14" in finance_persistence
    and "extrato limitado 50" in finance_persistence
    and "não inferir defeito" in finance_test)

# V2-09: o mercado nunca chama liquidacao de OS; tudo passa por regras
# e persistencia sem yield no perfil do proprietario.
used_rules=text(SHARED/"V2UsedMarketRules.lua")
used_test=text(TOOLS/"V2UsedMarketRulesTest.luau")
check("V2-09: ofertas finitas, limite de 1 carro e cooldown por perfil",
    all(k in used_rules for k in (
        'Rules.MaxOwned = 1','Rules.MinServiceCount = 3',
        'Rules.CooldownSeconds = 600','Rules.Offers = {',
        'function Rules.CanBuy','function Rules.Sanitize',
        'function Rules.Plan','function Rules.Public')))
check("V2-09: operacoes validadas no servidor sem controle de saldo do cliente",
    'function DataService.TradeUsedCar' in data_service
    and 'V2UsedMarketRules.Plan(profile, operation, itemId' in data_service
    and 'HttpService:GenerateGUID(false)' in data_service
    and 'DataService.TakeParts(player, planned.Parts)' in data_service
    and 'DataService.AddCoins(player, planned.Delta, planned.Reason)' in data_service
    and 'function WorkshopService.UsedMarketAction' in workshop
    and 'PlotService.IsInsidePlot' in workshop
    and 'if not nearShop(player) then return false, SHOP_FAR end' in workshop)
check("V2-09: remoto limitado, dados privados e painel de gestão existente",
    '"UsedMarket"' in main_src
    and 'WorkshopService.UsedMarketAction(player, payload.Operation, payload.Id, payload.Style)' in main_src
    and 'profileView.UsedMarket = nil' in workshop
    and 'V2UsedMarketRules.Public(profile, os.time())' in workshop
    and 'Store.Act("UsedMarket"' in finance_ui
    and 'HudParts.vehicleThumb(card' in finance_ui)
check("V2-09: revenda separada das OS e historico financeiro categoria propria",
    'string.find(r,"^Usados:")' in finance
    and 'Market="Market"' in finance
    and 'Rules.Offers[input]' in used_rules
    and 'Rules.MaxOwned' in used_rules
    and 'CreditRepairOnce' not in used_rules
    and 'VehicleService.Spawn' not in used_rules)
check("V2-09: regressao de abuso, dupla venda e salvamento escrita",
    '"V2UsedMarketRulesTest"' in runner
    and (TOOLS/"V2UsedMarketRulesTest.luau").is_file()
    and 'replay de venda' in used_test
    and 'salvamento/relogin' in used_test
    and 'estoque ausente' in used_test)


used_visual=text(ROOT/"src"/"server"/"V2UsedMarketDisplay.lua")
used_visual_test=text(TOOLS/"V2UsedMarketDisplayTest.luau")
check("V2-09: vitrine de patio sem substituir carros de OS, limpeza e prompts",
    all(k in used_visual for k in (
        "function Display.Sync", "function Display.Clear",
        "Safety.StripScripts(clone)", "piece.CanCollide = false",
        "piece.CanTouch = false", "piece.CanQuery = false",
        'or "V2UsedMarketDisplay"', 'prompt.Triggered:Connect',
        "UsedRules.Sanitize",
        'active[player.UserId]=createDisplay',
    )) and "V2UsedMarketDisplay.Sync(player, profile" in workshop
    and "V2UsedMarketDisplay.Clear(userId)" in workshop)
check("V2-09: preview fisico testado em Edit e registrado",
    (TOOLS/"V2UsedMarketDisplayTest.luau").is_file()
    and '"V2UsedMarketDisplayTest"' in runner
    and 'vitrine nao reivindica bay/OS' in used_visual_test
    and "nao duplica carro" in used_visual_test)



# V2-10: cosméticos pagos uma vez, showroom finito, primeira exposição
# com reputação única por variante, sem ação financeira via UI de prévia.
show_rules=text(SHARED/"V2ShowroomRules.lua")
show_visual=text(SHARED/"V2ShowroomVisual.lua")
show_preview=text(CLIENT/"UI"/"V2ShowroomPreview.lua")
show_test=text(TOOLS/"V2ShowroomRulesTest.luau")
show_persistence=text(TOOLS/"PersistenceTest.luau")
check("V2-10: catálogo fechado com preço maior que bônus e limites do showroom",
    all(k in show_rules for k in (
        'Rules.MaxShowroom = 2','Rules.MaxUniqueReputation = 3',
        'function Rules.ValidOption','function Rules.Parse','function Rules.Quote',
        'function Rules.SaleBonus','function Rules.Spent',
        'Paint = {','Finish = {','Wheels = {'))
    and 'Appearance.Quote(category, choice, car)' in used_rules)
check("V2-10: UID conservado em vitrines com reputação que não repete",
    all(k in used_rules for k in (
        'state.ShowroomSeen[variant] = true',
        'if exhibit.Uid == input then index = i break end',
        'market.ShowroomSeen[car.Variant] = true',
        'market.Owned = {}',
        'operation == "Showcase"',
        'operation == "Recall"',
        'operation == "SellExhibit"',
        'Appearance.Spent(exhibit)',
        'Appearance.SaleBonus(car)'))
    and 'planned.ReputationAward > 0' in data_service
    and 'DataService.AddReputation(player, planned.ReputationAward)' in data_service
    and 'profile.UsedMarket = planned.Market' in data_service)
check("V2-10: não altera crédito de OS e showroom fica fora dos boxes",
    'CreditRepairOnce' not in show_rules + show_visual
    and 'VehicleService.Spawn' not in used_visual
    and 'showcases[player.UserId]=displays' in used_visual
    and 'local positions={{-32,-36},{31,-36}}' in used_visual
    and 'piece.CanCollide = false' in used_visual)
check("V2-10: UI preview antes/depois sem enviar seleção antes de confirmar",
    'function Preview.Pair' in show_preview
    and 'Visual.Apply(carModel,car)' in show_preview
    and 'previewChoice[car.Uid]=spec' in finance_ui
    and 'V2ShowroomPreview.Pair' in finance_ui
    and '"CONFIRMAR PERSONALIZAÇÃO"' in finance_ui
    and '"CANCELAR PRÉVIA (GRÁTIS)"' in finance_ui
    and 'Operation="Customize"' in finance_ui
    and 'Operation="SellExhibit"' in finance_ui
    and '"EXIBIR NO SHOWROOM' in finance_ui)
check("V2-10: suites econômicas, visuais e persistência no runner",
    all((TOOLS/(name+".luau")).is_file() and ('"'+name+'"') in runner
        for name in (
            "V2ShowroomRulesTest","V2ShowroomVisualTest","V2ShowroomDisplayTest"))
    and 'repetição de showcase não duplica reputação' in show_test
    and 'reexibir mesma variante não gera mais reputação' in show_test
    and 'V2-10: showroom não ressurge após venda e reconexão' in show_persistence)



# V2-11: o carro em OS permanece no box enquanto o clone físico dirige.
# Velocidade/posição são observadas APENAS no servidor; nenhum Touched paga.
drive_rules=text(SHARED/"V2DriveRules.lua")
drive_service=text(ROOT/"src"/"server"/"V2DriveService.lua")
drive_client=text(CLIENT/"V2DriveControls.client.lua")
drive_suspension=text(TOOLS/"V2DriveSuspensionTest.luau")
drive_rig_test=text(TOOLS/"V2DriveRigTest.luau")
drive_rule_test=text(TOOLS/"V2DriveRulesTest.luau")
drive_scene=text(ROOT/"src"/"server"/"VehicleService.lua")
check("V2-11: apenas Hatch piloto/OS com motorista e componentes fechados",
    all(x in drive_rules for x in (
        'R.PilotVehicle = "Hatch amarelo"', 'function R.PilotEligible',
        'function R.CanLaunch','ctx.OtherSession','ctx.JobSession',
        'ctx.ComponentsClosed','ctx.SupportRaised',
        'function R.PermittedOccupant'))
    and 'function WorkshopService.DriveCar' in workshop
    and 'Owner=job.OwnerUserId==player.UserId' in workshop
    and 'EmployeeBusy=employeeReserved(job)' in workshop)
check("V2-11: carro original e box preservados, com rollback idempotente",
    all(x in drive_scene for x in (
        'function VehicleService.SuspendForDrive',
        'function VehicleService.ResumeFromDrive',
        'drivePaused[jobId]', 'entry.Transparency',
        'entry.CanCollide','entry.CanTouch','entry.CanQuery',
        'car:SetAttribute("Estacionado",false)',
        'car:SetAttribute("Estacionado",true)',
        'if cancelDriveHandler then cancelDriveHandler(jobId) end'))
    and 'VehicleService.ResumeFromDrive(jobId)' in drive_service)
check("V2-11: física do servidor com VehicleSeat e constraints mecânicas",
    all(x in drive_service for x in (
        'Instance.new("VehicleSeat")','Instance.new("HingeConstraint")',
        'Enum.ActuatorType.Motor','Enum.ActuatorType.Servo',
        'node:SetNetworkOwner(nil)', 'seat.MaxSpeed',
        'Rules.MotorMaxTorque','Rules.SteerTorque'))
    and 'Safety.StripScripts(model)' in drive_service
    and 'template.Archivable' in drive_service)
check("V2-11: input analógico não transmite movimento, dinheiro ou token",
    'driveInputEvent.Name="DriveInput"' in main_src
    and 'V2DriveService.Input(player,jobId,throttle,steer)' in main_src
    and 'function Service.Input(' in drive_service
    and 's.OwnerId~=player.UserId' in drive_service
    and 's.Seat.Occupant~=s.DriverHumanoid' in drive_service
    and 'now-s.LastInputRequest<0.07' in drive_service
    and 'now-s.InputAt<0.35' in drive_service
    and 'driveInput:FireServer(jobId,throttle,steer)' in drive_client
    and 'CreditRepairOnce' not in drive_service
    and 'DataService' not in drive_service
    and '.Touched:Connect' not in drive_service)
check("V2-11: limites anti-teleporte, duração, colisão e rota observada",
    all(x in drive_rules for x in (
        'R.MaximumSeconds = 150','R.MaxSpeed = 54','R.MaxRadius = 260',
        'function R.AssessMotion','function R.Advance',
        'R.CheckpointMinInterval','velocity.Magnitude > R.MaxSpeed'))
    and 'Rules.AssessMotion(' in drive_service
    and 'Rules.Advance(' in drive_service
    and 'workspace:Raycast(' in drive_service
    and 'Rules.SessionViolation(' in drive_service
    and 'now-started>R.MaximumSeconds' in drive_rules
    and 'clear(jobId,problem,true)' in drive_service)
check("V2-11: retorno seguro nos eventos de retorno, desconexão e despawn",
    'function Service.CancelJob(' in drive_service
    and 'function Service.CancelPlayer(' in drive_service
    and 'function Service.End(' in drive_service
    and 'V2DriveService.CancelPlayer(player.UserId)' in main_src
    and 'VehicleService.SetDriveCancelHandler' in main_src
    and 'action == "DriveCar"' in main_src
    and 'Mode="Return"' in finance_ui
    and 'V2DriveService.Status(job.Id)' in workshop
    and 'V2DriveService.BusyJob(jobId)' in workshop)
check("V2-11: segurança, rig real e rollback cobertos por regressões Edit",
    all((TOOLS/(n+".luau")).is_file() and ('"'+n+'"') in runner
        for n in ("V2DriveRulesTest","V2DriveRigTest","V2DriveSuspensionTest"))
    and 'replay da rota completa' in drive_rule_test
    and 'quatro rodas com motores HingeConstraint' in drive_rig_test
    and 'rollback devolve todos os materiais' in drive_suspension)


# V2-12/13: implementações completas, mas gate de homologação de física
# permanece DESLIGADO até o proprietário validar no Roblox Studio.
scenario_rules=text(SHARED/"V2DriveScenarioRules.lua")
quality_rules=text(SHARED/"V2QualityDriveRules.lua")
scenario_test=text(TOOLS/"V2DriveScenarioTest.luau")
quality_test=text(TOOLS/"V2QualityDriveTest.luau")
repair_game=text(CLIENT/"UI"/"RepairGame.lua")
operation_game=text(CLIENT/"UI"/"OperationRepairGame.lua")
client_store=text(CLIENT/"UI"/"Store.lua")
check("V2-12/13: gate físico explícito desligado até QA Studio",
    "R.LiveEnabled=false" in scenario_rules
    and 'V2DriveScenarioRules.LiveEnabled' in workshop
    and 'mode=="Diagnosis"' in workshop
    and 'mode=="Quality"' in workshop)
check("V2-12: seed privado e seleção finita condicionada ao Hatch e defeito",
    all(x in scenario_rules for x in (
        'R.DiagnosticChance=.38','R.QualityChance=.24',
        'R.IsCandidate','Random.new(seed)',
        'R.Plan','R.Signals','R.HasCondition',
        'R.DiagnosticEvidence','R.CanConclude'))
    and 'job.V2DriveScenario=V2DriveScenarioRules.Plan(' in workshop
    and 'math.random(1,2147483646)' in workshop
    and 'job.V2DriveEvidence=evidence' in workshop)
check("V2-12: evento de sensação emitido só pelo servidor via telemetria",
    'ScenarioRules.HasCondition(' in drive_service
    and 's.InputThrottle,s.InputSteer' in drive_service
    and 's.Progress.Passed,s.Context.TriggerCheckpoint' in drive_service
    and 'Service.SetDriveCueHandler' in drive_service
    and 'actionEvent:FireClient(driver,"DriveCue",payload)' in main_src
    and 'Store.DriveCue' in client_store
    and 'SoundIds' in drive_client
    and 'Haptics:SetMotor' in drive_client)
check("V2-12: diagnóstico por bancada nunca é substituído por Touched",
    'DiagnosisEvidence.HasRelevantExam(' in workshop
    and 'DiagnosisRules.Judge(' in workshop
    and 'job.V2DriveEvidence' in workshop
    and 'Findings = findings' in workshop
    and 'HasRepairCredit' not in scenario_rules
    and 'CreditRepairOnce' not in scenario_rules
    and 'Touched' not in scenario_rules)
check("V2-12: uma OS, tentativas limitadas e rota verificada pelo servidor",
    'job.V2DiagnosticStarts+=1' in workshop
    and 'job.V2DiagnosticStarts>=2' in workshop
    and 'job.V2DiagnosticDone=true' in workshop
    and 'returned==true and s.Progress.Done==true' in drive_service
    and 'ScenarioRules.CanConclude(' in drive_service
    and 'outcome.Reproduced~=true' in scenario_rules
    and 'mode=="Diagnosis"' in workshop)
check("V2-13: minigame avaliado é selado sem nova rota de crédito",
    'local function settleEvaluatedRepair' in workshop
    and workshop.count('DataService.SettleRepairOwnerOnce(')==1
    and 'PendingQuality[player.UserId]=pending' in workshop
    and 'pending.Session=session' in workshop
    and 'pending.Result=result' in workshop
    and 'return settleEvaluatedRepair(player,jobId,session,result' in workshop
    and 'function WorkshopService.QualityReview(' in workshop
    and 'settleEvaluatedRepair(player,jobId,' in workshop)
check("V2-13: qualidade real, livre escolha, custo/retrabalho finitos",
    all(x in quality_rules for x in (
        'R.MinPassQuality=70','R.MaxReworks=1',
        'function R.CanOffer','function R.OnReturn',
        'pending.Quality<R.MinPassQuality',
        'function R.CanFinalize','function R.Timeout',
        'ExtraCost=0,ExtraParts=0'))
    and 'job.V2ReworkCount=(job.V2ReworkCount or 0)+1' in workshop
    and 'job.V2QualityReviewPending' in workshop
    and 'not job.V2QualityReviewPending' in workshop)
check("V2-13: pre-credit UX fecha minigame sem receber bônus prematuro",
    'answer.Status="QualityPending"' in workshop
    and 'eventSender(player,"RepairQualityPending"' in workshop
    and 'Store.RepairQualityPending' in client_store
    and 'payload.Status=="QualityPending"' in repair_game
    and 'payload.Status=="QualityPending"' in operation_game
    and 'Operation="Skip"' in finance_ui
    and 'Operation="Redo"' in finance_ui
    and 'Operation="Finalize"' in finance_ui)
check("V2-13: não paga enquanto dirige, retorna e não duplica liquidação V1",
    'V2DriveService.BusyJob(jobId)' in workshop
    and 'SettlingRepairs[player.UserId]=nil' in workshop
    and 'DataService.HasRepairCredit(player, jobId, session.Token)' in workshop
    and 'DataService.StageWorkerClaim' in workshop
    and 'SettlementDeliveryRules.New' in workshop
    and 'RepairReceiptRules.Remember' in workshop
    and 'R.LiveEnabled=false' in scenario_rules)
check("V2-12/13: testes de seed, spoof, abortos, payout único no runner",
    all((TOOLS/(n+".luau")).is_file() and ('"'+n+'"') in runner
        for n in ("V2DriveScenarioTest","V2QualityDriveTest"))
    and 'seed único gera decisão reprodutível' in scenario_test
    and 'replay de sessão terminada' in scenario_test
    and 'colisão ou abortos apenas restauram oferta' in quality_test
    and 'sem cobrança ou reembolso independente' in quality_test)


# V2-14: contrato de frota e relacionamento persistente. Nenhuma ação
# do cliente pode passar preço, token de reparo, remuneração ou checkpoint.
fleet_rules=text(SHARED/"V2FleetBusinessRules.lua")
fleet_service=text(ROOT/"src"/"server"/"ContractService.lua")
fleet_test=text(TOOLS/"V2FleetBusinessRulesTest.luau")
contract_test=text(TOOLS/"V2FleetContractTest.luau")
persistence=text(TOOLS/"PersistenceTest.luau")
check("V2-14: especializações elegíveis, margem, equipe, estoque e prazo reais",
    all(x in fleet_rules for x in (
        'function Rules.Quote(', 'function Rules.TermsFromQuote(',
        'Rules.Modes=', 'QuoteMode=mode','PartTypeCount',
        'PriceMultiplier', 'LowStock=lowStock',
        'OwnerContribution','CollaboratorContribution','NpcContribution',
        'PartnerBonusPercent'))
    and 'V2FleetBusinessRules.Quote(offer' in workshop
    and 'getOpenJobCount(player.UserId)' in workshop
    and 'profile.Parts' in workshop
    and 'profile.Employees' in workshop)
check("V2-14: propostas são opt-in, recusáveis e servidor escolhe preço",
    'proposals[player.UserId]' in fleet_service
    and 'function Service.Negotiate(' in fleet_service
    and 'Service.Offer(player)' in fleet_service
    and 'FleetRules.TermsFromQuote(' in fleet_service
    and 'mode=="Express"' not in main_src
    and 'action == "NegotiateFleet"' in main_src
    and 'WorkshopService.NegotiateFleet' in main_src
    and 'Store.Act("NegotiateFleet"' in finance_ui)
check("V2-14: não há OS de frota impossível por equipamento/nível",
    'local candidates={}' in workshop
    and 'def.Specialization==fleet.Offer.Spec' in workshop
    and 'equipment[def.RequiredEquipment]==true' in workshop
    and 'fleet=nil -- nunca lançar uma OS impossível' in workshop)
check("V2-14: sucesso aceito só para contrato aberto + JobId único",
    'function Service.FleetDone(' in fleet_service
    and 'c.DoneJobs[jobId]' in fleet_service
    and 'c.DoneJobs[jobId]=true' in fleet_service
    and 'c.Token~=token' in fleet_service
    and 'Service.Active(owner.UserId)' in fleet_service
    and 'ContractService.FleetDone(owner,job.Fleet,job.Id' in workshop)
check("V2-14: bônus de frota próprio e idempotente no mesmo perfil",
    'function DataService.RecordFleetOutcomeOnce(' in data_service
    and 'V2FleetBusinessRules.Record(profile.FleetAccounts' in data_service
    and 'DataService.AddCoins(player,bonus,' in data_service
    and 'DataService.AddReputation(player,rep)' in data_service
    and 'record.Bonus' in data_service
    and 'record.Reputation' in data_service
    and 'function Service.endContract' not in fleet_service
    and 'RecordFleetOutcomeOnce(player,c.RewardKey' in fleet_service
    and 'GenerateGUID(false)' in fleet_service
    and 'PendingClaims' not in fleet_service)
check("V2-14: parceiro persistido e resumo não expõe chave de crédito",
    'FleetAccounts = V2FleetBusinessRules.NewAccounts()' in data_service
    and 'data.FleetAccounts = V2FleetBusinessRules.SanitizeAccounts' in data_service
    and 'profileView.FleetAccounts=nil' in workshop
    and 'function DataService.FleetAccountSummary(' in data_service
    and 'function Rules.PublicAccounts(' in fleet_rules
    and 'MaxCreditKeys=96' in fleet_rules
    and 'MaxHistory=20' in fleet_rules)
check("V2-14: decisão de equipe/terceiro não duplica OS",
    '(job.EmployeeAssignedSlot or job.V2EmployeeSlot) and "Staff"' in workshop
    and '"Collaborator"' in workshop
    and '"Owner"' in workshop
    and 'Methods=table.clone(c.Methods)' in fleet_service
    and 'methods.Collaborator' in finance_ui
    and 'Store.Act("AssignStaffJob"' in finance_ui
    and 'QualityReview' in workshop
    and 'StageWorkerClaim' in workshop)
check("V2-14: falhas de prazo ou disconnect sem multa artificial",
    'result~="Expired"' in fleet_rules
    and 'completed and c.Offer.Coins or 0' in fleet_service
    and 'completed and c.Offer.Reputation or 0' in fleet_service
    and 'Sem multa' in fleet_service
    and 'Players.PlayerRemoving:Connect' in fleet_service
    and 'proposals[player.UserId]=nil' in fleet_service)
check("V2-14: bonificação de frota tem receita operacional separada",
    'Fleet="Fleet"' in finance
    and 'return "Fleet" end' in finance
    and 'operationIn=groups.Service.In+groups.Fleet.In' in finance
    and 'FleetReceipts=groups.Fleet.In' in finance
    and 'Fleet="Prêmios de contratos"' in finance_ui
    and 'fleetReport.FleetReceipts==120' in text(TOOLS/"V2FinancialRulesTest.luau"))
check("V2-14: suites puras, serviço e persistência no runner",
    all((TOOLS/(n+".luau")).is_file() and ('"'+n+'"') in runner
        for n in ("V2FleetBusinessRulesTest","V2FleetContractTest"))
    and 'replay da mesma chave' in fleet_test
    and 'última OS válida libera exatamente um prêmio' in contract_test
    and 'V2-14: queda/reconexão conserva bônus' in persistence)


# V2-15: revisão transversal P0. O CI continua sem ser Studio; valida
# mecanismos executáveis, limites e rastreabilidade dos testes escritos.
remote_rules=text(SHARED/"V2RemoteSecurityRules.lua")
remote_test=text(TOOLS/"V2RemoteSecurityTest.luau")
runtime_assets=text(TOOLS/"V2RuntimeAssetBudgetTest.luau")
visual_budget=text(SHARED/"V2VisualBudgetRules.lua")
neighborhood_server=text(ROOT/"src"/"server"/"V2NeighborhoodAssets.lua")
neighborhood_client=text(CLIENT/"V2NeighborhoodAmbient.client.lua")
access_rules=text(SHARED/"V2AccessibilityRules.lua")
access_test=text(TOOLS/"V2AccessibilityTest.luau")
place_audit=text(TOOLS/"V2ReleasePlaceAudit.luau")
drive_client=text(CLIENT/"V2DriveControls.client.lua")
check("V2-15: limite transversal de ações antes de qualquer mutação de perfil",
    'V2RemoteSecurityRules.ConsumeAction(' in main_src
    and 'V2RemoteSecurityRules.PayloadValid(payload)' in main_src
    and main_src.index('V2RemoteSecurityRules.PayloadValid(payload)')
        < main_src.index('if action == "CheckRepairResult"')
    and 'ActionPerSecond=26' in remote_rules
    and 'ActionBurst=44' in remote_rules)
check("V2-15: snapshots anti-flood sem duplicar cache V1",
    'V2RemoteSecurityRules.ConsumeSnapshot(' in main_src
    and 'SnapshotCacheRules.Get(snapshotStates' in main_src
    and 'return {Ready=false,Throttled=true}' in main_src
    and 'snapshotBudgets[player.UserId]=nil' in main_src)
check("V2-15: recusa árvores remotas profundas, circulares e valores inválidos",
    all(k in remote_rules for k in (
        'R.MaxNodes=120','R.MaxDepth=5','R.MaxString=512',
        'if seen[v] then return false',
        'if nodes>R.MaxNodes',
        'kind~="table" then return false',
        'if not finite(v) then',
        'type(k)=="string"'))
    and 'not R.PayloadValid(circular)' in remote_test
    and 'not R.PayloadValid({Quantity=0/0})' in remote_test
    and 'lastActionAt[player.UserId] = nil' in main_src)
check("V2-15: asset físico de Hatch é pré-filtrado antes do Clone",
    'VisualBudget.PreflightTemplate(template,"Drive")' in drive_service
    and 'if template and allowed and template.Archivable then' in drive_service
    and drive_service.index('PreflightTemplate(template,"Drive")')
        < drive_service.index('local model=template:Clone()')
    and 'VisualBudget.CanStartDrive(active)' in drive_service
    and 'Rules.MaxConcurrentDriveRigs=5' in visual_budget)
check("V2-15: pedestres/figurantes local/server têm orçamento real",
    'VisualBudget.PreflightTemplate(template,"Ambient")' in neighborhood_server
    and 'Budget.PreflightTemplate(source,"Ambient")' in neighborhood_client
    and 'Rules.MaxAmbientTemplateParts=90' in visual_budget
    and 'Rules.MaxDriveShellDescendants=350' in visual_budget
    and 'Rules.MaxDriveSurfaceAppearances=24' in visual_budget)
check("V2-15: prova do bônus de frota salva antes de confirmar sucesso",
    'local ok,saved=pcall(data.Save,player)' in fleet_service
    and 'if not ok or not saved then' in fleet_service
    and 'if contracts[player.UserId]~=c then return false end' in fleet_service
    and fleet_service.index('if not ok or not saved then')
        < fleet_service.index('contracts[player.UserId]=nil')
    and 'function Service.RetryPending(player:Player):boolean' in fleet_service
    and 'c.Settling=true' in fleet_service
    and 'c.Settling=false' in fleet_service)
check("V2-15: retry Save não duplica bônus, liga ou JobId",
    'c.LeagueCredited=true' in fleet_service
    and 'reason~="Duplicado."' in fleet_service
    and 'c.DoneJobs[jobId]' in fleet_service
    and 'failed' not in fleet_service[:100]
    and 'retry de Save confirma a prova financeira' in contract_test
    and 'sucesso comunicado somente após persistência' in contract_test)
check("V2-15: configurações inclusivas validadas e persistentes no mesmo perfil",
    'V2AccessibilityRules.New()' in data_service
    and 'V2AccessibilityRules.Sanitize(data.Accessibility)' in data_service
    and 'function DataService.SetAccessibility(' in data_service
    and 'function WorkshopService.SetAccessibility(' in workshop
    and 'action == "SetAccessibility"' in main_src
    and 'Store.Act("SetAccessibility"' in finance_ui
    and all(k in access_rules for k in (
        'DriveHaptics=v.DriveHaptics~=false',
        'DriveSfx=v.DriveSfx~=false',
        'LowDetail=v.LowDetail==true',
        'if type(key)~="string"')))
check("V2-15: reduzir movimento, áudio e figurantes não modifica diagnóstico",
    'accessibility.DriveSfx~=false' in drive_client
    and 'accessibility.DriveHaptics~=false' in drive_client
    and 'local lowDetail=type(preferences)=="table"' in neighborhood_client
    and 'if lowDetail==true then' in text(SHARED/"V2NeighborhoodRules.lua")
    and 'CueReproduced=true' in drive_service
    and 'DriveCue' in client_store)
check("V2-15: suite Edit de auditoria informa avisos e não declara QA físico",
    'Workspace.StreamingEnabled==true' in place_audit
    and 'Scenario.LiveEnabled==false' in place_audit
    and 'Licenças/uso dos áudios' in place_audit
    and 'Não é teste de FPS real' in place_audit
    and 'Tools' in runner)
credits_rules=text(SHARED/"V2Credits.lua")
credits_panel=text(CLIENT/"UI"/"Panels"/"Profile.lua")
credits_test=text(TOOLS/"V2CreditsTest.luau")
check("V2-15: tela de créditos e fontes apresenta avisos de direitos não resolvidos",
    'local V2Credits = require(ReplicatedStorage.Shared.V2Credits)' in credits_panel
    and '{ Id = "credits", Label = "Créditos"' in credits_panel
    and 'V2Credits.Entries' in credits_panel
    and 'V2Credits.Pending' in credits_panel
    and 'Sprites do HUD/painéis' in credits_rules
    and 'autorização escrita' in credits_rules
    and 'substitui a checagem de licença' in credits_panel
    and (TOOLS/"V2CreditsTest.luau").is_file()
    and '"V2CreditsTest"' in runner)
check("V2-15: suites registradas e regressão multi-servidor de acessibilidade",
    all((TOOLS/(n+".luau")).is_file() and ('"'+n+'"') in runner
        for n in ("V2RemoteSecurityTest","V2RuntimeAssetBudgetTest",
            "V2AccessibilityTest","V2ReleasePlaceAudit"))
    and 'V2-15: explicitamente false continua false após Save/Load'
        in persistence
    and 'falha de Save NÃO anuncia sucesso' in contract_test
    and 'sem áudio' not in remote_rules)


# V2-16: build/QA readiness is deliberately NOT an approval to publish.
release_rules=text(SHARED/"V2ReleaseGateRules.lua")
release_tests=text(TOOLS/"V2ReleaseGateRulesTest.luau")
beta_smoke=text(TOOLS/"V2BetaSmokeAudit.luau")
release_cli=text(TOOLS/"ci"/"release_gate.py")
release_manifest=json.loads(text(ROOT/"docs"/"release"/"V2_RELEASE_EVIDENCE.json"))
release_workflow=text(ROOT/".github"/"workflows"/"code-health.yml")
release_docs=text(ROOT/"docs"/"V2_FASE_16_HOMOLOGACAO_BETA.md")
check("V2-16: release gate possui 16 requisitos com fonte inequívoca",
    '#Rules.Gates' in release_rules
    and 'result.Approved=result.Passed==result.Total' in release_rules
    and all(('Id="'+id+'"') in release_rules for id in (
        "ci_code","merge_main","studio_suites","assets_place","services_15",
        "onboarding","cooperation","data_safety","inventory_fifo",
        "drive_physics","touch_gamepad","performance","stream_audio",
        "licenses","beta_closed","owner_go")))
check("V2-16: gate sempre requer evidência atrelada ao SHA atual",
    'entry.BuildSha~=headSha' in release_rules
    and 'entry.Source~=gate.Source' in release_rules
    and 'entry.Status~="Passed"' in release_rules
    and 'elegível' not in text(SHARED/"V2DriveScenarioRules.lua").lower())
check("V2-16: template inicial não possui nenhuma aprovação artificial",
    release_manifest.get("Version")==1
    and len(release_manifest.get("Entries",{}))==16
    and all(x.get("Status") in ("Pending","Blocked")
        and not x.get("Proof") and not x.get("BuildSha")
        for x in release_manifest["Entries"].values())
    and all(release_manifest["Entries"][id]["Status"]=="Blocked"
        for id in ("merge_main","inventory_fifo","licenses")))
check("V2-16: release enforcer é independente do CI verde",
    'def evaluate(manifest:' in release_cli
    and 'if opts.mode == "enforce" and not result["Approved"]' in release_cli
    and 'if opts.self_test:' in release_cli
    and '--mode report' in release_workflow
    and '--self-test' in release_workflow
    and 'rojo build default.project.json' in release_workflow)
check("V2-16: suites dos gates e auditoria de beta estão no runner",
    '"V2ReleaseGateRulesTest"' in runner
    and '"V2BetaSmokeAudit"' in runner
    and 'not pending.Approved' in release_tests
    and 'not R.Evaluate(modified,sha).Approved' in release_tests
    and 'StudioPlaceAudit' in beta_smoke
    and 'DataStore' in beta_smoke)
check("V2-16: documentação não transforma CI em aprovação de gameplay",
    'Go/No-Go' in release_docs
    and 'RunAllTests' in release_docs
    and '15' in release_docs
    and 'main' in release_docs
    and 'V2-08' in release_docs
    and 'V2-12' in release_docs
    and 'licenças' in release_docs
    and 'beta' in release_docs.lower()
    and 'não publica' in release_docs)

print(f"\nStatic checks: {passed} passed, {len(failures)} failed")
if failures:
    raise SystemExit(1)
print("Note: Roblox runtime tests, asset licenses, visuals and performance remain unverified.")
