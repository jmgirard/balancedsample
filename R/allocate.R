# Helpers that turn target proportions into set sizes and that spread the rows
# of each stratum over the sets. Every method uses these, so the exact
# stratification guarantee lives in one place.

# Random permutation that is safe for vectors of length one.
shuffle <- function(x) {
  x[sample.int(length(x))]
}

# Integer set sizes that sum to `n` and follow `props` (largest remainder,
# random tie breaks).
sizes_from_props <- function(n, props) {
  raw <- n * props / sum(props)
  out <- floor(raw + 1e-9)
  left <- n - sum(out)
  if (left > 0) {
    frac <- round(raw - out, 9)
    ord <- order(-frac, stats::runif(length(frac)))
    pick <- ord[seq_len(left)]
    out[pick] <- out[pick] + 1
  }
  as.integer(out)
}

# Count matrix (strata x sets). Row sums are the stratum sizes and column sums
# are `sizes`. When the set sizes differ by at most one (v-fold CV) or there
# are two sets (initial split), every cell is the floor or the ceiling of its
# proportional share.
allocate_strata <- function(strata, sizes) {
  strata <- droplevels(as.factor(strata))
  n_lvl <- nlevels(strata)
  k <- length(sizes)
  m <- tabulate(as.integer(strata), n_lvl)
  n <- sum(m)
  if (n != sum(sizes)) {
    cli::cli_abort("Internal error: strata and set sizes do not match.", .internal = TRUE)
  }

  if (max(sizes) - min(sizes) <= 1) {
    # Cyclic labels over strata laid end to end. Any run of length m_j holds
    # each label floor(m_j / k) or ceiling(m_j / k) times.
    if (all(sizes == sizes[1])) {
      perm <- shuffle(seq_len(k))
    } else {
      big <- which(sizes == max(sizes))
      perm <- c(shuffle(big), shuffle(which(sizes != max(sizes))))
    }
    ord <- shuffle(seq_len(n_lvl))
    rows <- rep(ord, m[ord])
    labels <- rep_len(perm, n)
    counts <- unclass(table(
      factor(rows, levels = seq_len(n_lvl)),
      factor(labels, levels = seq_len(k))
    ))
    dimnames(counts) <- NULL
    return(counts)
  }

  if (k == 2) {
    raw <- m * sizes[1] / n
    c1 <- floor(raw + 1e-9)
    extra <- sizes[1] - sum(c1)
    if (extra > 0) {
      frac <- round(raw - c1, 9)
      ord <- order(-frac, stats::runif(n_lvl))
      pick <- ord[seq_len(extra)]
      c1[pick] <- c1[pick] + 1
    }
    return(cbind(c1, m - c1, deparse.level = 0))
  }

  # General case: sequential proportional allocation on remaining capacity.
  counts <- matrix(0L, n_lvl, k)
  cap <- sizes
  for (j in shuffle(seq_len(n_lvl))) {
    raw <- m[j] * cap / sum(cap)
    cnt <- pmin(floor(raw + 1e-9), cap)
    left <- m[j] - sum(cnt)
    if (left > 0) {
      frac <- round(raw - cnt, 9)
      frac[cnt >= cap] <- -Inf
      ord <- order(-frac, stats::runif(k))
      pick <- ord[seq_len(left)]
      cnt[pick] <- cnt[pick] + 1
    }
    counts[j, ] <- cnt
    cap <- cap - cnt
  }
  counts
}

# Random assignment with exact strata. `fine` gives optional sub-strata that
# are nested inside `strata`; they are balanced without breaking the exact
# counts of `strata`.
stratified_random <- function(sizes, strata = NULL, fine = NULL) {
  k <- length(sizes)
  if (is.null(strata)) {
    if (is.null(fine)) {
      return(shuffle(rep.int(seq_len(k), sizes)))
    }
    return(stratified_random(sizes, fine))
  }
  strata <- droplevels(as.factor(strata))
  counts <- allocate_strata(strata, sizes)
  lv <- as.integer(strata)
  out <- integer(length(lv))
  for (j in seq_len(nrow(counts))) {
    idx <- which(lv == j)
    if (is.null(fine)) {
      out[idx] <- shuffle(rep.int(seq_len(k), counts[j, ]))
    } else {
      out[idx] <- stratified_random(counts[j, ], fine[idx])
    }
  }
  out
}

# Run `fun(x, sizes)` inside each exact stratum, using the exact counts from
# allocate_strata(). Strata that are too small for the method get a random
# assignment.
within_strata <- function(x, sizes, exact, fun, min_rows = 1L) {
  if (is.null(exact)) {
    return(fun(x, sizes))
  }
  exact <- droplevels(as.factor(exact))
  counts <- allocate_strata(exact, sizes)
  lv <- as.integer(exact)
  out <- integer(nrow(x))
  for (j in seq_len(nrow(counts))) {
    idx <- which(lv == j)
    sz <- counts[j, ]
    if (length(idx) < min_rows || any(sz == 0)) {
      out[idx] <- shuffle(rep.int(seq_along(sz), sz))
    } else {
      out[idx] <- fun(x[idx, , drop = FALSE], sz)
    }
  }
  out
}

# Move random rows from sets that are too large to sets that are too small.
fix_sizes <- function(assign, sizes) {
  k <- length(sizes)
  repeat {
    diff <- tabulate(assign, k) - sizes
    if (all(diff == 0)) {
      return(as.integer(assign))
    }
    from <- which(diff > 0)[1]
    to <- which(diff < 0)[1]
    idx <- which(assign == from)
    assign[idx[sample.int(length(idx), 1)]] <- to
  }
}

# Relabel arbitrary set labels so that the largest generated sets map to the
# largest targets, then fix any size differences.
relabel_to_sizes <- function(assign, sizes) {
  assign <- as.integer(factor(assign))
  k <- length(sizes)
  have <- tabulate(assign, max(assign))
  from <- order(-have, stats::runif(length(have)))
  to <- order(-sizes, stats::runif(k))
  map <- integer(length(have))
  n_map <- min(length(from), k)
  map[from[seq_len(n_map)]] <- to[seq_len(n_map)]
  # Extra generated sets (if any) are folded into the smallest targets.
  if (length(from) > k) {
    map[from[-seq_len(k)]] <- to[k]
  }
  fix_sizes(map[assign], sizes)
}
