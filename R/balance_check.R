#' Check the balance of a split or of a set of resamples
#'
#' `balance_check()` compares the assessment set of each split with its
#' analysis set. For a three-way split, it compares the validation set and the
#' testing set each with the training set. It reports a standardized mean
#' difference (SMD) for each variable and the energy distance for all
#' variables together. It also reports how random sets of the same sizes
#' from these data would look, so you can tell balance from chance. It works
#' with any `rset` or `rsplit`, so you can compare balanced folds with
#' ordinary [rsample::vfold_cv()] folds.
#'
#' @param x An `rset` (for example from [balanced_vfold_cv()]), an `rsplit`
#'   (for example from [balanced_initial_split()]), or a three-way split (from
#'   [balanced_initial_validation_split()] or
#'   [rsample::initial_validation_split()]).
#' @param ... For `balance_check()`, <[`tidy-select`][tidyselect::language]>
#'   columns to check. If empty, the `balance` and `exact` columns stored in
#'   `x` are used. For `summary()`, not used and must be empty.
#' @param max_n The largest number of rows per set for the energy distance.
#'   Larger sets are subsampled at random to keep memory use low.
#' @param variance_ratio If `TRUE`, also report the variance ratio of each
#'   numeric variable.
#' @param chance The number of times the rows of each split are reassigned
#'   at random to sets of the same sizes, to show how unbalanced random sets
#'   would be. Use `0` to leave this out. See Details.
#'
#' @details
#' For a numeric variable, the SMD is the difference in means (assessment
#' minus analysis) divided by the pooled standard deviation,
#' `sqrt((var_assessment + var_analysis) / 2)`. For a categorical variable,
#' there is one SMD per level, from the proportions of that level. Values
#' under 0.1 in absolute size are often taken as good balance, but with
#' small sets or many variables random sets rarely meet that rule; see
#' below. If both sets
#' have zero variance but different means, the SMD is `Inf` or `-Inf`; the
#' plot shows these values at the edge of the panel.
#'
#' Stored `exact` columns with whole numbers are treated as categories, as
#' the split functions treat them, so they get one SMD per level and no
#' variance ratio. This holds whether you name them or not. Other
#' whole-number columns are numeric.
#'
#' With `variance_ratio = TRUE`, each numeric variable also gets the variance
#' of the assessment set divided by the variance of the analysis set. It is 1
#' when the spreads are equal, and values between 0.5 and 2 are often taken
#' as good balance. The SMD can be 0 while the spreads differ, and the
#' variance ratio shows which variable differs. A variance within rounding
#' error of zero counts as zero: if both are zero, the ratio is 1, and if one
#' is, it is 0 or `Inf`. With fewer than two values in a set, it is `NA`.
#'
#' Missing values are dropped variable by variable for the SMD and the
#' variance ratio. A variable with missing values also gets an SMD for the
#' share of its values that are missing, with `level` `"(missing)"`. In
#' `summary()`, this row counts as one more level of the variable. The
#' energy distance uses all rows. It encodes missing values as the split
#' functions do with `na = "include"`: a numeric variable gets the mean of
#' its observed values plus an indicator of which values are missing, and a
#' categorical variable gets a level for them. So with missing values, it compares the encoded
#' data, not only the observed values.
#'
#' The energy distance is the V-statistic
#' `2 E|X - Y| - E|X - X'| - E|Y - Y'|` on the standardized variables (one
#' indicator column per categorical level). It is 0 when the two sets have the
#' same distribution, and it also detects differences in spread and shape.
#'
#' Printing the result shows a short table. For one split, it has the SMD
#' of each variable and level. For up to 10 splits, it has one row per split,
#' as from `summary()`. For more splits, it has one row per variable, as from
#' `summary(by = "variable")`. Columns that don't fit the width of the
#' console are left out, and a note names them. Printing compares each
#' variable with chance, as `summary()` does; use `summary()` with
#' `threshold` for a fixed value. Use [tibble::as_tibble()] to see all rows.
#'
#' `summary()` first reduces each variable in each split to its largest
#' absolute SMD, over its levels and its `"(missing)"` row. So a variable
#' with many levels counts once, like a numeric variable. The largest
#' absolute SMD of a split shows the worst variable, but it tends to grow
#' with the number of variables: in random splits of 30 rows against 270,
#' it averaged 0.21 with 2 variables and 0.48 with 40. The mean across
#' variables stayed near 0.15 in such splits, so it is better for
#' comparing splits that check different numbers of variables. The rule of
#' thumb of 0.1 is hard to meet with small sets: in the same random splits,
#' one variable's absolute SMD was under 0.1 only about 40% of the time. An
#' `exact` column also can't do better than whole rows allow.
#'
#' So `balance_check()` also shows how random sets of the same sizes from
#' these data would look. For each split, it puts the rows of the analysis
#' and assessment sets back together, deals them out at random into two sets
#' of the same sizes, and measures each variable's largest absolute SMD, as
#' `summary()` does. It does this `chance` times. A random SMD has a
#' standard deviation of about `sqrt(1 / n_assessment + 1 / n_analysis)`, so
#' this reference grows as the sets get smaller. Splits with the same data
#' and sizes, such as the folds of [rsample::vfold_cv()], share one set of
#' draws. The draws use R's random number generator, so use [set.seed()] to
#' repeat them. If `x` was made with `group` and its data have the group
#' column, whole groups are dealt out instead, with the same number of
#' groups in each set as in the split.
#'
#' `summary()` divides the mean of the variables' largest absolute SMDs by
#' the same mean in the random sets. Random folds, such as those from
#' [rsample::vfold_cv()], give a ratio near 1, and well-balanced folds give
#' less. By default, it counts a variable as over when its largest absolute
#' SMD is above what 95% of the random sets stay under. This count shows
#' splits that are worse than chance; one in 20 variables is over in random
#' splits. The ratio and the count say how balanced the sets are, not how
#' much balancing will change your results. That depends mostly on how small
#' the sets are and, for a yes/no outcome, on how few events each set has.
#'
#' @return A tibble with class `balance_check`. It has the ID columns of `x`,
#'   and the columns `variable`, `level`, `statistic` (`"smd"`, `"energy"`,
#'   `"variance_ratio"`, `"chance_mean"`, or `"chance_q95"`), and `value`.
#'   Energy rows have `NA` in `variable` and `level`. Each variable in each
#'   split has a `"chance_mean"` row, the mean of its largest absolute SMD
#'   over the random sets (leaving out any that are infinite, which tiny
#'   sets can give), and a `"chance_q95"` row, the value that 95% of them
#'   stay under. These rows have `NA` in `level`, and come after the
#'   energy row of their split.
#'
#'   `summary()` with `by = "split"` returns a tibble with one row per split.
#'   It has the ID columns and these columns:
#'   * `max_abs_smd`: the largest absolute SMD in the split, with the
#'     `variable` and `level` it belongs to (the first one if several tie).
#'   * `mean_abs_smd`: the mean over the variables of their largest absolute
#'     SMD.
#'   * `n_over`: the number of variables whose largest absolute SMD is above
#'     their own `"chance_q95"`, or above `threshold` if you give one. Without
#'     chance rows (with `chance = 0`), `threshold` is 0.1.
#'   * `n_variables`: the number of variables with an SMD that isn't
#'     missing.
#'   * `energy`: the energy distance.
#'   * With variance ratios, `variance_ratio`, the ratio farthest from 1 on
#'     the log scale (so 0.25 is farther than 3), and
#'     `variance_ratio_variable`, the variable it belongs to.
#'   * With chance rows, `chance_mean_abs_smd`, the mean over the variables
#'     of their `"chance_mean"`, and `ratio_to_chance`, `mean_abs_smd`
#'     divided by it. Random sets give about 1, and balanced sets less.
#'
#'   If the split has no SMD that isn't missing, `max_abs_smd`,
#'   `mean_abs_smd`, `variable`, and `level` are `NA`. If it has no energy
#'   row, `energy` is `NA`.
#'
#'   With `by = "variable"`, it returns one row per variable, with
#'   `median_abs_smd` and `max_abs_smd` (the median and the largest of the
#'   variable's largest absolute SMD in each split), the `level` and the ID
#'   columns of the split with the largest, `n_over` (the number of splits
#'   where it is over, as above), and `n_splits` (the number of splits
#'   where the variable has an SMD that isn't missing). With variance
#'   ratios, it also has `variance_ratio`, the ratio farthest from 1 over the
#'   splits. With chance rows, it also has `chance_q95`, the median over the
#'   splits of the variable's `"chance_q95"`.
#'
#'   Each split must have its own ID, so no ID may have more than one energy
#'   row. Only the ID columns that `balance_check()` made are used, so
#'   columns you add are ignored. If you rename an ID column, the columns
#'   whose names start with `id` are used instead. If you drop one, splits
#'   that differ only in it would merge, so `summary()` gives an error and
#'   printing shows the rows.
#'
#' @examples
#' set.seed(1)
#' folds <- balanced_vfold_cv(
#'   sim_patients,
#'   v = 5,
#'   balance = c(age, income, diagnosis)
#' )
#' balance_check(folds)
#' summary(balance_check(folds))
#' summary(balance_check(folds), by = "variable")
#' summary(balance_check(folds, variance_ratio = TRUE))
#'
#' # Compare with ordinary folds
#' random_folds <- rsample::vfold_cv(sim_patients, v = 5)
#' summary(balance_check(random_folds, age, income, diagnosis))
#' @export
balance_check <- function(
  x,
  ...,
  max_n = 2000,
  variance_ratio = FALSE,
  chance = 100
) {
  UseMethod("balance_check")
}

