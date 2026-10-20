# Polygon-held-out validation; identifiers and coordinates are never predictors.
require_new(out("cv_results.rds"))
d <- load_training(); labels <- config$classes$label
results <- list(); summary_rows <- list(); fold_rows <- list()
for (name in names(config$models)) {
  vars <- config$models[[name]]; pred <- rep(NA_character_, nrow(d))
  for (g in sort(unique(d$fold))) {
    train <- d[d$fold != g, ]; valid <- d[d$fold == g, ]
    need(length(intersect(train$sample_id, valid$sample_id)) == 0,
         "A training polygon occurs in both splits.")
    fit <- fit_rf(train, vars, config$rf$cv_seed + g)
    p <- as.character(predict(fit, data = valid[vars], num.threads = config$rf$num.threads)$predictions)
    pred[d$fold == g] <- p
    fm <- metrics(valid$class, p, labels)
    fold_rows[[length(fold_rows) + 1]] <- data.frame(model = name, fold = g,
      pixels = nrow(valid), overall_accuracy = fm$overall_accuracy,
      balanced_accuracy = fm$balanced_accuracy, macro_F1 = fm$macro_F1)
  }
  need(!anyNA(pred), "Missing cross-validation predictions.")
  m <- metrics(d$class, pred, labels); m$predictions <- pred
  results[[name]] <- m
  summary_rows[[name]] <- data.frame(model = name, overall_accuracy = m$overall_accuracy,
    balanced_accuracy = m$balanced_accuracy, macro_F1 = m$macro_F1)
  # Retain reference row labels explicitly in CSV exports.
  write_table(data.frame(reference = rownames(m$confusion), as.data.frame.matrix(m$confusion),
                         check.names = FALSE), out(paste0("cv_confusion_", name, ".csv")))
  write_table(m$per_class, out(paste0("cv_class_metrics_", name, ".csv")))
  by_polygon <- aggregate(list(accuracy = pred == as.character(d$class)),
    by = d[c("sample_id", "class", "fold")], FUN = mean)
  write_table(by_polygon, out(paste0("cv_polygon_", name, ".csv")))
}
write_table(do.call(rbind, summary_rows), out("cv_summary.csv"))
write_table(do.call(rbind, fold_rows), out("cv_folds.csv"))
saveRDS(results, out("cv_results.rds"))
print(do.call(rbind, summary_rows))
