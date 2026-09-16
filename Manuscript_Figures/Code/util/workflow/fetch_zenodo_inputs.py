#!/usr/bin/env python3
"""Fetch only missing publication ZIPs from the pinned Zenodo record."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import tempfile
from urllib.parse import urlparse
from urllib.request import urlopen
from zipfile import ZipFile


CODE_ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = CODE_ROOT.parents[1]
MANIFEST = CODE_ROOT / "config" / "zenodo_inputs.tsv"
COLUMNS = ("dataset_id", "doi", "file_name", "sha256", "target_relative", "required_probe")
DOI = "10.5281/zenodo.22799665"


def input_rows() -> list[dict[str, str]]:
    with MANIFEST.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if tuple(reader.fieldnames or ()) != COLUMNS:
            raise RuntimeError("Invalid Zenodo manifest schema")
        rows = list(reader)
    if [row["dataset_id"] for row in rows] != ["Model_fitting", "data"]:
        raise RuntimeError("Zenodo manifest must declare exactly Model_fitting and data")
    return rows


def safe_relative(value: str) -> Path:
    path = PurePosixPath(value)
    if not value or path.is_absolute() or ".." in path.parts or "\\" in value:
        raise RuntimeError(f"Unsafe relative path: {value}")
    return Path(*path.parts)


def target_for(row: dict[str, str]) -> tuple[Path, list[Path]]:
    if row["doi"] != DOI or row["file_name"] != row["dataset_id"] + ".zip":
        raise RuntimeError(f"Unexpected Zenodo DOI or filename: {row['dataset_id']}")
    expected = Path("results") / row["dataset_id"]
    if safe_relative(row["target_relative"]) != expected:
        raise RuntimeError(f"Unexpected Zenodo target: {row['target_relative']}")
    probes = [safe_relative(item) for item in row["required_probe"].split(",")]
    if not probes:
        raise RuntimeError(f"No layout probes for {row['dataset_id']}")
    return REPO_ROOT / expected, probes


def check_layout(root: Path, probes: list[Path]) -> None:
    missing = [str(root / probe) for probe in probes if not (root / probe).is_dir()]
    if missing:
        raise RuntimeError(
            "Existing or downloaded dataset has an incomplete expected layout: "
            + ", ".join(missing)
        )


def record_file(record_id: str, file_name: str) -> dict:
    url = f"https://zenodo.org/api/records/{record_id}"
    try:
        with urlopen(url, timeout=60) as response:
            record = json.load(response)
    except Exception as error:
        raise RuntimeError(
            f"Zenodo record {record_id} is not yet public or reachable. "
            "The DOI is reserved; publish Model_fitting.zip and data.zip before downloading."
        ) from error
    if record.get("doi") != DOI:
        raise RuntimeError(f"Zenodo record DOI mismatch: {record.get('doi')}")
    matches = [
        item for item in record.get("files", [])
        if item.get("key", item.get("filename")) == file_name
    ]
    if len(matches) != 1:
        raise RuntimeError(f"Zenodo record does not contain exactly one {file_name}")
    item = matches[0]
    download_url = item.get("links", {}).get("self", "")
    parsed = urlparse(download_url)
    if parsed.scheme != "https" or parsed.hostname != "zenodo.org":
        raise RuntimeError(f"Unexpected Zenodo download URL for {file_name}")
    checksum = item.get("checksum", "")
    if not re.fullmatch(r"md5:[0-9a-fA-F]{32}", checksum):
        raise RuntimeError(f"Zenodo metadata has no valid MD5 for {file_name}")
    return item


def checked_download(item: dict, file_name: str, expected_sha: str, path: Path) -> str:
    digest_md5 = hashlib.md5()
    digest_sha = hashlib.sha256()
    expected_md5 = item["checksum"].split(":", 1)[1].lower()
    url = item["links"]["self"]
    with urlopen(url, timeout=120) as response, path.open("xb") as output:
        while chunk := response.read(8 * 1024 * 1024):
            output.write(chunk)
            digest_md5.update(chunk)
            digest_sha.update(chunk)
    if digest_md5.hexdigest() != expected_md5:
        raise RuntimeError(f"Zenodo MD5 mismatch for {file_name}")
    observed_sha = digest_sha.hexdigest()
    if expected_sha != "TO_BE_ASSIGNED":
        if not re.fullmatch(r"[0-9a-fA-F]{64}", expected_sha):
            raise RuntimeError(f"Invalid pinned SHA-256 for {file_name}")
        if observed_sha != expected_sha.lower():
            raise RuntimeError(f"Pinned SHA-256 mismatch for {file_name}")
    else:
        print(f"WARNING: {file_name} has no release-pinned SHA-256; observed {observed_sha}")
    return observed_sha


def extract_checked(archive: Path, stage: Path, target_name: str, probes: list[Path]) -> Path:
    with ZipFile(archive) as zipped:
        members = zipped.infolist()
        if not members:
            raise RuntimeError(f"Empty Zenodo ZIP: {archive.name}")
        seen: set[str] = set()
        for member in members:
            raw = member.filename.rstrip("/")
            relative = safe_relative(raw)
            if raw in seen or not relative.parts:
                raise RuntimeError(f"Duplicate or unsafe ZIP member: {member.filename}")
            if any(
                part.lower().startswith("chromosome_flux")
                or "empirical_comparison" in part.lower()
                or "growth_permissive" in part.lower()
                or "20_21" in part.lower()
                or part.lower().startswith(("supp_fig6-20", "supp_fig6-21"))
                for part in relative.parts
            ):
                raise RuntimeError(f"Excluded experiment appears in publication ZIP: {member.filename}")
            seen.add(raw)
            mode = member.external_attr >> 16
            if stat.S_ISLNK(mode):
                raise RuntimeError(f"ZIP symlink is not permitted: {member.filename}")
        zipped.extractall(stage)
    candidate = stage
    top_level = list(stage.iterdir())
    if len(top_level) == 1 and top_level[0].is_dir():
        if top_level[0].name == target_name:
            candidate = top_level[0]
        elif top_level[0].name == "results":
            nested = top_level[0] / target_name
            if nested.is_dir() and len(list(top_level[0].iterdir())) == 1:
                candidate = nested
    check_layout(candidate, probes)
    return candidate


def install(row: dict[str, str], target: Path, probes: list[Path]) -> None:
    record_id = DOI.rsplit(".", 1)[1]
    item = record_file(record_id, row["file_name"])
    download_root = REPO_ROOT / "results" / ".zenodo-downloads"
    download_root.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix="stage-", dir=download_root))
    archive = stage / row["file_name"]
    extraction = stage / "unpacked"
    extraction.mkdir()
    try:
        observed_sha = checked_download(
            item, row["file_name"], row["sha256"], archive
        )
        candidate = extract_checked(archive, extraction, target.name, probes)
        if target.exists():
            raise RuntimeError(f"Refusing to overwrite existing directory: {target}")
        os.replace(candidate, target)
        print(f"Installed {row['dataset_id']} from {DOI} ({observed_sha})")
    finally:
        shutil.rmtree(stage)


def main() -> None:
    active = os.environ.get("LTEE_CONTAINER_RUNTIME_ACTIVE", "").lower()
    if active not in {"true", "t", "1", "yes", "y"}:
        raise RuntimeError("Zenodo inputs must be fetched inside the locked container")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", default="required", choices=("required", "all", "Model_fitting", "data"))
    args = parser.parse_args()
    for row in input_rows():
        if args.dataset not in {"required", "all", row["dataset_id"]}:
            continue
        target, probes = target_for(row)
        if target.exists():
            if not target.is_dir():
                raise RuntimeError(f"Zenodo target exists but is not a directory: {target}")
            check_layout(target, probes)
            print(f"Present: {target}; skipping download")
            continue
        install(row, target, probes)


if __name__ == "__main__":
    main()