#' @export
balance_check.default <- function(
  x,
  ...,
  max_n = 2000,
  variance_ratio = FALSE,
  chance = 100
) {
  cli::cli_abort(
    "{.arg x} must be an {.cls rset}, an {.cls rsplit}, or a {.cls three_way_split}, not {.obj_type_friendly {x}}."
  )
}

#' @rdname balance_check
#' @export
balance_check.rset <- function(
  x,
  ...,
  max_n = 2000,
  variance_ratio = FALSE,
  chance = 100
) {
  check_whole(max_n, min = 2)
  check_flag(variance_ratio)
  check_whole(chance, min = 0)
  if (nrow(x) == 0) {
    cli::cli_abort("{.arg x} has no splits.")
  }
  # The columns are selected in the first split. The splits of a
  # manual_rset() can have different data, so check that the others have them.
  cols <- check_columns(x$splits[[1]]$data, x, ...)
  for (i in seq_len(nrow(x))) {
    lacking <- setdiff(cols, names(x$splits[[i]]$data))
    if (length(lacking) > 0) {
      cli::cli_abort(
        c(
          "Every split of {.arg x} must have the columns to check.",
          x = "Split {i} has no {.field {lacking}}."
        )
      )
    }
  }
  id_cols <- grep("^id", names(x), value = TRUE)
  ids <- tibble::as_tibble(as.data.frame(x)[id_cols])
  cache <- new.env(parent = emptyenv())

  res <- lapply(seq_len(nrow(x)), function(i) {
    # Splits of a manual_rset() can have different data.
    split <- x$splits[[i]]
    data <- exact_as_factors(split$data, x, cols)
    out <- split_balance(
      split,
      cols,
      max_n,
      data,
      variance_ratio,
      chance,
      group_units(split$data, x),
      cache
    )
    id_rows <- ids[rep(i, nrow(out)), , drop = FALSE]
    cbind(id_rows, out)
  })
  new_balance_check(do.call(rbind, res), id_cols)
}

