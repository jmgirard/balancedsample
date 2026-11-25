test_that("balance_check() returns one SMD per variable and level", {
  d <- sim_data()
  set.seed(1)
  folds <- balanced_vfold_cv(
    d,
    v = 4,
    balance = c(x1, cat),
    exact = sex,
    method = "rerandomize"
  )
  bc <- balance_check(folds)
  expect_s3_class(bc, "balance_check")
  expect_named(bc, c("id", "variable", "level", "statistic", "value"))
  # x1 + 3 levels of cat + 2 levels of sex + energy = 7 rows per fold, and
  # two chance rows for each of the 3 variables.
  expect_equal(nrow(bc), 4 * (7 + 6))
  expect_equal(sum(bc$statistic == "energy"), 4)
  expect_equal(sum(bc$statistic == "chance_mean"), 4 * 3)
  expect_equal(nrow(balance_check(folds, chance = 0)), 4 * 7)
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
  folds <- balanced_vfold_cv(
    d,
    v = 3,
    repeats = 2,
    balance = x1,
    method = "rerandomize"
  )
  bc <- balance_check(folds)
  expect_true(all(c("id", "id2") %in% names(bc)))

  s <- balanced_initial_split(d, balance = c(x1, x2), method = "rerandomize")
  bc <- balance_check(s)
  expect_equal(unique(bc$id), "Split")
  expect_output(print(bc), "Balance check: 1 split, 2 variables")
  withr::local_options(width = 40)
  header <- utils::capture.output(print(bc))[1:4]
  expect_match(header[1], "^# Balance check: 1 split, 2 variables$")
  header <- utils::capture.output(print(bc))[1:5]
  expect_match(
    header[2],
    "^# \\|SMD\\| above chance \\(95%\\) in [0-2] of 2 variables,$"
  )
  expect_match(header[3], "^# ratio to chance [0-9.e-]+,$")
  expect_match(header[4], "^# energy distance [0-9.e-]+$")
  expect_equal(header[5], "")
})

test_that("balance_check() drops missing values and reports the share missing", {
  d <- data.frame(z = c(1, 2, 3, NA, 5, 6), w = c("a", NA, "b", "a", "b", "a"))
  s <- rsample::make_splits(list(analysis = 1:3, assessment = 4:6), d)
  bc <- balance_check(s, z, w, chance = 0)
  smd <- bc$statistic == "smd"
  expect_equal(
    bc$value[smd & bc$variable %in% "z" & is.na(bc$level)],
    (5.5 - 2) / sqrt((0.5 + 1) / 2)
  )
  expect_equal(bc$level[bc$variable %in% "w"], c("a", "b", "(missing)"))
  # z is missing in 1 of 3 assessment rows and in no analysis row; w the
  # other way round.
  missing <- bc$value[bc$level %in% "(missing)"]
  expect_equal(missing, c(1, -1))
  expect_false(anyNA(bc$value))
})

test_that("the energy distance uses all rows when values are missing", {
  set.seed(1)
  n <- 200
  d <- data.frame(x = rnorm(n), y = rnorm(n))
  # Every row has a missing value, so no row is complete.
  d$x[seq(1, n, 2)] <- NA
  d$y[seq(2, n, 2)] <- NA
  split <- rsample::initial_split(d)
  en <- balance_check(split, x, y)
  en <- en$value[en$statistic == "energy"]
  expect_true(is.finite(en) && en > 0)

  # The same encoding as the split functions: filled values and indicators.
  xs <- build_balance_matrix(d)
  expect_equal(
    en,
    energy_distance(
      xs[rsample::complement(split), ],
      xs[split$in_id, ]
    )
  )

  # With no missing values, nothing changes.
  d <- data.frame(x = rnorm(n), g = sample(letters[1:3], n, TRUE))
  split <- rsample::initial_split(d)
  bc <- balance_check(split, x, g)
  xs <- build_balance_matrix(d)
  expect_equal(
    bc$value[bc$statistic == "energy"],
    energy_distance(xs[rsample::complement(split), ], xs[split$in_id, ])
  )
  expect_false(any(bc$level %in% "(missing)"))
})

test_that("balance_check() reports complete separation as Inf", {
  d <- data.frame(g = rep(c("A", "B"), each = 4))
  s <- rsample::make_splits(list(analysis = 1:4, assessment = 5:8), d)
  bc <- balance_check(s, g)
  expect_equal(bc$value[bc$statistic == "smd"], c(-Inf, Inf))
  expect_output(
    print(bc),
    "|SMD| above chance (95%) in 1 of 1 variable,",
    fixed = TRUE
  )
  expect_output(
    print(balance_check(s, g, chance = 0)),
    "|SMD| > 0.1 in 1 of 1 variable,",
    fixed = TRUE
  )
  expect_output(print(bc), "g         A      -Inf", fixed = TRUE)

  d <- data.frame(x = c(0, 0, 1e-13, 1e-13))
  s <- rsample::make_splits(list(analysis = 1:2, assessment = 3:4), d)
  expect_equal(balance_check(s, x)$value[1], Inf)
})

