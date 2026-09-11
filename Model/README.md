# LTEE Oxygen Model package

This directory is a self-contained copy of the O2 supply-demand model code and
the local input files used by its in-vivo, in-vitro, and joint fitting entry
points.

## Snapshot provenance

- Source repository: `/Users/4482173/Documents/GitHub/soft_couping_org`
- Source branch: `soft_couping_org`
- Source commit: `490b4e90abbed7a4a5a2f08908da42a1b4e9e8f9`
- Source commit subject: `Refactor O2 fitting and multi-warmup workflows`
- Snapshot date: 2026-09-10
- `oxygen/code` and all copied input paths were clean at snapshot time.
- Two unrelated modified `.DS_Store` files elsewhere in the source repository
  were not copied or modified.

## Layout

```text
Model/
├── data/InVivoData_Gemcitabine/          # in-vivo observations
├── oxygen/code/                           # copied oxygen/code tree
├── oxygen/config/                         # fitting YAML
├── oxygen/data/                           # parameter, seed, and flow inputs
├── oxygen/ploidyOxygen/data/fit_objects/  # in-vitro fit objects
├── code_manifest.sha256                   # checksums for copied code
└── input_manifest.tsv                     # input provenance and checksums
```

The nested `Model/oxygen/...` layout is intentional. The runner derives the
project root by walking upward from
`oxygen/code/O2_supply_demand_MAP`, so this layout preserves the original path
contract without editing model code.

## Fitting entry point

Run commands from this `Model` directory and pass it as `--project_root`:

```bash
bash oxygen/code/O2_supply_demand_MAP/runner/run_o2_fit.sh \
  --project_root="$PWD" \
  --fitting_mode=invivo
```

Use `--fitting_mode=invitro` for the in-vitro fit. The shared configuration is
`oxygen/config/O2_supply_demand.yaml`; its relative input paths resolve within
this package.

For a joint fit started without historical warm-start results, pass:

```bash
--joint_fitting_mode=DIRECT --joint_warmup_enable=FALSE
```

Alternatively, provide both `--invivo_best_seed_dir` and
`--invitro_best_seed_dir`. The source YAML and runner contain legacy default
references to:

- `oxygen/results/fit_invivo_O2_buffering_500seed/seed50`
- `oxygen/results/fit_invitro_O2_buffering_500seed/seed350`

Those two directories were absent from the source checkout at snapshot time,
so they are not included. Historical fitting results are not silently
substituted for these missing inputs.

## Included inputs

Direct fitting inputs include the in-vivo workbook and ploidy/necrosis tables,
the in-vivo and in-vitro parameter tables, the seed list, the flow-density
table, three in-vitro fit-object RDS files, and the default joint soft-coupling
table. Small compatibility inputs already colocated under `oxygen/data` were
also retained and are marked as `supporting` in `input_manifest.tsv`.

## Exclusions

The package does not include `oxygen/results`, fitting reports, generated
figures, logs, `.DS_Store`, Rcpp caches, Python caches, or other runtime output.
R, system libraries, R packages, containers, and Slurm configuration are
runtime dependencies rather than fitting input files and are not bundled here.

## Integrity checks

From the `Model` directory:

```bash
shasum -a 256 -c code_manifest.sha256
```

Input checksums and their original absolute source paths are recorded in
`input_manifest.tsv`.