#' @rdname balance_check
#' @export
balance_check.rsplit <- function(
  x,
  ...,
  max_n = 2000,
  variance_ratio = FALSE,
  chance = 100
) {
  check_whole(max_n, min = 2)
  check_flag(variance_ratio)
  check_whole(chance, min = 0)
  cols <- check_columns(x$data, x, ...)
  out <- split_balance(
    x,
    cols,
    max_n,
    exact_as_factors(x$data, x, cols),
    variance_ratio,
    chance,
    group_units(x$data, x)
  )
  new_balance_check(cbind(tibble::tibble(id = rep("Split", nrow(out))), out))
}

#' @rdname balance_check
#' @export
balance_check.three_way_split <- function(
  x,
  ...,
  max_n = 2000,
  variance_ratio = FALSE,
  chance = 100
) {
  check_whole(max_n, min = 2)
  check_flag(variance_ratio)
  check_whole(chance, min = 0)
  cols <- check_columns(x$data, x, ...)
  data <- exact_as_factors(x$data, x, cols)
  test_id <- setdiff(seq_len(nrow(x$data)), c(x$train_id, x$val_id))
  units <- group_units(x$data, x)
  cache <- new.env(parent = emptyenv())
  res <- lapply(
    list(Validation = x$val_id, Testing = test_id),
    function(out_id) {
      split <- rsample::make_splits(
        list(analysis = x$train_id, assessment = out_id),
        data = x$data
      )
      split_balance(
        split,
        cols,
        max_n,
        data,
        variance_ratio,
        chance,
        units,
        cache
      )
    }
  )
  ids <- rep(names(res), vapply(res, nrow, integer(1)))
  new_balance_check(cbind(tibble::tibble(id = ids), do.call(rbind, res)))
}

check_columns <- function(data, x, ..., call = rlang::caller_env()) {
  pos <- tidyselect::eval_select(
    rlang::expr(c(!!!rlang::enquos(...))),
    data,
    allow_rename = FALSE,
    error_call = call
  )
  cols <- names(pos)
  if (length(cols) == 0) {
    stored <- stored_args(x)
    cols <- unique(c(stored$balance, stored$exact))
  }
  if (length(cols) == 0) {
    cli::cli_abort(
      c(
        "Select the columns to check.",
        i = "For example, {.code balance_check(folds, age, income)}."
      ),
      call = call
    )
  }
  cols
}

# Three-way splits keep their arguments in `val_att`.
stored_args <- function(x) {
  attr(x, "val_att") %||% attributes(x)
}

# The split functions treat whole-number and logical `exact` columns as
# categories, so the check does too, with one SMD per level. The energy
# distance then gives missing values a level, as the split does, instead of
# a fill and an indicator.
exact_as_factors <- function(data, x, cols) {
  for (nm in intersect(cols, stored_args(x)$exact)) {
    if (is.numeric(data[[nm]]) || is.logical(data[[nm]])) {
      data[[nm]] <- factor(data[[nm]])
    }
  }
  data
}

# The group of each row, if `x` was made with `group` and the data have the
# column, so that the chance reference reassigns whole groups.
group_units <- function(data, x) {
  group <- unname(stored_args(x)$group)
  if (length(group) == 1 && is.character(group) && group %in% names(data)) {
    data[[group]]
  }
}

split_balance <- function(
  split,
  cols,
  max_n,
  data = split$data,
  variance_ratio = FALSE,
  chance = 0,
  units = NULL,
  cache = NULL
) {
  an <- split$in_id
  as <- rsample::complement(split)
  measured <- lapply(data[cols], smd_columns)

  smd <- Map(
    function(m, nm) variable_balance(m, nm, an, as, variance_ratio),
    measured,
    cols
  )

  # The energy distance uses all rows, encoded as the split functions
  # encode them, so that missing values count too.
  en <- NA_real_
  if (length(as) > 0 && length(an) > 0) {
    xs <- build_balance_matrix(data[cols])
    en <- energy_distance(
      xs[as, , drop = FALSE],
      xs[an, , drop = FALSE],
      max_n
    )
  }
  energy <- tibble::tibble(
    variable = NA_character_,
    level = NA_character_,
    statistic = "energy",
    value = en
  )
  out <- do.call(rbind, c(unname(smd), list(energy)))
  if (chance > 0) {
    out <- rbind(
      out,
      chance_balance(measured, cols, an, as, chance, units, cache)
    )
  }
  out
}