test_that("SMDs don't depend on the units or the origin", {
  x <- c(-2, -1, 1, 2, -1.5, 0.5)
  smd <- function(v) {
    s <- rsample::make_splits(
      list(analysis = 1:3, assessment = 4:6),
      data.frame(v = v)
    )
    balance_check(s, v)$value[1]
  }
  expect_equal(smd(x * 1e-14), smd(x))
  expect_equal(smd(x * 1e14), smd(x))
  expect_equal(smd(x + 1e12), smd(x))
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
  folds <- balanced_vfold_cv(
    d,
    v = 3,
    repeats = 2,
    balance = c(x1, cat),
    method = "rerandomize"
  )
  bc <- balance_check(folds)
  expect_s3_class(ggplot2::autoplot(bc), "ggplot")
  expect_s3_class(ggplot2::autoplot(bc, type = "energy"), "ggplot")
  # The record of ID columns doesn't reach the plotted data.
  expect_null(attr(ggplot2::autoplot(bc)$data, "id_cols"))

  s <- balanced_initial_split(d, balance = x1, method = "rerandomize")
  p <- ggplot2::autoplot(balance_check(s), type = "energy")
  expect_s3_class(p, "ggplot")
})

test_that("balance_check() handles logical and missing columns", {
  d <- data.frame(
    flag = c(TRUE, FALSE, TRUE, FALSE, TRUE, TRUE),
    z = c(NA, NA, NA, 1, 2, 3)
  )
  s <- rsample::make_splits(list(analysis = 1:3, assessment = 4:6), d)
  bc <- balance_check(s, flag, z, chance = 0)
  expect_equal(bc$level[bc$variable %in% "flag"], c("FALSE", "TRUE"))
  # z is missing in the whole analysis set, so it has no SMD of its values,
  # and its share missing differs completely.
  z <- bc$variable %in% "z"
  expect_true(is.na(bc$value[z & is.na(bc$level)]))
  expect_equal(bc$value[z & bc$level %in% "(missing)"], -Inf)
  expect_true(is.finite(bc$value[bc$statistic == "energy"]))
})

test_that("balance_check() subsamples large sets for the energy distance", {
  a <- matrix(stats::rnorm(60), ncol = 2)
  b <- matrix(stats::rnorm(80, mean = 1), ncol = 2)
  set.seed(6)
  sub <- energy_distance(a, b, max_n = 10)
  set.seed(6)
  a_rows <- sample.int(nrow(a), 10)
  b_rows <- sample.int(nrow(b), 10)
  expect_equal(sub, energy_distance(a[a_rows, ], b[b_rows, ]))

  d <- sim_data()
  set.seed(6)
  folds <- balanced_vfold_cv(d, v = 2, balance = c(x1, x2))
  # A smaller `max_n` changes the energy distance through the public API.
  energy <- function(bc) bc$value[bc$statistic == "energy"]
  set.seed(7)
  small <- energy(balance_check(folds, max_n = 5))
  full <- energy(balance_check(folds))
  expect_false(isTRUE(all.equal(small, full)))
  expect_error(balance_check(folds, max_n = 1), "at least 2")
  expect_snapshot(balance_check(folds, max_n = 1), error = TRUE)
})

test_that("balance_check() needs at least one split", {
  empty <- rsample::manual_rset(list(), character())
  expect_error(balance_check(empty, mpg), "no splits", class = "rlang_error")
})

test_that("summary() gives one row per split", {
  d <- sim_data()
  set.seed(8)
  folds <- balanced_vfold_cv(
    d,
    v = 3,
    repeats = 2,
    balance = c(x1, cat),
    exact = sex,
    method = "rerandomize"
  )
  bc <- balance_check(folds)
  s <- summary(bc)
  expect_false(inherits(s, "balance_check"))
  expect_named(
    s,
    c(
      "id",
      "id2",
      "max_abs_smd",
      "variable",
      "level",
      "mean_abs_smd",
      "n_over",
      "n_variables",
      "energy",
      "chance_mean_abs_smd",
      "ratio_to_chance"
    )
  )
  expect_equal(s$id, folds$id)
  expect_equal(s$id2, folds$id2)
  expect_equal(s$energy, bc$value[bc$statistic == "energy"])
  for (i in seq_len(nrow(s))) {
    rows <- bc[bc$id == s$id[i] & bc$id2 == s$id2[i], ]
    smd <- rows[rows$statistic == "smd", ]
    worst <- which.max(abs(smd$value))
    expect_equal(s$max_abs_smd[i], abs(smd$value[worst]))
    expect_equal(s$variable[i], smd$variable[worst])
    expect_equal(s$level[i], smd$level[worst])
  }
  expect_error(summary(bc, 1), class = "rlib_error_dots_nonempty")
})

