# Balancing methods. See registry.R for the contract.

# anticlust -------------------------------------------------------------------

# The exchange step only swaps rows that share a category, so a stratified
# random start keeps the exact counts from allocate_strata(). anticlust's own
# restarts (`repetitions`) draw starts that ignore those counts, so with exact
# strata the restarts are run here instead, each from a new stratified start.
# Groups are handled by aggregation: anticlust's `must_link` needs fold sizes
# that groups can fill exactly and, for the k-plus objective, equal fold
# sizes, which real grouped data rarely allows.
method_anticlust <- function(x_scaled, sizes, exact = NULL, group = NULL,
                             objective = "kplus", standardize = TRUE,
                             repetitions = NULL, ...) {
  rlang::check_installed("anticlust", reason = "to use `method = \"anticlust\"`.")
  k <- length(sizes)
  # With one row per set, an exchange can only relabel the sets.
  if (all(sizes == 1L)) {
    return(stratified_random(sizes, exact))
  }
  # The k-plus features are built here, as anticlustering() would build them,
  # so that constant moment columns can be dropped before scaling (they
  # become NaN otherwise). A data frame is never mistaken for a distance
  # matrix.
  features <- anticlust_features(x_scaled, objective, standardize)
  if (identical(objective, "kplus")) {
    x_in <- as.data.frame(features)
    obj_in <- "variance"
    std_in <- FALSE
  } else {
    x_in <- as.data.frame(x_scaled)
    obj_in <- objective
    std_in <- standardize
  }
  stratum_counts <- function(a) table(exact, factor(a, levels = seq_len(k)), dnn = NULL)

  run <- function(reps) {
    init <- stratified_random(sizes, exact)
    out <- anticlust::anticlustering(
      x_in,
      K = init,
      objective = obj_in,
      standardize = std_in,
      categories = if (is.null(exact)) NULL else as.integer(exact),
      repetitions = reps,
      ...
    )
    out <- as.integer(out)
    if (!is.null(exact) && !identical(stratum_counts(out), stratum_counts(init))) {
      cli::cli_abort(
        c(
          "These anticlust options changed the {.arg exact} counts.",
          i = "Use {.code method = \"exchange\"} or {.code \"local-maximum\"} with {.arg exact}."
        ),
        call = NULL
      )
    }
    out
  }

  if (is.null(exact) || is.null(repetitions) || repetitions <= 1) {
    return(run(repetitions))
  }
  best <- NULL
  best_val <- -Inf
  for (r in seq_len(repetitions)) {
    out <- run(NULL)
    val <- anticlust_objective(features, out, objective)
    if (is.null(best) || val > best_val) {
      best <- out
      best_val <- val
    }
  }
  best
}

# The features and objective that anticlustering() maximizes, so that
# restarts can be compared.
anticlust_features <- function(x, objective, standardize) {
  if (identical(objective, "kplus")) {
    x <- anticlust::kplus_moment_variables(x, 2, FALSE)
  }
  if (standardize && !is.function(objective)) {
    x <- scale(x)
    x <- x[, colSums(!is.finite(x)) == 0, drop = FALSE]
  }
  x
}

anticlust_objective <- function(features, clusters, objective) {
  if (is.function(objective)) {
    return(objective(features, clusters))
  }
  switch(
    objective,
    kplus = ,
    variance = anticlust::variance_objective(features, clusters),
    diversity = ,
    distance = anticlust::diversity_objective(features, clusters),
    dispersion = anticlust::dispersion_objective(features, clusters),
    cli::cli_abort(
      "{.arg repetitions} with {.arg exact} does not support {.code objective = \"{objective}\"}.",
      call = NULL
    )
  )
}

# twinning --------------------------------------------------------------------

method_twinning <- function(x_scaled, sizes, exact = NULL, group = NULL,
                            strategy = 1L, leaf_size = 8L) {
  rlang::check_installed("twinning", reason = "to use `method = \"twinning\"`.")
  n <- sum(sizes)
  k <- length(sizes)
  # twinning drops matrix dimensions for one column; a zero column does not
  # change any distance.
  if (ncol(x_scaled) == 1) {
    x_scaled <- cbind(x_scaled, 0)
  }

  if (!strategy %in% 1:3) {
    cli::cli_abort("{.arg strategy} must be 1, 2, or 3.", call = NULL)
  }

  # For two sets, strategies 1 and 2 of multiplet() reduce to twin(r = 2).
  # Strategy 3 builds a different sequence, so it uses multiplet().
  if (k == 2 && strategy != 3) {
    small <- which.min(sizes)
    other <- 3L - small
    r <- round(n / sizes[small])
    if (r < 2 || abs(sizes[small] - n / r) >= 1) {
      cli::cli_abort(
        c(
          "{.code method = \"twinning\"} can only split off 1/r of the data, where r is a whole number.",
          i = "Use {.arg prop} = 1/2, 2/3, 3/4, 4/5, 9/10, or another value of 1 - 1/r."
        ),
        call = NULL
      )
    }
    split_fun <- function(x, sz) {
      idx <- twinning::twin(x, r = r, format_data = FALSE, leaf_size = leaf_size)
      a <- rep.int(other, nrow(x))
      a[idx] <- small
      fix_sizes(a, sz)
    }
    return(within_strata(x_scaled, sizes, exact, split_fun, min_rows = 2 * r))
  }

  if (strategy == 2 && !is_power_of_two(k)) {
    cli::cli_abort(
      c(
        "Twinning strategy 2 needs {.arg v} to be a power of 2.",
        x = "{.arg v} is {k}.",
        i = "Use {.arg v} = 2, 4, 8, or 16, or use strategy 1 or 3."
      ),
      call = NULL
    )
  }
  fold_fun <- function(x, sz) {
    a <- twinning::multiplet(
      x,
      k = length(sz),
      strategy = strategy,
      format_data = FALSE,
      leaf_size = leaf_size
    )
    relabel_to_sizes(a, sz)
  }
  within_strata(x_scaled, sizes, exact, fold_fun, min_rows = 2 * k)
}

