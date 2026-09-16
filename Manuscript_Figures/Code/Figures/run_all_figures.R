#!/usr/bin/env Rscript

script_dir <- local({
  arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(arg)) dirname(normalizePath(sub("^--file=", "", arg[[1L]]))) else getwd()
})

raw_args <- commandArgs(trailingOnly = TRUE)
container_active <- tolower(trimws(Sys.getenv(
  "LTEE_CONTAINER_RUNTIME_ACTIVE",
  unset = Sys.getenv("O2SD_CONTAINER_RUNTIME_ACTIVE", unset = "")
)))
if (!container_active %in% c("true", "t", "1", "yes", "y")) {
  stop(
    "The publication workflow is container-only. Run ",
    "Manuscript_Figures/Code/run_all_figures.sh instead of host Rscript."
  )
}

run_all_static_check <- function() {
  workspace_root <- normalizePath(
    file.path(script_dir, "..", ".."), mustWork = TRUE
  )
  project_root <- normalizePath(file.path(workspace_root, ".."), mustWork = TRUE)
  manifest_path <- file.path(
    workspace_root, "Code", "config", "manifests", "figure_entrypoints.tsv"
  )
  if (!file.exists(manifest_path)) {
    stop("Missing publication figure manifest: ", manifest_path)
  }
  manifest <- utils::read.delim(
    manifest_path, check.names = FALSE, stringsAsFactors = FALSE
  )
  required_columns <- c(
    "figure", "analysis_entry", "drawing_entry", "data_directory", "main_output"
  )
  if (!identical(names(manifest), required_columns)) {
    stop("Unexpected publication figure manifest schema.")
  }
  required_figures <- c(
    paste0("Figure", 1:6),
    "Supp_Figure4_1", "Supp_Figure4_2",
    "Supp_Figure5_1", "Supp_Figure5_2",
    paste0("Supp_Figure6_", c(1:7, 10:19)),
    "Supp_Figure6_14_Log"
  )
  missing_figures <- setdiff(required_figures, manifest$figure)
  unexpected_figures <- setdiff(manifest$figure, required_figures)
  if (length(missing_figures)) {
    stop(
      "Publication figure manifest is missing: ",
      paste(missing_figures, collapse = ", ")
    )
  }
  if (length(unexpected_figures) || anyDuplicated(manifest$figure)) {
    stop(
      "Publication figure manifest has unexpected or duplicate entries: ",
      paste(unique(unexpected_figures), collapse = ", ")
    )
  }
  declared_paths <- c(manifest$analysis_entry, manifest$drawing_entry)
  denied <- grepl(
    "chromosome[_ -]?flux|empirical[_ -]?comparison",
    declared_paths,
    ignore.case = TRUE
  )
  if (any(denied)) {
    stop(
      "Excluded analysis appears in the publication manifest: ",
      paste(declared_paths[denied], collapse = ", ")
    )
  }
  entry_paths <- file.path(workspace_root, declared_paths)
  missing_entries <- entry_paths[!file.exists(entry_paths)]
  if (length(missing_entries)) {
    stop(
      "Publication manifest entry point(s) are missing:\n",
      paste(missing_entries, collapse = "\n")
    )
  }
  model_root <- file.path(
    project_root, "Model", "oxygen", "code", "O2_supply_demand_MAP"
  )
  required_model <- file.path(model_root, c(
    "model/model_O2_supply_demand_MAP.R",
    "model/model_O2_supply_demand_MAP.cpp",
    "util/o2_supply_demand_map_shared.R",
    "util/o2_supply_demand_map_fit_joint_backend.R"
  ))
  missing_model <- required_model[!file.exists(required_model)]
  if (length(missing_model)) {
    stop(
      "Repository Model package is incomplete:\n",
      paste(missing_model, collapse = "\n")
    )
  }
  message(
    "Publication deployment check passed: ", nrow(manifest),
    " declared figures; repository Model root=", model_root
  )
  invisible(manifest)
}