# The values that the SMDs of one variable are measured on: one 0/1 column
# per level of a categorical variable, or the numeric values, and a 0/1
# column of which values are missing if any are.
smd_columns <- function(v) {
  if (is.logical(v)) {
    v <- factor(v, levels = c(FALSE, TRUE))
  }
  if (is.character(v)) {
    v <- factor(v)
  }
  numeric <- NULL
  if (is.factor(v)) {
    level <- levels(droplevels(v))
    values <- lapply(level, function(l) as.numeric(v == l))
    binary <- rep(TRUE, length(level))
  } else {
    numeric <- as.numeric(as_balance_numeric(v))
    level <- NA_character_
    values <- list(numeric)
    binary <- FALSE
  }
  miss <- is.na(v)
  if (any(miss)) {
    level <- c(level, "(missing)")
    values <- c(values, list(miss * 1))
    binary <- c(binary, TRUE)
  }
  list(level = level, values = values, binary = binary, numeric = numeric)
}

# The SMDs of one variable, from smd_columns(), one per level and one for
# the share missing.
column_smds <- function(m, an, as) {
  vapply(
    seq_along(m$values),
    function(j) {
      smd_value(m$values[[j]][as], m$values[[j]][an], binary = m$binary[j])
    },
    numeric(1)
  )
}

# SMDs (and variance ratios) of one variable. Missing values are dropped,
# and the share missing gets its own row.
variable_balance <- function(m, nm, an, as, variance_ratio) {
  out <- tibble::tibble(
    variable = nm,
    level = m$level,
    statistic = "smd",
    value = column_smds(m, an, as)
  )
  if (variance_ratio && !is.null(m$numeric)) {
    v <- m$numeric
    vr <- tibble::tibble(
      variable = nm,
      level = NA_character_,
      statistic = "variance_ratio",
      value = variance_ratio_value(v[as], v[an])
    )
    out <- rbind(out[1, ], vr, out[-1, ])
  }
  out
}

# How unbalanced random sets of the same sizes would be. The rows of both
# sets are reassigned at random to sets of the same sizes, `chance` times,
# and each time each variable is reduced to its largest absolute SMD, as in
# summary(). With `units`, whole groups are reassigned instead, with the
# same number of groups in each set as in the split. Splits with the same
# data, rows, and sizes share one set of draws through `cache`.
chance_balance <- function(measured, cols, an, as, chance, units, cache) {
  rows <- sort(c(an, as))
  n_as <- length(as)
  if (!is.null(units)) {
    code <- match(units[rows], unique(units[rows]))
    n_units <- max(c(0L, code))
    n_as_units <- length(unique(units[as]))
  }
  key <- list(
    measured = measured,
    rows = rows,
    n_as = n_as,
    units = if (!is.null(units)) list(code, n_as_units)
  )
  if (!is.null(cache)) {
    for (entry in cache$entries) {
      if (identical(entry$key, key)) {
        return(entry$out)
      }
    }
  }

  worst <- function(m, an, as) {
    smd <- abs(column_smds(m, an, as))
    if (all(is.na(smd))) NA_real_ else max(smd, na.rm = TRUE)
  }
  draws <- vapply(
    seq_len(chance),
    function(r) {
      if (is.null(units)) {
        new_as <- seq_len(length(rows)) %in% sample.int(length(rows), n_as)
      } else {
        new_as <- code %in% sample.int(n_units, n_as_units)
      }
      vapply(
        measured,
        worst,
        numeric(1),
        an = rows[!new_as],
        as = rows[new_as]
      )
    },
    numeric(length(measured))
  )
  draws <- matrix(draws, nrow = length(measured))
  stat <- function(f) {
    apply(draws, 1, function(d) {
      d <- d[!is.na(d)]
      if (length(d) > 0) f(d) else NA_real_
    })
  }
  # In tiny sets, a draw can separate a level completely (an SMD of Inf).
  # Such draws are left out of the mean, so that one of them doesn't make
  # the whole reference Inf.
  finite_mean <- function(d) {
    d <- d[is.finite(d)]
    if (length(d) > 0) mean(d) else Inf
  }
  q95 <- function(d) stats::quantile(d, 0.95, names = FALSE)
  out <- tibble::tibble(
    variable = rep(cols, each = 2),
    level = NA_character_,
    statistic = rep(c("chance_mean", "chance_q95"), length(cols)),
    value = as.vector(rbind(stat(finite_mean), stat(q95)))
  )
  if (!is.null(cache)) {
    cache$entries <- c(cache$entries, list(list(key = key, out = out)))
  }
  out
}

smd_value <- function(a, b, binary = FALSE) {
  a <- a[!is.na(a)]
  b <- b[!is.na(b)]
  if (length(a) == 0 || length(b) == 0) {
    return(NA_real_)
  }
  if (binary) {
    pa <- mean(a)
    pb <- mean(b)
    diff <- pa - pb
    den <- sqrt((pa * (1 - pa) + pb * (1 - pb)) / 2)
    tol <- near_zero(1)
  } else {
    # Each variance is measured within its own set, before the shift below.
    den <- sqrt((set_variance(a) + set_variance(b)) / 2)
    # Measure from an observed value, so that a large origin (such as a
    # date-time in seconds) doesn't swamp small differences.
    ref <- c(a, b)[1]
    a <- a - ref
    b <- b - ref
    diff <- mean(a) - mean(b)
    tol <- near_zero(max(abs(c(a, b))))
  }
  if (den == 0) {
    return(if (abs(diff) <= tol) 0 else sign(diff) * Inf)
  }
  out <- diff / den
  if (abs(out) < 1e-12) 0 else out
}

