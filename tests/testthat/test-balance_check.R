test_that("balance_check() returns one SMD per variable and level", {
  d <- sim_data()
  set.seed(1)
  folds <- balanced_vfold_cv(d, v = 4, balance = c(x1, cat), exact = sex, method = "rerandomize")
  bc <- balance_check(folds)
  expect_s3_class(bc, "balance_check")
  expect_named(bc, c("id", "variable", "level", "statistic", "value"))
  # x1 + 3 levels of cat + 2 levels of sex + energy = 7 rows per fold
  expect_equal(nrow(bc), 4 * 7)
  expect_equal(sum(bc$statistic == "energy"), 4)
  expect_true(all(bc$value[bc$statistic == "energy"] >= 0))
})

test_that("balance_check() matches a direct SMD", {
  d <- sim_data()
  set.seed(2)
  folds <- rsample::vfold_cv(d, v = 3)
  bc <- balance_check(folds, x1)
  s <- folds$splits[[1]]
  a <- d$x1[rsample::complement(s)]
  b <- d$x1[s$in_id]
  expected <- (mean(a) - mean(b)) / sqrt((var(a) + var(b)) / 2)
  expect_equal(bc$value[bc$id == "Fold1" & bc$statistic == "smd"], expected)
})

test_that("energy distance is near zero for identical sets and grows with a shift", {
  set.seed(3)
  a <- matrix(rnorm(200), ncol = 2)
  expect_equal(energy_distance(a, a), 0)
  expect_gt(energy_distance(a, a + 2), energy_distance(a, a + 0.1))
})

test_that("balance_check() works on repeats and on splits", {
  d <- sim_data()
  set.seed(4)
  folds <- balanced_vfold_cv(d, v = 3, repeats = 2, balance = x1, method = "rerandomize")
  bc <- balance_check(folds)
  expect_true(all(c("id", "id2") %in% names(bc)))

  s <- balanced_initial_split(d, balance = c(x1, x2), method = "rerandomize")
  bc <- balance_check(s)
  expect_equal(unique(bc$id), "Split")
  expect_output(print(bc), "Balance check: 1 split")
})

test_that("balance_check() drops missing values", {
  d <- data.frame(z = c(1, 2, 3, NA, 5, 6), w = c("a", NA, "b", "a", "b", "a"))
  s <- rsample::make_splits(list(analysis = 1:3, assessment = 4:6), d)
  bc <- balance_check(s, z, w)
  expect_equal(bc$value[bc$variable %in% "z"], (5.5 - 2) / sqrt((0.5 + 1) / 2))
  expect_false(anyNA(bc$value))
})

test_that("balance_check() reports complete separation as Inf", {
  d <- data.frame(g = rep(c("A", "B"), each = 4))
  s <- rsample::make_splits(list(analysis = 1:4, assessment = 5:8), d)
  bc <- balance_check(s, g)
  expect_equal(bc$value[bc$statistic == "smd"], c(-Inf, Inf))
  expect_output(print(bc), "max \\|SMD\\| = Inf")
})

test_that("balance_check() needs columns for plain rsample objects", {
  d <- sim_data()
  expect_snapshot(balance_check(rsample::vfold_cv(d, v = 3)), error = TRUE)
  expect_snapshot(balance_check(1), error = TRUE)
})

test_that("autoplot() returns ggplot objects", {
  skip_if_not_installed("ggplot2")
  d <- sim_data()
  set.seed(5)
  folds <- balanced_vfold_cv(d, v = 3, repeats = 2, balance = c(x1, cat), method = "rerandomize")
  bc <- balance_check(folds)
  expect_s3_class(ggplot2::autoplot(bc), "ggplot")
  expect_s3_class(ggplot2::autoplot(bc, type = "energy"), "ggplot")
})
