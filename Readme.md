# LTEE Oxygen Model

This repository is the standalone computational package for the LTEE oxygen,
chromosome-state, and tumor-growth model. It contains the model implementation,
fitting inputs, publication analysis code, and the Figure 1--6 rendering
workflow.

## Reproducibility policy

All fitting, downstream analysis, and figure rendering for the publication must
run in the locked container environment. Host R and host Python are not
supported scientific runtimes. The host is used only to run Docker or, on an
HPC system, Apptainer/Singularity.

The supported analysis environment is:

| Item | Locked value |
|---|---|
| Analysis version | `publication-r44` |
| Docker Hub image | `docker.io/zafiro/o2_supply_demand_map:r44` |
| Platform | `linux/amd64` |
| Docker config ID | `sha256:32c49db0ad27a0b5832b601ba96e2b72bfc1e2f1ccbf34687f8f596f1f7cdcd5` |
| OCI index digest | `sha256:015fbbc343f17e979a8c36a546d50e1dd18043c675c61ecaee5b51f1043039c5` |
| OCI linux/amd64 manifest | `sha256:32d30d8d3cae9468e466cabeaa7f51cfcc07b4a867ea66aa06c998c141067132` |
| Reference SIF SHA-256 | `ee9fe0f5ab6d3fb0689b23c02d330de677afa4d0cc044df9f2eeeae42f8e5e68` |

The image version and identity, rather than a particular Docker Desktop/Engine
release, define the scientific environment. A current Docker release that
supports `--platform linux/amd64` and bind mounts is sufficient. Exact R,
Python, system-library, and package versions are part of the image and are
checked by the container validation scripts.

The publication wrapper verifies the Docker image ID and platform. A locally
built publication derivative is accepted only when it contains the expected
analysis-version and base-manifest labels. HPC execution accepts either the
reference SIF checksum or a SIF created and smoke-tested by
`container/build-sif.sh`. Every run also verifies required commands (including
Ghostscript `gs` and `pdflatex` for the revised vector PDFs), R packages, and
headless Cairo rendering before analysis begins.

## Publication scope

The active publication manifest is
`Manuscript_Figures/Code/config/manifests/figure_entrypoints.tsv`. It includes:

- main Figures 1, 2, 3, 4, 5, and 6;
- Supplementary Figures 4-1, 4-2, 5-1, and 5-2;
- Supplementary Figures 6-1 through 6-7 and 6-10 through 6-19, including
  the separately declared signed-log version of Supplementary Figure 6-14.

Chromosome-flux experiments, empirical-comparison drafts, and their generated
results are explicitly outside this publication workflow. They are not listed
in the manifest, are not called by `run_all_figures.R`, and are excluded when
the frozen cache is staged into a fresh publication workspace. Supplementary
Figure 6-8/6-9 and 6-20/6-21 code paths are also not in the current publication
manifest.

The current Figure 1 design key distinguishes live/dead population counts with
a split symbol and terminal necrosis with a filled square. Figure 4D shows the
single largest Kruskal-Wallis epsilon-squared among parameters passing the
Benjamini-Hochberg `q < 0.05` gate; its all-parameter overview remains in
Supplementary Figure 4-1. Figure 6 and the active Supplementary Figure 6
series use the iteration4 analysis/data versions.

All figure analyses resolve the mechanistic implementation from:

```text
Model/oxygen/code/O2_supply_demand_MAP
```

The historical copy under `Manuscript_Figures/Code/vendor/` is retained only
for provenance. It is not the active model.

## Repository layout

The table describes every directory family in the repository. A `/**` suffix
means that all leaf directories below it inherit the stated role; individual
model layers also contain their own README files and machine-readable registry.

