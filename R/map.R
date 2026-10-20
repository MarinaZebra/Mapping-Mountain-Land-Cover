# Final fitting uses all training cells; CV results remain separate.
for (name in names(config$models)) {
  require_new(out(paste0("classification_", name, ".tif")))
  require_new(out(paste0("model_", name, ".rds")))
}
d <- load_training(); r <- terra::rast(out("predictors.tif"))
eligible <- !is.na(terra::values(terra::rast(out("eligible.tif")), mat = FALSE))
for (name in names(config$models)) {
  vars <- config$models[[name]]
  fit <- fit_rf(d, vars, config$rf$final_seed)
  x <- terra::values(r[[vars]], mat = TRUE)
  need(all(is.finite(x[eligible, , drop = FALSE])), "Non-finite mapping predictors.")
  p <- as.character(predict(fit, data = as.data.frame(x[eligible, , drop = FALSE]),
    num.threads = config$rf$num.threads)$predictions)
  codes <- config$classes$code[match(p, config$classes$label)]
  need(!anyNA(codes), "Unknown predicted class.")
  result <- terra::rast(r[[1]]); v <- rep(NA_integer_, terra::ncell(result)); v[eligible] <- codes
  terra::values(result) <- v; names(result) <- "class_code"
  terra::writeRaster(result, out(paste0("classification_", name, ".tif")),
    datatype = "INT1U", NAflag = 255, gdal = "COMPRESS=LZW")
  saveRDS(fit, out(paste0("model_", name, ".rds")))
}
write_table(config$classes, out("class_legend.csv"))
