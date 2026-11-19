# Balancing methods. See registry.R for the contract.

# anticlust -------------------------------------------------------------------

# The exchange step only swaps rows that share a category, so a stratified
# random start keeps the exact counts from allocate_strata(). Groups are
# handled by aggregation: anticlust's `must_link` needs fold sizes that groups
# can fill exactly and, for the k-plus objective, equal fold sizes, which
# real grouped data rarely allows.
method_anticlust <- function(x_scaled, sizes, exact = NULL, group = NULL,
                             objective = "kplus", standardize = TRUE, ...) {
  rlang::check_installed("anticlust", reason = "to use `method = \"anticlust\"`.")
  init <- stratified_random(sizes, exact)
  categories <- if (is.null(exact)) NULL else as.integer(exact)
  out <- anticlust::anticlustering(
    x_scaled,
    K = init,
    objective = objective,
    standardize = standardize,
    categories = categories,
    ...
  )
  as.integer(out)
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

  if (k == 2) {
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

  if (!strategy %in% 1:3) {
    cli::cli_abort("{.arg strategy} must be 1, 2, or 3.", call = NULL)
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
# statistic is the largest value over "one set versus the rest" comparisons,
# and the per-set threshold is raised so that the acceptance rate is about
# `p_accept` when the comparisons are treated as independent.
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
  k_eff <- if (k == 2) 1 else k
  threshold <- stats::qchisq(p_accept^(1 / k_eff), df = inv$rank)

  best <- NULL
  best_val <- Inf
  for (d in seq_len(max_draws)) {
    a <- stratified_random(sizes, exact)
    val <- max_mahalanobis(x_scaled, a, k, inv$inverse)
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
  fine <- interaction(bins, drop = TRUE)
  fine <- pool_strata(fine, exact, min_size = pool * nrow(x_scaled))
  stratified_random(sizes, exact, fine)
}

bin_column <- function(v, n_bins) {
  if (length(unique(v)) <= n_bins) {
    return(factor(v))
  }
  br <- unique(stats::quantile(v, probs = seq(0, 1, length.out = n_bins + 1), names = FALSE))
  cut(v, br, include.lowest = TRUE)
}

pool_strata <- function(fine, exact, min_size) {
  prefix <- if (is.null(exact)) "" else paste0(as.integer(exact), "\r")
  key <- paste0(prefix, as.character(fine))
  tab <- table(key)
  small <- key %in% names(tab)[tab < min_size]
  key[small] <- paste0(prefix[pmin(length(prefix), which(small))], ".pooled")
  factor(key)
}
