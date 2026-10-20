# Independent expected values for class-balanced and imbalanced confusion cases.
source("R/functions.R")
classes <- c("Scree", "Bedrock", "Grassland")
r <- c(rep("Scree", 8), "Bedrock", "Grassland")
p <- rep("Scree", 10)
m <- metrics(r, p, classes)
stopifnot(isTRUE(all.equal(m$overall_accuracy, 0.8)),
          isTRUE(all.equal(m$balanced_accuracy, 1 / 3)),
          isTRUE(all.equal(m$macro_F1, (2 * 0.8 / 1.8) / 3)))
perfect <- metrics(classes, classes, classes)
stopifnot(perfect$overall_accuracy == 1, perfect$balanced_accuracy == 1, perfect$macro_F1 == 1)
# Missing reference classes must not be silently omitted from a macro average.
missing <- metrics("Scree", "Scree", classes)
stopifnot(is.na(missing$balanced_accuracy), is.na(missing$macro_F1))
message("Metric tests passed.")
