#!/usr/bin/env python3
"""Stage the Zenodo figure cache into a separate writable analysis workspace."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import tempfile


ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "results" / "data" / "Figures"
TARGET = ROOT / "Manuscript_Figures" / "data" / "Figures"
PROBES = ("Figure1/data_contract.tsv", "Figure6/fixed_pmisseg_v1")


def ignore_excluded(directory: str, names: list[str]) -> set[str]:
    excluded = {
        ".DS_Store",
        "Figure6_empirical_comparison",
        "Supp_Figure6_8",
        "Supp_Figure6_9",
    }
    return {
        name for name in names
        if name in excluded
        or name.startswith("chromosome_flux")
        or name.startswith(".rcpp_cache")
        or "empirical_comparison" in name.lower()
        or "growth_permissive" in name.lower()
        or "20_21" in name.lower()
        or name.lower().startswith(("supp_fig6-20", "supp_fig6-21"))
    }


def main() -> None:
    if os.environ.get("LTEE_CONTAINER_RUNTIME_ACTIVE", "").lower() not in {"true", "t", "1", "yes", "y"}:
        raise RuntimeError("Publication data staging must run in the locked container")
    if not SOURCE.is_dir():
        raise RuntimeError(f"Missing Zenodo figure cache: {SOURCE}")
    if TARGET.is_dir() and all((TARGET / probe).exists() for probe in PROBES):
        print(f"Figure workspace already staged: {TARGET}")
        return
    if TARGET.exists() and (not TARGET.is_dir() or any(TARGET.iterdir())):
        raise RuntimeError(f"Incomplete nonempty figure workspace; will not overwrite: {TARGET}")
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    staging_parent = Path(tempfile.mkdtemp(prefix="figure-stage-", dir=TARGET.parent))
    staged = staging_parent / "Figures"
    try:
        shutil.copytree(SOURCE, staged, ignore=ignore_excluded)
        if not all((staged / probe).exists() for probe in PROBES):
            raise RuntimeError("Zenodo data archive lacks required Figure 1/6 intermediates")
        if TARGET.is_dir():
            TARGET.rmdir()
        os.replace(staged, TARGET)
        print(f"Staged figure intermediates: {TARGET}")
    finally:
        shutil.rmtree(staging_parent)


if __name__ == "__main__":
    main()
