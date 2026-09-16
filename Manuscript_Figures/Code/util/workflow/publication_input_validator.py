#!/usr/bin/env python3
"""Validate the publication's actual two-ZIP input layout before analysis."""

from __future__ import annotations

import argparse
import csv
import os
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[4]
FIT_ROOT = ROOT / "results" / "Model_fitting"
INVIVO = FIT_ROOT / "fit_invivo_unified_500seed_r442_exact_20260825_032031"
INVITRO = FIT_ROOT / "fit_invitro_unified_500seed_r442_exact_20260825_032031"
JOINT = FIT_ROOT / "fit_joint_invivo_clusters_global_invitro_best_500seed_r442_exact_20260826_033633"
MODEL = ROOT / "Model" / "oxygen" / "code" / "O2_supply_demand_MAP"
SOURCE_DATA = ROOT / "results" / "data" / "Figures" / "Figure1"
FIGURE_DATA = ROOT / "Manuscript_Figures" / "data" / "Figures"
REPORT = ROOT / "Manuscript_Figures" / "audit" / "reports" / "publication_input_validation.tsv"
FROZEN = (
    "invitro_kary_cells.tsv",
    "invitro_lineage_timeline.tsv",
    "invitro_passage_observations.tsv",
    "invivo_burden_long.tsv",
    "invivo_harvest_catalog.tsv",
    "invivo_ploidy_cells.tsv",
)


def check_seed_set(root: Path, label: str, results: list[tuple[str, str, str]]) -> None:
    if not root.is_dir():
        results.append((label, "FAIL", f"Missing directory: {root}"))
        return
    observed = {
        int(path.name[4:]) for path in root.iterdir()
        if path.is_dir() and re.fullmatch(r"seed[0-9]+", path.name)
    }
    extra = sorted(observed - set(range(1, 501)))
    if not observed or extra:
        results.append((label, "FAIL", f"found={len(observed)}; out-of-range seed IDs={extra[:10]}"))
        return
    status = "PASS" if len(observed) == 500 else "WARN"
    results.append((
        label, status,
        f"found={len(observed)} seed directories; run label 500seed does not by itself prove all 500 outputs were retained",
    ))


def check_path(path: Path, label: str, results: list[tuple[str, str, str]]) -> None:
    results.append((label, "PASS" if path.exists() else "FAIL", str(path)))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", choices=("preflight", "postflight"), required=True)
    args = parser.parse_args()
    if os.environ.get("LTEE_CONTAINER_RUNTIME_ACTIVE", "").lower() not in {"true", "t", "1", "yes", "y"}:
        raise RuntimeError("Publication input validation must run in the locked container")
    results: list[tuple[str, str, str]] = []
    expected_environment = {
        "FIGURE_MODEL_CODE_ROOT": MODEL,
        "FIGURE_INVIVO_RESULT_ROOT": INVIVO,
        "FIGURE_INVITRO_RESULT_ROOT": INVITRO,
        "FIGURE_JOINT_RESULT_ROOT": JOINT,
        "FIGURE_GEMCITABINE_DATA_ROOT": ROOT / "Model" / "data" / "InVivoData_Gemcitabine",
        "FIGURE_LTEE_DATA_ROOT": SOURCE_DATA,
        "FIGURE_INVITRO_SOURCE_DATA_ROOT": SOURCE_DATA / "source_raw",
    }
    for name, expected in expected_environment.items():
        actual = Path(os.environ.get(name, "/missing")).resolve()
        results.append((name, "PASS" if actual == expected else "FAIL", f"{actual} (expected {expected})"))
    for relative in (
        "model/model_O2_supply_demand_MAP.R",
        "model/model_O2_supply_demand_MAP.cpp",
        "util/o2_supply_demand_map_shared.R",
        "util/o2_supply_demand_map_fit_joint_backend.R",
    ):
        check_path(MODEL / relative, f"Model/{relative}", results)
    check_seed_set(INVIVO, "in_vivo_500_seeds", results)
    check_seed_set(INVITRO, "in_vitro_500_seeds", results)
    check_path(INVIVO / "seed25" / "fit_summary.tsv", "in_vivo_figure_seed25", results)
    check_path(INVITRO / "seed144" / "fit_summary.tsv", "in_vitro_figure_seed144", results)
    pair_directories = sorted(path for path in JOINT.glob("fit_joint_tsne_vi_seed*_C0*_vt_seed*") if path.is_dir()) if JOINT.is_dir() else []
    cluster_ids = {
        match.group(1) for path in pair_directories
        if (match := re.search(r"_(C0[1-6])_", path.name))
    }
    results.append((
        "joint_cluster_directories",
        "PASS" if len(pair_directories) == 6 and cluster_ids == {f"C0{i}" for i in range(1, 7)} else "FAIL",
        f"found={len(pair_directories)}; cluster IDs={sorted(cluster_ids)}; expected C01-C06",
    ))
    for pair in pair_directories:
        check_seed_set(pair, f"joint_{pair.name}", results)
    for name in FROZEN:
        check_path(SOURCE_DATA / name, f"frozen_{name}", results)
    check_path(SOURCE_DATA / "source_raw" / "cloneid_passaging_sum159_snapshot_20260731.tsv", "raw_population", results)
    check_path(SOURCE_DATA / "source_raw" / "invitro_observed_flow.tsv", "raw_flow", results)
    check_path(FIGURE_DATA / "Figure1" / "data_contract.tsv", "staged_Figure1", results)
    check_path(FIGURE_DATA / "Figure6" / "fixed_pmisseg_v1", "staged_Figure6", results)

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    with REPORT.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(("phase", "check", "status", "detail"))
        writer.writerows((args.phase, *row) for row in results)
    failed = [row for row in results if row[1] == "FAIL"]
    warnings = [row for row in results if row[1] == "WARN"]
    print(f"Publication input {args.phase}: {len(results) - len(failed) - len(warnings)} PASS, {len(warnings)} WARN, {len(failed)} FAIL")
    for label, _, detail in warnings:
        print(f"WARN {label}: {detail}")
    for label, _, detail in failed:
        print(f"FAIL {label}: {detail}")
    print(f"Validation report: {REPORT}")
    if failed:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
