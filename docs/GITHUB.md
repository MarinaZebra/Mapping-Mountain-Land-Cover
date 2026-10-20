# Publishing the repository

1. Extract this folder and check that no confidential data, local credentials or
   large imagery are included. Input rasters, outputs and config/config.R are ignored.
2. Choose a software licence if you want to permit reuse (for example MIT or GPL,
   according to your intended terms). No licence is implied by public visibility.
3. Run tests in R; inspect a full real-data run and document its environment.
4. Create an empty repository named `mountain-landcover-rf` on GitHub.
5. From this folder:

```sh
git init
git add .
git commit -m "Add configurable mountain land-cover workflow"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/mountain-landcover-rf.git
git push -u origin main
```

Replace YOUR_USERNAME. The workflow under .github/workflows runs R tests on push.
A first passing CI run verifies the synthetic workflow, not the historical case-study
results. To reproduce a particular real run, share its exact input datasets or
stable download instructions with product IDs, configuration, software environment,
and manual training/reference files, subject to their licences.
