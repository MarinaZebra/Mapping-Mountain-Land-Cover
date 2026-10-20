# All paths are relative to the repository root unless absolute.
# Copy this file to config/config.R and edit it for your study area.
config <- list(
  run_dir = "outputs/my_study_v1", # A NEW folder for each experiment.
  study_area = list(path = "data/input/study_area.gpkg", layer = "study_area"),
  training = list(path = "data/input/training.gpkg", layer = "training"),
  # Set exclusions = NULL only when you have reviewed the image and need no mask.
  exclusions = list(path = "data/input/exclusions.gpkg", layer = "exclusions"),
  # Supply single-band, co-registered rasters with IDENTICAL geometry.
  # Names below are predictor names, not mandatory source filenames.
  rasters = c(
    B02 = "data/input/B02.tif", B03 = "data/input/B03.tif",
    B04 = "data/input/B04.tif", B08 = "data/input/B08.tif",
    B11 = "data/input/B11.tif", B12 = "data/input/B12.tif",
    elevation = "data/input/elevation.tif", slope = "data/input/slope.tif"
  ),
  # NDVI is computed here. A supplied NDVI raster is not needed.
  ndvi = list(red = "B04", nir = "B08", name = "NDVI"),
  models = list(
    Sentinel = c("B02", "B03", "B04", "B08", "B11", "B12", "NDVI"),
    Sentinel_terrain = c("B02", "B03", "B04", "B08", "B11", "B12", "NDVI", "elevation", "slope")
  ),
  classes = data.frame(code = c(1L, 2L, 3L),
                       label = c("Scree", "Bedrock", "Grassland")),
  fields = list(id = "sample_id", class = "class_code", fold = "fold"),
  # Conservative erosion before sampling: removes centres closer than half a
  # pixel diagonal to a polygon boundary. This helps avoid mixed boundary cells.
  # Use 0 for centre-only inclusion. This is not the original full-cell algorithm.
  training_edge_buffer_m = "half_diagonal",
  # Optional extra exclusion distance around training polygons during review.
  review_buffer_m = 0,
  rf = list(num.trees = 500L, mtry = 2L, min.node.size = 5L,
            cv_seed = 100L, final_seed = 2026L, num.threads = 1L),
  review = list(stratification_model = "Sentinel_terrain", per_stratum = 20L,
                seed = 2026L),
  # Fill this CSV AFTER interpreting cells without viewing the prediction key.
  reference_csv = "data/reference/review_labels.csv",
  csv = list(sep = ";", dec = ",", encoding = "UTF-8-BOM")
)
