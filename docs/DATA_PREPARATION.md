# Preparing a new study area

## 1. Select data and define the task — manual
Choose target land-cover classes, season and a manageable area. Record the Sentinel
product/acquisition date, terrain source/year/resolution and reference imagery date.
Check clouds, snow, cast shadow, water and out-of-scope vegetation. Temporal
mismatches between reference imagery and satellite data can create label errors.

Use a local projected CRS in metres. Define one reference grid, usually a native
10 m Sentinel band. The workflow supports other pixel sizes but all predictors must
share one grid. Resampling native 20 m bands to 10 m does not create 10 m detail.

## 2. Prepare raster predictors — external processing
This is not a manual tracing task: use QGIS/GDAL tools or your own preprocessing
scripts. The repository does not perform these transformations automatically.

Suggested QGIS sequence:
1. Load red/NIR/visible/SWIR bands and inspect CRS, pixel size, origin and NoData.
2. Convert product digital values to valid, consistently scaled reflectance if
   necessary, respecting the product metadata, scale and additive offsets.
3. Reproject/resample each predictor to the reference grid. For continuous values,
   use a justified method (e.g. bilinear interpolation); align grid origin and bounds
   as well as pixel size. Use nearest neighbour for categorical quality masks.
4. Aggregate a finer DEM to the target grid using an appropriate summary (mean was
   used in the exercise). Preserve elevation units and NoData.
5. Derive slope in DEGREES from the aligned DEM for the exercise's methodology.
   Slope derived at 2 m and then averaged is a different predictor.
6. Prefer a processing buffer around the final AOI when deriving slope, so the AOI
   boundary does not create artificial edge values. Then align the final layers.
7. Export one single-band GeoTIFF per predictor. Confirm declared NoData.

A different processing order can be valid, but document it and use the same
method for training and prediction. An apparent mismatch in file extent alone is
not evidence of a positional shift. Final model inputs, however, must have identical
geometry, which the preparation stage checks.

## 3. Delineate the study area — manual
Create a polygon GeoPackage, assign its true source CRS and save it. The R workflow
projects vectors to the raster CRS. It does not guess missing CRS definitions.

## 4. Digitise training polygons — manual
Use orthophotos and/or field references. Cover each class's spectral and terrain
variability rather than selecting only the clearest examples in one location.
Avoid mixed boundaries, deep shadow and uncertain features. Add `sample_id`,
`class_code`, `fold`. One polygon per row, unique IDs. Do not overlap polygons.

Assign folds BEFORE modelling. Keep related or nearby polygons together where
appropriate; ensure each fold contains all classes. With four folds, each class
needs representation in all four. The original exercise used 13 polygons, but a new
area should determine its own adequate sample size and class balance.

The default erosion rule removes a half-diagonal margin before selecting centres.
It is conservative and may leave no cells in a small polygon. Inspect the resulting
`training_pixels.csv` and counts; do not assume the historical count is expected.

## 5. Digitise exclusions — manual
Create polygons for areas you do not intend to classify, based on the SATELLITE
acquisition rather than a shadow visible only in another-date orthophoto. Cover
out-of-scope classes, clouds/snow/water and unusable shadow as appropriate.
Using an official quality mask upstream is also possible but is not automated here.
Set exclusions to NULL only after deliberately reviewing this choice.
Every cell touched by an exclusion is masked. Training cells in excluded or missing
data areas are omitted; a polygon with no remaining cells causes an error.

## 6. Run prepare/CV/map/sample — automated
Follow README commands. Inspect class/fold counts, CV confusion matrices and both
maps. Preserve the chosen experiment; use a new run folder for changed data/settings.

## 7. Interpret the independent sample — manual
Display the cell polygons over high-resolution reference imagery at a consistent
scale. Assess the WHOLE cell; adopt and document a majority-cover rule or another
consistent rule before labelling. Do not view the prediction key during labelling.
Copy the reference CSV template and fill its status, class code, confidence and note.
Keep mixed cells unresolved if no defensible reference label can be assigned.
Mark known non-target features as `other`, rather than quietly dropping them.

## 8. Assess and report — automated calculation, analyst interpretation
Run assess and report the sample design, reference source, unresolved/non-target
counts and conditional nature of the weighted target accuracy. Field checks and
additional independent spatial samples strengthen ecological claims.
