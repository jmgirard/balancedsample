#' Balanced training/testing split
#'
#' `balanced_initial_split()` makes one training/testing split in which the
#' two sets are similar on several variables at once. Use [rsample::training()]
#' and [rsample::testing()] to get the two data sets.
#'
#' @inheritParams balanced_vfold_cv
#' @param prop The proportion of data (or of groups, if you use `group`) for
#'   the training set. With `method = "twinning"`, `prop` must be `1 - 1/r`
#'   for a whole number `r`, for example 1/2, 2/3, 3/4, 4/5, or 9/10.
#'
#' @details
#' The methods, options, and group handling are the same as for
#' [balanced_vfold_cv()]. With `method = "twinning"`, the split uses
#' [twinning::twin()], and the options are `leaf_size` only.
#'
#' @return An `rsplit` object with class `balanced_initial_split` and
#'   `initial_split`.
#'
#' @seealso [balanced_vfold_cv()], [balance_check()]
#'
#' @examples
#' set.seed(1)
#' split <- balanced_initial_split(
#'   mtcars,
#'   prop = 3 / 4,
#'   balance = c(mpg, hp, wt),
#'   exact = am,
#'   method = "rerandomize"
#' )
#' split
#' rsample::training(split)
#' @export
balanced_initial_split <- function(data,
                                   prop = 3 / 4,
                                   balance = NULL,
                                   exact = NULL,
                                   group = NULL,
                                   method = "anticlust",
                                   options = list()) {
  call <- rlang::current_env()
  if (!is.numeric(prop) || length(prop) != 1 || is.na(prop) || prop <= 0 || prop >= 1) {
    cli::cli_abort("{.arg prop} must be a number between 0 and 1.", call = call)
  }
  entry <- get_balance_method(method, call = call)
  if (method == "twinning" && "strategy" %in% names(options)) {
    cli::cli_abort(
      "{.arg strategy} applies to folds only. Remove it from {.arg options}.",
      call = call
    )
  }
  check_method_options(entry, options, call = call)
  prep <- prepare_balance_data(
    data,
    rlang::enquo(balance),
    rlang::enquo(exact),
    rlang::enquo(group),
    call = call
  )
  if (!is.null(prep$group) && nlevels(prep$group) < 2) {
    cli::cli_abort("{.arg group} must have at least two groups.", call = call)
  }

  a <- assign_balanced(prep, c(prop, 1 - prop), entry, options, call = call)
  res <- rsample::make_splits(
    list(analysis = which(a == 1L), assessment = which(a == 2L)),
    data = data,
    class = c("balanced_initial_split", "initial_split")
  )

  attrib <- list(
    prop = prop,
    balance = prep$balance_names,
    exact = prep$exact_names,
    group = prep$group_name,
    method = method,
    options = options
  )
  for (nm in names(attrib)) {
    attr(res, nm) <- attrib[[nm]]
  }
  res
}
