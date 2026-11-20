# balance_check() needs columns for plain rsample objects

    Code
      balance_check(rsample::vfold_cv(d, v = 3))
    Condition
      Error in `balance_check()`:
      ! Select the columns to check.
      i For example, `balance_check(folds, age, income)`.

---

    Code
      balance_check(1)
    Condition
      Error in `balance_check()`:
      ! `x` must be an <rset>, an <rsplit>, or a <three_way_split>, not a number.

# balance_check() subsamples large sets for the energy distance

    Code
      balance_check(folds, max_n = 1)
    Condition
      Error in `balance_check()`:
      ! `max_n` must be a whole number of at least 2.

