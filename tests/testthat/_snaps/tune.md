# calibration falls back to an empty set when it can't split

    Code
      cal <- rsample::internal_calibration_split(folds$splits[[1]], args)
    Condition
      Warning:
      Cannot create calibration split; creating an empty calibration set.
      Caused by error in `balanced_initial_split()`:
      i In argument: `tidyselect::all_of(split_args$balance %||% character())`.
      Caused by error in `tidyselect::all_of()`:
      ! Can't subset elements that don't exist.
      x Element `not_a_column` doesn't exist.

