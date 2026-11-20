test_that("balanced folds work with tune::fit_resamples()", {
  # The floor in DESCRIPTION; much older tune can't take a model spec here.
  skip_if_not_installed("tune", "2.0.0")
  skip_if_not_installed("parsnip")

  set.seed(1)
  folds <- balanced_vfold_cv(
    mtcars,
    v = 4,
    balance = c(mpg, hp, wt),
    exact = am,
    method = "rerandomize"
  )
  res <- tune::fit_resamples(
    parsnip::linear_reg(),
    mpg ~ hp + wt,
    resamples = folds
  )
  expect_s3_class(res, "resample_results")
  metrics <- tune::collect_metrics(res)
  expect_equal(sort(metrics$.metric), c("rmse", "rsq"))
  expect_true(all(metrics$n == 4))
})

test_that("balanced initial splits work with tune::last_fit()", {
  skip_if_not_installed("tune", "2.0.0")
  skip_if_not_installed("parsnip")

  set.seed(2)
  split <- balanced_initial_split(
    mtcars,
    prop = 3 / 4,
    balance = c(mpg, hp, wt),
    method = "rerandomize"
  )
  res <- tune::last_fit(parsnip::linear_reg(), mpg ~ hp + wt, split = split)
  expect_s3_class(res, "last_fit")
  expect_equal(nrow(tune::collect_predictions(res)), 8)
})

test_that("calibration splits of folds are balanced initial splits", {
  d <- sim_data()
  set.seed(3)
  folds <- balanced_vfold_cv(
    d,
    v = 5,
    balance = c(x1, x2),
    exact = site,
    group = id,
    method = "rerandomize"
  )
  outer <- folds$splits[[1]]
  cal <- rsample::internal_calibration_split(
    outer,
    split_args = rsample::.get_split_args(folds)
  )
  expect_s3_class(cal, "balanced_vfold_split_cal")
  expect_s3_class(cal, "internal_calibration_split")
  expect_s3_class(cal, "balanced_vfold_split")

  fit_set <- rsample::analysis(cal)
  cal_set <- rsample::calibration(cal)
  expect_equal(nrow(fit_set) + nrow(cal_set), nrow(rsample::analysis(outer)))
  # Groups stay together, and about 1/5 of the groups go to calibration.
  expect_length(intersect(fit_set$id, cal_set$id), 0)
  n_groups <- length(unique(rsample::analysis(outer)$id))
  expect_equal(length(unique(cal_set$id)), round(n_groups / 5), tolerance = 1)
})

test_that("calibration splits of an initial split use the same prop", {
  d <- sim_data()
  set.seed(4)
  split <- balanced_initial_split(d, prop = 4 / 5, balance = c(x1, cat))
  cal <- rsample::internal_calibration_split(
    split,
    split_args = rsample::.get_split_args(split)
  )
  expect_s3_class(cal, "balanced_initial_split_cal")
  expect_equal(nrow(rsample::calibration(cal)), 32)

  # tune::last_fit() passes no split arguments.
  cal <- rsample::internal_calibration_split(split, split_args = list())
  expect_equal(nrow(rsample::calibration(cal)), 32)
  expect_equal(attr(cal, "balance"), c("x1", "cat"))
})

test_that("twinning folds drop `strategy` for the calibration split", {
  skip_if_not_installed("twinning")
  d <- sim_data()
  set.seed(5)
  folds <- balanced_vfold_cv(
    d,
    v = 4,
    balance = c(x1, x2),
    method = "twinning",
    options = list(strategy = 2)
  )
  cal <- rsample::internal_calibration_split(
    folds$splits[[1]],
    split_args = rsample::.get_split_args(folds)
  )
  expect_equal(nrow(rsample::calibration(cal)), 150 / 4, tolerance = 1)
})

test_that("calibration falls back to an empty set when it can't split", {
  set.seed(6)
  folds <- balanced_vfold_cv(mtcars[1:4, ], v = 2, balance = mpg)
  args <- rsample::.get_split_args(folds)
  # A column that is not in the data makes the inner split fail.
  args$balance <- "not_a_column"
  expect_snapshot(
    cal <- rsample::internal_calibration_split(folds$splits[[1]], args)
  )
  expect_equal(nrow(rsample::calibration(cal)), 0)
  expect_equal(nrow(rsample::analysis(cal)), 2)
})

