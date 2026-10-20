# Join reference labels only after blind interpretation is finished.
require_new(out("assessment_summary.csv"))
need(file.exists(config$reference_csv), "Missing completed reference CSV: ", config$reference_csv)
key <- read_table(out("review_key.csv")); ref <- read_table(config$reference_csv)
need(all(c("review_id", "class_ref", "status", "confidence", "note") %in% names(ref)),
     "Reference table must retain all template columns.")
need(!anyNA(ref$review_id) && !anyDuplicated(ref$review_id) &&
  nrow(ref) == nrow(key) && setequal(ref$review_id, key$review_id),
  "Reference IDs must match the entire review sample exactly, without duplicates.")
ref <- ref[match(key$review_id, ref$review_id), ]
need(all(ref$status %in% c("target", "other", "unresolved")), "Unknown reference status.")
code <- suppressWarnings(as.numeric(as.character(ref$class_ref)))
target <- ref$status == "target"; other <- ref$status == "other"
need(all(!is.na(code[target]) & code[target] %in% config$classes$code),
     "Every target reference requires a configured class code.")
need(all(is.na(code[!target]) | code[!target] == 0),
     "For other/unresolved cells, leave class_ref blank (or zero).")
w <- key$N_stratum / key$n_stratum
need(all(is.finite(w) & w > 0), "Invalid sampling weights.")
need(any(target), "No assigned target-class references are available.")
summary_rows <- list()
for (name in names(config$models)) {
  p <- key[[paste0("pred_", name)]]
  correct <- target & !is.na(code) & p == code
  # Conditional ratio estimate among assigned target-class references.
  conditional <- sum(w[correct]) / sum(w[target])
  # Other land-cover types are known errors for a forced target-class map.
  # Unresolved references produce bounds, not assumed successes/failures.
  lower <- sum(w[correct]) / sum(w)
  upper <- (sum(w[correct]) + sum(w[ref$status == "unresolved"])) / sum(w)
  summary_rows[[name]] <- data.frame(model = name, target_labels = sum(target),
    other_labels = sum(other), unresolved = sum(ref$status == "unresolved"),
    target_correct = sum(correct), raw_target_accuracy = mean(p[target] == code[target]),
    weighted_target_accuracy = conditional, full_sample_lower_bound = lower,
    full_sample_upper_bound = upper)
  cm <- table(Reference = factor(code[target], levels = config$classes$code),
              Prediction = factor(p[target], levels = config$classes$code))
  write_table(data.frame(reference_code = rownames(cm), as.data.frame.matrix(cm),
    check.names = FALSE), out(paste0("assessment_confusion_counts_", name, ".csv")))
}
write_table(do.call(rbind, summary_rows), out("assessment_summary.csv"))
write_table(data.frame(key, ref[, setdiff(names(ref), "review_id"), drop = FALSE],
                       sampling_weight = w), out("assessment_joined.csv"))
file.copy(config$reference_csv, out("reference_labels_used.csv"))
print(do.call(rbind, summary_rows))
