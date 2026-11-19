test_that("folds are rsample objects with the right sizes", {
  d <- sim_data()
  for (m in available_methods()) {
    set.seed(1)
    folds <- balanced_vfold_cv(d, v = 7, balance = c(x1, x2, cat), method = m)
    expect_s3_class(folds, c("balanced_vfold_cv", "rset"))
    expect_equal(nrow(folds), 7)
    expect_equal(folds$id, sprintf("Fold%d", 1:7))
    n_assess <- vapply(folds$splits, function(s) length(rsample::complement(s)), integer(1))
    expect_true(all(n_assess %in% c(28L, 29L)), info = m)
    expect_true(assessed_once(folds, nrow(d)), info = m)
    expect_s3_class(rsample::analysis(folds$splits[[1]]), "data.frame")
  }
})

test_that("repeats give two ID columns and fresh partitions", {
  d <- sim_data()
  set.seed(1)
  folds <- balanced_vfold_cv(d, v = 5, repeats = 3, balance = c(x1, x2), method = "rerandomize")
  expect_equal(nrow(folds), 15)
  expect_named(folds, c("splits", "id", "id2"))
  expect_true(assessed_once(folds, nrow(d)))
  first <- rsample::complement(folds$splits[[1]])
  others <- lapply(folds$splits[6:10], rsample::complement)
  expect_false(any(vapply(others, setequal, logical(1), first)))
})

test_that("exact strata are balanced to within one row", {
  d <- sim_data()
  strata <- interaction(d$cat, d$sex, drop = TRUE)
  for (m in available_methods()) {
    set.seed(2)
    folds <- balanced_vfold_cv(d, v = 6, balance = c(x1, x2, x3), exact = c(cat, sex), method = m)
    expect_true(strata_exact(folds, strata), info = m)
    expect_true(assessed_once(folds, nrow(d)), info = m)
  }
})

test_that("exact alone works without balance columns", {
  d <- sim_data()
  set.seed(3)
  folds <- balanced_vfold_cv(d, v = 4, exact = cat)
  expect_true(strata_exact(folds, d$cat))
})

test_that("groups stay together", {
  d <- sim_data()
  for (m in available_methods()) {
    set.seed(4)
    folds <- balanced_vfold_cv(d, v = 5, balance = c(x1, x2), group = id, method = m)
    expect_true(groups_intact(folds, d$id), info = m)
    expect_true(assessed_once(folds, nrow(d)), info = m)
  }
})

test_that("groups and exact strata work together", {
  d <- sim_data()
  site <- factor(d$site)
  for (m in available_methods()) {
    set.seed(5)
    folds <- balanced_vfold_cv(d, v = 4, balance = x1, exact = site, group = id, method = m)
    expect_true(groups_intact(folds, d$id), info = m)
    # Exactness holds for groups (not rows) per stratum.
    n_groups <- vapply(folds$splits, function(s) {
      out <- rsample::complement(s)
      tapply(d$id[out], site[out], function(z) length(unique(z)))
    }, numeric(2))
    expect_true(all(apply(n_groups, 1, function(r) max(r) - min(r) <= 1)), info = m)
  }
})

test_that("exact columns must be constant within groups", {
  d <- sim_data()
  expect_snapshot(
    balanced_vfold_cv(d, v = 4, balance = x1, exact = sex, group = id, method = "rerandomize"),
    error = TRUE
  )
})

test_that("balanced folds beat random folds on the balance variables", {
  d <- sim_data(n = 300)
  set.seed(6)
  random <- mean(replicate(10, max_abs_smd(rsample::vfold_cv(d, v = 5), x1, x2, x3)))
  for (m in setdiff(available_methods(), "interaction")) {
    set.seed(6)
    bal <- mean(replicate(5, max_abs_smd(
      balanced_vfold_cv(d, v = 5, balance = c(x1, x2, x3), method = m)
    )))
    expect_lt(bal, random)
  }
})

test_that("rerandomize meets its threshold or warns", {
  d <- sim_data()
  set.seed(7)
  expect_no_warning(
    balanced_vfold_cv(d, v = 5, balance = c(x1, x2), method = "rerandomize")
  )
  expect_warning(
    balanced_vfold_cv(
      d, v = 5, balance = c(x1, x2), method = "rerandomize",
      options = list(p_accept = 1e-12, max_draws = 3)
    ),
    "threshold"
  )
})

test_that("method options are checked", {
  d <- sim_data()
  expect_snapshot(error = TRUE, {
    balanced_vfold_cv(d, balance = x1, method = "rerandomize", options = list(foo = 1))
    balanced_vfold_cv(d, balance = x1, method = "nope")
    balanced_vfold_cv(d, balance = x1, method = "interaction", options = list(1))
  })
  skip_if_not_installed("anticlust")
  expect_snapshot(
    balanced_vfold_cv(d, balance = x1, options = list(K = 3)),
    error = TRUE
  )
})

test_that("anticlust options pass through", {
  skip_if_not_installed("anticlust")
  d <- sim_data(n = 60)
  set.seed(8)
  folds <- balanced_vfold_cv(d, v = 3, balance = c(x1, x2), options = list(objective = "diversity"))
  expect_true(assessed_once(folds, nrow(d)))
})

test_that("twinning strategy 2 needs a power of two", {
  skip_if_not_installed("twinning")
  d <- sim_data()
  expect_snapshot(
    balanced_vfold_cv(d, v = 5, balance = x1, method = "twinning", options = list(strategy = 2)),
    error = TRUE
  )
  set.seed(9)
  folds <- balanced_vfold_cv(d, v = 4, balance = x1, method = "twinning", options = list(strategy = 2))
  expect_true(assessed_once(folds, nrow(d)))
})

test_that("bad inputs give clear errors", {
  d <- sim_data()
  expect_snapshot(error = TRUE, {
    balanced_vfold_cv(d)
    balanced_vfold_cv(d, v = 1, balance = x1)
    balanced_vfold_cv(d[1:3, ], v = 4, balance = x1)
    balanced_vfold_cv(d, balance = x1, exact = x2)
    balanced_vfold_cv(d, balance = c(x1, id), group = id)
    balanced_vfold_cv(d, balance = x1, group = c(id, sex))
    balanced_vfold_cv(d, v = 50, balance = x1, group = id)
  })
  d$x1[3] <- NA
  expect_snapshot(balanced_vfold_cv(d, balance = x1), error = TRUE)
})

test_that("results are reproducible with a seed", {
  d <- sim_data()
  for (m in available_methods()) {
    set.seed(10)
    a <- balanced_vfold_cv(d, v = 4, balance = c(x1, x2), method = m)
    set.seed(10)
    b <- balanced_vfold_cv(d, v = 4, balance = c(x1, x2), method = m)
    expect_identical(
      lapply(a$splits, rsample::complement),
      lapply(b$splits, rsample::complement),
      info = m
    )
  }
})

test_that("print shows the method and design", {
  d <- sim_data()
  set.seed(11)
  folds <- balanced_vfold_cv(d, v = 3, balance = x1, exact = site, group = id, method = "rerandomize")
  expect_match(pretty(folds), "3-fold balanced cross-validation \\(rerandomize\\)")
  expect_match(pretty(folds), "stratified by site, grouped by id")
  expect_output(print(folds), "balanced cross-validation")
})
