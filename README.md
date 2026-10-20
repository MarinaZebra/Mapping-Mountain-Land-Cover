# Mountain Land-Cover Classification with Random Forest

A configurable R workflow to compare spectral and terrain-enhanced land-cover
classification. Developed through a scree, exposed-bedrock and grassland exercise
in Posets–Maladeta, Spanish Pyrenees. Apply the workflow to other areas by supplying
local imagery, terrain predictors and independently interpreted training polygons.

**Author:** Marina Pérez

This repository classifies land cover. Scree predictions alone do not confirm a
Habitats Directive habitat type such as 8130. Ecological interpretation and field
validation are separate tasks.

## What the code does
1. Check raster alignment, crop to a study area, compute NDVI and apply exclusions.
2. Extract training cells from labelled polygons and retain their assigned folds.
3. Compare configurable Random Forest models using polygon-held-out validation.
4. Fit final models and map both on the same eligible raster cells.
5. Select a blinded, stratified random review sample outside training polygons.
6. Join manually assigned references and compute independent assessment results.

The workflow is reusable, but it cannot decide which image, reference class or
training polygon is ecologically appropriate. Real input data are not bundled.

## Manual tasks and external preprocessing

| Action | Who/where | What the repository expects |
|---|---|---|
| Choose the study area and acquisition date | **Manual**, analyst | Appropriate season, usable cloud/snow/shadow conditions |
| Download imagery and terrain data | **External**, data provider | Known products, acquisition dates, CRS and NoData metadata |
| Delineate the study-area boundary | **Manual**, e.g. QGIS | Polygon GeoPackage with declared CRS |
| Align/resample bands and terrain | **External preprocessing**, QGIS/GDAL; can be scripted | Single-band rasters with identical grid geometry; the R code checks alignment |
| Prepare elevation and slope | **External preprocessing**, QGIS/GDAL; can be scripted | Metres for elevation, degrees for slope; both aligned to the image grid |
| Digitise and label representative training polygons | **Manual**, QGIS/orthophoto interpretation or field data | Unique sample ID, class code and fold per polygon |
| Assign validation folds | **Manual**, analyst | Whole polygons grouped into independent folds; each fold contains each class |
| Draw exclusions | **Manual**, QGIS | Snow, water, cloud, deep shadow or other classes outside the task, as appropriate |
| Compute NDVI and extract predictor values | **Automated**, R | Valid, consistently scaled red and NIR reflectance |
| Fit, validate and map models | **Automated**, R | Reviewed inputs and configured settings |
| Interpret review cells without viewing predictions | **Manual**, high-resolution imagery/field references | Completed label CSV with confidence and notes |
| Compute independent assessment | **Automated**, R | Completed CSV and original sampling key |

See [docs/DATA_PREPARATION.md](docs/DATA_PREPARATION.md) for the QGIS checklist.

## Requirements and installation
R with packages `terra` and `ranger`. The original exercise used ranger 0.18.0 and
terra 1.8.70; this generalised workflow is not yet certified against a particular
R/package combination. GitHub Actions is configured to run synthetic tests when
uploaded; no successful Actions run is claimed here.

```r
install.packages(c("terra", "ranger"))
```

This implementation reads cropped raster values into memory. It suits small demos
and study areas; it is not a streaming solution for regional/national mosaics.
Use a projected CRS with metre units, preferably the appropriate local UTM zone.

## Quick start with your own area
1. Extract/clone the repository and open `mountain-landcover-rf.Rproj` in RStudio.
2. Complete the manual tasks and preprocessing listed above.
3. Put inputs under `data/input/`, or use external paths. Large/local data are ignored by Git.
4. Copy `config/config.example.R` to `config/config.R` and edit paths, class definitions,
   vector layer names, model predictors and the run folder.
5. Run the commands below from a terminal at the repository root.

```sh
Rscript scripts/run.R prepare config/config.R
Rscript scripts/run.R cv config/config.R
Rscript scripts/run.R map config/config.R
Rscript scripts/run.R sample config/config.R
```

The first stage requires a NEW run folder. Later stages read its frozen configuration
and intermediate files, so they work in fresh R sessions without restored workspaces.
Changing model settings or inputs requires a new run. If a stage fails, inspect the
error; for the simplest recovery, fix inputs/configuration and start a new run folder.
Do not delete or regenerate an already interpreted review sample.

After `sample`:
- Load `review_cells.gpkg` in QGIS and review the whole cell against independent imagery.
- Copy `review_labels_template.csv` to `data/reference/review_labels.csv`.
- Edit the copy in a spreadsheet/text editor. Keep all IDs and columns unchanged.
- Keep `review_key.csv` hidden until interpretation is finished.
- Set `reference_csv` in your configuration to the completed CSV. This is the only
  configuration field allowed to change within a run.

```sh
Rscript scripts/run.R assess config/config.R
```

The default CSV dialect is semicolon-separated with decimal commas. All CSV exports
use this dialect. Use the same dialect when saving reference labels.

## Input contracts

### Training polygons
One feature per training polygon. Default fields:

| Field | Type | Meaning |
|---|---|---|
| sample_id | text/integer | Unique polygon ID |
| class_code | integer | One of the configured class codes |
| fold | positive integer | Validation fold; one assignment per polygon |

