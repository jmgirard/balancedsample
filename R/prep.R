# Column selection and preprocessing shared by the user-facing functions.

prepare_balance_data <- function(data, balance, exact, group, call = rlang::caller_env()) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame, not {.obj_type_friendly {data}}.", call = call)
  }
  if (nrow(data) < 2) {
    cli::cli_abort("{.arg data} must have at least two rows.", call = call)
  }

  bal_pos <- tidyselect::eval_select(balance, data, allow_rename = FALSE, error_call = call)
  exa_pos <- tidyselect::eval_select(exact, data, allow_rename = FALSE, error_call = call)
  grp_pos <- tidyselect::eval_select(group, data, allow_rename = FALSE, error_call = call)

  if (length(bal_pos) == 0 && length(exa_pos) == 0) {
    cli::cli_abort(
      c(
        "Select at least one column with {.arg balance} or {.arg exact}.",
        i = "For example, {.code balance = c(age, income)}."
      ),
      call = call
    )
  }
  if (length(grp_pos) > 1) {
    cli::cli_abort(
      "{.arg group} must select one column, not {length(grp_pos)}.",
      call = call
    )
  }
  if (length(grp_pos) == 1 && any(c(bal_pos, exa_pos) == grp_pos)) {
    cli::cli_abort(
      "The {.arg group} column {.field {names(grp_pos)}} can't also be in {.arg balance} or {.arg exact}.",
      call = call
    )
  }

  used <- unique(c(bal_pos, exa_pos, grp_pos))
  not_vector <- names(data)[used][vapply(data[used], function(v) !is.null(dim(v)) || is.list(v), logical(1))]
  if (length(not_vector) > 0) {
    cli::cli_abort(
      c(
        "Selected columns must be plain vectors.",
        x = "{.field {not_vector}} {?is a/are} matrix, data frame, or list column{?s}."
      ),
      call = call
    )
  }
  has_na <- names(data)[used][vapply(data[used], anyNA, logical(1))]
  if (length(has_na) > 0) {
    cli::cli_abort(
      c(
        "Selected columns must not have missing values.",
        x = "Missing values in {.field {has_na}}."
      ),
      call = call
    )
  }

  for (nm in names(exa_pos)) {
    col <- data[[nm]]
    whole <- is.numeric(col) && all(col == round(col))
    if (!(is.factor(col) || is.character(col) || is.logical(col) || whole)) {
      cli::cli_abort(
        c(
          "{.arg exact} columns must be categorical.",
          x = "{.field {nm}} is {.obj_type_friendly {col}}.",
          i = "Convert it to a factor, or move it to {.arg balance}."
        ),
        call = call
      )
    }
  }

  exact_fct <- NULL
  if (length(exa_pos) > 0) {
    exact_fct <- combine_levels(data[exa_pos])
  }
  group_fct <- NULL
  if (length(grp_pos) == 1) {
    group_fct <- factor(data[[grp_pos]])
  }

  list(
    x = build_balance_matrix(data[bal_pos], call = call),
    exact = exact_fct,
    group = group_fct,
    balance_names = names(bal_pos),
    exact_names = names(exa_pos),
    group_name = names(grp_pos)
  )
}

# One factor level per observed combination of the columns in `cols`. The key
# is built from integer codes, so level labels that contain the separator
# can't make two combinations collide.
combine_levels <- function(cols) {
  codes <- lapply(cols, function(v) as.integer(as.factor(v)))
  factor(do.call(paste, c(unname(codes), sep = "_")))
}

# Numeric matrix with one standardized column per numeric variable and one
# standardized indicator column per level of each categorical variable.
# Constant columns are dropped.
build_balance_matrix <- function(df, call = rlang::caller_env()) {
  n <- nrow(df)
  if (ncol(df) == 0) {
    return(matrix(numeric(0), nrow = n, ncol = 0))
  }
  cols <- lapply(names(df), function(nm) {
    v <- df[[nm]]
    if (is.logical(v)) v <- as.integer(v)
    if (is.character(v)) v <- factor(v)
    if (is.factor(v)) {
      v <- droplevels(v)
      m <- outer(as.integer(v), seq_len(nlevels(v)), "==") * 1
      colnames(m) <- paste0(nm, "_", levels(v))
      return(m)
    }
    if (is.numeric(v)) {
      if (any(!is.finite(v))) {
        cli::cli_abort("{.field {nm}} has infinite values.", call = call)
      }
      return(matrix(as.double(v), ncol = 1, dimnames = list(NULL, nm)))
    }
    cli::cli_abort(
      c(
        "{.arg balance} columns must be numeric, logical, character, or factor.",
        x = "{.field {nm}} is {.obj_type_friendly {v}}."
      ),
      call = call
    )
  })
  standardize_matrix(do.call(cbind, cols))
}

standardize_matrix <- function(x) {
  if (ncol(x) == 0) {
    return(x)
  }
  sds <- apply(x, 2, stats::sd)
  keep <- is.finite(sds) & sds > 1e-12
  x <- x[, keep, drop = FALSE]
  if (ncol(x) == 0) {
    return(x)
  }
  centers <- colMeans(x)
  x <- sweep(x, 2, centers, "-")
  sweep(x, 2, sds[keep], "/")
}

# Collapse rows to one row per group, assign groups, and expand back to rows.
# Each group row holds the group means of the standardized columns plus the log
# group size, so large and small groups are also spread over the sets.
assign_grouped <- function(x, exact, group, props, assign_fun, call = rlang::caller_env()) {
  g <- as.integer(group)
  n_grp <- nlevels(group)
  counts <- tabulate(g, n_grp)

  if (ncol(x) > 0) {
    xg <- rowsum(x, g, reorder = TRUE) / counts
  } else {
    xg <- matrix(numeric(0), nrow = n_grp, ncol = 0)
  }
  if (ncol(x) > 0 || !is.null(exact)) {
    xg <- cbind(xg, .group_size = log(counts))
  }
  xg <- standardize_matrix(xg)

  exact_g <- NULL
  if (!is.null(exact)) {
    n_lvl <- vapply(split(as.integer(exact), g), function(z) length(unique(z)), integer(1))
    if (any(n_lvl > 1)) {
      cli::cli_abort(
        c(
          "{.arg exact} columns must be constant within each group.",
          x = "{sum(n_lvl > 1)} group{?s} contain{?s/} more than one {.arg exact} level."
        ),
        call = call
      )
    }
    first <- match(seq_len(n_grp), g)
    exact_g <- droplevels(exact[first])
  }

  sizes_g <- sizes_from_props(n_grp, props)
  out_g <- assign_fun(xg, sizes_g, exact_g)
  out_g[g]
}