test_that("summary() counts each variable once", {
  d <- data.frame(
    x = c(1, 4, 2, 6, 3, 5, 2, 7),
    g = c("a", "b", "c", "d", "a", "a", "b", "c"),
    z = c(1, NA, 3, 4, NA, NA, 7, 8)
  )
  s <- rsample::make_splits(list(analysis = 1:4, assessment = 5:8), d)
  bc <- balance_check(s, x, g, z)
  smd <- bc[bc$statistic == "smd", ]
  # A level or the share missing stands for its variable.
  worst <- tapply(abs(smd$value), smd$variable, max)[c("x", "g", "z")]
  out <- summary(bc)
  expect_equal(out$max_abs_smd, max(worst))
  expect_equal(out$mean_abs_smd, mean(worst))
  expect_equal(out$n_variables, 3L)
  # By default, each variable is compared with its own chance reference.
  q95 <- bc[bc$statistic == "chance_q95", ]
  q95 <- setNames(q95$value, q95$variable)[c("x", "g", "z")]
  expect_equal(out$n_over, sum(worst > q95))
  expect_equal(summary(bc, threshold = 0.1)$n_over, sum(worst > 0.1))
  expect_equal(summary(bc, threshold = 0)$n_over, sum(worst > 0))
  expect_equal(summary(bc, threshold = 100)$n_over, 0L)
  expect_equal(
    summary(bc, threshold = unname(worst["x"]))$n_over,
    sum(worst > worst["x"])
  )

  # Of tied largest SMDs, the first row wins, however the rows are sorted.
  d <- data.frame(
    g = c("a", "d", "d", "d", "a", "e", "e", "e"),
    h = c("f", "b", "b", "b", "f", "c", "c", "c")
  )
  s <- rsample::make_splits(list(analysis = 1:4, assessment = 5:8), d)
  tied <- balance_check(s, g, h)
  tied <- tied[order(tied$level), ]
  expect_equal(summary(tied)$variable, "h")
  expect_equal(summary(tied)$level, "b")

  expect_snapshot(summary(bc, threshold = -1), error = TRUE)
  expect_snapshot(summary(bc, threshold = NA), error = TRUE)
  expect_snapshot(summary(bc, by = "level"), error = TRUE)
})

test_that("summary(by = \"variable\") gives one row per variable", {
  d <- sim_data()
  set.seed(8)
  folds <- balanced_vfold_cv(
    d,
    v = 3,
    repeats = 2,
    balance = c(x1, x2, cat),
    exact = sex,
    method = "rerandomize"
  )
  bc <- balance_check(folds, variance_ratio = TRUE)
  out <- summary(bc, by = "variable", threshold = 0.05)
  expect_named(
    out,
    c(
      "variable",
      "median_abs_smd",
      "max_abs_smd",
      "level",
      "id",
      "id2",
      "n_over",
      "n_splits",
      "variance_ratio",
      "chance_q95"
    )
  )
  expect_equal(out$variable, c("x1", "x2", "cat", "sex"))
  smd <- bc[bc$statistic == "smd", ]
  for (v in out$variable) {
    rows <- smd[smd$variable == v, ]
    key <- paste(rows$id, rows$id2)
    per_split <- tapply(abs(rows$value), key, max)
    at <- which.max(abs(rows$value))
    o <- out[out$variable == v, ]
    expect_equal(o$median_abs_smd, stats::median(per_split))
    expect_equal(o$max_abs_smd, max(per_split))
    expect_equal(o$level, rows$level[at])
    expect_equal(c(o$id, o$id2), c(rows$id[at], rows$id2[at]))
    expect_equal(o$n_over, sum(per_split > 0.05))
    expect_equal(o$n_splits, 6L)
  }
  vr <- bc[bc$statistic == "variance_ratio" & bc$variable == "x2", ]
  expect_equal(
    out$variance_ratio[out$variable == "x2"],
    vr$value[which.max(abs(log(vr$value)))]
  )
  expect_true(is.na(out$variance_ratio[out$variable == "cat"]))

  # A variable with no SMD in a split doesn't count for that split, and one
  # with no SMD at all still gets a row.
  none <- bc[
    !(bc$variable %in% "x1" & bc$statistic == "smd") |
      bc$id2 == "Fold1",
  ]
  none$value[none$variable %in% "x1" & none$statistic == "smd"] <- NA
  none <- summary(none, by = "variable")
  expect_equal(none$variable, out$variable)
  expect_equal(none$n_splits[none$variable == "x1"], 0L)
  expect_true(is.na(none$max_abs_smd[none$variable == "x1"]))
  expect_true(is.na(none$id[none$variable == "x1"]))
  part <- bc[!(bc$variable %in% "x1" & bc$id2 == "Fold1"), ]
  part <- summary(part, by = "variable")
  expect_equal(part$n_splits[part$variable == "x1"], 4L)
  expect_equal(part$n_splits[part$variable != "x1"], c(6L, 6L, 6L))

  empty <- summary(bc[0, ], by = "variable")
  expect_equal(nrow(empty), 0)
  expect_named(empty, setdiff(names(out), c("variance_ratio", "chance_q95")))
  expect_type(empty$median_abs_smd, "double")
  expect_type(empty$n_over, "integer")
})

test_that("print() shows one split, a few splits, or many splits", {
  # The chance reference comes from random draws.
  set.seed(1)
  d <- data.frame(
    x = c(1, 4, 2, 6, 3, 5, 2, 7, 4, 4, 5, 1),
    g = rep(c("a", "b", "b"), 4),
    z = c(1, NA, 3, 4, NA, 6, 7, 8, 2, 3, 1, 5)
  )
  s <- rsample::make_splits(list(analysis = 1:8, assessment = 9:12), d)
  expect_snapshot(print(balance_check(s, x, g, z, variance_ratio = TRUE)))

  folds <- function(k) {
    splits <- lapply(seq_len(k), function(i) {
      out <- ((i - 1L) %% 12L) + 1L
      out <- c(out, (out %% 12L) + 1L)
      rsample::make_splits(
        list(analysis = setdiff(1:12, out), assessment = out),
        d
      )
    })
    rsample::manual_rset(splits, paste0("Fold", seq_len(k)))
  }
  expect_snapshot(withr::with_options(
    list(width = 120),
    print(balance_check(folds(3), x, g, variance_ratio = TRUE))
  ))
  expect_snapshot(print(balance_check(folds(11), x, g, z)))

  # Columns that don't fit are dropped, the ratio with its variable.
  wide <- balance_check(folds(3), x, g, variance_ratio = TRUE)
  withr::with_options(
    list(width = 70),
    out <- utils::capture.output(print(wide))
  )
  expect_true(all(nchar(out) <= 70))
  expect_false(any(grepl("variance ratio|ratio variable", out[1:8])))
  expect_true(any(grepl(
    "Not shown for lack of width: variance ratio, ratio variable",
    out,
    fixed = TRUE
  )))

  # Ten splits still get one row each.
  out <- utils::capture.output(print(balance_check(folds(10), x)))
  expect_true(any(grepl("^Fold10 ", out)))
})

