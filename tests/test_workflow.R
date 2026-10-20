# End-to-end mechanics test using synthetic raster/vector inputs, not real imagery.
# Each stage runs in a new R process to detect hidden workspace dependencies.
stopifnot(requireNamespace("terra", quietly = TRUE), requireNamespace("ranger", quietly = TRUE))
source("config/config.example.R")
workspace <- tempfile("landcover_test_"); dir.create(workspace)

r <- terra::rast(nrows = 60, ncols = 60, xmin = 0, xmax = 600,
                 ymin = 0, ymax = 600, crs = "EPSG:32631")
xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
truth_index <- pmin(3L, floor(xy[, 1] / 200) + 1L)
class_codes <- c(2L, 4L, 9L)
config$classes <- data.frame(code = class_codes, label = c("Scree", "Bedrock", "Grassland"))
bands <- list(B02 = c(.1, .2, .08), B03 = c(.15, .23, .12),
              B04 = c(.2, .25, .1), B08 = c(.25, .27, .6),
              B11 = c(.3, .4, .2), B12 = c(.28, .36, .17))
for (name in names(config$rasters)) {
  v <- if (name %in% names(bands)) bands[[name]][truth_index] else
    if (name == "elevation") 1800 + xy[, 2] else 10 + truth_index * 10
  layer <- terra::setValues(r, v)
  config$rasters[[name]] <- file.path(workspace, paste0(name, ".tif"))
  terra::writeRaster(layer, config$rasters[[name]])
}
rect <- function(x1, y1, x2, y2) terra::as.polygons(terra::ext(x1, x2, y1, y2), crs = terra::crs(r))
aoi <- rect(0, 0, 600, 600)
aoi_path <- file.path(workspace, "aoi.gpkg"); terra::writeVector(aoi, aoi_path, layer = "study_area")
config$study_area <- list(path = aoi_path, layer = "study_area")
polys <- list(); k <- 0
for (cl in 1:3) for (fold in 1:3) {
  k <- k + 1
  v <- rect((cl - 1) * 200 + 50, (fold - 1) * 200 + 50,
            (cl - 1) * 200 + 150, (fold - 1) * 200 + 150)
  v$sample_id <- k; v$class_code <- class_codes[cl]; v$fold <- fold
  polys[[k]] <- v
}
training <- do.call(rbind, polys)
training_path <- file.path(workspace, "training.gpkg")
terra::writeVector(training, training_path, layer = "training")
config$training <- list(path = training_path, layer = "training")
config$exclusions <- NULL
config$rf$num.trees <- 30L
config$review$per_stratum <- 6L
config$run_dir <- file.path(workspace, "run")
config$reference_csv <- file.path(workspace, "reference.csv")
config_path <- file.path(workspace, "config.R")
write_config <- function() writeLines(c("config <-", capture.output(dput(config))), config_path)
write_config()
run_stage <- function(stage) {
  result <- system2(file.path(R.home("bin"), "Rscript"),
    c("scripts/run.R", stage, shQuote(config_path)), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(result, "status")) && attr(result, "status") != 0)
    stop(paste(result, collapse = "\n"))
}
for (stage in c("prepare", "cv", "map", "sample")) run_stage(stage)
source("R/functions.R")
d <- read_table(out("training_pixels.csv"))
stopifnot(!anyDuplicated(d$cell), all(d$class_code %in% class_codes), length(unique(d$fold)) == 3)
a <- terra::rast(out("classification_Sentinel.tif"))
b <- terra::rast(out("classification_Sentinel_terrain.tif"))
stopifnot(terra::compareGeom(a, b),
          all(na.omit(terra::values(a, mat = FALSE)) %in% class_codes))
key <- read_table(out("review_key.csv"))
stopifnot(nrow(key) == 18, !anyDuplicated(key$cell), all(table(key$stratum) == 6),
          !any(key$cell %in% d$cell))
labels <- read_table(out("review_labels_template.csv"))
labels$class_ref <- class_codes[truth_index[key$cell]]
labels$status <- "target"
labels$class_ref[1:2] <- NA_integer_
labels$status[1:2] <- c("other", "unresolved")
labels$note[1] <- "Synthetic non-target reference for testing"
write_table(labels, config$reference_csv)
run_stage("assess")
summary <- read_table(out("assessment_summary.csv"))
stopifnot(all(summary$target_labels == 16), all(summary$other_labels == 1),
          all(summary$unresolved == 1),
          all(summary$weighted_target_accuracy >= 0 & summary$weighted_target_accuracy <= 1),
          all(summary$full_sample_lower_bound <= summary$full_sample_upper_bound))
# Independent calculation checks that assessment uses original stratum weights.
w <- key$N_stratum / key$n_stratum
p <- key$pred_Sentinel; target <- labels$status == "target"
correct <- target & !is.na(labels$class_ref) & p == labels$class_ref
expected <- sum(w[correct]) / sum(w[target])
stopifnot(isTRUE(all.equal(summary$weighted_target_accuracy[summary$model == "Sentinel"], expected)))
unlink(workspace, recursive = TRUE)
message("Synthetic workflow tests passed.")