if (any(raw_args == "--check-only")) {
  run_all_static_check()
  quit(save = "no", status = 0L)
}

source(file.path(script_dir, "util", "runtime", "process_runner.R"))

run_all_parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- list(
    n_core = 8L,
    recompute_fixed_o2 = FALSE,
    recompute_invivo_tsne = FALSE,
    model_dependent_only = FALSE,
    first_main_figure = 1L,
    resume_after_figure5f_de = FALSE,
    figure6_smoke = FALSE
  )
  for (arg in args) {
    if (grepl("^--n-core=", arg)) {
      out$n_core <- as.integer(sub("^--n-core=", "", arg))
    } else if (grepl("^--recompute-fixed-o2=", arg)) {
      out$recompute_fixed_o2 <- as_boolean(
        sub("^--recompute-fixed-o2=", "", arg)
      )
    } else if (grepl("^--recompute-invivo-tsne=", arg)) {
      out$recompute_invivo_tsne <- as_boolean(
        sub("^--recompute-invivo-tsne=", "", arg)
      )
    } else if (grepl("^--model-dependent-only=", arg)) {
      out$model_dependent_only <- as_boolean(
        sub("^--model-dependent-only=", "", arg)
      )
    } else if (grepl("^--first-main-figure=", arg)) {
      out$first_main_figure <- as.integer(
        sub("^--first-main-figure=", "", arg)
      )
    } else if (grepl("^--resume-after-figure5f-de=", arg)) {
      out$resume_after_figure5f_de <- as_boolean(
        sub("^--resume-after-figure5f-de=", "", arg)
      )
    } else if (grepl("^--figure6-smoke=", arg)) {
      out$figure6_smoke <- as_boolean(
        sub("^--figure6-smoke=", "", arg)
      )
    } else if (is_runtime_path_argument(arg)) {
      next
    } else {
      stop("Unknown run_all_figures.R option: ", arg)
    }
  }
  if (!is.finite(out$n_core) || out$n_core < 1L) {
    stop("--n-core must be a positive integer.")
  }
  if (!out$first_main_figure %in% c(1L, 3L, 4L)) {
    stop("--first-main-figure must be one of 1, 3, or 4.")
  }
  out
}

run_figure_entry <- function(script, args = character()) {
  path <- file.path(CODE_ROOT, script)
  require_files(path, "figure entry")
  message("\n==> ", script)
  run_process(
    "Rscript",
    args = c(path, runtime_path_arguments(), args)
  )
}

