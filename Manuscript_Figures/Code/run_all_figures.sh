#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "${script_dir}/../.." && pwd -P)"
lock_file="${script_dir}/config/container_image_lock.tsv"
container_entry="/workspace/Manuscript_Figures/Code/run_all_figures_container.sh"
fetch_entry="/workspace/Manuscript_Figures/Code/fetch_zenodo_inputs.sh"

lock_value() {
  awk -F '\t' -v key="$1" 'NR > 1 && $1 == key { print $2; exit }' "${lock_file}"
}

[[ -f "${lock_file}" ]] || {
  echo "Missing analysis-image lock: ${lock_file}" >&2
  exit 2
}

analysis_version="$(lock_value analysis_version)"
default_image="$(lock_value docker_image)"
expected_config_id="$(lock_value docker_config_id)"
expected_manifest="$(lock_value docker_amd64_manifest_digest)"
expected_platform="$(lock_value platform)"
default_sif_name="$(lock_value sif_file_name)"
expected_sif_sha="$(lock_value sif_sha256)"

runtime="auto"
image="${LTEE_ANALYSIS_IMAGE:-${default_image}}"
sif_image="${LTEE_ANALYSIS_SIF:-${repo_root}/container/${default_sif_name}}"
n_core=8
offline=FALSE
check_only=FALSE
recompute_fixed_o2=FALSE
recompute_invivo_tsne=FALSE
model_dependent_only=FALSE
first_main_figure=1
resume_after_figure5f_de=FALSE
figure6_smoke=FALSE

usage() {
  cat <<EOF
Usage: Manuscript_Figures/Code/run_all_figures.sh [options]

This is the only supported publication-figure entry point. It never runs R on
the host. macOS/Linux workstations use Docker; HPC uses a verified SIF through
Apptainer or Singularity.

Runtime options:
  --runtime=auto|docker|apptainer|singularity
  --image=IMAGE              Default: ${default_image}
  --sif=PATH                 Default: <repo>/container/${default_sif_name}
  --offline                  Do not fetch missing Zenodo inputs
  --download-missing         Fetch required missing inputs (default behavior)
  --check-only               Validate image and deployed entry points; no data needed

Workflow options:
  --n-core=N                 Default: 8
  --recompute-fixed-o2=TRUE|FALSE
  --recompute-invivo-tsne=TRUE|FALSE
  --model-dependent-only=TRUE|FALSE
  --first-main-figure=1|3|4
  --resume-after-figure5f-de=TRUE|FALSE
  --figure6-smoke=TRUE|FALSE
  -h, --help

Required repository layout:
  results/Model_fitting  (three named fit directories)
  results/data           (Figures intermediates and frozen source tables)

Missing Docker images and SIF files are never built or pulled automatically.
EOF
}

boolean_value() {
  case "$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')" in
    true|t|1|yes|y) printf 'TRUE' ;;
    false|f|0|no|n) printf 'FALSE' ;;
    *) echo "$1 must be TRUE or FALSE." >&2; exit 2 ;;
  esac
}

for argument in "$@"; do
  case "${argument}" in
    --runtime=*) runtime="${argument#*=}" ;;
    --image=*) image="${argument#*=}" ;;
    --sif=*) sif_image="${argument#*=}" ;;
    --n-core=*) n_core="${argument#*=}" ;;
    --offline) offline=TRUE ;;
    --download-missing) offline=FALSE ;;
    --check-only) check_only=TRUE ;;
    --recompute-fixed-o2=*) recompute_fixed_o2="$(boolean_value --recompute-fixed-o2 "${argument#*=}")" ;;
    --recompute-invivo-tsne=*) recompute_invivo_tsne="$(boolean_value --recompute-invivo-tsne "${argument#*=}")" ;;
    --model-dependent-only=*) model_dependent_only="$(boolean_value --model-dependent-only "${argument#*=}")" ;;
    --first-main-figure=*) first_main_figure="${argument#*=}" ;;
    --resume-after-figure5f-de=*) resume_after_figure5f_de="$(boolean_value --resume-after-figure5f-de "${argument#*=}")" ;;
    --figure6-smoke=*) figure6_smoke="$(boolean_value --figure6-smoke "${argument#*=}")" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: ${argument}" >&2; usage >&2; exit 2 ;;
  esac
done

case "${runtime}" in
  auto|docker|apptainer|singularity) ;;
  *) echo "--runtime must be auto, docker, apptainer, or singularity." >&2; exit 2 ;;
esac
[[ "${n_core}" =~ ^[1-9][0-9]*$ ]] || {
  echo "--n-core must be a positive integer." >&2
  exit 2
}
case "${first_main_figure}" in 1|3|4) ;; *)
  echo "--first-main-figure must be 1, 3, or 4." >&2
  exit 2
esac