For existing Spanish project data, map the fields explicitly, for example
`fields = list(id = "id_muestra", class = "clase", fold = "grupo")` after adding
a fold/group field to the polygon layer. The training CSV is generated anew;
this workflow does not import the historical pixel CSV.

Field names can be mapped in the configuration. Codes can be any unique integers
from 1 to 254; 255 is reserved for raster NoData. Labels must be unique. The number
of classes, polygons, folds and pixels is not fixed to the original exercise.
Each held-out fold and its training complement must contain every class.
Overlapping selected training cells cause an error instead of double-counting.

The default `training_edge_buffer_m = "half_diagonal"` erodes polygons by half a
pixel diagonal before selecting cell centres. This is a conservative boundary
rule for reducing mixed cells. Small polygons may vanish: revise them or explicitly
choose another non-negative buffer, including zero for centre-only selection.

### Raster predictors
Inputs must have identical CRS, extent, resolution, dimensions and grid origin.
They must represent comparable measurements, with NoData correctly declared.
No automatic reprojection or resampling of rasters occurs in R.
NDVI is computed from configured red/NIR bands when their sum is positive.
Do not mix raw digital numbers and offset-corrected reflectance between dates.
Nodata encoded as an ordinary zero must be corrected before running.
Model predictors can be configured, but this workflow currently requires the two
bands used for NDVI and computes that index during preparation.

### Review references
Columns: `review_id`, `class_ref`, `status`, `confidence`, `note`.

| status | class_ref | Interpretation |
|---|---|---|
| target | Configured class code | A reference assigned to a target land-cover class |
| other | Blank or 0 | A known non-target class, e.g. a missed lake |
| unresolved | Blank or 0 | Mixed/ambiguous cell that cannot be assigned confidently |

Confidence/notes are recorded but do not automatically remove observations from
assessment. Status must be assigned using an explicit interpretation protocol.

## Outputs
- Prepared predictor stack, common eligibility mask and frozen input vectors.
- Input checksums, configuration and per-stage R session information.
- Extracted training pixels with polygon IDs, folds and coordinates.
- Pooled CV metrics, fold metrics, per-class metrics, confusion counts and polygon scores.
- Fitted model RDS files and GeoTIFF maps (class codes; NoData 255; LZW compression).
- Review-cell GeoPackage, prediction key, stratum sizes and reference CSV template.
- Independent assessment summary, raw confusion counts and joined audit table.

Outputs and private/local inputs are excluded from Git by default.
Use releases or an appropriate data repository for shareable large datasets.

## Validation and interpretation
**CV:** all pixels from a polygon stay together. Coordinates/IDs/folds are not
predictors. Inverse-frequency class weights are recomputed in each training split.
This is not automatically distance-separated spatial-block validation. Nearby
polygons may remain spatially correlated; design folds accordingly.

**Map comparison:** all models use the same complete-case and exclusion mask,
including availability of predictors only used in the terrain model. Thus the
mapped population remains identical across models.

**Independent review:** equal numbers of cells are sampled without replacement
per predicted class of the configured stratification model. All cells touching
training polygons are excluded; an optional additional buffer can be set.
Inverse-inclusion weights are `N_stratum / n_stratum`.

The reported weighted target accuracy is a ratio estimate conditional on the
references assigned to target classes. Known non-target cells are treated as
errors in full-sample bounds; unresolved cells produce lower/upper bounds.
These bounds are NOT confidence intervals. No formal significance test or
confidence interval is implemented. Raw confusion-count tables are unweighted.
Small, image-interpreted samples do not establish field accuracy or transferability.
Do not tune and claim independent performance on the same review sample.

## Relationship to the Posets–Maladeta exercise
The two-model comparison, fixed polygon folds, inverse-frequency weights, RF
settings (500 trees, mtry 2, minimum node size 5), seeds and review design follow
the exercise. This repository adds configurable inputs, automatic extraction from
training polygons and an explicit reference-assessment stage.

Re-extracting pixels with the conservative edge rule will not necessarily produce
the original 1,914 pixels. The code is generalised for reuse; it does not promise
bit-for-bit reproduction of the historical run from different inputs.
A template containing the original fold assignment is provided in `data/templates/`.
It is metadata only, not a substitute for training geometries.

## Tests and reproducible environments
```sh
Rscript tests/test_metrics.R
Rscript tests/test_workflow.R
```
The second test creates a small synthetic dataset and runs every stage in separate
R processes. It checks mechanics, not ecological accuracy. Runtime tests have not
been run in the environment where this package was prepared (R is unavailable).
A GitHub Actions workflow is included to run them on GitHub.

After validating a real run in your environment, record its exact dependencies:
```r
install.packages("renv")
renv::init(bare = TRUE)
renv::snapshot(packages = c("terra", "ranger"), prompt = FALSE)
```
Commit the generated lockfile and renv bootstrap files after checking them.
No lockfile with unverified versions is included. Also record QGIS/GDAL versions,
input product IDs and manual decisions. Hashes of GeoPackages/rasters are recorded;
if using shapefiles, archive all sidecars and their checksums separately.

## Case study

[View the Posets–Maladeta case-study summary](docs/posets-maladeta-case-study.pdf)

## Repository publication
See [docs/GITHUB.md](docs/GITHUB.md). This folder is ready to initialise as a Git
repository; no GitHub repository has been created or published automatically.
No project licence is selected: choose one before granting public reuse rights.
Satellite/terrain/reference imagery have their own data licences.