test_that("print() shows enough digits to agree with the counts", {
  expect_equal(
    format_smd(c(0.09996, 0.10004, 0.1, -0.0998, 0.232, Inf, -Inf, NA), 0.1),
    c("0.09996", "0.10004", "0.1", "-0.0998", "0.232", "Inf", "-Inf", "NA")
  )
  # Mean differences of 0.1 with SDs of 1: just above and below 0.1 in
  # floating point, and counted and shown as 0.1.
  xs <- list(
    c(-2, -1, 0, -1.9, -0.9, 0.1),
    c(-1, 0, 1, -0.9, 0.1, 1.1),
    c(-3.9, -2.9, -1.9, -3.8, -2.8, -1.8)
  )
  for (x in xs) {
    s <- rsample::make_splits(
      list(analysis = 1:3, assessment = 4:6),
      data.frame(x = x)
    )
    # Without the chance reference, the cut-off is 0.1.
    bc <- balance_check(s, x, chance = 0)
    expect_equal(abs(bc$value[1]), 0.1)
    expect_equal(summary(bc)$n_over, 0L)
    expect_equal(summary(bc, by = "variable")$n_over, 0L)
    out <- utils::capture.output(print(bc))
    expect_equal(sub("^x +", "", out[grepl("^x ", out)]), "0.1")
  }
  expect_equal(format_num(c(0.15123, 2, NA)), c("0.151", "2", "NA"))
})

test_that("print() falls back to the rows when it can't summarize", {
  d <- sim_data()
  set.seed(11)
  bc <- balance_check(rsample::vfold_cv(d, v = 3), x1)
  expect_output(print(bc[0, ]), "Balance check: 0 splits")
  out <- utils::capture.output(print(bc[c("id", "statistic", "value")]))
  expect_equal(out[1], "# Balance check")
  expect_match(out[2], "A tibble")
  # Only energy rows, or only variance ratios.
  rep_bc <- balance_check(
    rsample::vfold_cv(d, v = 4, repeats = 3),
    x1,
    variance_ratio = TRUE
  )
  for (stat in c("energy", "variance_ratio")) {
    expect_no_warning(
      out <- utils::capture.output(print(rep_bc[rep_bc$statistic == stat, ]))
    )
    expect_equal(out[1], "# Balance check")
  }

  # Dropping an ID column would merge splits.
  smd <- rep_bc[rep_bc$statistic == "smd", ]
  smd$id2 <- NULL
  expect_snapshot(summary(smd), error = TRUE)
  expect_equal(utils::capture.output(print(smd))[1], "# Balance check")
})

test_that("summary() handles splits, three-way splits, and missing SMDs", {
  d <- sim_data()
  set.seed(9)
  s3 <- balanced_initial_validation_split(
    d,
    prop = c(0.6, 0.2),
    balance = c(x1, x2),
    method = "rerandomize"
  )
  bc3 <- balance_check(s3)
  out3 <- summary(bc3)
  expect_equal(out3$id, c("Validation", "Testing"))
  expect_equal(out3$energy, bc3$value[bc3$statistic == "energy"])
  for (id in out3$id) {
    smd <- bc3$value[bc3$id == id & bc3$statistic == "smd"]
    expect_equal(out3$max_abs_smd[out3$id == id], max(abs(smd)))
  }

  d <- data.frame(
    z = c(NA, NA, NA, 1, 2, 3),
    g = c("a", "b", "a", "b", "a", "b")
  )
  s <- rsample::make_splits(list(analysis = 1:3, assessment = 4:6), d)
  # z has no observed value in the analysis set, so its only SMD that
  # isn't missing is the one of its share missing.
  bc <- balance_check(s, z)
  out <- summary(bc[!bc$level %in% "(missing)", ])
  expect_equal(out$id, "Split")
  expect_true(is.na(out$max_abs_smd))
  expect_true(is.na(out$variable))
  out <- summary(bc)
  expect_equal(out$variable, "z")
  expect_equal(out$level, "(missing)")
  expect_equal(out$max_abs_smd, Inf)
  bc$value[bc$statistic == "energy"] <- NA
  expect_true(is.na(summary(bc)$energy))

  out <- summary(balance_check(s, g))
  expect_equal(out$variable, "g")
  # The two levels of g tie, and the first one is kept.
  expect_equal(out$level, "a")
  expect_equal(out$max_abs_smd, abs(balance_check(s, g)$value[1]))
  d$g <- factor(d$g, levels = c("b", "a"))
  s <- rsample::make_splits(list(analysis = 1:3, assessment = 4:6), d)
  expect_equal(summary(balance_check(s, g))$level, "b")

  d <- data.frame(g = rep(c("A", "B"), each = 4))
  s <- rsample::make_splits(list(analysis = 1:4, assessment = 5:8), d)
  out <- summary(balance_check(s, g))
  expect_equal(out$max_abs_smd, Inf)
  expect_equal(out$level, "A")
})

