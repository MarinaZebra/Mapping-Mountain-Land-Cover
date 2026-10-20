# Generate once. Never regenerate IDs after reference interpretation has started.
require_new(out("review_cells.gpkg")); require_new(out("review_key.csv"))
require_new(out("review_labels_template.csv"))
maps <- lapply(names(config$models), function(n) terra::rast(out(paste0("classification_", n, ".tif"))))
names(maps) <- names(config$models)
base <- maps[[config$review$stratification_model]]
for (m in maps) need(terra::compareGeom(base, m, stopOnError = FALSE), "Map geometry mismatch.")
pred <- lapply(maps, terra::values, mat = FALSE)
polys <- terra::vect(out("training_polygons.gpkg"), layer = "training")
if (config$review_buffer_m > 0) polys <- terra::buffer(polys, config$review_buffer_m)
training <- terra::values(terra::rasterize(polys, base, field = 1,
  background = 0, touches = TRUE), mat = FALSE) == 1
eligible <- Reduce(`&`, lapply(pred, is.finite)) & !training
strata <- pred[[config$review$stratification_model]]
set.seed(config$review$seed)
cells <- integer(0); sizes <- integer(nrow(config$classes))
for (k in seq_len(nrow(config$classes))) {
  candidates <- which(eligible & strata == config$classes$code[k])
  sizes[k] <- length(candidates)
  need(length(candidates) >= config$review$per_stratum,
       "Insufficient review cells in stratum: ", config$classes$code[k])
  cells <- c(cells, candidates[sample.int(length(candidates), config$review$per_stratum)])
}
cells <- cells[sample.int(length(cells))]
key <- data.frame(review_id = seq_along(cells), cell = cells, stratum = strata[cells],
  N_stratum = sizes[match(strata[cells], config$classes$code)],
  n_stratum = config$review$per_stratum)
for (n in names(pred)) key[[paste0("pred_", n)]] <- pred[[n]][cells]
write_table(key, out("review_key.csv"))
write_table(data.frame(stratum = config$classes$code, N_stratum = sizes,
                      n_stratum = config$review$per_stratum), out("review_strata.csv"))
ids <- rep(NA_integer_, terra::ncell(base)); ids[cells] <- key$review_id
r <- terra::rast(base); terra::values(r) <- ids; names(r) <- "review_id"
v <- terra::as.polygons(r, aggregate = FALSE, na.rm = TRUE)
terra::writeVector(v, out("review_cells.gpkg"), layer = "cells")
terra::writeVector(terra::centroids(v), out("review_cells.gpkg"), layer = "centres", insert = TRUE)
# Keep reference labels in CSV to avoid short string fields in some GIS exports.
write_table(data.frame(review_id = key$review_id, class_ref = NA_integer_,
  status = "unresolved", confidence = "", note = ""), out("review_labels_template.csv"))
