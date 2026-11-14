#!/usr/bin/env python3
"""Auditoria estática extra: código e suites, sem afirmar runtime/Studio.

Checks all repository Lua/Luau source files for broken direct Shared requires,
client-side imports of private answer keys and test registry mismatches.
The test is intentionally conservative: it only validates resolvable literals,
never dynamic require names or UI/physics.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHARED = ROOT / "src" / "shared"
SERVER = ROOT / "src" / "server"
CLIENT = ROOT / "src" / "client"
TOOLS = ROOT / "tools"
failures: list[str] = []
warnings: list[str] = []
checks = 0

shared_files = {
    p.name.removesuffix(".lua") for p in SHARED.glob("*.lua")
}
server_files = {
    p.name.removesuffix(".lua") for p in SERVER.glob("*.lua")
}
sources = sorted(
    p for p in ROOT.rglob("*")
    if p.is_file() and (p.suffix in {".lua", ".luau"})
    and ".git" not in p.parts
)
# Clear syntax forms only; require(script.Parent.Parent.*) and dynamic paths
# cannot be resolved statically and are intentionally not guessed.
shared_call = re.compile(
    r"\brequire\s*\(\s*(?:ReplicatedStorage\.Shared|"
    r"game\.ReplicatedStorage\.Shared|Shared)\.([A-Za-z_]\w*)\s*\)"
)
server_call = re.compile(
    r"\brequire\s*\(\s*script\.Parent\.([A-Za-z_]\w*)\s*\)"
)
repl_paths = re.compile(
    r"(?:ReplicatedStorage\.Shared|game\.ReplicatedStorage\.Shared)"
    r"\.(?:RepairOperations|WorkshopProcedures)\b"
)
for source in sources:
    body = source.read_text(encoding="utf-8")
    rel = source.relative_to(ROOT)
    for ref in shared_call.findall(body):
        checks += 1
        if ref not in shared_files:
            failures.append(f"{rel}: Shared.{ref} não existe no Rojo")
    if source.parent == SERVER:
        for ref in server_call.findall(body):
            checks += 1
            if ref not in server_files:
                failures.append(f"{rel}: Server.{ref} não existe")
    if source.is_relative_to(CLIENT) and repl_paths.search(body):
        failures.append(f"{rel}: gabarito privado alcançável pelo cliente")

for secret in ("RepairOperations", "WorkshopProcedures"):
    checks += 1
    if (SHARED / (secret + ".lua")).is_file():
        failures.append(f"SEGURANÇA: {secret} replicado em src/shared")
    if secret not in server_files:
        failures.append(f"{secret} ausente no servidor")
    if not (SERVER / (secret + ".lua")).is_file():
        failures.append(f"arquivo privado {secret} ausente")

runner = (TOOLS / "RunAllTests.luau").read_text(encoding="utf-8")
suites = re.findall(r'\"([A-Za-z_]\w*(?:Test|Audit))\"', runner.split("local suites = {", 1)[-1].split("}", 1)[0])
checks += len(suites)
if len(suites) != len(set(suites)):
    failures.append("RunAllTests contém suites duplicadas")
for name in suites:
    if not (TOOLS / (name + ".luau")).is_file():
        failures.append(f"Suite registrada não existe: {name}")
if len(suites) < 70:
    failures.append(f"Regressão: runner possui apenas {len(suites)} suites, esperado >=70")
for must in (
    "RequestBudgetRulesTest",
    "V2FleetContractTest",
    "V2ReleaseGateRulesTest",
    "V2BetaSmokeAudit",
    "StudioPlaceAudit",
):
    if must not in suites:
        failures.append(f"Suite obrigatória não registrada: {must}")
checks += 5

# Avisos não aprovam produto: licenças/asset/QA humanos permanecem fora do CI.
if not (ROOT / "docs" / "release" / "V2_RELEASE_EVIDENCE.json").is_file():
    failures.append("Manifest de release ausente")
else:
    checks += 1
warnings.append("V2-08 fornecedores/lotes FIFO ainda pendente; QA Studio não executada no CI")
warnings.append("Licenças de alguns assets, integração main e beta dependem de evidência humana")

for problem in failures:
    print("FAIL", problem)
for warning in warnings:
    print("WARN", warning)
print(f"Audit static modules: {len(sources)} sources, {len(suites)} suites, "
      f"{checks} checks, {len(failures)} failures, {len(warnings)} warnings")
if failures:
    raise SystemExit(1)
print("PASS cross-module integrity (NOT Play Solo, Luau compilation or game QA)")
