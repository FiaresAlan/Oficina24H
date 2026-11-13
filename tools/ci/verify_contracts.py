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
check("legacy timing repair remains supported", "RepairRules.Evaluate(session.Plan, presses, elapsed, mods)" in workshop)

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
check("client checks receipt before resending a finish",
      'Store.Act("CheckRepairResult"' in ui
      and 'payload.Status == "Completed"' in ui and 'payload.Status == "Active"' in ui)
check("client result correlated with job and token",
      "payload.JobId ~= jobId or payload.Token ~= sessionToken" in ui)
# C8: per-profile persistent settlement idempotency (NOT multi-user atomicity).
ledger = text(SHARED / "SettlementLedgerRules.lua")
data_service = text(ROOT / "src" / "server" / "DataService.lua")
check("ledger bounded and sanitized", "SettlementLedgerRules.MaxEntries" in ledger and "function SettlementLedgerRules.Sanitize" in ledger)
check("ledger persists in profile schema v5", "local SCHEMA_VERSION = 7" in data_service
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
check("claim bounded sanitized and verified against owner's ledger",
      "Claims.MaxPending = 64" in claim and "function Claims.Authorized" in claim)
check("schema v6 keeps private pending claims",
      "PendingClaims = {}" in data_service
      and "SettlementClaimRules.Sanitize(data.PendingClaims)" in data_service
      and "profileView.PendingClaims = nil" in workshop)
check("server persists worker claim before consuming inventory",
      'DataService.StageWorkerClaim(player, workshopOwner.UserId,' in workshop
      and workshop.index("DataService.StageWorkerClaim(player, workshopOwner.UserId,")
      < workshop.index('DataService.TakeParts(workshopOwner, defect.Parts)'))
check("recovery requires saved owner evidence",
      "SettlementClaimRules.Authorized(claim, ownerRaw.RepairLedger," in data_service
      and "Store:GetAsync(keyFor(claim.OwnerUserId))" in data_service)
check("claim recovery persisted before clearing",
      "if DataService.Save(worker) then" in data_service
      and "SettlementClaimRules.Remove(profile.PendingClaims, claim.JobId, claim.Token)" in data_service)
check("claim reconciliation runs on load and autosave",
      "task.spawn(DataService.ReconcileWorkerClaims, player)" in data_service)
check("claim tests registered",
      '"SettlementClaimRulesTest"' in runner and (TOOLS / "SettlementClaimRulesTest.luau").is_file())

# C14/C15: a prova do dono tem retenção independente e o resgate só roda
# após janela de segurança; resumos de pendências não expõem tokens.
proof = text(SHARED / "OwnerSettlementProofRules.lua")
check("archive compact proofs for 1024 collaboration payments",
      "Proofs.MaxEntries = 1024" in proof and "function Proofs.Sanitize" in proof)
check("owner archive is private and saved with the profile",
      "OwnerSettlementProofs = {}" in data_service
      and "OwnerSettlementProofRules.Sanitize(data.OwnerSettlementProofs)" in data_service
      and "profileView.OwnerSettlementProofs = nil" in workshop)
check("owner credit creates archive bound to worker",
      '"Owner", service.DisplayName, job.VehicleName, player.UserId, actorPay)' in workshop)
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
check("readme links project checklist", "issues/15" in text(ROOT / "README.md"))

print(f"\nStatic checks: {passed} passed, {len(failures)} failed")
if failures:
    raise SystemExit(1)
print("Note: Roblox runtime tests, asset licenses, visuals and performance remain unverified.")