# Variance of one set, or 0 if it is within rounding error of zero. Each set
# is measured from its own first value, so a gap between the sets doesn't
# hide the spread within them.
set_variance <- function(a) {
  if (length(a) < 2) {
    return(0)
  }
  a <- a - a[1]
  v <- stats::var(a)
  if (v <= near_zero(max(abs(a)))^2) 0 else v
}

# Variance of `a` over the variance of `b`. A variance within rounding error
# of zero counts as zero: two zeros give 1, and a zero over a variance above
# zero gives 0 (or Inf the other way round).
variance_ratio_value <- function(a, b) {
  a <- a[!is.na(a)]
  b <- b[!is.na(b)]
  if (length(a) < 2 || length(b) < 2) {
    return(NA_real_)
  }
  va <- set_variance(a)
  vb <- set_variance(b)
  if (va == 0 && vb == 0) {
    return(1)
  }
  if (vb == 0) {
    return(Inf)
  }
  if (va == 0) {
    return(0)
  }
  va / vb
}

energy_distance <- function(a, b, max_n = 2000) {
  if (ncol(a) == 0) {
    return(0)
  }
  if (nrow(a) > max_n) {
    a <- a[sample.int(nrow(a), max_n), , drop = FALSE]
  }
  if (nrow(b) > max_n) {
    b <- b[sample.int(nrow(b), max_n), , drop = FALSE]
  }
  2 * mean_dist(a, b) - mean_dist(a, a) - mean_dist(b, b)
}

mean_dist <- function(a, b) {
  d2 <- outer(rowSums(a^2), rowSums(b^2), "+") - 2 * tcrossprod(a, b)
  mean(sqrt(pmax(d2, 0)))
}

# `id_cols` records the ID columns, so that summary() can tell them from
# columns added later.
new_balance_check <- function(x, id_cols = "id") {
  x <- tibble::as_tibble(x)
  attr(x, "id_cols") <- id_cols
  class(x) <- c("balance_check", class(x))
  x
}


#' @export
print.balance_check <- function(x, ...) {
  s <- tryCatch(balance_splits(x), rlang_error = function(e) NULL)
  if (is.null(s) || (nrow(x) > 0 && !any(s$x$statistic == "smd"))) {
    # For example, a subset without some of the columns, or with only the
    # energy rows.
    cat("# Balance check\n")
    print(unclass_balance(x), ...)
    return(invisible(x))
  }
  # With chance rows, each variable is compared with its own chance
  # reference, and otherwise with 0.1.
  threshold <- if (uses_chance(s$x, NULL)) NULL else 0.1
  by_split <- summary_by_split(s, threshold)
  n_split <- nrow(by_split)
  vars <- s$x$variable[s$x$statistic == "smd"]
  n_var <- length(unique(vars[!is.na(vars)]))
  cat_header(c(
    paste0("Balance check: ", n_split, " split", if (n_split != 1) "s"),
    paste0(n_var, " variable", if (n_var != 1) "s")
  ))
  if (n_split == 0) {
    return(invisible(x))
  }

  en <- by_split$energy
  ratio <- if ("ratio_to_chance" %in% names(by_split)) by_split$ratio_to_chance
  rule <- if (is.null(threshold)) "above chance (95%)" else "> 0.1"
  if (n_split == 1) {
    over <- paste0(
      "|SMD| ",
      rule,
      " in ",
      by_split$n_over,
      " of ",
      by_split$n_variables,
      " variable",
      if (by_split$n_variables != 1) "s"
    )
    ratio <- if (!is.null(ratio)) paste("ratio to chance", format_num(ratio))
    energy <- paste("energy distance", format_num(en))
  } else {
    n_over <- sum(by_split$n_over > 0)
    over <- paste0(
      n_over,
      " of ",
      n_split,
      " splits",
      if (n_over == 1) " has" else " have",
      " a variable with |SMD| ",
      rule
    )
    if (!is.null(ratio)) {
      ratio <- paste(
        "mean ratio to chance",
        format_num(mean(ratio, na.rm = TRUE))
      )
    }
    energy <- paste("mean energy distance", format_num(mean(en, na.rm = TRUE)))
  }
  cat_header(c(over, ratio, if (any(!is.na(en))) energy))
  cat("\n")

  if (n_split == 1) {
    hidden <- cat_table(detail_table(s$x, threshold))
    note <- "tibble::as_tibble() gives all {nrow(x)} rows."
  } else if (n_split <= 10) {
    hidden <- cat_table(split_table(by_split, s$id_cols, threshold))
    note <- paste(
      "summary() gives this table as a tibble, and tibble::as_tibble()",
      "gives all {nrow(x)} rows."
    )
  } else {
    by_var <- summary_by_variable(s, threshold)
    hidden <- cat_table(variable_table(by_var, s$id_cols, threshold))
    note <- paste(
      'summary(by = "variable") gives this table as a tibble, summary()',
      "gives one row per split, and tibble::as_tibble() gives all",
      "{nrow(x)} rows."
    )
  }
  note <- gsub("{nrow(x)}", nrow(x), note, fixed = TRUE)
  if (length(hidden) > 0) {
    note <- c(
      paste0(
        "Not shown for lack of width: ",
        paste(hidden, collapse = ", "),
        "."
      ),
      note
    )
  }
  cat(
    "\n",
    paste0(strwrap(note, getOption("width") - 2, prefix = "# "), "\n"),
    sep = ""
  )
  invisible(x)
}

