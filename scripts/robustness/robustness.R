# Stöðugleikagreiningar fyrir kaflann (svör við ritrýni).
#
# Endurtekur líkönin úr notebooks_simplified_r/02_models.Rmd á nákvæmlega sama hátt
# (sama skipting með seed 42, sömu factor-stig) og bætir við:
#   * 50 endurteknum lagskiptum 80/20 skiptingum (hversu stöðug er nákvæmnin?)
#   * fjölkosta lógistískri aðhvarfsgreiningu til samanburðar („hefðbundið“ líkan)
#   * líkönum sem byggja aðeins á fáum spurningum
#   * umröðunarmikilvægi (permutation importance) til hliðar við Gini-mikilvægi
#
# Keyrt úr rót verkefnisins eftir að 00_preprocess hefur búið til data/:
#   Rscript scripts/robustness/robustness.R              # líkanið í kaflanum
#   Rscript scripts/robustness/robustness.R without_gov  # án mats á frammistöðu ríkisstjórnar
#   Rscript scripts/robustness/robustness.R all        # allar breytur (líka málefnaeign/flokkshollusta)

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(rpart); library(randomForest); library(nnet)
})

args    <- commandArgs(trailingOnly = TRUE)
VARIANT <- if (length(args) >= 1) args[1] else "main"
N_REPS  <- 50

df   <- read_csv("data/iskos_clean.csv",  show_col_types = FALSE)
meta <- read_csv("data/feature_meta.csv", show_col_types = FALSE)

# Same exclusions as 02_models.Rmd; the variants switch them off for comparison.
LEAK_GROUPS  <- c("4 – Málefnaeign", "5 – Flokkshollusta og leiðtogar")
EXCLUDE_VARS <- character(0)
if (VARIANT == "without_gov") EXCLUDE_VARS <- c("govprfm")
if (VARIANT == "all") { LEAK_GROUPS <- character(0); EXCLUDE_VARS <- character(0) }

leak_vars <- meta |> filter(group %in% LEAK_GROUPS | short_name %in% EXCLUDE_VARS) |> pull(label)
X_raw <- df |> select(-flokkur, -any_of(leak_vars))   # character columns stay character here
y     <- factor(df$flokkur)
lab   <- function(short) meta$label[match(short, meta$short_name)]

cat("Afbrigði:", VARIANT, "| svarendur:", nrow(X_raw), "| breytur:", ncol(X_raw), "\n")

# ---- helpers ---------------------------------------------------------------

# Stratified 80/20 split, identical to 02_models.Rmd.
strat_split <- function(seed) {
  set.seed(seed)
  sort(unlist(lapply(split(seq_along(y), y), function(idx) sample(idx, floor(0.8 * length(idx))))))
}

# Factor handling identical to 02_models.Rmd: levels come from the training rows,
# and the test rows are coded with the training levels. A level that never occurs in
# a training split (rare; never in the seed-42 split) is replaced by the most common
# training level, since randomForest cannot predict from missing values.
make_factors <- function(Xtr, Xte) {
  Xtr <- Xtr |> mutate(across(where(is.character), as.factor))
  Xte <- Xte |> mutate(across(where(is.character), as.factor))
  for (nm in names(Xtr)) if (is.factor(Xtr[[nm]])) {
    Xte[[nm]] <- factor(Xte[[nm]], levels = levels(Xtr[[nm]]))
    Xte[[nm]][is.na(Xte[[nm]])] <- names(which.max(table(Xtr[[nm]])))
  }
  list(tr = Xtr, te = Xte)
}

# Accuracy, balanced accuracy (mean recall over parties), macro-F1 and top-2 accuracy.
# A missing prediction (NA, from an unseen level) counts as wrong.
metrics <- function(truth, pred, prob = NULL) {
  pred <- as.character(pred); pred[is.na(pred)] <- "__NA__"
  cm   <- table(factor(truth, levels(y)), factor(pred, c(levels(y), "__NA__")))[, levels(y)]
  rec  <- diag(cm) / as.numeric(table(factor(truth, levels(y))))
  prec <- ifelse(colSums(cm) > 0, diag(cm) / colSums(cm), 0)
  f1   <- ifelse(rec + prec > 0, 2 * rec * prec / (rec + prec), 0)
  out  <- c(acc = mean(pred == as.character(truth)), bal_acc = mean(rec), macro_f1 = mean(f1))
  if (!is.null(prob)) {
    top2 <- vapply(seq_len(nrow(prob)), function(i) {
      if (anyNA(prob[i, ])) return(FALSE)
      as.character(truth[i]) %in% colnames(prob)[order(prob[i, ], decreasing = TRUE)[1:2]]
    }, logical(1))
    out <- c(out, top2 = mean(top2))
  }
  out
}

