# Read aligned single-band predictors; preserve their grid without resampling.
need(all(file.exists(config$rasters)), "Missing raster files; edit config/config.R.")
layers <- lapply(config$rasters, terra::rast)
for (i in seq_along(layers)) {
  need(terra::nlyr(layers[[i]]) == 1, "Single-band input required: ", names(layers)[i])
  need(terra::compareGeom(layers[[1]], layers[[i]], stopOnError = FALSE),
       "Raster grid mismatch: ", names(layers)[i], ". Align inputs before running.")
}
r <- terra::rast(layers); names(r) <- names(config$rasters)
need(nzchar(terra::crs(r)) && !terra::is.lonlat(r), "Use a projected raster CRS in metres, such as local UTM.")
# The metre requirement is also a documented input contract (not all projected CRSs use metres).
aoi <- terra::project(read_vector(config$study_area), terra::crs(r))
r <- terra::mask(terra::crop(r, aoi), aoi, touches = FALSE)
red <- r[[config$ndvi$red]]; nir <- r[[config$ndvi$nir]]
den <- red + nir
ndvi <- terra::ifel(den > 0, (nir - red) / den, NA)
names(ndvi) <- config$ndvi$name
r <- c(r, ndvi)
interior <- terra::rasterize(aoi, r[[1]], field = 1, background = 0, touches = FALSE)
excluded <- terra::rast(interior); terra::values(excluded) <- 0
if (!is.null(config$exclusions)) {
  ex <- terra::project(read_vector(config$exclusions), terra::crs(r))
  excluded <- terra::rasterize(ex, r[[1]], field = 1, background = 0, touches = TRUE)
}
# Complete-case eligibility is shared by every model for a fair map comparison.
values <- terra::values(r, mat = TRUE)
inside <- terra::values(interior, mat = FALSE) == 1
excluded_values <- terra::values(excluded, mat = FALSE) == 1
complete <- rowSums(!is.finite(values)) == 0
eligible <- inside & complete & !excluded_values
need(any(eligible), "No eligible cells remain after masking.")
mask <- terra::rast(r[[1]]); terra::values(mask) <- ifelse(eligible, 1, NA)
terra::writeRaster(r, out("predictors.tif"), gdal = "COMPRESS=LZW")
terra::writeRaster(mask, out("eligible.tif"), gdal = "COMPRESS=LZW")
terra::writeVector(aoi, out("study_area.gpkg"), layer = "study_area")

# Training polygons and folds are interpreted/assigned by the analyst, not inferred.
polys <- terra::project(read_vector(config$training), terra::crs(r))
attrs <- as.data.frame(polys)
f <- config$fields
need(all(unlist(f) %in% names(attrs)), "Training polygons require configured ID, class and fold fields.")
ids <- as.character(attrs[[f$id]])
codes <- suppressWarnings(as.numeric(as.character(attrs[[f$class]])))
folds <- suppressWarnings(as.numeric(as.character(attrs[[f$fold]])))
need(!anyNA(ids) && all(nzchar(ids)) && !anyDuplicated(ids), "Training polygon IDs must be unique and non-empty.")
need(!anyNA(codes) && all(codes %in% config$classes$code), "Invalid training class code.")
need(!anyNA(folds) && all(folds >= 1 & folds == as.integer(folds)) && length(unique(folds)) >= 2,
     "Assign at least two positive integer folds to training polygons.")
# Freeze the full training geometry for independent-review exclusion.
terra::writeVector(polys, out("training_polygons.gpkg"), layer = "training")
edge <- config$training_edge_buffer_m
if (identical(edge, "half_diagonal")) edge <- sqrt(sum(terra::res(r)^2)) / 2
need(is.numeric(edge) && length(edge) == 1 && is.finite(edge) && edge >= 0, "Invalid training edge buffer.")
seen <- rep(FALSE, terra::ncell(r)); tables <- vector("list", nrow(polys))
for (i in seq_len(nrow(polys))) {
  polygon <- polys[i, ]
  if (edge > 0) polygon <- terra::buffer(polygon, width = -edge)
  need(nrow(polygon) > 0 && sum(terra::expanse(polygon), na.rm = TRUE) > 0,
       "Polygon vanished after erosion: ", ids[i], ". Enlarge it or revise the edge rule.")
  hit <- terra::values(terra::rasterize(polygon, r[[1]], field = 1,
                                     background = 0, touches = FALSE), mat = FALSE) == 1
  cells <- which(hit & eligible)
  need(length(cells) > 0, "No usable training cells for polygon: ", ids[i])
  need(!any(seen[cells]), "Training polygons select overlapping cells. Resolve overlap first.")
  seen[cells] <- TRUE
  xy <- terra::xyFromCell(r, cells)
  tables[[i]] <- data.frame(sample_id = ids[i], class_code = codes[i],
    class = config$classes$label[match(codes[i], config$classes$code)],
    fold = folds[i], cell = cells, x = xy[, 1], y = xy[, 2],
    values[cells, , drop = FALSE], check.names = FALSE)
}
d <- do.call(rbind, tables)
# Every held-out fold and its training complement must contain every class.
for (g in sort(unique(d$fold))) {
  need(all(config$classes$label %in% d$class[d$fold == g]), "Validation fold lacks a class: ", g)
  need(all(config$classes$label %in% d$class[d$fold != g]), "Training complement lacks a class: ", g)
}
write_table(d, out("training_pixels.csv"))
write_table(data.frame(inside = sum(inside), excluded_inside = sum(inside & excluded_values),
  complete_inside = sum(inside & complete), eligible = sum(eligible), training = nrow(d)), out("data_counts.csv"))
# Record input hashes for later provenance checks; sidecar files should also be archived.
input_paths <- unique(c(unname(config$rasters), config$study_area$path,
                       config$training$path, config$exclusions$path))
write_table(data.frame(path = input_paths, md5 = unname(tools::md5sum(input_paths))), out("input_checksums.csv"))
print(table(d$fold, d$class))