# The name of the column that counts the variables over the cut-off.
over_name <- function(threshold) {
  if (is.null(threshold)) "over chance" else paste("over", threshold)
}

# The signed SMD of each variable and level of one split, with the chance
# reference of each variable on its first row.
detail_table <- function(x, threshold) {
  smd <- x$statistic == "smd"
  out <- list(
    variable = x$variable[smd],
    level = ifelse(is.na(x$level[smd]), "", x$level[smd]),
    SMD = format_smd(x$value[smd], threshold)
  )
  align <- c("left", "left", "decimal")
  first <- !duplicated(x$variable[smd])
  q95 <- which(x$statistic == "chance_q95")
  if (length(q95) > 0) {
    at <- match(x$variable[smd], x$variable[q95])
    at[!first] <- NA
    out$`chance 95%` <- ifelse(is.na(at), "", format_num(x$value[q95][at]))
    align <- c(align, "decimal")
  }
  vr <- which(x$statistic == "variance_ratio")
  if (length(vr) > 0) {
    at <- match(x$variable[smd], x$variable[vr])
    at[!is.na(x$level[smd])] <- NA
    out$`variance ratio` <- ifelse(is.na(at), "", format_num(x$value[vr][at]))
    align <- c(align, "decimal")
  }
  list(columns = out, align = align)
}

# One row per split, from summary().
split_table <- function(s, id_cols, threshold) {
  ids <- lapply(s[id_cols], format_id)
  out <- c(
    ids,
    list(
      `max |SMD|` = format_smd(s$max_abs_smd, threshold),
      variable = variable_label(s$variable, s$level),
      `mean |SMD|` = format_smd(s$mean_abs_smd, threshold)
    )
  )
  align <- c(rep("left", length(ids)), "decimal", "left", "decimal")
  if ("ratio_to_chance" %in% names(s)) {
    out$`vs chance` <- format_num(s$ratio_to_chance)
    align <- c(align, "decimal")
  }
  out$over <- paste0(s$n_over, "/", s$n_variables)
  out$energy <- format_num(s$energy)
  names(out)[names(out) == "over"] <- over_name(threshold)
  align <- c(align, "right", "decimal")
  if ("variance_ratio" %in% names(s)) {
    out$`variance ratio` <- format_num(s$variance_ratio)
    out$`ratio variable` <- ifelse(
      is.na(s$variance_ratio_variable),
      "",
      s$variance_ratio_variable
    )
    align <- c(align, "decimal", "left")
  }
  # The ratio and its variable are shown or dropped together.
  group <- seq_along(out)
  group[names(out) == "ratio variable"] <- group[
    names(out) == "ratio variable"
  ] -
    1L
  list(columns = out, align = align, group = group)
}

# One row per variable, from summary(by = "variable").
variable_table <- function(s, id_cols, threshold) {
  ids <- lapply(s[id_cols], format_id)
  out <- list(
    variable = s$variable,
    `median |SMD|` = format_smd(s$median_abs_smd, threshold),
    `max |SMD|` = format_smd(s$max_abs_smd, threshold),
    level = ifelse(is.na(s$level), "", s$level),
    `in split` = do.call(paste, c(unname(ids), sep = " / "))
  )
  align <- c("left", "decimal", "decimal", "left", "left")
  if ("chance_q95" %in% names(s)) {
    out$`chance 95%` <- format_num(s$chance_q95)
    align <- c(align, "decimal")
  }
  out$over <- paste0(s$n_over, "/", s$n_splits)
  names(out)[names(out) == "over"] <- over_name(threshold)
  align <- c(align, "right")
  if ("variance_ratio" %in% names(s)) {
    out$`variance ratio` <- format_num(s$variance_ratio)
    align <- c(align, "decimal")
  }
  list(columns = out, align = align)
}

format_id <- function(v) {
  ifelse(is.na(v), "NA", as.character(v))
}

variable_label <- function(variable, level) {
  out <- ifelse(is.na(level), variable, paste0(variable, ": ", level))
  ifelse(is.na(variable), "", out)
}

# Three significant digits, element by element.
format_num <- function(v) {
  vapply(
    v,
    function(z) if (is.na(z)) "NA" else format(signif(z, 3)),
    character(1),
    USE.NAMES = FALSE
  )
}

# Whether `a` is above the threshold by more than rounding error, so that an
# SMD that is 0.1 in decimal arithmetic but 0.1 + 1e-17 in floating point
# isn't counted.
above <- function(a, threshold) {
  a - threshold > sqrt(.Machine$double.eps)
}

# Like format_num(), with more digits where rounding would put a value on
# the other side of the threshold, or on it, so that the shown values agree
# with the counts. A value within rounding error of the threshold shows as
# the threshold.
format_smd <- function(v, threshold) {
  # Compared with a cut-off of each variable's own, the values are shown
  # plainly.
  if (is.null(threshold)) {
    return(format_num(v))
  }
  vapply(
    v,
    function(z) {
      if (!is.finite(z)) {
        return(format(z))
      }
      over <- above(abs(z), threshold)
      near <- !over && !above(threshold, abs(z))
      d <- 3
      shown <- signif(abs(z), d)
      while (
        d < 15 &&
          ((shown > threshold) != over ||
            (shown == threshold && !near))
      ) {
        d <- d + 1
        shown <- signif(abs(z), d)
      }
      format(signif(z, d), digits = max(7, d))
    },
    character(1),
    USE.NAMES = FALSE
  )
}

