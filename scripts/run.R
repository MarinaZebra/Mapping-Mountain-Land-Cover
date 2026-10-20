# Usage from the repository root:
# Rscript scripts/run.R prepare config/config.R
# Stages: prepare, cv, map, sample, assess. Run each in a fresh R session.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: Rscript scripts/run.R STAGE [CONFIG]", call. = FALSE)
stage <- args[1]
config_file <- if (length(args) >= 2) args[2] else "config/config.R"
if (!file.exists(config_file)) stop("Copy config/config.example.R to config/config.R and edit paths.")
if (!all(vapply(c("ranger", "terra"), requireNamespace, logical(1), quietly = TRUE)))
  stop('Install dependencies first: install.packages(c("ranger", "terra"))')
source(config_file, encoding = "UTF-8")
source("R/functions.R", encoding = "UTF-8")
check_config()
allowed <- c("prepare", "cv", "map", "sample", "assess")
need(stage %in% allowed, "Unknown stage. Use: ", paste(allowed, collapse = ", "))
if (stage == "prepare") {
  need(!dir.exists(config$run_dir), "Run folder already exists. Choose a new run_dir.")
  dir.create(config$run_dir, recursive = TRUE)
  saveRDS(config, out("configuration.rds"))
  file.copy(config_file, out("configuration.R"))
} else {
  need(file.exists(out("configuration.rds")), "Run prepare first.")
  saved <- readRDS(out("configuration.rds"))
  # Reference labels become available after sampling; only that path may change.
  saved$reference_csv <- config$reference_csv
  need(identical(saved, config), "Configuration changed. Restore it or start a new run.")
}
source(file.path("R", paste0(stage, ".R")), encoding = "UTF-8")
capture.output(sessionInfo(), file = out(paste0("session_", stage, ".txt")))
message("Completed stage: ", stage)