is_power_of_two <- function(k) {
  k >= 1 && bitwAnd(as.integer(k), as.integer(k) - 1L) == 0L
}

# rerandomize -----------------------------------------------------------------

# Morgan and Rubin (2012): draw stratified random splits and keep the first
# whose Mahalanobis imbalance is under a threshold. For more than two sets the
# statistic is the largest value over "one set versus the rest" comparisons.
# The threshold is the `p_accept` quantile of the statistic over pilot draws
# (at least 100, more for small `p_accept`, up to `max_draws`) made under the
# same constraints, so it accounts for exact strata, unequal
# set sizes, and the dependence between the comparisons.
method_rerandomize <- function(x_scaled, sizes, exact = NULL, group = NULL,
                               p_accept = 0.1, max_draws = 1000L) {
  if (!is.numeric(p_accept) || length(p_accept) != 1 || p_accept <= 0 || p_accept > 1) {
    cli::cli_abort("{.arg p_accept} must be a number above 0 and at most 1.", call = NULL)
  }
  if (!is.numeric(max_draws) || length(max_draws) != 1 || max_draws < 1) {
    cli::cli_abort("{.arg max_draws} must be a whole number of at least 1.", call = NULL)
  }
  k <- length(sizes)
  inv <- pseudo_inverse(stats::cov(x_scaled))
  if (inv$rank == 0) {
    return(stratified_random(sizes, exact))
  }
  imbalance <- function(a) max_mahalanobis(x_scaled, a, k, inv$inverse)

  n_pilot <- max(100L, min(ceiling(10 / p_accept), max_draws))
  pilot <- vapply(seq_len(n_pilot), function(i) imbalance(stratified_random(sizes, exact)), numeric(1))
  threshold <- stats::quantile(pilot, p_accept, names = FALSE, type = 1)

  best <- NULL
  best_val <- Inf
  for (d in seq_len(max_draws)) {
    a <- stratified_random(sizes, exact)
    val <- imbalance(a)
    if (val < best_val) {
      best <- a
      best_val <- val
    }
    if (val <= threshold) {
      return(a)
    }
  }
  cli::cli_warn(c(
    "No draw met the rerandomization threshold after {max_draws} draw{?s}.",
    i = "Using the best draw (imbalance {signif(best_val, 3)}, threshold {signif(threshold, 3)}).",
    i = "Raise {.arg p_accept} or {.arg max_draws} in {.arg options}."
  ))
  best
}

max_mahalanobis <- function(x, assign, k, s_inv) {
  n <- nrow(x)
  sums <- rowsum(x, assign, reorder = TRUE)
  total <- colSums(x)
  nk <- tabulate(assign, k)
  vals <- vapply(seq_len(k), function(j) {
    d <- sums[j, ] / nk[j] - (total - sums[j, ]) / (n - nk[j])
    nk[j] * (n - nk[j]) / n * drop(crossprod(d, s_inv %*% d))
  }, numeric(1))
  max(vals)
}

pseudo_inverse <- function(m) {
  s <- svd(m)
  tol <- max(dim(m)) * max(s$d) * .Machine$double.eps
  keep <- s$d > tol
  if (!any(keep)) {
    return(list(inverse = m * 0, rank = 0L))
  }
  inverse <- s$v[, keep, drop = FALSE] %*%
    (t(s$u[, keep, drop = FALSE]) / s$d[keep])
  list(inverse = inverse, rank = sum(keep))
}

# interaction -----------------------------------------------------------------

# Baseline: cut each numeric column into quantile bins, cross all bins, pool
# sparse cells, and stratify at random. Exact strata stay exact because the
# crossed cells are nested inside them.
method_interaction <- function(x_scaled, sizes, exact = NULL, group = NULL,
                               n_bins = 4L, pool = 0.1) {
  if (!is.numeric(n_bins) || length(n_bins) != 1 || n_bins < 2) {
    cli::cli_abort("{.arg n_bins} must be a whole number of at least 2.", call = NULL)
  }
  if (!is.numeric(pool) || length(pool) != 1 || pool < 0 || pool >= 1) {
    cli::cli_abort("{.arg pool} must be a number from 0 up to (not including) 1.", call = NULL)
  }
  bins <- lapply(seq_len(ncol(x_scaled)), function(j) bin_column(x_scaled[, j], n_bins))
  fine <- combine_levels(bins)
  fine <- pool_strata(fine, exact, min_size = pool * nrow(x_scaled))
  stratified_random(sizes, exact, fine)
}

# Quantile bins from ranks. Tied values share a rank, so they stay in one bin,
# and a heavily tied value gets its own bin instead of absorbing the others.
bin_column <- function(v, n_bins) {
  if (length(unique(v)) <= n_bins) {
    return(factor(v))
  }
  r <- rank(v, ties.method = "average")
  factor(ceiling(r * n_bins / length(v)))
}

pool_strata <- function(fine, exact, min_size) {
  prefix <- if (is.null(exact)) "" else paste0(as.integer(exact), "\r")
  key <- paste0(prefix, as.character(fine))
  tab <- table(key)
  small <- key %in% names(tab)[tab < min_size]
  key[small] <- paste0(prefix[pmin(length(prefix), which(small))], ".pooled")
  factor(key)
}