test_that("summary() keeps splits apart however the rows are arranged", {
  d <- sim_data()
  set.seed(10)
  folds <- rsample::vfold_cv(d, v = 3)
  bc <- balance_check(folds, x1, cat)
  shuffled <- bc[sample(nrow(bc)), ]
  expect_equal(
    summary(shuffled)[order(summary(shuffled)$id), ],
    summary(bc)
  )

  # IDs that would collide if pasted, and `NA` next to "NA".
  folds <- rsample::vfold_cv(d, v = 2, repeats = 2)
  bc <- balance_check(folds, x1, cat)
  key <- paste(bc$id, bc$id2)
  fold <- match(key, unique(key))
  bc$id <- c("a\rb", "a", NA, "NA")[fold]
  bc$id2 <- c("c", "b\rc", "x", "x")[fold]
  out <- summary(bc)
  expect_equal(out$id, c("a\rb", "a", NA, "NA"))
  expect_equal(out$energy, bc$value[bc$statistic == "energy"])
})

test_that("summary() handles empty and incomplete input", {
  d <- sim_data()
  set.seed(11)
  bc <- balance_check(rsample::vfold_cv(d, v = 3), x1)
  empty <- summary(bc[0, ])
  expect_equal(nrow(empty), 0)
  # With no rows, there are no chance rows either.
  expect_named(
    empty,
    setdiff(names(summary(bc)), c("chance_mean_abs_smd", "ratio_to_chance"))
  )
  expect_type(empty$max_abs_smd, "double")
  expect_type(empty$variable, "character")
  expect_type(empty$energy, "double")

  expect_snapshot(summary(bc[c("id", "statistic", "value")]), error = TRUE)
  expect_snapshot(summary(bc[-1]), error = TRUE)

  dup <- bc
  dup$id <- "same"
  expect_snapshot(summary(dup), error = TRUE)

  # Only the ID columns balance_check() made are IDs, even if an added
  # column's name starts with "id".
  noted <- bc
  noted$note <- seq_len(nrow(bc))
  noted$identifier <- seq_len(nrow(bc))
  expect_equal(summary(noted), summary(bc))

  # Without the record, columns whose names start with "id" are IDs.
  plain <- bc
  attr(plain, "id_cols") <- NULL
  plain$note <- seq_len(nrow(bc))
  expect_equal(summary(plain), summary(bc))
  plain$identifier <- seq_len(nrow(bc))
  expect_equal(nrow(summary(plain)), nrow(bc))

  # A renamed ID column is still an ID.
  set.seed(12)
  rep_bc <- balance_check(rsample::vfold_cv(d, v = 3, repeats = 2), x1)
  renamed <- rep_bc
  names(renamed)[names(renamed) == "id2"] <- "id_fold"
  out <- summary(renamed[renamed$statistic == "smd", ])
  expect_equal(nrow(out), 6)
  expect_equal(out$id_fold, summary(rep_bc)$id2)

  # print() returns its input, and summary() drops the record.
  expect_output(printed <- print(bc))
  expect_identical(printed, bc)
  expect_null(attr(summary(bc), "id_cols"))

  # Rows with a missing or unknown statistic.
  expect_snapshot(summary(bc[c(NA, seq_len(nrow(bc))), ]), error = TRUE)
})

test_that("whole-number exact columns are checked as categories", {
  d <- data.frame(code = rep(1:3, 20), x = seq_len(60))
  set.seed(1)
  folds <- balanced_vfold_cv(d, v = 3, balance = x, exact = code)
  bc <- balance_check(folds)
  expect_equal(
    bc$level[bc$variable %in% "code" & bc$statistic == "smd"],
    rep(c("1", "2", "3"), 3)
  )

  # A set with only code 2 differs from one with codes 1 and 3, although
  # the means are equal.
  d <- data.frame(code = c(2, 2, 2, 2, 1, 3, 1, 3), y = 1:8)
  plain <- rsample::make_splits(list(analysis = 5:8, assessment = 1:4), d)
  # Named columns from a plain split stay numeric.
  expect_equal(balance_check(plain, code)$value[1], 0)
  stored <- plain
  attr(stored, "exact") <- "code"
  bc <- balance_check(stored)
  expect_equal(bc$value[bc$variable %in% "code" & bc$level %in% "2"], Inf)
  # Naming a stored exact column keeps it categorical, with no variance
  # ratio, and the energy distance matches that of a factor.
  bc <- balance_check(stored, code, variance_ratio = TRUE)
  expect_equal(bc$level[bc$statistic == "smd"], c("1", "2", "3"))
  expect_false(any(bc$statistic == "variance_ratio"))
  as_factor <- rsample::make_splits(
    list(analysis = 5:8, assessment = 1:4),
    transform(d, code = factor(code))
  )
  expect_equal(
    bc$value[bc$statistic == "energy"],
    balance_check(as_factor, code)$value[4]
  )
})