# Prints columns of text, each aligned to the left, to the right, or on its
# decimal points, under its name. Columns that don't fit the width are
# dropped from the right, a group at a time, and their names returned.
cat_table <- function(table) {
  width <- function(text) nchar(text, type = "width")
  pad <- function(text, right) {
    gap <- strrep(" ", max(c(0, width(text))) - width(text))
    if (right) paste0(gap, text) else paste0(text, gap)
  }
  padded <- Map(
    function(name, text, align) {
      if (align == "decimal") {
        dot <- regexpr(".", text, fixed = TRUE)
        dot[dot < 0] <- width(text)[dot < 0] + 1L
        text <- paste0(
          pad(substr(text, 1, dot - 1), right = TRUE),
          pad(substring(text, dot), right = FALSE)
        )
      }
      pad(c(name, text), right = align != "left")
    },
    names(table$columns),
    table$columns,
    table$align
  )
  group <- table$group %||% seq_along(padded)
  widths <- vapply(padded, function(p) width(p[1]), numeric(1))
  keep <- rep(TRUE, length(padded))
  while (
    sum(widths[keep]) + 2 * (sum(keep) - 1) > getOption("width") &&
      length(unique(group[keep])) > 1
  ) {
    keep[group == max(group[keep])] <- FALSE
  }
  lines <- do.call(paste, c(unname(padded[keep]), sep = "  "))
  cat(paste0(sub(" +$", "", lines), "\n"), sep = "")
  invisible(names(table$columns)[!keep])
}

#' @rdname balance_check
#' @param object A `balance_check` object.
#' @param threshold `NULL` (the default) to count a variable in `n_over`
#'   when its largest absolute SMD is above its chance reference
#'   (`"chance_q95"`), or 0.1 if `object` has none. Or a fixed absolute SMD
#'   to count above, such as 0.1. A value within rounding error of the
#'   cut-off (1.5e-8) counts as equal to it, so it isn't counted.
#' @param by `"split"` for one row per split, or `"variable"` for one row per
#'   variable across the splits.
#' @export
summary.balance_check <- function(
  object,
  ...,
  threshold = NULL,
  by = c("split", "variable")
) {
  rlang::check_dots_empty()
  if (
    !is.null(threshold) &&
      (!is_number(threshold) || !is.finite(threshold) || threshold < 0)
  ) {
    cli::cli_abort(
      "{.arg threshold} must be {.code NULL} or a number of at least 0."
    )
  }
  by <- rlang::arg_match(by)
  s <- balance_splits(object)
  if (by == "split") {
    summary_by_split(s, threshold)
  } else {
    summary_by_variable(s, threshold)
  }
}

# Checks that `object` can be summarized, and finds the rows of each split.
balance_splits <- function(object, call = rlang::caller_env()) {
  x <- unclass_balance(object)
  stat_cols <- c("variable", "level", "statistic", "value")
  # Use the ID columns balance_check() recorded, so that added columns are
  # ignored. If the record is missing or an ID column was renamed or
  # dropped, take the columns whose names start with "id", as rsample does.
  recorded <- attr(object, "id_cols")
  id_cols <- recorded
  if (is.null(id_cols) || !all(id_cols %in% names(x))) {
    id_cols <- grep("^id", names(x), value = TRUE)
  }
  # With an ID column dropped, splits that differ only in it would merge.
  if (length(id_cols) > 0 && length(id_cols) < length(recorded)) {
    lost <- setdiff(recorded, names(x))
    cli::cli_abort(
      c(
        "{.arg object} must keep its ID columns.",
        x = "It has no {.field {lost}}."
      ),
      call = call
    )
  }
  if (!all(stat_cols %in% names(x)) || length(id_cols) == 0) {
    cli::cli_abort(
      c(
        "{.arg object} must have ID columns and the columns {.code {stat_cols}}.",
        i = "Summarize the output of {.fn balance_check}."
      ),
      call = call
    )
  }
  stats <- c("smd", "energy", "variance_ratio", "chance_mean", "chance_q95")
  if (!all(x$statistic %in% stats)) {
    cli::cli_abort(
      "{.code statistic} must be {.or {.val {stats}}} in every row of {.arg object}.",
      call = call
    )
  }
  # Integer codes keep `NA` apart from "NA" and can't collide when pasted.
  codes <- lapply(x[id_cols], function(v) match(v, unique(v)))
  key <- do.call(paste, c(unname(codes), sep = "."))
  rows <- unname(split(seq_len(nrow(x)), factor(key, levels = unique(key))))
  n_energy <- vapply(rows, function(i) sum(x$statistic[i] == "energy"), 1L)
  if (any(n_energy > 1)) {
    cli::cli_abort(
      c(
        "Each split in {.arg object} must have its own ID.",
        x = "Some IDs have more than one energy row."
      ),
      call = call
    )
  }
  list(x = x, id_cols = id_cols, rows = rows)
}

# Among rows `i`, the row of the largest absolute SMD of each variable, in
# the order the variables first appear. A tie keeps the first row.
worst_by_variable <- function(x, i) {
  i <- i[x$statistic[i] == "smd" & !is.na(x$value[i])]
  by_var <- split(i, factor(x$variable[i], levels = unique(x$variable[i])))
  vapply(by_var, function(j) j[which.max(abs(x$value[j]))], integer(1))
}

# Among rows `i`, the row of the variance ratio farthest from 1 on the log
# scale (so 0.25 is farther than 3).
farthest_ratio <- function(x, i) {
  i <- i[x$statistic[i] == "variance_ratio" & !is.na(x$value[i])]
  if (length(i) == 0) {
    return(NA_integer_)
  }
  i[which.max(abs(log(x$value[i])))]
}

