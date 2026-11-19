# Helpers that turn target proportions into set sizes and that spread the rows
# of each stratum over the sets. Every method uses these, so the exact
# stratification guarantee lives in one place.

# Random permutation that is safe for vectors of length one.
shuffle <- function(x) {
  x[sample.int(length(x))]
}

# Integer set sizes that sum to `n` and follow `props` (largest remainder,
# random tie breaks). When `n` is at least the number of sets, every set gets
# at least one unit, taken from the largest set.
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
  while (n >= length(out) && any(out == 0)) {
    big <- which.max(out)
    out[big] <- out[big] - 1
    out[which(out == 0)[1]] <- 1
  }
  as.integer(out)
}

# Count matrix (strata x sets). Row sums are the stratum sizes, column sums
# are `sizes`, and every cell is the floor or the ceiling of its proportional
# share `m_j * sizes_k / n`. Such a controlled rounding always exists for a
# two-way table (Cox, 1987). When the set sizes differ by at most one (v-fold
# CV), each cell is also kept to the floor or the ceiling of `m_j / k`, so the
# counts of a stratum differ by at most one over the folds; if both bounds
# can't hold at once, only the first is used.
allocate_strata <- function(strata, sizes) {
  strata <- droplevels(as.factor(strata))
  k <- length(sizes)
  m <- tabulate(as.integer(strata), nlevels(strata))
  n <- sum(m)
  if (n != sum(sizes)) {
    cli::cli_abort(
      "Internal error: strata and set sizes do not match.",
      .internal = TRUE
    )
  }

  share <- outer(m, sizes) / n
  lo <- floor(share + 1e-9)
  hi <- ceiling(share - 1e-9)
  if (max(sizes) - min(sizes) <= 1) {
    even <- matrix(m / k, length(m), k)
    counts <- round_shares(
      share,
      pmax(lo, floor(even + 1e-9)),
      pmin(hi, ceiling(even - 1e-9)),
      m,
      sizes
    )
    if (!is.null(counts)) {
      return(counts)
    }
  }
  counts <- round_shares(share, lo, hi, m, sizes)
  if (is.null(counts)) {
    cli::cli_abort(
      "Internal error: no controlled rounding found.",
      .internal = TRUE
    )
  }
  counts
}

# Integer matrix between `lo` and `hi` (which differ by at most one) with row
# sums `m` and column sums `sizes`, or NULL if there is none. Start from `lo`
# and hand out the remaining units one at a time. A unit goes to a random open
# cell, weighted by how far the share is above `lo`. When a stratum has no
# open cell left in a set with spare room, an augmenting path moves earlier
# units along to make room.
round_shares <- function(share, lo, hi, m, sizes) {
  need <- m - rowSums(lo)
  cap <- sizes - colSums(lo)
  if (any(need < 0) || any(cap < 0)) {
    return(NULL)
  }
  open <- hi > lo
  weight <- pmax(share - lo, 1e-6)
  up <- matrix(FALSE, nrow(lo), ncol(lo))

  for (j in shuffle(which(need > 0))) {
    for (t in seq_len(need[j])) {
      cand <- which(open[j, ] & !up[j, ] & cap > 0)
      if (length(cand) > 0) {
        to <- cand[sample.int(length(cand), 1, prob = weight[j, cand])]
        up[j, to] <- TRUE
        cap[to] <- cap[to] - 1
      } else {
        res <- augment_rounding(up, open, cap, j)
        if (is.null(res)) {
          return(NULL)
        }
        up <- res$up
        cap[res$end] <- cap[res$end] - 1
      }
    }
  }
  counts <- lo + up
  storage.mode(counts) <- "integer"
  dimnames(counts) <- NULL
  counts
}

# Breadth-first search over sets for a path that gives stratum `j` one more
# unit: `j` takes an open cell in a full set, a stratum that holds a unit in
# that set moves it to another of its open cells, and so on until a set with
# spare room is reached. Returns NULL if there is no such path.
augment_rounding <- function(up, open, cap, j) {
  k <- ncol(up)
  prev <- rep(NA_integer_, k)
  via <- rep(NA_integer_, k)
  start <- which(open[j, ] & !up[j, ])
  prev[start] <- 0L
  queue <- start
  end <- NA_integer_
  while (length(queue) > 0 && is.na(end)) {
    from <- queue[1]
    queue <- queue[-1]
    for (r in which(up[, from])) {
      nxt <- which(open[r, ] & !up[r, ] & is.na(prev))
      prev[nxt] <- from
      via[nxt] <- r
      queue <- c(queue, nxt)
      done <- nxt[cap[nxt] > 0]
      if (length(done) > 0) {
        end <- done[1]
        break
      }
    }
  }
  if (is.na(end)) {
    return(NULL)
  }
  col <- end
  while (prev[col] != 0L) {
    r <- via[col]
    up[r, prev[col]] <- FALSE
    up[r, col] <- TRUE
    col <- prev[col]
  }
  up[j, col] <- TRUE
  list(up = up, end = end)
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
# assignment. Without exact strata, all rows form one stratum.
within_strata <- function(x, sizes, exact, fun, min_rows = 1L) {
  if (is.null(exact)) {
    exact <- factor(rep.int(1L, nrow(x)))
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