# Design matrix for the multinomial logit: ordinal answers as numbers (training-median
# imputation + a missing indicator), nominal answers as dummies; constant columns dropped.
logit_design <- function(Xtr, Xte) {
  for (nm in names(Xtr)) if (is.numeric(Xtr[[nm]])) {
    miss_tr <- Xtr[[nm]] == -1; miss_te <- Xte[[nm]] == -1
    med <- median(Xtr[[nm]][!miss_tr])
    if (any(miss_tr)) { Xtr[[paste0(nm, "__na")]] <- as.numeric(miss_tr); Xte[[paste0(nm, "__na")]] <- as.numeric(miss_te) }
    Xtr[[nm]][miss_tr] <- med; Xte[[nm]][miss_te] <- med
  }
  both <- bind_rows(Xtr, Xte) |> mutate(across(where(is.character), as.factor))
  mm   <- model.matrix(~ ., data = both)[, -1, drop = FALSE]
  ntr  <- nrow(Xtr)
  keep <- apply(mm[seq_len(ntr), , drop = FALSE], 2, function(v) length(unique(v)) > 1)
  mm   <- mm[, keep, drop = FALSE]
  mu   <- colMeans(mm[seq_len(ntr), , drop = FALSE]); sdv <- apply(mm[seq_len(ntr), , drop = FALSE], 2, sd)
  mm   <- sweep(sweep(mm, 2, mu), 2, sdv, "/")
  list(tr = data.frame(mm[seq_len(ntr), , drop = FALSE]), te = data.frame(mm[-seq_len(ntr), , drop = FALSE]))
}

fit_logit <- function(Xtr, Xte, ytr) {
  d  <- logit_design(Xtr, Xte)
  ml <- multinom(ytr ~ ., data = d$tr, maxit = 2000, MaxNWts = 1e5, trace = FALSE)
  pr <- predict(ml, d$te, type = "probs")
  if (is.null(dim(pr))) pr <- matrix(pr, nrow = 1, dimnames = list(NULL, names(pr)))
  list(pred = colnames(pr)[max.col(pr, ties.method = "first")], prob = pr)
}

TWO   <- lab(c("lrscale", "EUmship"))
THREE <- lab(c("lrscale", "elecdist", "EUmship"))

fit_eval <- function(train_idx, seed) {
  f   <- make_factors(X_raw[train_idx, ], X_raw[-train_idx, ])
  Xtr <- f$tr; Xte <- f$te; ytr <- y[train_idx]; yte <- y[-train_idx]
  res <- list()
  modal <- names(sort(table(ytr), decreasing = TRUE))[1]
  res$modal <- metrics(yte, rep(modal, length(yte)))
  dt <- rpart(flokkur ~ ., data = bind_cols(Xtr, flokkur = ytr), method = "class",
              control = rpart.control(maxdepth = 3, cp = 0, minsplit = 2, minbucket = 1, xval = 0))
  ted <- bind_cols(Xte, flokkur = yte)
  res$tree <- metrics(yte, predict(dt, ted, type = "class"), predict(dt, ted, type = "prob"))
  set.seed(seed)
  rf <- randomForest(x = Xtr, y = ytr, ntree = 300, importance = TRUE)
  # predict() breaks tied votes at random, so we predict the training rows first, exactly
  # as 02_models.Rmd does; this keeps the seed-42 numbers identical to the notebook.
  invisible(predict(rf, Xtr))
  res$rf_pred <- predict(rf, Xte)
  res$rf <- metrics(yte, res$rf_pred, predict(rf, Xte, type = "prob"))
  set.seed(seed)
  rf3 <- randomForest(x = Xtr[, THREE], y = ytr, ntree = 300)
  res$rf3 <- metrics(yte, predict(rf3, Xte[, THREE]), predict(rf3, Xte[, THREE], type = "prob"))
  lg  <- fit_logit(X_raw[train_idx, ], X_raw[-train_idx, ], ytr);           res$logit  <- metrics(yte, lg$pred, lg$prob)
  lg2 <- fit_logit(X_raw[train_idx, TWO], X_raw[-train_idx, TWO], ytr);     res$logit2 <- metrics(yte, lg2$pred, lg2$prob)
  lg3 <- fit_logit(X_raw[train_idx, THREE], X_raw[-train_idx, THREE], ytr); res$logit3 <- metrics(yte, lg3$pred, lg3$prob)
  res$gini <- sort(importance(rf, type = 2)[, 1], decreasing = TRUE)
  res$perm <- sort(importance(rf, type = 1, scale = FALSE)[, 1], decreasing = TRUE)
  res$rf_model <- rf; res$Xte <- Xte; res$yte <- yte
  res
}