# Whether a variable counts as over compares with its chance reference:
# with no `threshold`, if `x` has one, and with 0.1 otherwise.
uses_chance <- function(x, threshold) {
  is.null(threshold) && any(x$statistic == "chance_q95")
}

# Among rows `i` of one split, the value of `statistic` for each of `vars`.
chance_value <- function(x, i, vars, statistic) {
  j <- i[x$statistic[i] == statistic]
  x$value[j][match(vars, x$variable[j])]
}

# The cut-off of each variable in `worst`, a list with the rows of the
# largest absolute SMD of each variable in each split.
over_cutoffs <- function(s, worst, threshold) {
  x <- s$x
  if (!uses_chance(x, threshold)) {
    return(lapply(worst, function(w) rep(threshold %||% 0.1, length(w))))
  }
  Map(
    function(i, w) chance_value(x, i, x$variable[w], "chance_q95"),
    s$rows,
    worst
  )
}

summary_by_split <- function(s, threshold) {
  x <- s$x
  worst <- lapply(s$rows, worst_by_variable, x = x)
  cutoffs <- over_cutoffs(s, worst, threshold)
  top <- vapply(
    worst,
    function(w) {
      w <- sort(w)
      if (length(w) > 0) w[which.max(abs(x$value[w]))] else NA_integer_
    },
    integer(1)
  )
  abs_smd <- lapply(worst, function(w) abs(x$value[w]))
  energy <- vapply(
    s$rows,
    function(i) {
      en <- x$value[i][x$statistic[i] == "energy"]
      if (length(en) == 1) en else NA_real_
    },
    numeric(1)
  )
  first <- vapply(s$rows, `[`, integer(1), 1)
  out <- tibble::as_tibble(x[first, s$id_cols, drop = FALSE])
  out$max_abs_smd <- abs(x$value[top])
  out$variable <- x$variable[top]
  out$level <- x$level[top]
  out$mean_abs_smd <- vapply(
    abs_smd,
    function(a) if (length(a) > 0) mean(a) else NA_real_,
    numeric(1)
  )
  out$n_over <- vapply(
    seq_along(abs_smd),
    function(k) sum(above(abs_smd[[k]], cutoffs[[k]]), na.rm = TRUE),
    integer(1)
  )
  out$n_variables <- unname(lengths(abs_smd))
  out$energy <- energy
  if (any(x$statistic == "variance_ratio")) {
    vr <- vapply(s$rows, farthest_ratio, integer(1), x = x)
    out$variance_ratio <- x$value[vr]
    out$variance_ratio_variable <- x$variable[vr]
  }
  if (any(x$statistic == "chance_mean")) {
    out$chance_mean_abs_smd <- unname(vapply(
      seq_along(worst),
      function(k) {
        w <- worst[[k]]
        if (length(w) == 0) {
          return(NA_real_)
        }
        mean(chance_value(x, s$rows[[k]], x$variable[w], "chance_mean"))
      },
      numeric(1)
    ))
    out$ratio_to_chance <- out$mean_abs_smd / out$chance_mean_abs_smd
  }
  out
}

summary_by_variable <- function(s, threshold) {
  x <- s$x
  worst <- lapply(s$rows, worst_by_variable, x = x)
  rows <- as.integer(unlist(worst, use.names = FALSE))
  cutoffs <- as.numeric(unlist(over_cutoffs(s, worst, threshold)))
  split_of <- rep(seq_along(worst), lengths(worst))
  smd <- x$statistic == "smd" & !is.na(x$variable)
  vars <- unique(x$variable[smd])
  by_var <- unname(split(
    seq_along(rows),
    factor(x$variable[rows], levels = vars)
  ))
  top <- vapply(
    by_var,
    function(j) {
      if (length(j) > 0) j[which.max(abs(x$value[rows[j]]))] else NA_integer_
    },
    integer(1)
  )
  first <- vapply(s$rows, `[`, integer(1), 1)
  ids <- tibble::as_tibble(x[first[split_of[top]], s$id_cols, drop = FALSE])
  out <- tibble::tibble(
    variable = vars,
    median_abs_smd = vapply(
      by_var,
      function(j) {
        if (length(j) > 0) stats::median(abs(x$value[rows[j]])) else NA_real_
      },
      numeric(1)
    ),
    max_abs_smd = abs(x$value[rows[top]]),
    level = x$level[rows[top]]
  )
  out <- tibble::as_tibble(c(out, ids))
  out$n_over <- vapply(
    by_var,
    function(j) sum(above(abs(x$value[rows[j]]), cutoffs[j]), na.rm = TRUE),
    integer(1)
  )
  out$n_splits <- lengths(by_var)
  if (any(x$statistic == "variance_ratio")) {
    vr <- which(x$statistic == "variance_ratio")
    out$variance_ratio <- vapply(
      vars,
      function(v) x$value[farthest_ratio(x, vr[x$variable[vr] %in% v])],
      numeric(1),
      USE.NAMES = FALSE
    )
  }
  if (any(x$statistic == "chance_q95")) {
    q <- x$statistic == "chance_q95"
    out$chance_q95 <- vapply(
      vars,
      function(v) stats::median(x$value[q & x$variable %in% v]),
      numeric(1),
      USE.NAMES = FALSE
    )
  }
  out
}