| Directory | Purpose |
|---|---|
| `Model/` | Self-contained scientific model package and its immutable source-input snapshot. |
| `Model/data/InVivoData_Gemcitabine/` | In-vivo tumor burden, ploidy, treatment, and histology inputs. |
| `Model/oxygen/config/` | Canonical fitting YAML, including biological switches, optimizer controls, and objective settings. |
| `Model/oxygen/data/` | Parameter tables, seed lists, flow-density data, and supporting model inputs. |
| `Model/oxygen/ploidyOxygen/` | In-vitro ploidy/oxygen fit objects consumed by the fitting backend. |
| `Model/oxygen/code/O2_supply_demand_MAP/model/` | R/Rcpp implementation of chromosome-state transitions, growth, death, WGD, and oxygen feedback. |
| `Model/oxygen/code/O2_supply_demand_MAP/util/` | Shared parameter semantics, fitting backends, transforms, validation, and process helpers. |
| `Model/oxygen/code/O2_supply_demand_MAP/runner/` | Canonical fitting and post-fit orchestration. |
| `Model/oxygen/code/O2_supply_demand_MAP/simulation/` | Fixed-O2, fit-result, and parameter-landscape simulation layers. |
| `Model/oxygen/code/O2_supply_demand_MAP/analysis/` | Approved model analyses and feature extraction; local `chromosome_flux/` content is excluded from the publication. |
| `Model/oxygen/code/O2_supply_demand_MAP/vis/` | Model-level visualization layers. |
| `Model/oxygen/code/O2_supply_demand_MAP/report/` | Model-level report and result-bundle generation. |
| `Model/oxygen/code/O2_supply_demand_MAP/Docker/local/` | Docker-only local fitting and model-analysis wrappers. |
| `Model/oxygen/code/O2_supply_demand_MAP/Docker/hpc/` | Apptainer/Singularity-backed Slurm wrappers and runtime utilities. |
| `Model/oxygen/code/O2_supply_demand_MAP/hpc/` | Original Slurm orchestration mirrored by the container-backed HPC layer. |
| `Model/oxygen/code/O2_supply_demand_MAP/docs/` | Human- and machine-readable per-file model-code registry. |
| `results/Model_fitting/` | Three named complete in-vivo, in-vitro, and joint 500-seed result trees; restored from `Model_fitting.zip` if absent. |
| `results/data/Figures/` | Frozen Figure 1--6 intermediate and source data from `data.zip`; publication analysis stages a separate writable copy. |
| `Manuscript_Figures/Code/Figures/` | Figure-specific data preparation, analysis, drawing entry points, and shared figure utilities. |
| `Manuscript_Figures/Code/config/` | Figure entry manifest, container lock, Zenodo contract, path layout, palettes, and historical input-checksum records. |
| `Manuscript_Figures/Code/templates/` | Reusable figure reporting and audit templates. |
| `Manuscript_Figures/Code/hpc/` | Specialized historical/high-resource figure helpers; the supported publication runtime entry remains `run_all_figures.sh`. |
| `Manuscript_Figures/Code/Docker/` | Earlier figure-runtime manager wrappers retained for provenance; do not use them as the publication entry point. |
| `Manuscript_Figures/Code/vendor/` | Historical code snapshot retained for traceability; never selected as the active model root. |
| `Manuscript_Figures/data/Figures/` | Writable figure workspace, staged from `results/data/Figures` when absent, then updated by analyses; ignored by Git. |
| `Manuscript_Figures/data/share_bundle_figures_3_5/` | Historical/cached Figure 3--5 exchange bundle, not the authoritative model source. |
| `Manuscript_Figures/Figures/` | Rendered PNG/PDF publication figures. |
| `Manuscript_Figures/audit/` | Run-time manifests, checksums, parameters, logs, provenance, and validation reports. |
| `manuscript/` | Manuscript source and publication-facing figures/tables. |
| `manuscript/Figures/` | Copies of rendered figures used by the manuscript. |
| `manuscript/tables/` | Manuscript tables and their data products. |
| `container/` | Container deployment material. Use only the publication files named below for this repository. |
| `container/Dockerfile.analysis` | Thin publication image derived from the locked Docker manifest. |
| `container/build-analysis.sh` | Builds and validates the thin local publication image. |
| `container/build-sif.sh` | Builds, smoke-tests, hashes, and records provenance for an HPC SIF. |
| `container/analysis-image.lock.tsv` | Machine-readable publication OCI/SIF identity lock. |
| `container/evidence/`, `container/locks/`, `container/manifests/`, `container/scripts/` | May be present in the local copied Cellpose bundle; unrelated to this oxygen-model publication, not required in a fresh clone, and not used by its wrappers. |
| `ignore/` | Local planning/archive material; not a scientific input or supported entry point. |

