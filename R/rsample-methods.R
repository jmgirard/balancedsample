# Methods for rsample generics that tune and other tidymodels packages call on
# resamples.

# tune calls internal_calibration_split() when a workflow has a postprocessor
# that must be trained (for example, a calibration from tailor). The analysis
# set is split again: the model is fit on one part and the postprocessor on the
# other. The inner split uses the same balancing as the outer one.

#' @exportS3Method rsample::internal_calibration_split
internal_calibration_split.balanced_vfold_split <- function(
  x,
  split_args,
  ...
) {
  rlang::check_dots_empty()
  if (is.null(split_args$prop)) {
    split_args$prop <- 1 - 1 / split_args$v
  }
  balanced_calibration_split(
    rsample::analysis(x),
    split_args,
    class = c(
      "balanced_vfold_split_cal",
      "internal_calibration_split",
      class(x)
    )
  )
}

#' @exportS3Method rsample::internal_calibration_split
internal_calibration_split.balanced_initial_split <- function(
  x,
  split_args,
  ...
) {
  rlang::check_dots_empty()
  # tune::last_fit() wraps the split in a manual_rset, so `split_args` is
  # empty there. The split stores its own arguments.
  stored <- attributes(x)[c(
    "prop",
    "balance",
    "exact",
    "group",
    "method",
    "options"
  )]
  stored <- stored[!vapply(stored, is.null, logical(1))]
  split_args <- c(split_args, stored[setdiff(names(stored), names(split_args))])
  balanced_calibration_split(
    rsample::analysis(x),
    split_args,
    class = c(
      "balanced_initial_split_cal",
      "internal_calibration_split",
      class(x)
    )
  )
}

# As in rsample, the training set is split with the training share of the
# training and validation sets. twinning can only split off 1/r of the data,
# so with twinning the share is rounded to the nearest 1 - 1/r (or 1/r).
#' @exportS3Method rsample::internal_calibration_split
internal_calibration_split.balanced_initial_validation_split <- function(
  x,
  split_args,
  ...
) {
  rlang::check_dots_empty()
  stored <- attr(x, "val_att")
  stored <- stored[!vapply(stored, is.null, logical(1))]
  split_args <- c(split_args, stored[setdiff(names(stored), names(split_args))])
  balanced_calibration_split(
    rsample::training(x),
    split_args,
    class = c(
      "balanced_initial_validation_split_cal",
      "internal_calibration_split",
      "mc_split",
      "rsplit"
    ),
    share = three_way_fit_share
  )
}

# Errors here reach the fallback in balanced_calibration_split().
three_way_fit_share <- function(split_args) {
  p <- split_args$prop
  if (!is.numeric(p) || length(p) != 2 || !all(is.finite(p) & p > 0)) {
    cli::cli_abort(
      "{.arg prop} must be two finite numbers above 0.",
      call = NULL
    )
  }
  total <- sum(p)
  # Scale only if the sum overflows, so that other shares are unchanged.
  if (!is.finite(total)) {
    p <- p / max(p)
    total <- sum(p)
  }
  share <- p[[1]] / total
  if (rlang::is_string(split_args$method, "twinning")) {
    share <- nearest_twin_prop(share)
  }
  share
}

# The shares 1/r are not evenly spaced, so compare the two nearest ones. A
# share that rounds to 1 is left for balanced_calibration_split() to reject.
nearest_twin_prop <- function(prop) {
  small <- min(prop, 1 - prop)
  if (small <= 0) {
    return(prop)
  }
  r <- unique(pmax(2, c(floor(1 / small), ceiling(1 / small))))
  r <- r[which.min(abs(1 / r - small))]
  if (prop >= 0.5) 1 - 1 / r else 1 / r
}

# Like rsample, fall back to an empty calibration set with a warning if the
# analysis set can't be split (for example, if it is too small).
# `share` turns `split_args` into the share of `analysis_set` to fit on.
balanced_calibration_split <- function(
  analysis_set,
  split_args,
  class,
  share = function(args) args$prop
) {
  split <- tryCatch(
    {
      options <- split_args$options %||% list()
      # `strategy` applies to folds only. balanced_initial_split() rejects
      # options that aren't a list.
      if (is.list(options)) {
        options$strategy <- NULL
      }
      balanced_initial_split(
        analysis_set,
        prop = share(split_args),
        balance = tidyselect::all_of(split_args$balance %||% character()),
        exact = tidyselect::all_of(split_args$exact %||% character()),
        group = tidyselect::all_of(split_args$group %||% character()),
        method = split_args$method %||% "anticlust",
        options = options
      )
    },
    error = function(cnd) {
      cli::cli_warn(
        "Cannot create calibration split; creating an empty calibration set.",
        parent = cnd
      )
      rsample::make_splits(analysis_set, analysis_set[0, , drop = FALSE])
    }
  )
  class(split) <- class
  split
}

#' @export
labels.balanced_vfold_cv <- function(object, make_factor = FALSE, ...) {
  if ("id2" %in% names(object)) {
    out <- paste(object$id, object$id2, sep = ".")
  } else {
    out <- as.character(object$id)
  }
  if (make_factor) {
    out <- as.factor(out)
  }
  out
}
