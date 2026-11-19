#' Check the balance of a split or of a set of resamples
#'
#' `balance_check()` compares the assessment set of each split with its
#' analysis set. It reports a standardized mean difference (SMD) for each
#' variable and the energy distance for all variables together. It works
#' with any `rset` or `rsplit`, so you can compare balanced folds with
#' ordinary [rsample::vfold_cv()] folds.
#'
#' @param x An `rset` (for example from [balanced_vfold_cv()]) or an `rsplit`
#'   (for example from [balanced_initial_split()]).
#' @param ... <[`tidy-select`][tidyselect::language]> Columns to check. If
#'   empty, the `balance` and `exact` columns stored in `x` are used.
#' @param max_n The largest number of rows per set for the energy distance.
#'   Larger sets are subsampled at random to keep memory use low.
#'
#' @details
#' For a numeric variable, the SMD is the difference in means (assessment
#' minus analysis) divided by the pooled standard deviation,
#' `sqrt((var_assessment + var_analysis) / 2)`. For a categorical variable,
#' there is one SMD per level, from the proportions of that level. Values
#' under 0.1 in absolute size are often taken as good balance. If both sets
#' have zero variance but different means, the SMD is `Inf` or `-Inf`; the
#' plot shows these values at the edge of the panel.
#'
#' Missing values are dropped variable by variable for the SMD. The energy
#' distance uses the rows that have no missing values in any checked column.
#'
#' The energy distance is the V-statistic
#' `2 E|X - Y| - E|X - X'| - E|Y - Y'|` on the standardized variables (one
#' indicator column per categorical level). It is 0 when the two sets have the
#' same distribution, and it also detects differences in spread and shape.
#'
#' @return A tibble with class `balance_check`. It has the ID columns of `x`,
#'   and the columns `variable`, `level`, `statistic` (`"smd"` or `"energy"`),
#'   and `value`. Energy rows have `NA` in `variable` and `level`.
#'
#' @examples
#' set.seed(1)
#' folds <- balanced_vfold_cv(
#'   mtcars, v = 4, balance = c(mpg, hp, wt), method = "rerandomize"
#' )
#' balance_check(folds)
#'
#' # Compare with ordinary folds
#' balance_check(rsample::vfold_cv(mtcars, v = 4), mpg, hp, wt)
#' @export
balance_check <- function(x, ..., max_n = 2000) {
  UseMethod("balance_check")
}

#' @export
balance_check.default <- function(x, ..., max_n = 2000) {
  cli::cli_abort(
    "{.arg x} must be an {.cls rset} or an {.cls rsplit}, not {.obj_type_friendly {x}}."
  )
}

#' @rdname balance_check
#' @export
balance_check.rset <- function(x, ..., max_n = 2000) {
  check_whole(max_n, min = 2)
  if (nrow(x) == 0) {
    cli::cli_abort("{.arg x} has no splits.")
  }
  data <- x$splits[[1]]$data
  cols <- check_columns(data, x, ...)
  id_cols <- grep("^id", names(x), value = TRUE)
  ids <- tibble::as_tibble(as.data.frame(x)[id_cols])

  res <- lapply(seq_len(nrow(x)), function(i) {
    out <- split_balance(x$splits[[i]], cols, max_n)
    id_rows <- ids[rep(i, nrow(out)), , drop = FALSE]
    cbind(id_rows, out)
  })
  new_balance_check(do.call(rbind, res))
}

#' @rdname balance_check
#' @export
balance_check.rsplit <- function(x, ..., max_n = 2000) {
  check_whole(max_n, min = 2)
  cols <- check_columns(x$data, x, ...)
  out <- split_balance(x, cols, max_n)
  new_balance_check(cbind(tibble::tibble(id = rep("Split", nrow(out))), out))
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
    cols <- unique(c(attr(x, "balance"), attr(x, "exact")))
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

split_balance <- function(split, cols, max_n) {
  data <- split$data
  an <- split$in_id
  as <- rsample::complement(split)

  smd <- lapply(cols, function(nm) {
    v <- data[[nm]]
    if (is.logical(v)) {
      v <- factor(v, levels = c(FALSE, TRUE))
    }
    if (is.character(v)) {
      v <- factor(v)
    }
    if (is.factor(v)) {
      lv <- levels(droplevels(v))
      vals <- vapply(
        lv,
        function(l) {
          z <- as.numeric(v == l)
          smd_value(z[as], z[an], binary = TRUE)
        },
        numeric(1)
      )
      return(tibble::tibble(
        variable = nm,
        level = lv,
        statistic = "smd",
        value = unname(vals)
      ))
    }
    tibble::tibble(
      variable = nm,
      level = NA_character_,
      statistic = "smd",
      value = smd_value(as.numeric(v[as]), as.numeric(v[an]))
    )
  })

  keep <- which(stats::complete.cases(data[cols]))
  pos <- integer(nrow(data))
  pos[keep] <- seq_along(keep)
  as_k <- pos[as][pos[as] > 0]
  an_k <- pos[an][pos[an] > 0]
  en <- NA_real_
  if (length(as_k) > 0 && length(an_k) > 0) {
    xs <- build_balance_matrix(data[keep, cols, drop = FALSE])
    en <- energy_distance(
      xs[as_k, , drop = FALSE],
      xs[an_k, , drop = FALSE],
      max_n
    )
  }
  energy <- tibble::tibble(
    variable = NA_character_,
    level = NA_character_,
    statistic = "energy",
    value = en
  )
  do.call(rbind, c(smd, list(energy)))
}

smd_value <- function(a, b, binary = FALSE) {
  a <- a[!is.na(a)]
  b <- b[!is.na(b)]
  if (length(a) == 0 || length(b) == 0) {
    return(NA_real_)
  }
  diff <- mean(a) - mean(b)
  if (binary) {
    pa <- mean(a)
    pb <- mean(b)
    den <- sqrt((pa * (1 - pa) + pb * (1 - pb)) / 2)
  } else {
    va <- if (length(a) > 1) stats::var(a) else 0
    vb <- if (length(b) > 1) stats::var(b) else 0
    den <- sqrt((va + vb) / 2)
  }
  # Tolerances are relative to the size of the values, so the result does not
  # depend on the units.
  tol <- 1e-12 * max(abs(c(a, b)))
  if (den <= tol) {
    return(if (abs(diff) <= tol) 0 else sign(diff) * Inf)
  }
  out <- diff / den
  if (abs(out) < 1e-12) 0 else out
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

new_balance_check <- function(x) {
  x <- tibble::as_tibble(x)
  class(x) <- c("balance_check", class(x))
  x
}

#' @export
print.balance_check <- function(x, ...) {
  smd <- x$value[x$statistic == "smd"]
  en <- x$value[x$statistic == "energy"]
  n_split <- length(en)
  smd <- abs(smd[!is.na(smd)])
  max_smd <- if (length(smd) > 0) max(smd) else NA_real_
  mean_en <- if (any(!is.na(en))) mean(en, na.rm = TRUE) else NA_real_
  cat(
    "# Balance check: ",
    n_split,
    " split",
    if (n_split != 1) "s",
    ", ",
    "max |SMD| = ",
    format(signif(max_smd, 3)),
    ", ",
    "mean energy distance = ",
    format(signif(mean_en, 3)),
    "\n",
    sep = ""
  )
  class(x) <- setdiff(class(x), "balance_check")
  print(x, ...)
  invisible(x)
}