`Model/code_manifest.sha256` and `Model/input_manifest.tsv` document the model
snapshot. `Model/oxygen/code/O2_supply_demand_MAP/docs/CODE_FILE_REGISTRY.md`
provides the leaf-level purpose, inputs, outputs, and functions for the large
model code tree.

## Obtain the container

### macOS

Install and start Docker Desktop. On Apple Silicon, the locked `linux/amd64`
image runs through Docker's architecture emulation, so it may be slower than on
an Intel/AMD64 system.

```bash
docker pull --platform linux/amd64 docker.io/zafiro/o2_supply_demand_map:r44
bash Manuscript_Figures/Code/run_all_figures.sh --check-only
```

The second command validates the local image and deployed figure entry points.
It does not download scientific data or run a figure analysis.

### Windows

Install Docker Desktop with the WSL2 backend and select Linux containers. In
PowerShell, from the repository root:

```powershell
docker pull --platform linux/amd64 docker.io/zafiro/o2_supply_demand_map:r44
.\Manuscript_Figures\Code\run_all_figures.ps1 -CheckOnly
```

Use the PowerShell wrapper for figure production. For fitting and model-level
analysis, use a WSL2 shell and the same Bash/Docker commands shown below. Keep
the checkout on a Docker-shareable drive and preserve LF line endings for Bash
scripts.

### HPC with Apptainer or Singularity

Docker daemons are usually unavailable on compute clusters. Create a SIF from
the locked Docker manifest on a host with registry access:

```bash
module load apptainer  # site-specific; omit if already on PATH
bash container/build-sif.sh \
  --output=/path/to/o2_supply_demand_map_r44.sif
```

The helper pins the linux/amd64 manifest, tests the scientific commands and R
packages, and writes `/path/to/image.sif.provenance.tsv`. Then validate the
repository inside an interactive allocation or batch job:

```bash
bash Manuscript_Figures/Code/run_all_figures.sh \
  --runtime=apptainer \
  --sif=/path/to/o2_supply_demand_map_r44.sif \
  --check-only
```

If an already-distributed reference SIF is used, its expected SHA-256 is shown
in the environment table above. The wrapper checks it directly. A newly built
SIF may have a different binary hash; it is accepted only when its helper-made
provenance sidecar matches both that hash and the locked Docker manifest.

The wrapper does not submit a Slurm job. Request an appropriate interactive or
batch allocation first, then call it within that allocation. Figure 6 full-range
finite-time scans are the dominant CPU/memory stage; use the existing
`Manuscript_Figures/Code/hpc/` resource notes as the cluster-specific sizing
reference rather than running a production scan on a login node.

### Build from this repository

Pulling the Docker Hub image is recommended. If local policy requires an image
built from the repository, use the publication Dockerfile, not the pre-existing
Cellpose Dockerfiles:

```bash
IMAGE_TAG=ltee-oxygen-model:publication-r44 \
  bash container/build-analysis.sh

LTEE_ANALYSIS_IMAGE=ltee-oxygen-model:publication-r44 \
  bash Manuscript_Figures/Code/run_all_figures.sh --check-only
```