test_that("the SMD plot of a three-way split tells the sets apart", {
  skip_if_not_installed("ggplot2")
  d <- sim_data()
  set.seed(3)
  s <- balanced_initial_validation_split(d, balance = c(x1, x2))
  built <- ggplot2::ggplot_build(ggplot2::autoplot(balance_check(s)))
  points <- built$data[[length(built$data)]]
  expect_equal(length(unique(points$shape)), 2)
  folds <- balanced_vfold_cv(d, v = 3, balance = c(x1, x2))
  built <- ggplot2::ggplot_build(ggplot2::autoplot(balance_check(folds)))
  expect_equal(length(unique(built$data[[length(built$data)]]$shape)), 1)
})

test_that("variance ratios show differences in spread", {
  d <- data.frame(
    x = c(-1, 1, -1, 1, -5, 5, -5, 5),
    g = rep(c("a", "b"), 4),
    k = c(1, 1, 1, 1, 2, 2, 2, 2)
  )
  s <- rsample::make_splits(list(analysis = 1:4, assessment = 5:8), d)
  bc <- balance_check(s, x, g, k, variance_ratio = TRUE)
  vr <- bc[bc$statistic == "variance_ratio", ]
  # Only numeric variables get one.
  expect_equal(vr$variable, c("x", "k"))
  expect_equal(bc$value[bc$variable %in% "x" & bc$statistic == "smd"], 0)
  expect_equal(vr$value[1], 25)
  # Two zero variances give 1.
  expect_equal(vr$value[2], 1)
  expect_equal(summary(bc)$variance_ratio, 25)
  expect_false("variance_ratio" %in% names(summary(balance_check(s, x))))

  # A zero variance on one side gives 0 or Inf, and a set of one gives NA.
  d <- data.frame(x = c(1, 2, 3, 4, 4, 4))
  s <- rsample::make_splits(list(analysis = 1:3, assessment = 4:6), d)
  bc <- balance_check(s, x, variance_ratio = TRUE)
  expect_equal(bc$value[bc$statistic == "variance_ratio"], 0)
  s <- rsample::make_splits(list(analysis = 4:6, assessment = 1:3), d)
  bc <- balance_check(s, x, variance_ratio = TRUE)
  expect_equal(bc$value[bc$statistic == "variance_ratio"], Inf)
  s <- rsample::make_splits(list(analysis = 1:5, assessment = 6L), d)
  bc <- balance_check(s, x, variance_ratio = TRUE)
  expect_true(is.na(bc$value[bc$statistic == "variance_ratio"]))
  expect_true(is.na(summary(bc)$variance_ratio))

  # The ratio farthest from 1 on the log scale is summarized.
  d <- data.frame(
    x = c(-2, 2, -2, 2, -1, 1, -1, 1),
    y = c(-1, 1, -1, 1, -1.5, 1.5, -1.5, 1.5)
  )
  s <- rsample::make_splits(list(analysis = 1:4, assessment = 5:8), d)
  expect_equal(
    summary(balance_check(s, x, y, variance_ratio = TRUE))$variance_ratio,
    0.25
  )

  expect_snapshot(balance_check(s, x, variance_ratio = NA), error = TRUE)
})

test_that("variance ratios work for every kind of object", {
  d <- sim_data()
  set.seed(4)
  folds <- balanced_vfold_cv(d, v = 3, balance = c(x1, cat))
  bc <- balance_check(folds, variance_ratio = TRUE)
  expect_equal(sum(bc$statistic == "variance_ratio"), 3)
  s3 <- balanced_initial_validation_split(d, balance = x1)
  bc <- balance_check(s3, variance_ratio = TRUE)
  expect_equal(
    bc$id[bc$statistic == "variance_ratio"],
    c("Validation", "Testing")
  )
  expect_output(print(bc), "Balance check: 2 splits")
  skip_if_not_installed("ggplot2")
  expect_s3_class(ggplot2::autoplot(bc), "ggplot")
})

test_that("each split of an rset is checked on its own data", {
  a <- rsample::make_splits(
    list(analysis = 1:4, assessment = 5:8),
    data.frame(x = rep(0:1, each = 4))
  )
  b <- rsample::make_splits(
    list(analysis = 1:4, assessment = 5:8),
    data.frame(x = rep(0:1, 4))
  )
  r <- rsample::manual_rset(list(a, b), c("First", "Second"))
  s <- summary(balance_check(r, x))
  expect_equal(s$max_abs_smd, c(Inf, 0))
  expect_equal(s$energy[2], 0)
})

test_that("small differences far from the origin are measured", {
  t0 <- as.POSIXct("2026-01-01", tz = "UTC")
  # Microseconds on a date-time in seconds.
  d <- data.frame(t = t0 + c(0, 10, 0, 10, 10, 30, 10, 30) / 1e6)
  s <- rsample::make_splits(list(analysis = 1:4, assessment = 5:8), d)
  set.seed(1)
  bc <- balance_check(s, t, variance_ratio = TRUE)
  d0 <- data.frame(t = c(0, 10, 0, 10, 10, 30, 10, 30))
  s0 <- rsample::make_splits(list(analysis = 1:4, assessment = 5:8), d0)
  set.seed(1)
  expect_equal(bc$value, balance_check(s0, t, variance_ratio = TRUE)$value)
  expect_equal(ncol(build_balance_matrix(d)), 1)
})

