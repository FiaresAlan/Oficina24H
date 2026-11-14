#!/usr/bin/env python3
"""V2-16 release decision gate: no Studio, legal or beta evidence is assumed.

This script checks an operator-maintained evidence manifest and the exact
commit. It cannot authenticate real-world claims: review the linked logs,
licences and sign-off before uploading evidence to the repository.
By default (--mode report) it always emits a BLOCKED summary rather than
turning unfinished QA into a failing code-health CI. Use --mode enforce to
fail a deployment/release command when ANY gate is not truly passed.
"""
from __future__ import annotations

import argparse
import copy
import datetime as dt
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT = ROOT / "docs" / "release" / "V2_RELEASE_EVIDENCE.json"

GATES: dict[str, str] = {
    "ci_code": "CI",
    "merge_main": "GitHub",
    "studio_suites": "Studio",
    "assets_place": "Studio",
    "services_15": "Studio",
    "onboarding": "Studio",
    "cooperation": "Studio",
    "data_safety": "Studio",
    "inventory_fifo": "Studio",
    "drive_physics": "Studio",
    "touch_gamepad": "Studio",
    "performance": "Studio",
    "stream_audio": "Studio",
    "licenses": "Legal",
    "beta_closed": "Beta",
    "owner_go": "Owner",
}
STATES = {"Pending", "Passed", "Failed", "Blocked"}


def valid_sha(value: object) -> bool:
    return isinstance(value, str) and bool(re.fullmatch(r"[0-9a-fA-F]{40}|[0-9a-fA-F]{64}", value))


def valid_proof(value: object) -> bool:
    if not isinstance(value, str) or not 18 <= len(value) <= 1000:
        return False
    return bool(re.fullmatch(r"https://\S+|studio://[A-Za-z0-9._/-]+", value))


def valid_date(value: object) -> bool:
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", value):
        return False
    try:
        date = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        return 2025 <= date.year <= 2100
    except ValueError:
        return False


def evaluate(manifest: object, head_sha: str) -> dict[str, object]:
    status: dict[str, object] = {
        "Approved": False,
        "Passed": 0,
        "Failed": 0,
        "Blocked": 0,
        "Pending": 0,
        "Total": len(GATES),
        "Problems": [],
    }
    problems: list[str] = status["Problems"]  # type: ignore[assignment]
    if not valid_sha(head_sha):
        problems.append("SHA alvo inválido; informe o commit completo (--sha).")
        status["Pending"] = len(GATES)
        return status
    if not isinstance(manifest, dict) or manifest.get("Version") != 1 or not isinstance(manifest.get("Entries"), dict):
        problems.append("Manifest ausente ou versão/Entries incompatíveis.")
        status["Pending"] = len(GATES)
        return status
    entries: dict = manifest["Entries"]
    for id, expected_source in GATES.items():
        entry = entries.get(id)
        if not isinstance(entry, dict):
            status["Pending"] = int(status["Pending"]) + 1
            problems.append(f"{id}: nenhuma evidência anexada")
            continue
        state = entry.get("Status", "Pending")
        if state not in STATES:
            state = "Failed"
        if state == "Passed":
            reasons: list[str] = []
            if entry.get("Source") != expected_source:
                reasons.append(f"fonte diferente de {expected_source}")
            if not valid_proof(entry.get("Proof")):
                reasons.append("URL/referência de prova inválida")
            if not isinstance(entry.get("Notes"), str) or len(entry["Notes"]) < 12:
                reasons.append("detalhes insuficientes")
            if not valid_date(entry.get("VerifiedAt")):
                reasons.append("data/hora UTC inválida")
            if entry.get("BuildSha") != head_sha:
                reasons.append("prova de outro commit")
            if reasons:
                status["Failed"] = int(status["Failed"]) + 1
                problems.append(f"{id}: " + ", ".join(reasons))
            else:
                status["Passed"] = int(status["Passed"]) + 1
        else:
            status[state] = int(status[state]) + 1
            problems.append(f"{id}: {state}")
    status["Approved"] = status["Passed"] == len(GATES) and not any(
        status[k] for k in ("Failed", "Blocked", "Pending")
    )
    return status


def self_test() -> None:
    sha = "a" * 40
    empty = {"Version": 1, "Entries": {}}
    assert evaluate(empty, sha)["Pending"] == 16
    assert not evaluate(empty, sha)["Approved"]
    assert not evaluate(empty, "")["Approved"]
    assert not evaluate({"Version": 2, "Entries": {}}, sha)["Approved"]
    entries = {}
    for id, source in GATES.items():
        entries[id] = {
            "Status": "Passed",
            "Source": source,
            "Proof": "https://example.org/qa/record/official-signed-123",
            "Notes": "Exemplo sintético para testar a REGRA, não é evidência real.",
            "VerifiedAt": "2026-11-13T23:00:00Z",
            "BuildSha": sha,
        }
    fake = {"Version": 1, "Entries": entries}
    assert evaluate(fake, sha)["Approved"]  # somente prova a álgebra do gate
    assert not evaluate(fake, "b" * 40)["Approved"]
    for gate, field, value in (
        ("licenses", "Status", "Blocked"),
        ("owner_go", "Status", "Pending"),
        ("inventory_fifo", "Status", "Failed"),
        ("drive_physics", "Source", "CI"),
        ("merge_main", "Proof", "untrusted"),
        ("services_15", "BuildSha", "b" * 40),
        ("data_safety", "VerifiedAt", "tomorrow"),
    ):
        corrupt = copy.deepcopy(fake)
        corrupt["Entries"][gate][field] = value
        assert not evaluate(corrupt, sha)["Approved"], f"Expected blocker: {gate}.{field}"
    print("PASS release gate: 16 criteria, fail-closed, SHA-bound, owner/Studio/legal provenance checks")
    print("NOTE: synthetic self-test does NOT grant real release permission.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT)
    parser.add_argument("--sha", default="", help="exact 40-hex commit under approval")
    parser.add_argument("--mode", choices=("report", "enforce"), default="report")
    parser.add_argument("--self-test", action="store_true")
    opts = parser.parse_args()
    if opts.self_test:
        self_test()
        return 0
    try:
        manifest = json.loads(opts.manifest.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"ERROR: não foi possível ler o manifest: {exc}", file=sys.stderr)
        return 2
    result = evaluate(manifest, opts.sha)
    title = "ELEGÍVEL PARA REVISÃO HUMANA" if result["Approved"] else "RELEASE BLOQUEADA"
    print(f"{title}: {result['Passed']}/{result['Total']} gates aprovados, "
          f"{result['Failed']} inválidos, {result['Blocked']} bloqueados, "
          f"{result['Pending']} pendentes")
    for problem in result["Problems"]:
        print(f" - {problem}")
    print("ATENÇÃO: links e licença precisam de inspeção humana; CI/manifest não publicam o jogo.")
    if opts.mode == "enforce" and not result["Approved"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
