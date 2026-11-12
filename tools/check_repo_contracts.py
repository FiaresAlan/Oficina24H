#!/usr/bin/env python3
"""Verificação ESTÁTICA de contratos do projeto Roblox.

Não compila nem executa Luau, não testa Roblox Studio ou gameplay.
Use para descobrir módulos ausentes, suítes esquecidas e contrato Rojo inconsistente.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
SHARED = SRC / "shared"
TOOLS = ROOT / "tools"
issues: list[str] = []


def require_path(path: Path, reason: str) -> None:
    if not path.is_file():
        issues.append(f"{reason}: arquivo ausente {path.relative_to(ROOT)}")


def source_files() -> list[Path]:
    return sorted(SRC.rglob("*.lua"))


project = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))
tree = project["tree"]
expected = {
    "ReplicatedStorage": ("Shared", "src/shared"),
    "ServerScriptService": ("Server", "src/server"),
    "ServerStorage": ("Tools", "tools"),
}
for service, (folder, relative) in expected.items():
    actual = tree.get(service, {}).get(folder, {}).get("$path")
    if actual != relative:
        issues.append(f"Rojo {service}/{folder}: esperado {relative!r}, obtido {actual!r}")

client = tree.get("StarterPlayer", {}).get("StarterPlayerScripts", {}).get("Client", {}).get("$path")
if client != "src/client":
    issues.append(f"Rojo StarterPlayerScripts/Client: esperado src/client, obtido {client!r}")

known_shared = {p.stem for p in SHARED.glob("*.lua")}
shared_require = re.compile(r"require\(\s*(?:ReplicatedStorage|game:GetService\(['\"]ReplicatedStorage['\"]\))\.Shared\.([A-Za-z_]\w*)\s*\)")
relative_require = re.compile(r"require\(\s*script((?:\.Parent)+)\.([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)\s*\)")
for file in source_files():
    code = file.read_text(encoding="utf-8")
    for name in shared_require.findall(code):
        if name not in known_shared:
            issues.append(f"{file.relative_to(ROOT)}: Shared.{name} ausente")
    for parents, suffix in relative_require.findall(code):
        parent = file.parent
        for _ in range(parents.count(".Parent") - 1):
            parent = parent.parent
        path = parent.joinpath(*suffix.split("."))
        if not (path.with_suffix(".lua").is_file()
                or path.with_suffix(".client.lua").is_file()
                or path.with_suffix(".server.lua").is_file()):
            issues.append(f"{file.relative_to(ROOT)}: require relativo ausente script{parents}.{suffix}")

runner = (TOOLS / "RunAllTests.luau").read_text(encoding="utf-8")
match = re.search(r"local suites\s*=\s*\{([^}]+)\}", runner)
if not match:
    issues.append("RunAllTests: lista de suítes ausente")
    suite_names = []
else:
    suite_names = re.findall(r'["\']([A-Za-z_]\w*)["\']', match.group(1))
    if len(suite_names) != len(set(suite_names)):
        issues.append("RunAllTests: suítes duplicadas")
    for suite in suite_names:
        require_path(TOOLS / (suite + ".luau"), "RunAllTests")

new_modules = [
    "JobLifecycleRules", "HudLayoutRules", "ServiceFocusRules", "RepairOperations",
    "RepairPrepRules", "RepairSocketRules", "CollaborationRules",
]
for module in new_modules:
    require_path(SHARED / (module + ".lua"), "Shared")

print(f"Arquivos Luau examinados: {len(source_files())}")
print(f"Suítes integradas ao RunAllTests: {len(suite_names)}")
print("Aviso: este é um gate estático, NÃO significa que o jogo passou no Studio.")
if issues:
    for issue in issues:
        print("ERRO:", issue)
    raise SystemExit(1)
print("PASS: caminhos de módulos, mapeamento Rojo e suítes presentes.")
