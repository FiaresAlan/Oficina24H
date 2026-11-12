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
check("readme links project checklist", "issues/15" in text(ROOT / "README.md"))

print(f"\nStatic checks: {passed} passed, {len(failures)} failed")
if failures:
    raise SystemExit(1)
print("Note: Roblox runtime tests, asset licenses, visuals and performance remain unverified.")
