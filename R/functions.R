# Shared functions for data preparation, modelling, mapping and assessment.
abort <- function(...) stop(..., call. = FALSE)
need <- function(ok, ...) if (!isTRUE(ok)) abort(...)
read_vector <- function(spec) {
  need(is.list(spec) && file.exists(spec$path), "Missing vector input: ", spec$path)
  v <- if (is.null(spec$layer) || !nzchar(spec$layer)) terra::vect(spec$path) else
    terra::vect(spec$path, layer = spec$layer)
  need(nrow(v) > 0 && all(terra::is.valid(v)), "Empty or invalid vector: ", spec$path)
  need(nzchar(terra::crs(v)), "Vector CRS is undefined: ", spec$path)
  need(all(terra::geomtype(v) == "polygons"), "Polygon geometry required: ", spec$path)
  v
}
read_table <- function(path) read.table(path, header = TRUE, sep = config$csv$sep,
  dec = config$csv$dec, fileEncoding = config$csv$encoding, stringsAsFactors = FALSE,
  check.names = FALSE, comment.char = "", quote = '"')
write_table <- function(x, path) write.table(x, path, sep = config$csv$sep,
  dec = config$csv$dec, row.names = FALSE, fileEncoding = "UTF-8", quote = TRUE, na = "")
out <- function(...) file.path(config$run_dir, ...)
check_config <- function() {
  codes <- config$classes$code; labels <- config$classes$label
  need(length(codes) >= 2 && !anyNA(codes) && all(codes == as.integer(codes)) &&
    all(codes >= 1 & codes <= 254) && !anyDuplicated(codes),
    "Class codes must be unique integers between 1 and 254 (255 is NoData).")
  need(length(labels) == length(codes) && !anyNA(labels) && all(nzchar(labels)) &&
    !anyDuplicated(labels), "Class labels must be unique and non-empty.")
  need(length(config$models) >= 1 && !is.null(names(config$models)) &&
    !anyDuplicated(names(config$models)) && all(grepl("^[A-Za-z][A-Za-z0-9_]*$", names(config$models))),
    "Use unique alphanumeric model names starting with a letter.")
  need(!is.null(names(config$rasters)) && !anyDuplicated(names(config$rasters)) &&
    all(nzchar(names(config$rasters))), "Raster predictor names must be unique.")
  predictors <- c(names(config$rasters), config$ndvi$name)
  need(!any(predictors %in% c("sample_id", "class_code", "class", "fold", "cell", "x", "y")),
       "Predictor names conflict with metadata columns.")
  need(!anyDuplicated(predictors), "NDVI name duplicates an input raster name.")
  need(all(c(config$ndvi$red, config$ndvi$nir) %in% names(config$rasters)), "NDVI bands are missing.")
  for (vars in config$models) {
    need(length(vars) > 0 && !anyDuplicated(vars) && all(vars %in% predictors), "Invalid model predictors.")
    need(config$rf$mtry >= 1 && config$rf$mtry <= length(vars), "mtry exceeds a model's predictor count.")
  }
  need(config$review$stratification_model %in% names(config$models), "Unknown review stratification model.")
  need(config$review$per_stratum >= 1 && config$review$per_stratum == as.integer(config$review$per_stratum),
    "Review sample count must be a positive integer.")
  need(is.numeric(config$review_buffer_m) && config$review_buffer_m >= 0, "Invalid review buffer.")
}
metrics <- function(reference, prediction, classes) {
  cm <- table(Reference = factor(reference, levels = classes),
              Prediction = factor(prediction, levels = classes))
  recall <- ifelse(rowSums(cm) > 0, diag(cm) / rowSums(cm), NA_real_)
  precision <- ifelse(colSums(cm) > 0, diag(cm) / colSums(cm), 0)
  f1 <- ifelse(is.na(recall), NA_real_, ifelse(precision + recall > 0,
    2 * precision * recall / (precision + recall), 0))
  list(confusion = cm, per_class = data.frame(class = classes, recall, precision, F1 = f1),
       overall_accuracy = sum(diag(cm)) / sum(cm),
       balanced_accuracy = mean(recall), macro_F1 = mean(f1))
}
fit_rf <- function(d, vars, seed) {
  freq <- table(d$class)
  need(all(freq > 0), "Every training split must contain every class.")
  ranger::ranger(x = d[vars], y = d$class,
    num.trees = config$rf$num.trees, mtry = config$rf$mtry,
    min.node.size = config$rf$min.node.size,
    class.weights = nrow(d) / (length(freq) * as.numeric(freq)),
    seed = seed, num.threads = config$rf$num.threads)
}
load_training <- function() {
  d <- read_table(out("training_pixels.csv"))
  d$class <- factor(d$class, levels = config$classes$label)
  need(!anyNA(d$class), "Unknown class label in prepared training data.")
  d
}
require_new <- function(path) need(!file.exists(path), "Output already exists: ", path,
  ". Use a new run folder instead of overwriting an experiment.")