if [[ "${runtime}" == "auto" ]]; then
  if [[ -n "${SLURM_JOB_ID:-}" || -n "${SLURM_CLUSTER_NAME:-}" ]]; then
    if command -v apptainer >/dev/null 2>&1; then
      runtime=apptainer
    else
      runtime=singularity
    fi
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    runtime=docker
  elif command -v docker >/dev/null 2>&1; then
    runtime=docker
  elif command -v apptainer >/dev/null 2>&1; then
    runtime=apptainer
  elif command -v singularity >/dev/null 2>&1; then
    runtime=singularity
  else
    runtime=docker
  fi
fi

source_git_sha="unknown"
if command -v git >/dev/null 2>&1; then
  source_git_sha="$(git -C "${repo_root}" rev-parse HEAD 2>/dev/null || printf unknown)"
fi

runtime_tmp="$(mktemp -d "${TMPDIR:-/tmp}/ltee-oxygen-runtime.XXXXXX")"
cleanup() {
  rm -rf -- "${runtime_tmp}"
}
trap cleanup EXIT
mkdir -p "${runtime_tmp}/home" "${runtime_tmp}/cache" "${runtime_tmp}/rcpp-cache"
printf '%s\n' 'options(bitmapType = "cairo", device = "png", warn = 1)' \
  > "${runtime_tmp}/Rprofile"

common_environment=(
  "LTEE_CONTAINER_RUNTIME_ACTIVE=TRUE"
  "LTEE_CONTAINER_REPO_ROOT=/workspace"
  "LTEE_ANALYSIS_VERSION=${analysis_version}"
  "LTEE_ANALYSIS_IMAGE_REFERENCE=${image}"
  "LTEE_SOURCE_GIT_SHA=${source_git_sha}"
  "HOME=/runtime/home"
  "TMPDIR=/runtime/cache"
  "XDG_CACHE_HOME=/runtime/cache"
  "R_ENVIRON_USER=/dev/null"
  "R_PROFILE_USER=/runtime/Rprofile"
  "PYTHONNOUSERSITE=1"
  "OMP_NUM_THREADS=1"
  "OPENBLAS_NUM_THREADS=1"
  "MKL_NUM_THREADS=1"
  "VECLIB_MAXIMUM_THREADS=1"
  "RCPP_PARALLEL_NUM_THREADS=1"
)

docker_identity=""
prepare_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required but is not available on PATH." >&2
    echo "Install/start Docker Desktop, then download the locked image with:" >&2
    echo "  docker pull --platform ${expected_platform} ${default_image}" >&2
    exit 2
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "Docker is installed, but the Docker daemon is unavailable." >&2
    echo "Start Docker Desktop, then run:" >&2
    echo "  docker pull --platform ${expected_platform} ${default_image}" >&2
    exit 2
  fi
  if ! docker image inspect "${image}" >/dev/null 2>&1; then
    echo "Locked analysis image is not available locally: ${image}" >&2
    echo "Download it with:" >&2
    echo "  docker pull --platform ${expected_platform} ${default_image}" >&2
    exit 2
  fi
  docker_identity="$(docker image inspect --format '{{.Id}}' "${image}")"
  observed_platform="$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "${image}")"
  if [[ "${observed_platform}" != "${expected_platform}" ]]; then
    echo "Docker platform mismatch: expected ${expected_platform}, observed ${observed_platform}." >&2
    exit 2
  fi
  if [[ "${docker_identity}" != "${expected_config_id}" ]]; then
    label_version="$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' "${image}")"
    label_base_digest="$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.base.digest"}}' "${image}")"
    if [[ "${label_version}" != "${analysis_version}" || \
          "${label_base_digest}" != "${expected_manifest}" ]]; then
      echo "Docker image identity mismatch for ${image}." >&2
      echo "Expected config ID: ${expected_config_id}" >&2
      echo "Observed config ID: ${docker_identity}" >&2
      echo "The image is neither the locked Docker Hub image nor its labeled publication derivative." >&2
      exit 2
    fi
  fi
}

docker_exec() {
  local network_mode="$1"
  shift
  local args=(
    run --rm --init --platform "${expected_platform}"
    --user "$(id -u):$(id -g)"
    --network "${network_mode}"
    --workdir /workspace
    --mount "type=bind,source=${repo_root},target=/workspace"
    --mount "type=bind,source=${runtime_tmp},target=/runtime"
    --mount "type=bind,source=${runtime_tmp}/rcpp-cache,target=/workspace/Model/oxygen/code/O2_supply_demand_MAP/model/.rcpp_cache_o2_supply_demand_map"
  )
  local setting
  for setting in "${common_environment[@]}" \
    "LTEE_CONTAINER_RUNTIME=docker" \
    "LTEE_ANALYSIS_IMAGE_IDENTITY=${docker_identity}"; do
    args+=(--env "${setting}")
  done
  docker "${args[@]}" "${image}" "$@"
}