MODELS <- c(modal = "Algengasti flokkur", tree = "Ákvörðunartré (dýpt 3)", rf = "Slembiskógur",
            rf3 = "Slembiskógur, 3 spurningar", logit = "Aðhvarfsgreining, allar breytur",
            logit2 = "Aðhvarfsgreining, 2 spurningar", logit3 = "Aðhvarfsgreining, 3 spurningar")

# ---- 1. Main split (seed 42, identical to 02_models.Rmd) -----------------
main <- fit_eval(strat_split(42), seed = 42)
cat("\n=== Skipting með seed 42 (sama og í kaflanum) ===\n")
for (m in names(MODELS)) cat(sprintf("%-34s %s\n", MODELS[[m]],
                                     paste(sprintf("%s=%.3f", names(main[[m]]), main[[m]]), collapse = "  ")))
cm <- table(satt = main$yte, spá = main$rf_pred)
cat("\nRétt spá innan hvers flokks (recall):\n");  print(round(diag(cm) / rowSums(cm), 3))
cat("\nGini-mikilvægi, 10 efstu:\n");             print(round(head(main$gini, 10), 2))
cat("\nUmröðunarmikilvægi, 10 efstu:\n");          print(round(head(main$perm, 10), 4))
for (v in lab(c("age", "educationflo", "elecdist", "govprfm")))
  if (!is.na(v)) cat(sprintf("Sæti %-52s Gini: %s  umröðun: %s  (af %d)\n", v,
                             match(v, names(main$gini)), match(v, names(main$perm)), length(main$gini)))

# ---- 2. Repeated stratified 80/20 splits ---------------------------------
reps <- lapply(seq_len(N_REPS), function(s) fit_eval(strat_split(1000 + s), seed = 1000 + s))
cat("\n=== ", N_REPS, " endurteknar skiptingar: meðaltal [95% bil] ===\n", sep = "")
for (m in names(MODELS)) for (k in c("acc", "bal_acc", "top2")) {
  if (m == "modal" && k == "top2") next
  v <- sapply(reps, function(r) r[[m]][k])
  cat(sprintf("%-34s %-8s %.3f [%.3f, %.3f]\n", MODELS[[m]], k, mean(v), quantile(v, .025), quantile(v, .975)))
}
d <- sapply(reps, function(r) r$rf["acc"] - r$logit["acc"])
cat(sprintf("\nSlembiskógur betri en aðhvarfsgreining í %d af %d skiptingum (meðalmunur %.3f)\n",
            sum(d > 0), N_REPS, mean(d)))
rank_of <- function(v, what) sapply(reps, function(r) match(v, names(r[[what]])))
for (v in lab(c("age", "educationflo", "elecdist", "govprfm"))) if (!is.na(v) && v %in% names(X_raw))
  cat(sprintf("Sæti %-52s Gini: miðgildi %g  umröðun: miðgildi %g (bil %d–%d)\n", v,
              median(rank_of(v, "gini")), median(rank_of(v, "perm")),
              min(rank_of(v, "perm")), max(rank_of(v, "perm"))))
top3 <- table(unlist(lapply(reps, function(r) names(r$perm)[1:3])))
cat("\nHversu oft hver breyta er í 3 efstu sætum umröðunarmikilvægis:\n"); print(sort(top3, decreasing = TRUE))
