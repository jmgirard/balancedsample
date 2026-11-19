# exact columns must be constant within groups

    Code
      balanced_vfold_cv(d, v = 4, balance = x1, exact = sex, group = id, method = "rerandomize")
    Condition
      Error in `balanced_vfold_cv()`:
      ! `exact` columns must be constant within each group.
      x 35 groups contain more than one `exact` level.

# method options are checked

    Code
      balanced_vfold_cv(d, balance = x1, method = "rerandomize", options = list(foo = 1))
    Condition
      Error in `balanced_vfold_cv()`:
      ! Unknown option for method "rerandomize": `foo`.
      i Valid options: `p_accept` and `max_draws`.
    Code
      balanced_vfold_cv(d, balance = x1, method = "nope")
    Condition
      Error in `balanced_vfold_cv()`:
      ! `method` must be one of "anticlust", "interaction", "rerandomize", or "twinning", not "nope".
    Code
      balanced_vfold_cv(d, balance = x1, method = "interaction", options = list(1))
    Condition
      Error in `balanced_vfold_cv()`:
      ! All elements of `options` must have unique names.

---

    Code
      balanced_vfold_cv(d, balance = x1, options = list(K = 3))
    Condition
      Error in `balanced_vfold_cv()`:
      ! `options` can't set `K` for method "anticlust".
      i balancesample sets this argument from `balance`, `exact`, and `group`.

# twinning strategy 2 needs a power of two

    Code
      balanced_vfold_cv(d, v = 5, balance = x1, method = "twinning", options = list(
        strategy = 2))
    Condition
      Error in `balanced_vfold_cv()`:
      ! Method "twinning" failed.
      Caused by error:
      ! Twinning strategy 2 needs `v` to be a power of 2.
      x `v` is 5.
      i Use `v` = 2, 4, 8, or 16, or use strategy 1 or 3.

# bad inputs give clear errors

    Code
      balanced_vfold_cv(d)
    Condition
      Error in `balanced_vfold_cv()`:
      ! Select at least one column with `balance` or `exact`.
      i For example, `balance = c(age, income)`.
    Code
      balanced_vfold_cv(d, v = 1, balance = x1)
    Condition
      Error in `balanced_vfold_cv()`:
      ! `v` must be a whole number of at least 2.
    Code
      balanced_vfold_cv(d[1:3, ], v = 4, balance = x1)
    Condition
      Error in `balanced_vfold_cv()`:
      ! `v` (4) must not be more than the number of rows (3).
    Code
      balanced_vfold_cv(d, balance = x1, exact = x2)
    Condition
      Error in `balanced_vfold_cv()`:
      ! `exact` columns must be categorical.
      x x2 is a double vector.
      i Convert it to a factor, or move it to `balance`.
    Code
      balanced_vfold_cv(d, balance = c(x1, id), group = id)
    Condition
      Error in `balanced_vfold_cv()`:
      ! The `group` column id can't also be in `balance` or `exact`.
    Code
      balanced_vfold_cv(d, balance = x1, group = c(id, sex))
    Condition
      Error in `balanced_vfold_cv()`:
      ! `group` must select one column, not 2.
    Code
      balanced_vfold_cv(d, v = 50, balance = x1, group = id)
    Condition
      Error in `balanced_vfold_cv()`:
      ! `v` (50) must not be more than the number of groups (38).

---

    Code
      balanced_vfold_cv(d, balance = x1)
    Condition
      Error in `balanced_vfold_cv()`:
      ! Selected columns must not have missing values.
      x Missing values in x1.

---

    Code
      balanced_vfold_cv(m, 3, balance = x)
    Condition
      Error in `balanced_vfold_cv()`:
      ! Selected columns must be plain vectors.
      x x is a matrix, data frame, or list column.

