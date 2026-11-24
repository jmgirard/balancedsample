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

# summary() counts each variable once

    Code
      summary(bc, threshold = -1)
    Condition
      Error in `summary()`:
      ! `threshold` must be `NULL` or a number of at least 0.

---

    Code
      summary(bc, threshold = NA)
    Condition
      Error in `summary()`:
      ! `threshold` must be `NULL` or a number of at least 0.

---

    Code
      summary(bc, by = "level")
    Condition
      Error in `summary()`:
      ! `by` must be one of "split" or "variable", not "level".

# print() shows one split, a few splits, or many splits

    Code
      print(balance_check(s, x, g, z, variance_ratio = TRUE))
    Output
      # Balance check: 1 split, 3 variables
      # |SMD| above chance (95%) in 0 of 3 variables, ratio to chance 0.661,
      # energy distance 1.02
      
      variable  level         SMD  chance 95%  variance ratio
      x                    -0.129        1.58           0.667
      g         a          -0.272        1.62
      g         b           0.272
      z                    -0.937        1.41           0.419
      z         (missing)  -0.816
      
      # tibble::as_tibble() gives all 14 rows.

---

    Code
      withr::with_options(list(width = 120), print(balance_check(folds(3), x, g,
      variance_ratio = TRUE)))
    Output
      # Balance check: 3 splits, 2 variables
      # 0 of 3 splits have a variable with |SMD| above chance (95%), mean ratio to chance 0.699, mean energy distance 0.894
      
      id     max |SMD|  variable  mean |SMD|  vs chance  over chance  energy  variance ratio  ratio variable
      Fold1      0.693  x              0.555      0.705          0/2   0.707           1.23   x
      Fold2      1.15   g: a           0.805      1.02           0/2   1.09            0.479  x
      Fold3      0.417  g: a           0.292      0.37           0/2   0.884           2.22   x
      
      # summary() gives this table as a tibble, and tibble::as_tibble() gives all 27 rows.

---

    Code
      print(balance_check(folds(11), x, g, z))
    Output
      # Balance check: 11 splits, 3 variables
      # 1 of 11 splits has a variable with |SMD| above chance (95%),
      # mean ratio to chance 0.876, mean energy distance 1.54
      
      variable  median |SMD|  max |SMD|  level  in split  chance 95%  over chance
      x                0.36        1.13         Fold8           1.91         0/11
      g                0.417       1.15  a      Fold2           1.24         0/11
      z                0.979       3.19         Fold7           2.15         1/11
      
      # summary(by = "variable") gives this table as a tibble, summary() gives one
      # row per split, and tibble::as_tibble() gives all 132 rows.

# print() falls back to the rows when it can't summarize

    Code
      summary(smd)
    Condition
      Error in `summary()`:
      ! `object` must keep its ID columns.
      x It has no id2.

# summary() handles empty and incomplete input

    Code
      summary(bc[c("id", "statistic", "value")])
    Condition
      Error in `summary()`:
      ! `object` must have ID columns and the columns `variable`, `level`, `statistic`, and `value`.
      i Summarize the output of `balance_check()`.

---

    Code
      summary(bc[-1])
    Condition
      Error in `summary()`:
      ! `object` must have ID columns and the columns `variable`, `level`, `statistic`, and `value`.
      i Summarize the output of `balance_check()`.

---

    Code
      summary(dup)
    Condition
      Error in `summary()`:
      ! Each split in `object` must have its own ID.
      x Some IDs have more than one energy row.

---

    Code
      summary(bc[c(NA, seq_len(nrow(bc))), ])
    Condition
      Error in `summary()`:
      ! `statistic` must be "smd", "energy", "variance_ratio", "chance_mean", or "chance_q95" in every row of `object`.

# variance ratios show differences in spread

    Code
      balance_check(s, x, variance_ratio = NA)
    Condition
      Error in `balance_check()`:
      ! `variance_ratio` must be `TRUE` or `FALSE`.

# every split of an rset must have the columns to check

    Code
      balance_check(r, x)
    Condition
      Error in `balance_check()`:
      ! Every split of `x` must have the columns to check.
      x Split 2 has no x.

# balance_check() adds a chance reference for each variable

    Code
      balance_check(folds, chance = -1)
    Condition
      Error in `balance_check()`:
      ! `chance` must be a whole number of at least 0.

