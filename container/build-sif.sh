#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
lock_file="${script_dir}/analysis-image.lock.tsv"
output="${script_dir}/o2_supply_demand_map_r44.sif"
runtime="apptainer"

usage() {
  cat <<'EOF'
Usage: container/build-sif.sh [--output=/absolute/path/image.sif]
                              [--runtime=apptainer|singularity]

Creates an HPC SIF from the locked linux/amd64 Docker manifest, performs a
container smoke test, and writes <image.sif>.provenance.tsv. No fitting or
analysis is started.
EOF
}

for argument in "$@"; do
  case "${argument}" in
    --output=*) output="${argument#*=}" ;;
    --runtime=*) runtime="${argument#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: ${argument}" >&2; usage >&2; exit 2 ;;
  esac
done

case "${runtime}" in
  apptainer|singularity) ;;
  *) echo "--runtime must be apptainer or singularity." >&2; exit 2 ;;
esac
command -v "${runtime}" >/dev/null 2>&1 || {
  echo "${runtime} is not available. Load/install it before creating the SIF." >&2
  exit 2
}
[[ -f "${lock_file}" ]] || {
  echo "Missing image lock: ${lock_file}" >&2
  exit 2
}

manifest_reference="$(awk -F '\t' '$1 == "docker_amd64_manifest" {print $2}' "${lock_file}")"
manifest_sha="$(awk -F '\t' '$1 == "docker_amd64_manifest" {print $3}' "${lock_file}")"
[[ -n "${manifest_reference}" && -n "${manifest_sha}" ]] || {
  echo "The image lock lacks the Docker amd64 manifest reference." >&2
  exit 2
}

case "${output}" in
  /*) ;;
  *) output="$(pwd -P)/${output}" ;;
esac
mkdir -p "$(dirname "${output}")"
[[ ! -e "${output}" ]] || {
  echo "Refusing to overwrite existing SIF: ${output}" >&2
  exit 2
}

source_reference="docker://${manifest_reference}"
echo "Creating SIF from ${source_reference}"
"${runtime}" pull --arch amd64 "${output}" "${source_reference}"

"${runtime}" exec --cleanenv --containall "${output}" bash -lc '
set -euo pipefail
command -v Rscript >/dev/null
command -v python3 >/dev/null
command -v magick >/dev/null
command -v gs >/dev/null
command -v pdflatex >/dev/null
Rscript --vanilla -e '\''
packages <- c("Matrix", "Rcpp", "Rtsne", "cluster", "cowplot", "data.table", "dplyr",
  "future", "future.apply", "ggnewscale", "ggplot2", "ggrepel", "magick",
  "patchwork", "readxl", "scales", "shadowtext", "svglite", "tidyr")
stopifnot(all(vapply(packages, requireNamespace, logical(1L), quietly = TRUE)))
stopifnot(isTRUE(capabilities("cairo")))
'\''
'

if command -v sha256sum >/dev/null 2>&1; then
  observed_sha="$(sha256sum "${output}")"; observed_sha="${observed_sha%% *}"
else
  observed_sha="$(shasum -a 256 "${output}")"; observed_sha="${observed_sha%% *}"
fi
created_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '%s\t%s\n' \
  key value \
  docker_amd64_manifest_digest "sha256:${manifest_sha}" \
  docker_amd64_manifest_reference "${manifest_reference}" \
  sif_sha256 "${observed_sha}" \
  platform linux/amd64 \
  container_smoke_test PASS \
  created_at_utc "${created_at}" \
  > "${output}.provenance.tsv"

echo "SIF created and validated: ${output}"
echo "SHA-256: ${observed_sha}"
echo "Provenance: ${output}.provenance.tsv"