test_that("a gap between the sets doesn't hide the spread within them", {
  # Spreads of 1e-7 seconds at the epoch, against a set in 2026.
  d <- data.frame(
    t = as.POSIXct(
      c(0, 1e-7, 2e-7, 0, rep(1767225600, 4)),
      origin = "1970-01-01",
      tz = "UTC"
    )
  )
  x <- as.numeric(d$t)
  # The 2026 set has no spread.
  smd <- (x[5] - mean(x[1:4])) / sqrt(var(x[1:4]) / 2)
  s <- rsample::make_splits(list(analysis = 1:4, assessment = 5:8), d)
  expect_equal(balance_check(s, t)$value[1], smd)
  # Swapping the sets flips the sign but keeps the size.
  r <- rsample::make_splits(list(analysis = 5:8, assessment = 1:4), d)
  expect_equal(balance_check(r, t)$value[1], -smd)

  # Zero spread on one side gives a variance ratio of 0.
  bc <- balance_check(s, t, variance_ratio = TRUE)
  expect_equal(bc$value[bc$statistic == "variance_ratio"], 0)
})

test_that("every split of an rset must have the columns to check", {
  a <- rsample::make_splits(
    list(analysis = 1:4, assessment = 5:8),
    data.frame(x = 1:8, y = 1:8)
  )
  b <- rsample::make_splits(
    list(analysis = 1:4, assessment = 5:8),
    data.frame(y = 1:8)
  )
  r <- rsample::manual_rset(list(a, b), c("A", "B"))
  expect_snapshot(balance_check(r, x), error = TRUE)
})

test_that("logical exact columns are checked as categories", {
  set.seed(3)
  d <- data.frame(
    flag = rep(c(FALSE, TRUE, NA), c(11, 12, 10)),
    x = rnorm(33)
  )
  split <- balanced_initial_split(d, balance = x, exact = flag, na = "include")
  bc <- balance_check(split)
  expect_equal(
    bc$level[bc$variable %in% "flag" & bc$statistic == "smd"],
    c("FALSE", "TRUE", "(missing)")
  )
  as_factor <- rsample::make_splits(
    list(analysis = split$in_id, assessment = rsample::complement(split)),
    transform(d, flag = factor(flag))
  )
  energy <- function(bc) bc$value[bc$statistic == "energy"]
  expect_equal(energy(bc), energy(balance_check(as_factor, x, flag)))
})

test_that("balance_check() adds a chance reference for each variable", {
  d <- sim_data()
  set.seed(20)
  folds <- balanced_vfold_cv(d, v = 4, balance = c(x1, cat), exact = sex)
  set.seed(21)
  bc <- balance_check(folds)
  chance <- bc[bc$statistic %in% c("chance_mean", "chance_q95"), ]
  # Two rows per variable per split, with no level, after the energy row.
  expect_equal(nrow(chance), 4 * 3 * 2)
  expect_true(all(is.na(chance$level)))
  expect_equal(
    chance$variable[chance$id == "Fold1"],
    rep(c("x1", "cat", "sex"), each = 2)
  )
  fold1 <- which(bc$id == "Fold1")
  expect_equal(
    bc$statistic[fold1],
    c(rep("smd", 6), "energy", rep(c("chance_mean", "chance_q95"), 3))
  )
  mean_rows <- chance[chance$statistic == "chance_mean", ]
  q95_rows <- chance[chance$statistic == "chance_q95", ]
  expect_true(all(mean_rows$value > 0 & mean_rows$value < q95_rows$value))
  # Folds of the same size share one set of draws.
  expect_equal(length(unique(mean_rows$value)), 3)

  # The same seed gives the same draws, and another seed other draws.
  set.seed(21)
  expect_equal(balance_check(folds), bc)
  set.seed(22)
  expect_false(isTRUE(all.equal(balance_check(folds)$value, bc$value)))

  # Without the reference, the output is as before.
  plain <- balance_check(folds, chance = 0)
  expect_equal(
    plain,
    bc[!bc$statistic %in% c("chance_mean", "chance_q95"), ],
    ignore_attr = "row.names"
  )
  expect_snapshot(balance_check(folds, chance = -1), error = TRUE)
})

test_that("the chance reference reduces each variable as summary() does", {
  d <- data.frame(
    z = c(1, NA, 3, 4, NA, 6, 7, 8, 2, NA, 1, 5),
    code = rep(1:3, 4),
    flag = rep(c(TRUE, FALSE, FALSE), 4)
  )
  s <- rsample::make_splits(list(analysis = 1:8, assessment = 9:12), d)
  attr(s, "exact") <- "code"
  set.seed(23)
  bc <- balance_check(s, z, code, flag, chance = 20)
  # The same draws by hand: reassign the rows, then reduce each variable to
  # its largest absolute SMD, over its levels and its share missing.
  set.seed(23)
  worst <- vapply(
    1:20,
    function(r) {
      new_as <- seq_len(12) %in% sample.int(12, 4)
      drawn <- rsample::make_splits(
        list(analysis = which(!new_as), assessment = which(new_as)),
        d
      )
      attr(drawn, "exact") <- "code"
      out <- summary(
        balance_check(drawn, z, code, flag, chance = 0),
        by = "variable"
      )
      out$max_abs_smd
    },
    numeric(3)
  )
  expect_equal(
    bc$value[bc$statistic == "chance_mean"],
    unname(rowMeans(worst))
  )
  expect_equal(
    bc$value[bc$statistic == "chance_q95"],
    unname(apply(worst, 1, stats::quantile, 0.95, names = FALSE))
  )
})

