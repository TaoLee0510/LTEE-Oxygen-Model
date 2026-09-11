# Machine-readable manuscript tables

These directories contain the individual observations and numerical summaries that support the quantitative statements and condensed supplementary tables in the manuscript.

- `experimental/` contains the analyzed culture and tumor measurements, assay grids, measurement inventories, and the separate in vitro optimizer summaries.
- `invivo_landscape/` contains separate in vivo fitted-landscape, association, clustering, and optimizer summaries.
- `joint_search/` contains warm-start selection, clustering, optimizer, and objective-eligibility summaries.
- `fixed_o2/` contains separate-fit response classes and joint-ensemble response and robustness summaries used by the active manuscript figure package. Inverse-response summaries are excluded from the active manuscript package as of result-cleanup gate RC1 and retained only in the gate archive for provenance.
- `weak_gap/` contains the pair-level weak-spectral-gap robustness summary.

The files are copied without changing their numerical values. The condensed TeX tables use rounded display values; the machine-readable tables preserve the full available precision.