run_all_figures <- function(
    n_core = 8L,
    recompute_fixed_o2 = FALSE,
    recompute_invivo_tsne = FALSE,
    model_dependent_only = FALSE,
    first_main_figure = 1L,
    resume_after_figure5f_de = FALSE,
    figure6_smoke = FALSE
) {
  publication_manifest <- run_all_static_check()
  ensure_workspace_directories()

  if (!isTRUE(resume_after_figure5f_de)) {
    if (!isTRUE(model_dependent_only) && first_main_figure == 1L) {
      run_figure_entry("data_Figure1.R")
      run_figure_entry("draw_Figure1.R")
      run_figure_entry("data_Figure2.R")
      run_figure_entry("draw_Figure2.R")
    }
    if ((!isTRUE(model_dependent_only) && first_main_figure <= 3L) ||
        first_main_figure == 3L) {
      run_figure_entry("data_Figure3.R")
      run_figure_entry("draw_Figure3.R")
    } else {
      message("\nPreserving existing earlier figures; rebuilding Figure 4-5.")
    }
    run_figure_entry(
      "data_Figure4.R",
      c(
        paste0("--n-core=", n_core),
        paste0(
          "--recompute-fixed-o2=",
          if (isTRUE(recompute_fixed_o2)) "TRUE" else "FALSE"
        ),
        paste0(
          "--recompute-tsne=",
          if (isTRUE(recompute_invivo_tsne)) "TRUE" else "FALSE"
        )
      )
    )
    run_figure_entry("draw_Figure4.R")
    run_figure_entry("data_Supp_Figure4_1.R")
    run_figure_entry("draw_Supp_Figure4_1.R")
    run_figure_entry("data_Supp_Figure4_2.R")
    run_figure_entry("draw_Supp_Figure4_2.R")
    run_figure_entry("data_Figure5.R")
    run_figure_entry("data_Supp_Figure5_1.R")
    run_figure_entry("data_Supp_Figure5_2.R")
    run_figure_entry("finalize_Figure5_optimizer_ensemble.R")
    run_figure_entry("prepare_Figure5F_de_initial_population.R")
  } else {
    message(
      "\nResuming after validated Figure 5F DE initial-population products."
    )
  }
  run_figure_entry("audit_Figure5F_prior_optimizer_inputs.R")
  run_figure_entry("build_Figure5F_prior_optimizer_products.R")
  run_figure_entry("build_Figure5F_supplementary_table.R")
  run_figure_entry("draw_Figure5.R")
  run_figure_entry("draw_Supp_Figure5_1.R")
  run_figure_entry("draw_Supp_Figure5_2.R")

  run_figure_entry(
    "data_Figure6.R",
    c(
      paste0("--n-core=", n_core),
      "--rebuild=FALSE",
      "--n-resample=100"
    )
  )
  run_figure_entry(
    "data_Supp_Figure6_1.R",
    c(paste0("--n-core=", n_core), "--rebuild=FALSE")
  )
  run_figure_entry("data_Supp_Figure6_2.R")
  run_figure_entry(
    "data_Supp_Figure6_3.R",
    c(paste0("--n-core=", n_core), "--rebuild=FALSE")
  )
  run_figure_entry(
    "data_Supp_Figure6_4.R",
    c(paste0("--n-core=", n_core), "--rebuild=FALSE")
  )
  run_figure_entry(
    "data_Figure6_finite_time_q10.R",
    c(
      paste0("--n-core=", n_core),
      paste0("--smoke=", if (isTRUE(figure6_smoke)) "TRUE" else "FALSE"),
      "--publish-current=TRUE",
      "--compute-diagnostics=TRUE"
    )
  )
  run_figure_entry(
    "data_Figure6_full_range_q10.R",
    c(
      paste0("--n-core=", n_core),
      paste0("--smoke=", if (isTRUE(figure6_smoke)) "TRUE" else "FALSE"),
      "--publish-current=TRUE"
    )
  )
  run_figure_entry(
    "data_Supp_Figure6_14.R",
    c(
      paste0("--n-core=", n_core),
      paste0("--smoke=", if (isTRUE(figure6_smoke)) "TRUE" else "FALSE"),
      "--publish-current=TRUE"
    )
  )
  run_figure_entry(
    "data_Supp_Figure6_14_Full_Range.R",
    c(
      paste0("--n-core=", n_core),
      paste0("--smoke=", if (isTRUE(figure6_smoke)) "TRUE" else "FALSE"),
      "--publish-current=TRUE"
    )
  )
  run_figure_entry("draw_Figure6.R")
  for (index in c(1:7, 10:19)) {
    run_figure_entry(paste0("draw_Supp_Figure6_", index, ".R"))
  }
  run_figure_entry("draw_Supp_Figure6_14_Log.R")

  expected <- file.path(WORKSPACE_ROOT, publication_manifest$main_output)
  require_files(expected, "complete figure set")
  message("\nAll Figure 1-6 and publication supplementary outputs are complete.")
  invisible(expected)
}

if (sys.nframe() == 0L) {
  options <- run_all_parse_args()
  run_all_figures(
    n_core = options$n_core,
    recompute_fixed_o2 = options$recompute_fixed_o2,
    recompute_invivo_tsne = options$recompute_invivo_tsne,
    model_dependent_only = options$model_dependent_only,
    first_main_figure = options$first_main_figure,
    resume_after_figure5f_de = options$resume_after_figure5f_de,
    figure6_smoke = options$figure6_smoke
  )
}
