test_that("sizes_from_props() sums to n and follows the proportions", {
  set.seed(1)
  expect_equal(sum(sizes_from_props(103, rep(1 / 10, 10))), 103)
  expect_true(all(sizes_from_props(103, rep(1 / 10, 10)) %in% 10:11))
  expect_equal(sizes_from_props(100, c(3 / 4, 1 / 4)), c(75L, 25L))
})

test_that("allocate_strata() keeps row and column sums", {
  set.seed(1)
  strata <- factor(sample(
    letters[1:5],
    237,
    TRUE,
    prob = c(0.5, 0.2, 0.2, 0.05, 0.05)
  ))
  for (sizes in list(
    sizes_from_props(237, rep(0.1, 10)),
    c(178L, 59L),
    c(100L, 80L, 57L)
  )) {
    counts <- allocate_strata(strata, sizes)
    expect_equal(colSums(counts), sizes)
    expect_equal(rowSums(counts), as.vector(table(strata)))
  }
})

test_that("allocate_strata() gives floor or ceiling shares", {
  set.seed(2)
  strata <- factor(sample(letters[1:4], 151, TRUE))
  m <- as.vector(table(strata))

  sizes <- sizes_from_props(151, rep(1 / 7, 7))
  counts <- allocate_strata(strata, sizes)
  expect_true(all(apply(counts, 1, function(r) max(r) - min(r) <= 1)))

  sizes <- c(113L, 38L)
  counts <- allocate_strata(strata, sizes)
  share <- m * sizes[1] / sum(sizes)
  expect_true(all(counts[, 1] >= floor(share) & counts[, 1] <= ceiling(share)))
})

test_that("allocate_strata() uses the actual set sizes", {
  # Sets of 3, 3, 2, 2 rows: the 5-row stratum has a share of exactly 1 in
  # each 2-row set.
  strata <- factor(rep(letters[1:3], c(2, 5, 3)))
  for (seed in 1:20) {
    set.seed(seed)
    counts <- allocate_strata(strata, c(3L, 3L, 2L, 2L))
    expect_equal(counts[2, 3:4], c(1L, 1L))
  }
})

test_that("allocate_strata() rounds every cell for any set sizes", {
  set.seed(5)
  for (i in 1:200) {
    n <- sample(5:150, 1)
    k <- sample(2:min(8, n), 1)
    strata <- factor(sample(letters[1:sample(1:10, 1)], n, TRUE))
    sizes <- as.vector(stats::rmultinom(1, n - k, stats::rexp(k))) + 1L
    counts <- allocate_strata(strata, sizes)
    m <- as.vector(table(droplevels(strata)))
    share <- outer(m, sizes) / n
    expect_equal(colSums(counts), sizes)
    expect_equal(rowSums(counts), m)
    expect_true(all(
      counts >= floor(share + 1e-9) & counts <= ceiling(share - 1e-9)
    ))
  }
})

test_that("sizes_from_props() leaves no set empty when it can", {
  for (seed in 1:10) {
    set.seed(seed)
    expect_equal(sizes_from_props(2, c(0.75, 0.25)), c(1L, 1L))
    expect_equal(sizes_from_props(32, c(0.999, 0.001)), c(31L, 1L))
  }
})

test_that("stratified_random() respects nested strata", {
  set.seed(3)
  outer <- factor(sample(c("a", "b"), 120, TRUE))
  inner <- interaction(outer, sample(1:3, 120, TRUE))
  sizes <- sizes_from_props(120, rep(1 / 6, 6))
  a <- stratified_random(sizes, outer, inner)
  expect_equal(tabulate(a, 6), sizes)
  tab <- table(outer, a)
  expect_true(all(apply(tab, 1, function(r) max(r) - min(r) <= 1)))
})

test_that("fix_sizes() and relabel_to_sizes() hit the targets", {
  set.seed(4)
  a <- sample(1:3, 50, TRUE)
  expect_equal(tabulate(fix_sizes(a, c(20L, 20L, 10L)), 3), c(20L, 20L, 10L))
  expect_equal(
    tabulate(relabel_to_sizes(a, c(17L, 17L, 16L)), 3),
    c(17L, 17L, 16L)
  )
})

test_that("bin_column() keeps a heavily tied value in its own bin", {
  bins <- bin_column(c(rep(0, 100), 1:4), 4)
  expect_equal(nlevels(bins), 2)
  expect_equal(as.vector(table(bins)), c(100L, 4L))
  expect_equal(nlevels(bin_column(1:100, 4)), 4)
})
