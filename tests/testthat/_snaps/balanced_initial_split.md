# twinning needs prop = 1 - 1/r

    Code
      balanced_initial_split(d, prop = 0.7, balance = x1, method = "twinning")
    Condition
      Error in `balanced_initial_split()`:
      ! `method = "twinning"` can only split off 1/r of the data, where r is a whole number.
      i Use `prop` = 1/2, 2/3, 3/4, 4/5, 9/10, or another value of 1 - 1/r.

# bad prop values give clear errors

    Code
      balanced_initial_split(d, prop = 1, balance = x1)
    Condition
      Error in `balanced_initial_split()`:
      ! `prop` must be a number between 0 and 1.
    Code
      balanced_initial_split(d, prop = "a", balance = x1)
    Condition
      Error in `balanced_initial_split()`:
      ! `prop` must be a number between 0 and 1.