`Dockerfile.analysis` is intentionally thin: it derives from the immutable
model-analysis manifest and adds publication identity labels. Source code and
data are bind-mounted at runtime, so the image never hides a stale repository
copy.

## Data and Zenodo contract

A complete figure run expects this layout:

```text
results/
├── Model_fitting/
│   ├── fit_invivo_unified_500seed_r442_exact_20260825_032031/
│   ├── fit_invitro_unified_500seed_r442_exact_20260825_032031/
│   └── fit_joint_invivo_clusters_global_invitro_best_500seed_r442_exact_20260826_033633/
└── data/
    └── Figures/
        ├── Figure1/  # six frozen source tables and source_raw/
        ├── Figure2/ ... Figure6/
        └── active supplementary figure data directories
```

The reserved DOI is `10.5281/zenodo.22799665`. The planned record is not yet
published. It must contain exactly `Model_fitting.zip` and `data.zip`. The first
archive expands to the three named fit directories above; the second expands
to the contents of `results/data/` (or a single `data/` or `results/data/`
wrapper). Their contract
is in `Manuscript_Figures/Code/config/zenodo_inputs.tsv`.

For each of the two target directories, the wrapper first checks whether the
directory exists. It skips that archive when present and downloads only a
missing one. Existing directories are never overwritten or repaired by the
downloader. The container preflight checks the named fit trees, six joint
cluster directories, and selected required files. It records the observed
seed-directory counts, warning when they are below 500; a `500seed` run label
alone does not establish how many seed outputs were retained. Missing required
structures fail with a diagnostic rather than triggering an overwrite.

