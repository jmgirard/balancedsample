test_that("balanced folds work with tune::fit_resamples()", {
  skip_if_not_installed("tune")
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
  skip_if_not_installed("tune")
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
