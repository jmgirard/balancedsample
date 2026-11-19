test_that("initial splits have the right sizes and classes", {
  d <- sim_data()
  for (m in available_methods()) {
    set.seed(1)
    s <- balanced_initial_split(d, prop = 3 / 4, balance = c(x1, x2, cat), method = m)
    expect_s3_class(s, c("balanced_initial_split", "initial_split", "rsplit"))
    expect_equal(nrow(rsample::training(s)), 150, info = m)
    expect_equal(nrow(rsample::testing(s)), 50, info = m)
    expect_equal(attr(s, "prop"), 3 / 4)
    expect_equal(attr(s, "method"), m)
  }
})

test_that("initial splits stratify exactly", {
  d <- sim_data()
  strata <- interaction(d$cat, d$sex, drop = TRUE)
  share <- as.vector(table(strata)) * 0.8
  for (m in available_methods()) {
    set.seed(2)
    s <- balanced_initial_split(d, prop = 0.8, balance = c(x1, x2), exact = c(cat, sex), method = m)
    n_train <- tabulate(as.integer(strata)[s$in_id], nlevels(strata))
    expect_true(all(n_train >= floor(share) & n_train <= ceiling(share)), info = m)
  }
})

test_that("initial splits keep groups together", {
  d <- sim_data()
  for (m in available_methods()) {
    set.seed(3)
    s <- balanced_initial_split(d, prop = 0.75, balance = c(x1, x2), group = id, method = m)
    expect_length(intersect(d$id[s$in_id], d$id[rsample::complement(s)]), 0)
    # 38 groups * 0.75 = 28.5 groups for training
    expect_true(length(unique(d$id[s$in_id])) %in% 28:29, info = m)
  }
})

test_that("twinning needs prop = 1 - 1/r", {
  skip_if_not_installed("twinning")
  d <- sim_data()
  expect_snapshot(
    balanced_initial_split(d, prop = 0.7, balance = x1, method = "twinning"),
    error = TRUE
  )
  set.seed(4)
  s <- balanced_initial_split(d, prop = 0.25, balance = x1, method = "twinning")
  expect_equal(nrow(rsample::training(s)), 50)
})

test_that("bad prop values give clear errors", {
  d <- sim_data()
  expect_snapshot(error = TRUE, {
    balanced_initial_split(d, prop = 1, balance = x1)
    balanced_initial_split(d, prop = "a", balance = x1)
  })
})