container_runtime_command=""
sif_sha=""
prepare_sif() {
  container_runtime_command="${runtime}"
  if ! command -v "${container_runtime_command}" >/dev/null 2>&1; then
    echo "${runtime} is required for HPC execution but is not available on PATH." >&2
    echo "Load the cluster Apptainer/Singularity module, then create the SIF with:" >&2
    echo "  bash container/build-sif.sh --runtime=${runtime} --output=${sif_image}" >&2
    exit 2
  fi
  if [[ ! -f "${sif_image}" || ! -r "${sif_image}" ]]; then
    echo "Verified analysis SIF is missing or unreadable: ${sif_image}" >&2
    echo "Create it from the locked Docker image before analysis:" >&2
    echo "  bash container/build-sif.sh --runtime=${runtime} --output=${sif_image}" >&2
    echo "The helper pins the Docker manifest and creates a provenance sidecar." >&2
    exit 2
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sif_sha="$(sha256sum "${sif_image}")"; sif_sha="${sif_sha%% *}"
  elif command -v shasum >/dev/null 2>&1; then
    sif_sha="$(shasum -a 256 "${sif_image}")"; sif_sha="${sif_sha%% *}"
  else
    echo "Neither sha256sum nor shasum is available to verify the SIF." >&2
    exit 2
  fi
  if [[ "${sif_sha}" != "${expected_sif_sha}" ]]; then
    provenance="${sif_image}.provenance.tsv"
    provenance_sha=""
    provenance_manifest=""
    provenance_platform=""
    provenance_test=""
    if [[ -f "${provenance}" ]]; then
      provenance_sha="$(awk -F '\t' '$1 == "sif_sha256" {print $2}' "${provenance}")"
      provenance_manifest="$(awk -F '\t' '$1 == "docker_amd64_manifest_digest" {print $2}' "${provenance}")"
      provenance_platform="$(awk -F '\t' '$1 == "platform" {print $2}' "${provenance}")"
      provenance_test="$(awk -F '\t' '$1 == "container_smoke_test" {print $2}' "${provenance}")"
    fi
    if [[ "${provenance_sha}" != "${sif_sha}" || \
          "${provenance_manifest}" != "${expected_manifest}" || \
          "${provenance_platform}" != "${expected_platform}" || \
          "${provenance_test}" != "PASS" ]]; then
      echo "SIF checksum/provenance validation failed for ${sif_image}." >&2
      echo "Locked SIF SHA-256: ${expected_sif_sha}" >&2
      echo "Observed SHA-256: ${sif_sha}" >&2
      echo "Use the locked SIF, or recreate it with:" >&2
      echo "  bash container/build-sif.sh --runtime=${runtime} --output=${sif_image}" >&2
      exit 2
    fi
  fi
}

sif_exec() {
  local args=(
    exec --cleanenv --containall --pwd /workspace
    --home "${runtime_tmp}/home"
    --bind "${repo_root}:/workspace:rw"
    --bind "${runtime_tmp}:/runtime:rw"
    --bind "${runtime_tmp}/rcpp-cache:/workspace/Model/oxygen/code/O2_supply_demand_MAP/model/.rcpp_cache_o2_supply_demand_map:rw"
  )
  local setting
  for setting in "${common_environment[@]}" \
    "LTEE_CONTAINER_RUNTIME=${runtime}" \
    "LTEE_ANALYSIS_IMAGE_IDENTITY=${sif_image}" \
    "LTEE_ANALYSIS_SIF_SHA256=${sif_sha}"; do
    args+=(--env "${setting}")
  done
  "${container_runtime_command}" "${args[@]}" "${sif_image}" "$@"
}

if [[ "${runtime}" == "docker" ]]; then
  prepare_docker
  container_exec() { docker_exec "$@"; }
else
  prepare_sif
  container_exec() { local ignored_network="$1"; shift; sif_exec "$@"; }
fi

if [[ "${check_only}" == "TRUE" ]]; then
  container_exec none bash "${container_entry}" --check-only
  exit 0
fi

missing_inputs=()
required_probes=(
  "${repo_root}/results/Model_fitting"
  "${repo_root}/results/data"
)
for probe in "${required_probes[@]}"; do
  [[ -d "${probe}" ]] || missing_inputs+=("${probe}")
done
if (( ${#missing_inputs[@]} > 0 )); then
  if [[ "${offline}" == "TRUE" ]]; then
    echo "Required publication inputs are missing in --offline mode:" >&2
    printf '  %s\n' "${missing_inputs[@]}" >&2
    exit 2
  fi
  echo "Required inputs are missing; invoking the containerized Zenodo fetcher."
  container_exec bridge bash "${fetch_entry}" --dataset=required
fi

runner_args=(
  "--n-core=${n_core}"
  "--recompute-fixed-o2=${recompute_fixed_o2}"
  "--recompute-invivo-tsne=${recompute_invivo_tsne}"
  "--model-dependent-only=${model_dependent_only}"
  "--first-main-figure=${first_main_figure}"
  "--resume-after-figure5f-de=${resume_after_figure5f_de}"
  "--figure6-smoke=${figure6_smoke}"
)
container_exec none bash "${container_entry}" "${runner_args[@]}"
