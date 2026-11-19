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
      ! `x` must be an <rset> or an <rsplit>, not a number.

