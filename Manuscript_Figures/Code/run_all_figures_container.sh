#!/usr/bin/env bash

set -euo pipefail

active="${LTEE_CONTAINER_RUNTIME_ACTIVE:-${O2SD_CONTAINER_RUNTIME_ACTIVE:-}}"
case "$(printf '%s' "${active}" | tr '[:upper:]' '[:lower:]')" in
  true|t|1|yes|y) ;;
  *)
    echo "This script is an internal container entry point." >&2
    echo "Run Manuscript_Figures/Code/run_all_figures.sh on the host." >&2
    exit 2
    ;;
esac

repo_root="${LTEE_CONTAINER_REPO_ROOT:-/workspace}"
workspace_root="${repo_root}/Manuscript_Figures"
code_root="${workspace_root}/Code"
figure_runner="${code_root}/Figures/run_all_figures.R"
validator="${code_root}/util/workflow/publication_input_validator.py"
stage_data="${code_root}/util/workflow/stage_publication_data.py"
check_only=FALSE
runner_args=()

for argument in "$@"; do
  case "${argument}" in
    --check-only) check_only=TRUE ;;
    --n-core=*|--recompute-fixed-o2=*|--recompute-invivo-tsne=*|--model-dependent-only=*|--first-main-figure=*|--resume-after-figure5f-de=*|--figure6-smoke=*)
      runner_args+=("${argument}")
      ;;
    -h|--help)
      echo "Internal container entry point; use run_all_figures.sh --help."
      exit 0
      ;;
    *) echo "Unknown container entry option: ${argument}" >&2; exit 2 ;;
  esac
done

[[ -f "${figure_runner}" ]] || {
  echo "Missing figure runner: ${figure_runner}" >&2
  exit 2
}
for required_command in Rscript python3 magick gs pdflatex; do
  command -v "${required_command}" >/dev/null 2>&1 || {
    echo "Locked image is missing command: ${required_command}" >&2
    exit 2
  }
done

missing_packages="$(Rscript --vanilla -e '
packages <- c(
  "Matrix", "Rcpp", "Rtsne", "cluster", "cowplot", "data.table",
  "dplyr", "future", "future.apply", "ggnewscale", "ggplot2", "ggrepel",
  "magick", "patchwork", "readxl", "scales", "shadowtext", "svglite",
  "tidyr"
)
missing <- packages[!vapply(packages, requireNamespace, logical(1L), quietly = TRUE)]
cat(missing, sep = "\n")
')"
if [[ -n "${missing_packages}" ]]; then
  echo "Locked image is missing required R package(s):" >&2
  printf '%s\n' "${missing_packages}" >&2
  exit 2
fi
if ! Rscript --vanilla -e '
stopifnot(isTRUE(capabilities("cairo")))
path <- tempfile(fileext = ".png")
grDevices::png(path, width = 64, height = 64, type = "cairo")
graphics::plot.new()
grDevices::dev.off()
stopifnot(file.exists(path), file.info(path)$size > 0)
unlink(path)
' >/dev/null; then
  echo "Locked image failed the headless Cairo PNG smoke test." >&2
  exit 2
fi

export FIGURE_WORKSPACE_ROOT="${workspace_root}"
export FIGURE_MODEL_CODE_ROOT="${repo_root}/Model/oxygen/code/O2_supply_demand_MAP"
export FIGURE_INVIVO_RESULT_ROOT="${repo_root}/results/Model_fitting/fit_invivo_unified_500seed_r442_exact_20260825_032031"
export FIGURE_INVITRO_RESULT_ROOT="${repo_root}/results/Model_fitting/fit_invitro_unified_500seed_r442_exact_20260825_032031"
export FIGURE_JOINT_RESULT_ROOT="${repo_root}/results/Model_fitting/fit_joint_invivo_clusters_global_invitro_best_500seed_r442_exact_20260826_033633"
export FIGURE_GEMCITABINE_DATA_ROOT="${repo_root}/Model/data/InVivoData_Gemcitabine"
export FIGURE_LTEE_DATA_ROOT="${repo_root}/results/data/Figures/Figure1"
export FIGURE_INVITRO_SOURCE_DATA_ROOT="${FIGURE_LTEE_DATA_ROOT}/source_raw"

if [[ "${check_only}" == "TRUE" ]]; then
  exec Rscript --vanilla "${figure_runner}" --check-only
fi

for required_directory in \
  "${FIGURE_MODEL_CODE_ROOT}" \
  "${FIGURE_INVIVO_RESULT_ROOT}" \
  "${FIGURE_INVITRO_RESULT_ROOT}" \
  "${FIGURE_JOINT_RESULT_ROOT}" \
  "${FIGURE_GEMCITABINE_DATA_ROOT}" \
  "${FIGURE_LTEE_DATA_ROOT}" \
  "${FIGURE_INVITRO_SOURCE_DATA_ROOT}" \
  "${repo_root}/results/data/Figures"; do
  [[ -d "${required_directory}" ]] || {
    echo "Missing required publication input directory: ${required_directory}" >&2
    exit 2
  }
done

python3 "${stage_data}"

audit_parameters="${workspace_root}/audit/parameters"
mkdir -p "${audit_parameters}"
cat > "${audit_parameters}/container_runtime.tsv" <<EOF
key	value
analysis_version	${LTEE_ANALYSIS_VERSION:-unknown}
container_runtime	${LTEE_CONTAINER_RUNTIME:-unknown}
image_reference	${LTEE_ANALYSIS_IMAGE_REFERENCE:-unknown}
image_identity	${LTEE_ANALYSIS_IMAGE_IDENTITY:-unknown}
sif_sha256	${LTEE_ANALYSIS_SIF_SHA256:-not-applicable}
source_git_sha	${LTEE_SOURCE_GIT_SHA:-unknown}
container_platform	$(uname -s)/$(uname -m)
started_at_utc	$(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF

python3 "${validator}" --phase=preflight
Rscript --vanilla "${figure_runner}" "${runner_args[@]}"
python3 "${validator}" --phase=postflight
