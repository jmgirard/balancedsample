# twinning validation splits use whole parts

    Code
      balanced_initial_validation_split(d, prop = c(0.62, 0.2), balance = x1, method = "twinning")
    Condition
      Error in `balanced_initial_validation_split()`:
      ! With `method = "twinning"`, each proportion must be a multiple of 1/m for one whole number m up to 20.
      i For example, `prop = c(0.6, 0.2)` uses m = 5.
    Code
      balanced_initial_validation_split(d, prop = c(0.6, 0.2), balance = x1, method = "twinning",
      options = list(strategy = 2))
    Condition
      Error in `balanced_initial_validation_split()`:
      ! Method "twinning" failed.
      Caused by error:
      ! Twinning strategy 2 needs each proportion to be a multiple of 1/m, where m is a power of 2.
      x These proportions need m = 5.
      i Use proportions in quarters or eighths, such as `c(0.5, 0.25)`, or use strategy 1 or 3.

# bad validation split inputs give clear errors

    Code
      balanced_initial_validation_split(d, prop = 0.6, balance = x1)
    Condition
      Error in `balanced_initial_validation_split()`:
      ! `prop` must be two numbers above 0 that sum to less than 1.
      i For example, `prop = c(0.6, 0.2)`.
    Code
      balanced_initial_validation_split(d, prop = c(0.6, 0.4), balance = x1)
    Condition
      Error in `balanced_initial_validation_split()`:
      ! `prop` must be two numbers above 0 that sum to less than 1.
      i For example, `prop = c(0.6, 0.2)`.
    Code
      balanced_initial_validation_split(d, balance = x1, strata = cat)
    Condition
      Error in `balanced_initial_validation_split()`:
      ! balancesample uses `exact`, not `strata`.
      i Put categorical columns in `exact`, for example `exact = class`.
      i Put numeric columns in `balance`.
    Code
      balanced_initial_validation_split(d[1:4, ], balance = x1, group = site)
    Condition
      Error in `balanced_initial_validation_split()`:
      ! `group` must have at least three groups.

