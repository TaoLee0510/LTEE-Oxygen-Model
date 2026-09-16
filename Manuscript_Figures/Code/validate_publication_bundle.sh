#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "${script_dir}/../.." && pwd -P)"
figure_manifest="${script_dir}/config/manifests/figure_entrypoints.tsv"
container_lock="${script_dir}/config/container_image_lock.tsv"
model_lock="${repo_root}/Model/oxygen/code/O2_supply_demand_MAP/Docker/image_runtime_lock.tsv"

required_files=(
  "${repo_root}/Readme.md"
  "${script_dir}/run_all_figures.sh"
  "${script_dir}/run_all_figures.ps1"
  "${script_dir}/run_all_figures_container.sh"
  "${script_dir}/fetch_zenodo_inputs.sh"
  "${script_dir}/util/workflow/fetch_zenodo_inputs.py"
  "${script_dir}/util/workflow/stage_publication_data.py"
  "${script_dir}/util/workflow/publication_input_validator.py"
  "${script_dir}/Figures/run_all_figures.R"
  "${figure_manifest}"
  "${container_lock}"
  "${script_dir}/config/zenodo_inputs.tsv"
  "${repo_root}/container/Dockerfile.analysis"
  "${repo_root}/container/build-analysis.sh"
  "${repo_root}/container/build-sif.sh"
  "${model_lock}"
)
for path in "${required_files[@]}"; do
  [[ -f "${path}" ]] || {
    echo "Missing publication deployment file: ${path}" >&2
    exit 2
  }
done

for path in \
  "${script_dir}/run_all_figures.sh" \
  "${script_dir}/run_all_figures_container.sh" \
  "${script_dir}/fetch_zenodo_inputs.sh" \
  "${script_dir}/validate_publication_bundle.sh" \
  "${repo_root}/container/build-analysis.sh" \
  "${repo_root}/container/build-sif.sh"; do
  bash -n "${path}"
done

expected_figures=(
  Figure1 Figure2 Figure3 Figure4 Figure5 Figure6
  Supp_Figure4_1 Supp_Figure4_2 Supp_Figure5_1 Supp_Figure5_2
  Supp_Figure6_1 Supp_Figure6_2 Supp_Figure6_3 Supp_Figure6_4
  Supp_Figure6_5 Supp_Figure6_6 Supp_Figure6_7
  Supp_Figure6_10 Supp_Figure6_11 Supp_Figure6_12 Supp_Figure6_13
  Supp_Figure6_14 Supp_Figure6_14_Log Supp_Figure6_15
  Supp_Figure6_16 Supp_Figure6_17 Supp_Figure6_18 Supp_Figure6_19
)
manifest_rows="$(awk 'END {print NR - 1}' "${figure_manifest}")"
[[ "${manifest_rows}" -eq "${#expected_figures[@]}" ]] || {
  echo "Publication figure manifest must contain exactly ${#expected_figures[@]} rows; observed ${manifest_rows}." >&2
  exit 2
}
for figure in "${expected_figures[@]}"; do
  awk -F '\t' -v figure="${figure}" 'NR > 1 && $1 == figure { count++ } END { exit count != 1 }' \
    "${figure_manifest}" || {
      echo "Publication figure manifest lacks ${figure}." >&2
      exit 2
    }
done
if awk -F '\t' 'NR > 1 { print $1; print $2; print $3; print $4; print $5 }' "${figure_manifest}" \
    | grep -Eiq 'chromosome[_ -]?flux|empirical[_ -]?comparison|growth_permissive|Supp_Figure6_20|Supp_Figure6_21|supp_fig6-20|supp_fig6-21'; then
  echo "Excluded experiment or Supplementary Figure 6-20/21 is active." >&2
  exit 2
fi

while IFS=$'\t' read -r figure analysis drawing data_dir output; do
  [[ "${figure}" == "figure" ]] && continue
  [[ -f "${repo_root}/Manuscript_Figures/${analysis}" ]] || {
    echo "Missing analysis entry for ${figure}: ${analysis}" >&2
    exit 2
  }
  [[ -f "${repo_root}/Manuscript_Figures/${drawing}" ]] || {
    echo "Missing drawing entry for ${figure}: ${drawing}" >&2
    exit 2
  }
done < "${figure_manifest}"

zenodo_manifest="${script_dir}/config/zenodo_inputs.tsv"
[[ "$(awk 'END {print NR - 1}' "${zenodo_manifest}")" -eq 2 ]] || {
  echo "Zenodo manifest must contain exactly Model_fitting.zip and data.zip." >&2
  exit 2
}
for dataset in Model_fitting data; do
  awk -F '\t' -v dataset="${dataset}" \
    'NR > 1 && $1 == dataset && $2 == "10.5281/zenodo.22799665" && $3 == dataset ".zip" && $5 == "results/" dataset { found++ } END { exit found != 1 }' \
    "${zenodo_manifest}" || {
      echo "Invalid Zenodo archive contract for ${dataset}." >&2
      exit 2
    }
done

manifest_digest="$(awk -F '\t' '$1 == "docker_amd64_manifest_digest" {print $2}' "${container_lock}")"
model_digest="$(awk -F '\t' '$1 == "docker_amd64_manifest" {print "sha256:" $3}' "${model_lock}")"
[[ -n "${manifest_digest}" && "${manifest_digest}" == "${model_digest}" ]] || {
  echo "Figure and Model Docker manifest locks disagree." >&2
  exit 2
}
sif_digest="$(awk -F '\t' '$1 == "sif_sha256" {print $2}' "${container_lock}")"
model_sif_digest="$(awk -F '\t' '$1 == "apptainer_sif" {print $3}' "${model_lock}")"
[[ -n "${sif_digest}" && "${sif_digest}" == "${model_sif_digest}" ]] || {
  echo "Figure and Model SIF locks disagree." >&2
  exit 2
}

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -Command \
    "[void][System.Management.Automation.Language.Parser]::ParseFile('${script_dir}/run_all_figures.ps1',[ref]\$null,[ref]\$null)"
else
  echo "NOTE: pwsh is unavailable; PowerShell syntax was not runtime-parsed."
fi

echo "Publication bundle static validation: PASS"
echo "Container execution still requires the locked Docker image or verified SIF."