If a directory is absent after the DOI is published, the container downloader
reads the [Zenodo record API](https://developers.zenodo.org/), selects the
declared ZIP, verifies its Zenodo MD5 and any release-pinned SHA-256, checks
ZIP member safety, validates the extracted layout, and installs it atomically.
The `TO_BE_ASSIGNED` SHA-256 entries should be replaced with the two actual
archive hashes before release; until then, the downloader reports the observed
SHA-256 but cannot check it against an independent release pin.

The publication `data.zip` must exclude `chromosome_flux*`,
`*empirical_comparison*`, and Supplementary Figure 6-20/21 data (including
`Supp_Figure6_20_21*` and growth-permissive intermediates). The downloader
rejects an archive containing these excluded experiments. Curate a separate
publication copy before compressing if
the local `results/data` tree still contains these historical experiments;
do not delete the original results merely to assemble the release.

No data are downloaded by `--check-only`. During a normal online run, a
missing directory invokes the downloader inside the locked container. Docker
uses a networked container only for this step and `--network none` for
analysis; the SIF analysis path performs no scientific network access. Use
`--offline` to require both directories already be present.

## Run the model

### Model overview

The model tracks live and dead cell abundance over a chromosome-count state
grid. The default grid is `N_MIN=22` through `N_MAX=154`, with `N_UNIT=22` as
the haploid chromosome unit. Division, chromosome missegregation, whole-genome
doubling, ploidy-dependent viability, stress-associated death, dead-biomass
clearance, and oxygen-dependent growth jointly update the state. Effective
oxygen can respond dynamically to viable burden and chromosome-weighted oxygen
demand.

The same implementation is used for:

- in-vivo burden, chromosome/ploidy, and optional necrosis likelihoods;
- in-vitro growth-rate and chromosome-distribution likelihoods;
- joint fitting with shared centers and optional context-specific parameter
  deltas under a robust soft-coupling penalty.

The authoritative implementation is in `Model/.../model/`; shared parameter
transforms and context semantics are in `Model/.../util/`.

### Local Docker fitting

All commands below are launched from the repository root and execute R inside
Docker. First create an output directory and expose it to the model's Docker
wrapper:

```bash
mkdir -p results/new_fits
export O2SD_DOCKER_BINDS="$PWD/results/new_fits:$PWD/results/new_fits"
export O2SD_DOCKER_IMAGE="docker.io/zafiro/o2_supply_demand_map:r44@sha256:32d30d8d3cae9468e466cabeaa7f51cfcc07b4a867ea66aa06c998c141067132"
docker pull --platform linux/amd64 "$O2SD_DOCKER_IMAGE"
```

The digest-qualified `O2SD_DOCKER_IMAGE` makes the fitting wrappers use the
same immutable linux/amd64 artifact validated by the figure workflow.

Inspect a full standard in-vivo + in-vitro + joint workflow without fitting:

```bash
bash Model/oxygen/code/O2_supply_demand_MAP/Docker/local/run_full_fit_docker.sh \
  --project_root="$PWD/Model" \
  --config_path="$PWD/Model/oxygen/config/O2_supply_demand.yaml" \
  --out_root="$PWD/results/new_fits" \
  --invivo_run_prefix=in_vivo \
  --invitro_run_prefix=in_vitro \
  --joint_run_prefix=joint \
  --append_run_prefix_timestamp=FALSE \
  --dry_run=TRUE
```

Remove `--dry_run=TRUE` only after reviewing paths, seeds, and resource values.
For publication-scale separate fits:

```bash
bash Model/oxygen/code/O2_supply_demand_MAP/Docker/local/run_o2_fit_docker.sh \
  --project_root="$PWD/Model" \
  --config_path="$PWD/Model/oxygen/config/O2_supply_demand.yaml" \
  --out_root="$PWD/results/new_fits" \
  --fitting_mode=invivo \
  --invivo_run_prefix=in_vivo \
  --invivo_total_seeds=500 \
  --append_run_prefix_timestamp=FALSE \
  --n_cores=8

bash Model/oxygen/code/O2_supply_demand_MAP/Docker/local/run_o2_fit_docker.sh \
  --project_root="$PWD/Model" \
  --config_path="$PWD/Model/oxygen/config/O2_supply_demand.yaml" \
  --out_root="$PWD/results/new_fits" \
  --fitting_mode=invitro \
  --invitro_run_prefix=in_vitro \
  --invitro_total_seeds=500 \
  --append_run_prefix_timestamp=FALSE \
  --n_cores=8
```

To construct a multi-warmup joint result from completed separate runs:

```bash
bash Model/oxygen/code/O2_supply_demand_MAP/Docker/local/run_o2_fit_docker.sh \
  --project_root="$PWD/Model" \
  --config_path="$PWD/Model/oxygen/config/O2_supply_demand.yaml" \
  --out_root="$PWD/results/new_fits" \
  --fitting_mode=joint \
  --joint_fitting_mode=MULTI_WARMUP \
  --invivo_run_dir="$PWD/results/new_fits/in_vivo" \
  --invitro_run_dir="$PWD/results/new_fits/in_vitro" \
  --joint_run_prefix=joint \
  --joint_total_seeds=500 \
  --append_run_prefix_timestamp=FALSE \
  --joint_n_cores=8
```

The exact pair-selection controls used for a deposited manuscript result must
be recorded with that result. Do not infer or silently replace them from the
example command. These example runs go under `results/new_fits/` to avoid
overwriting the frozen three-directory publication bundle. The figure wrapper
uses the named results under `results/Model_fitting/` only; a new fit requires
explicit scientific review before it replaces a publication input.

### HPC fitting

Use the container-backed Slurm layer, never the parallel host-runtime scripts:

```bash
export O2SD_CONTAINER_IMAGE=/path/to/o2_supply_demand_map_r44.sif
export O2SD_CONTAINER_BINDS="$PWD:$PWD"

bash Manuscript_Figures/Code/run_all_figures.sh \
  --runtime=apptainer \
  --sif="$O2SD_CONTAINER_IMAGE" \
  --check-only

bash Model/oxygen/code/O2_supply_demand_MAP/Docker/hpc/submit/submit_o2_fit.sh \
  --fitting_mode=invivo \
  --config_path="$PWD/Model/oxygen/config/O2_supply_demand.yaml" \
  --out_root="$PWD/results/new_fits" \
  --dry_run=TRUE
```

The dry run is the safe path/resource review. Removing it submits work to the
scheduler. Site allocation, partition, memory, wall time, and array limits must
be selected for the target cluster. The mirrored HPC layer keeps scheduler
orchestration on the host while every R/Python worker runs inside the SIF.

### Fitting-mode parameters

| Option | Meaning |
|---|---|
| `--fitting_mode` | Selects `invivo`, `invitro`, or `joint`. |
| `--joint_fitting_mode` | `DIRECT` fits joint parameters directly; `JOINT` runs/reuses separate fits and selects anchors; `MULTI_WARMUP` creates multiple joint families from source landscapes. |
| `--project_root` | Must point to this repository's `Model/` package. |
| `--config_path` | YAML containing state-space, likelihood, optimizer, and biological controls. |
| `--out_root` | Parent directory for newly fitted runs; use `results/new_fits/` so the frozen `results/Model_fitting/` inputs remain untouched. |
| `--*_run_prefix` | Deterministic directory name for the corresponding fit. |
| `--append_run_prefix_timestamp` | Adds a timestamp when true; false is required for stable publication paths. |
| `--*_total_seeds` / `--*_seeds_csv` | Number or explicit identities of independent optimizer seeds. |
| `--*_n_cores` / `--n_cores` | Worker count; size this to the granted Docker/HPC allocation. |
| `--itermax`, `--NP` | DEoptim iteration limit and population size. |
| `--de_reltol`, `--de_steptol` | Relative convergence tolerance and allowed stagnant optimizer steps. |
| `--run_extra_results` | Runs result summaries required for ranking/selection after fitting. |
| `--dry_run` | Prints/audits the workflow without fitting or submitting it. |
| `--invivo_run_dir`, `--invitro_run_dir` | Existing complete source runs for joint or multi-warmup fitting. |
| `--joint_soft_coupling_sigma_default` | Default transformed-scale context-difference scale. |
| `--joint_soft_coupling_welsch_c` | Robust Welsch penalty tuning constant. |
| `--joint_soft_coupling_delta_params` | Chooses which shared parameters receive in-vivo/in-vitro deltas. |
| `--multi_warmup_*` | Controls landscape reductions, top seeds, cluster counts, anchors, pair construction, and deterministic reduction seeds. |

Run the container wrapper with `--help` for the complete interface. Boolean
arguments use explicit `TRUE`/`FALSE` values.

### Scientific parameters

The numeric initialization, fitted/fixed flag, lower bound, upper bound, and
source are authoritative in:

- `Model/oxygen/data/O2_supply_demand/parameter_table_O2.csv` for in vivo;
- `Model/oxygen/data/O2_supply_demand/parameter_table_invitro_buffering.csv`
  for in vitro;
- `Model/oxygen/data/O2_supply_demand/joint_soft_coupling_parameters_table.csv`
  for the joint transformed center/delta start table.

| Parameter | Meaning |
|---|---|
| `lam_max` | Maximum cell-division rate (`day^-1`). |
| `p_mis_base` | Baseline per-chromosome missegregation probability. |
| `p_misseg` | Maximum stress-induced increment above baseline. |
| `k_o_mis` | Stress-associated half-saturation scale controlling the induced missegregation/death-hazard relationship. |
| `buffer_smax` | Maximum per-copy survival factor after missegregation. |
| `buffer_beta` | Strength of ploidy-dependent viability loss after missegregation. |
| `buffer_n_exp` | Exponent controlling that ploidy dependence. |
| `p_wgd` | Per-division whole-genome-doubling probability. |
| `o2_S0` | Low-burden effective oxygen supply (`% O2`). |
| `kappa_O` | Amplitude of oxygen loss in the chromosome-weighted supply-demand target. |
| `eta_o2` | Exponent for chromosome-weighted oxygen demand. |
| `rho_2N` | Diploid cell density (`cells/mm^3`). |
| `beta_size` | Chromosome-number-to-cell-volume exponent in the burden observation model. |
| `alpha_o2` | Strength of stress-dependent growth damping at high chromosome count. |
| `gamma_growth` | Chromosome-number exponent in the resource-stress growth penalty. |
| `mu_hp` | Stress-associated death-rate scale (`day^-1`). |
| `gamma_mu` | Chromosome-number penalty exponent for stress-associated death. |
| `O2_crit` | Critical oxygen level for the oxygen-linked stress function (`% O2`). |
| `n_O` | Hill exponent of the oxygen-linked stress function. |
| `k_clear` | Dead-biomass clearance rate (`day^-1`). |
| `sigma_burden` | Log-normal observation SD for tumor burden. |
| `sigma_growth` | In-vitro growth-rate observation SD. |
| `sigma_kary` | Chromosome-count observation SD used to smooth predicted distributions. |
| `init_mean_2N`, `init_sd_2N` | Mean and SD of the initial diploid-cohort chromosome distribution. |
| `init_mean_4N`, `init_sd_4N` | Mean and SD of the initial tetraploid-cohort chromosome distribution. |
| `tau_O2` | Oxygen relaxation time constant when `fit_tau_O2=TRUE`. |
| `alpha`, `gamma` | Treatment-effect scale and exponent when `fit_treatment=TRUE`. |

Parameters prefixed `log10_` are optimized on a base-10 log scale. Joint
`delta__*` values allow the two biological contexts to differ around a shared
transformed center; feasibility bounds and the soft-coupling penalty are
applied by the joint backend.

### YAML controls

`Model/oxygen/config/O2_supply_demand.yaml` is fully commented. The most
important controls are:

| Control | Meaning |
|---|---|
| `N_MIN`, `N_MAX`, `N_UNIT` | Chromosome state-space bounds and reference unit. |
| `dt` | Simulation time step in days. |
| `init_total_size` | Effective starting population size. |
| `o2_burden_feedback` | Enables dynamic burden-to-oxygen feedback. |
| `O2_growth` | Enables oxygen/ploidy-dependent growth damping. |
| `ploidy_O2_death` | Selects uniform, diploid-null, or ploidy-related stress death. |
| `start_with` | Selects ploidy or chromosome-number endpoint semantics. |
| `use_necrosis_loss`, `lambda_necrosis` | Enables and weights the histology necrosis objective. |
| `dose_zero_only`, `paired_only` | Restricts fitted observations. |
| `fit_tau_O2`, `fit_treatment` | Makes the corresponding optional parameters estimable. |
| `joint_restriction` | Master switch for joint biological restrictions. |
| `joint_soft_coupling_enable` | Enables context center/delta parameterization and robust coupling. |
| `use_deoptim`, `itermax`, `NP` | Selects and sizes the global optimizer. |
| `lambda_prior` and `prior_*` | Soft-prior weight, centers, and scales. |
| `sigma_ploidy`, `sigma_necrosis_logit` | Observation-error scales. |

## Run downstream model analysis

The model-level post-fit pipeline follows simulation -> analysis ->
visualization -> report. Run it in Docker with selected completed seed
directories:

```bash
bash Model/oxygen/code/O2_supply_demand_MAP/Docker/local/run_full_analysis_docker.sh \
  --invivo_fit_dir="$PWD/results/Model_fitting/fit_invivo_unified_500seed_r442_exact_20260825_032031/seed25" \
  --invitro_fit_dir="$PWD/results/Model_fitting/fit_invitro_unified_500seed_r442_exact_20260825_032031/seed144" \
  --joint_fit_dir=/absolute/path/to/a/selected/joint/seed \
  --dry_run=TRUE
```

Remove `--dry_run=TRUE` after checking paths and scope. To run one selected
scope, use `Docker/local/run_postfit_docker.sh --scope=invivo|invitro|joint`.
These model-level products are inputs to, but not replacements for, the
manuscript-specific workflow below.

## Reproduce all publication figures

### Static/container check

```bash
bash Manuscript_Figures/Code/validate_publication_bundle.sh
bash Manuscript_Figures/Code/run_all_figures.sh --check-only
```

The first command is host-side static validation and runs no scientific code.
The second requires the locked image/SIF and checks the actual container.

### Full local run

```bash
bash Manuscript_Figures/Code/run_all_figures.sh --n-core=8
```

On Windows:

```powershell
.\Manuscript_Figures\Code\run_all_figures.ps1 -NCore 8
```

On HPC inside an allocation:

```bash
bash Manuscript_Figures/Code/run_all_figures.sh \
  --runtime=apptainer \
  --sif=/path/to/o2_supply_demand_map_r44.sif \
  --n-core=8
```

Useful figure options:

| Option | Meaning |
|---|---|
| `--offline` | Fail if an input is missing; never access Zenodo. |
| `--download-missing` | Download missing required inputs from the declared Zenodo records; this is the default. |
| `--n-core=N` | Worker count for parallel figure analyses. |
| `--recompute-fixed-o2=TRUE` | Recompute Figure 4 fixed-oxygen products rather than reuse a valid cache. |
| `--recompute-invivo-tsne=TRUE` | Recompute the in-vivo t-SNE used by Figure 4. |
| `--model-dependent-only=TRUE` | Preserve model-independent early products and rebuild the model-dependent sequence. |
| `--first-main-figure=1|3|4` | Resume from an allowed main-figure boundary. |
| `--resume-after-figure5f-de=TRUE` | Resume only after validated Figure 5F DE initial-population products exist. |
| `--figure6-smoke=TRUE` | Reduced Figure 6 deployment test; not a publication result. |

The wrapper calls `Manuscript_Figures/Code/Figures/run_all_figures.R` inside
the container. Direct host invocation of that R file fails by design.

Outputs are written to:

- `Manuscript_Figures/data/Figures/` for recomputed intermediates;
- `Manuscript_Figures/Figures/` for assembled PNG/PDF figures;
- `manuscript/Figures/` for manuscript-facing copies;
- `Manuscript_Figures/audit/` for runtime, path, checksum, and validation
  evidence.

Before and after a complete run, the active input validator checks the two-ZIP
directory contract, the six joint cluster directories, seed-directory counts,
the repository `Model/` path, and the frozen Figure 1 source
tables. It writes `Manuscript_Figures/audit/reports/publication_input_validation.tsv`.
The older `expected_scientific_input_md5.tsv` remains as a historical baseline
for a different input layout and is not the active validation contract. The
runtime audit records the Git commit, image/SIF identity, analysis version,
runtime type, platform, and start time.

## Failure behavior

- Missing Docker: the local wrapper stops and prints the exact `docker pull`
  command.
- Docker daemon stopped: the wrapper stops before data access or R execution.
- Missing/wrong image: the wrapper refuses to run; it never silently uses a
  different tag.
- Missing HPC SIF: the wrapper stops and instructs the user to run
  `container/build-sif.sh`.
- Wrong SIF checksum/provenance: the wrapper stops before analysis.
- Unpublished reserved DOI: a missing target cannot be downloaded; the
  downloader reports that the Zenodo record is not public or reachable.
- Existing data target: download is skipped for that archive; missing required
  internal structures fail the subsequent container preflight, while fewer
  than 500 retained seed directories produce an explicit warning.
- Host `Rscript`: publication entry points stop because the container-runtime
  marker is absent.
- Missing or incomplete publication input layout: preflight stops before
  figure generation and records the failed checks.

These failures are intentional reproducibility safeguards. Do not bypass them
by setting container marker environment variables manually.