test_that("random folds are near chance and balanced folds below it", {
  set.seed(24)
  random <- summary(balance_check(
    rsample::vfold_cv(sim_patients, v = 10),
    age,
    income,
    diagnosis,
    site
  ))
  ratio <- mean(random$ratio_to_chance)
  expect_gt(ratio, 0.7)
  expect_lt(ratio, 1.4)
  expect_equal(
    random$ratio_to_chance,
    random$mean_abs_smd / random$chance_mean_abs_smd
  )

  set.seed(24)
  folds <- balanced_vfold_cv(
    sim_patients,
    v = 10,
    balance = c(age, income),
    exact = c(diagnosis, site)
  )
  balanced <- summary(balance_check(folds))
  expect_lt(mean(balanced$ratio_to_chance), 0.5)
  expect_true(all(balanced$n_over == 0L))
})

test_that("summary() compares with chance unless given a threshold", {
  d <- sim_data()
  set.seed(25)
  folds <- rsample::vfold_cv(d, v = 5)
  set.seed(26)
  bc <- balance_check(folds, x1, x2, cat, sex)
  plain <- balance_check(folds, x1, x2, cat, sex, chance = 0)
  # A numeric threshold gives the old counts, and without chance rows the
  # cut-off is 0.1.
  new_cols <- c("chance_mean_abs_smd", "ratio_to_chance")
  fixed <- summary(bc, threshold = 0.1)
  expect_equal(fixed[setdiff(names(fixed), new_cols)], summary(plain))
  expect_equal(
    summary(bc, threshold = 0.1, by = "variable")[1:7],
    summary(plain, by = "variable")
  )
  expect_false(any(new_cols %in% names(summary(plain))))
  smd <- plain[plain$statistic == "smd", ]
  per_var <- tapply(abs(smd$value), list(smd$id, smd$variable), max)
  expect_equal(summary(plain)$n_over, unname(rowSums(per_var > 0.1)))

  # By default, each variable is compared with its own 95th percentile.
  q95 <- bc[bc$statistic == "chance_q95", ]
  q95 <- tapply(q95$value, list(q95$id, q95$variable), max)
  expect_equal(summary(bc)$n_over, unname(rowSums(per_var > q95)))
  by_var <- summary(bc, by = "variable")
  expect_equal(
    by_var$n_over,
    unname(colSums(per_var > q95)[by_var$variable])
  )
  expect_equal(
    by_var$chance_q95,
    unname(apply(q95, 2, stats::median)[by_var$variable])
  )

  # Printing names the cut-off it uses.
  expect_output(print(bc), "above chance (95%)", fixed = TRUE)
  expect_output(print(bc), "vs chance", fixed = TRUE)
  expect_output(print(plain), "|SMD| > 0.1", fixed = TRUE)
  expect_false(any(grepl("chance", utils::capture.output(print(plain)))))
})

test_that("the chance reference works for splits and three-way splits", {
  d <- sim_data()
  set.seed(27)
  s <- balanced_initial_split(d, balance = c(x1, cat))
  out <- summary(balance_check(s))
  expect_true(out$ratio_to_chance < 1)

  s3 <- balanced_initial_validation_split(
    d,
    prop = c(0.6, 0.2),
    balance = c(x1, x2)
  )
  bc3 <- balance_check(s3)
  expect_equal(
    unique(bc3$id[bc3$statistic == "chance_q95"]),
    c("Validation", "Testing")
  )
  out3 <- summary(bc3)
  expect_true(all(is.finite(out3$ratio_to_chance)))
})

test_that("grouped splits reassign whole groups for the chance reference", {
  d <- sim_data()
  set.seed(28)
  folds <- balanced_vfold_cv(d, v = 4, balance = x1, exact = site, group = id)
  # `site` is constant within a group, so random groups differ more on it
  # than random rows do.
  chance_site <- function(bc) {
    bc$value[bc$statistic == "chance_mean" & bc$variable %in% "site"]
  }
  set.seed(29)
  grouped <- chance_site(balance_check(folds))
  ungrouped <- folds
  attr(ungrouped, "group") <- NULL
  set.seed(29)
  by_row <- chance_site(balance_check(ungrouped))
  expect_true(all(grouped > by_row))

  # rsample's grouped folds store their group column too.
  rs_folds <- rsample::group_vfold_cv(d, group = id, v = 4)
  set.seed(30)
  rs_grouped <- chance_site(balance_check(rs_folds, x1, site))
  expect_gt(mean(rs_grouped), mean(by_row))
})

test_that("the SMD plot shows the chance band or the 0.1 lines", {
  skip_if_not_installed("ggplot2")
  d <- sim_data()
  set.seed(31)
  folds <- balanced_vfold_cv(d, v = 3, balance = c(x1, cat))
  layers <- function(p) {
    vapply(p$layers, function(l) class(l$geom)[1], character(1))
  }
  p <- ggplot2::autoplot(balance_check(folds))
  expect_true("GeomTile" %in% layers(p))
  built <- ggplot2::ggplot_build(p)
  tiles <- built$data[[which(layers(p) == "GeomTile")]]
  # One band for x1 and one for each level of cat.
  expect_equal(nrow(tiles), 4)
  p0 <- ggplot2::autoplot(balance_check(folds, chance = 0))
  expect_false("GeomTile" %in% layers(p0))
  xs <- unlist(lapply(
    ggplot2::ggplot_build(p0)$data,
    function(l) l$xintercept
  ))
  expect_true(all(c(-0.1, 0.1) %in% xs))
})