test_that("twinning calibration falls back to an empty set for a bad share", {
  skip_if_not_installed("twinning")
  d <- sim_data()
  set.seed(8)
  split <- balanced_initial_split(
    d,
    prop = 3 / 4,
    balance = x1,
    method = "twinning"
  )
  args <- rsample::.get_split_args(split)
  args$prop <- 0.7
  expect_snapshot(
    cal <- rsample::internal_calibration_split(split, args)
  )
  expect_equal(nrow(rsample::calibration(cal)), 0)
  expect_equal(nrow(rsample::analysis(cal)), 150)
})

test_that("tune trains a postprocessor on a balanced calibration split", {
  # tune 2.0.0 is the first version that trains postprocessors, and probably
  # 1.0.0 the first with the linear calibration.
  skip_if_not_installed("tune", "2.0.0")
  skip_if_not_installed("parsnip")
  skip_if_not_installed("workflows")
  skip_if_not_installed("tailor")
  skip_if_not_installed("probably", "1.0.0")

  # A linear calibration without smoothing fits on small calibration sets.
  # With smoothing, older probably versions skip the calibration.
  wf <- workflows::workflow(
    mpg ~ hp + wt,
    parsnip::linear_reg(),
    tailor::adjust_numeric_calibration(
      tailor::tailor(),
      method = "linear",
      smooth = FALSE
    )
  )
  # Predictions of the fitted model alone, without the postprocessor. The
  # formula uses the numeric columns as they are.
  raw_predict <- function(fitted, new_data) {
    model <- workflows::extract_fit_parsnip(fitted)
    stats::predict(model, new_data[c("hp", "wt")])$.pred
  }

  set.seed(7)
  folds <- balanced_vfold_cv(mtcars, v = 4, balance = c(mpg, hp, wt))
  ctrl <- tune::control_resamples(save_pred = TRUE, extract = function(x) x)
  res <- tune::fit_resamples(wf, resamples = folds, control = ctrl)
  expect_s3_class(res, "resample_results")
  expect_true(all(tune::collect_metrics(res)$n == 4))
  # In each fold, the collected predictions are the calibrated predictions
  # of the workflow that tune fitted, and the calibration changed them.
  pred <- tune::collect_predictions(res)
  for (i in seq_len(nrow(folds))) {
    fitted <- res$.extracts[[i]]$.extracts[[1]]
    new_data <- rsample::assessment(folds$splits[[i]])
    fold_pred <- pred[pred$id == folds$id[[i]], ]
    fold_pred <- fold_pred[order(fold_pred$.row), ]
    expect_equal(
      unname(fold_pred$.pred),
      unname(stats::predict(fitted, new_data)$.pred)
    )
    expect_gt(max(abs(fold_pred$.pred - raw_predict(fitted, new_data))), 1e-6)
  }

  set.seed(8)
  split <- balanced_initial_split(mtcars, balance = c(mpg, hp, wt))
  res <- tune::last_fit(wf, split = split)
  pred <- tune::collect_predictions(res)
  expect_equal(nrow(pred), 8)
  fitted <- tune::extract_workflow(res)
  new_data <- rsample::testing(split)
  pred <- pred[order(pred$.row), ]
  expect_equal(
    unname(pred$.pred),
    unname(stats::predict(fitted, new_data)$.pred)
  )
  expect_gt(max(abs(pred$.pred - raw_predict(fitted, new_data))), 1e-6)
})

test_that("labels() of repeated folds combine both IDs", {
  set.seed(8)
  folds <- balanced_vfold_cv(mtcars, v = 2, repeats = 2, balance = mpg)
  expect_equal(
    labels(folds),
    c("Repeat1.Fold1", "Repeat1.Fold2", "Repeat2.Fold1", "Repeat2.Fold2")
  )
  expect_s3_class(labels(folds, make_factor = TRUE), "factor")
  single <- balanced_vfold_cv(mtcars, v = 2, balance = mpg)
  expect_equal(labels(single), c("Fold1", "Fold2"))
})
