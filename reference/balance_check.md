# Check the balance of a split or of a set of resamples

`balance_check()` compares the assessment set of each split with its
analysis set. For a three-way split, it compares the validation set and
the testing set each with the training set. It reports a standardized
mean difference (SMD) for each variable and the energy distance for all
variables together. It works with any `rset` or `rsplit`, so you can
compare balanced folds with ordinary
[`rsample::vfold_cv()`](https://rsample.tidymodels.org/reference/vfold_cv.html)
folds.

## Usage

``` r
balance_check(x, ..., max_n = 2000, variance_ratio = FALSE)

# S3 method for class 'rset'
balance_check(x, ..., max_n = 2000, variance_ratio = FALSE)

# S3 method for class 'rsplit'
balance_check(x, ..., max_n = 2000, variance_ratio = FALSE)

# S3 method for class 'three_way_split'
balance_check(x, ..., max_n = 2000, variance_ratio = FALSE)

# S3 method for class 'balance_check'
summary(object, ..., threshold = 0.1, by = c("split", "variable"))
```

## Arguments

- x:

  An `rset` (for example from
  [`balanced_vfold_cv()`](https://jmgirard.github.io/balancedsample/reference/balanced_vfold_cv.md)),
  an `rsplit` (for example from
  [`balanced_initial_split()`](https://jmgirard.github.io/balancedsample/reference/balanced_initial_split.md)),
  or a three-way split (from
  [`balanced_initial_validation_split()`](https://jmgirard.github.io/balancedsample/reference/balanced_initial_validation_split.md)
  or
  [`rsample::initial_validation_split()`](https://rsample.tidymodels.org/reference/initial_validation_split.html)).

- ...:

  For `balance_check()`,
  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  columns to check. If empty, the `balance` and `exact` columns stored
  in `x` are used. For
  [`summary()`](https://rdrr.io/r/base/summary.html), not used and must
  be empty.

- max_n:

  The largest number of rows per set for the energy distance. Larger
  sets are subsampled at random to keep memory use low.

- variance_ratio:

  If `TRUE`, also report the variance ratio of each numeric variable.

- object:

  A `balance_check` object.

- threshold:

  The absolute SMD above which
  [`summary()`](https://rdrr.io/r/base/summary.html) counts a variable
  in `n_over`. A value within rounding error of `threshold` (1.5e-8)
  counts as equal to it, so it isn't counted.

- by:

  `"split"` for one row per split, or `"variable"` for one row per
  variable across the splits.

## Value

A tibble with class `balance_check`. It has the ID columns of `x`, and
the columns `variable`, `level`, `statistic` (`"smd"`, `"energy"`, or
`"variance_ratio"`), and `value`. Energy rows have `NA` in `variable`
and `level`.

[`summary()`](https://rdrr.io/r/base/summary.html) with `by = "split"`
returns a tibble with one row per split. It has the ID columns and these
columns:

- `max_abs_smd`: the largest absolute SMD in the split, with the
  `variable` and `level` it belongs to (the first one if several tie).

- `mean_abs_smd`: the mean over the variables of their largest absolute
  SMD.

- `n_over`: the number of variables whose largest absolute SMD is above
  `threshold`.

- `n_variables`: the number of variables with an SMD that isn't missing.

- `energy`: the energy distance.

- With variance ratios, `variance_ratio`, the ratio farthest from 1 on
  the log scale (so 0.25 is farther than 3), and
  `variance_ratio_variable`, the variable it belongs to.

If the split has no SMD that isn't missing, `max_abs_smd`,
`mean_abs_smd`, `variable`, and `level` are `NA`. If it has no energy
row, `energy` is `NA`.

With `by = "variable"`, it returns one row per variable, with
`median_abs_smd` and `max_abs_smd` (the median and the largest of the
variable's largest absolute SMD in each split), the `level` and the ID
columns of the split with the largest, `n_over` (the number of splits
where it is above `threshold`), and `n_splits` (the number of splits
where the variable has an SMD that isn't missing). With variance ratios,
it also has `variance_ratio`, the ratio farthest from 1 over the splits.

Each split must have its own ID, so no ID may have more than one energy
row. Only the ID columns that `balance_check()` made are used, so
columns you add are ignored. If you rename an ID column, the columns
whose names start with `id` are used instead. If you drop one, splits
that differ only in it would merge, so
[`summary()`](https://rdrr.io/r/base/summary.html) gives an error and
printing shows the rows.

## Details

For a numeric variable, the SMD is the difference in means (assessment
minus analysis) divided by the pooled standard deviation,
`sqrt((var_assessment + var_analysis) / 2)`. For a categorical variable,
there is one SMD per level, from the proportions of that level. Values
under 0.1 in absolute size are often taken as good balance. If both sets
have zero variance but different means, the SMD is `Inf` or `-Inf`; the
plot shows these values at the edge of the panel.

Stored `exact` columns with whole numbers are treated as categories, as
the split functions treat them, so they get one SMD per level and no
variance ratio. This holds whether you name them or not. Other
whole-number columns are numeric.

With `variance_ratio = TRUE`, each numeric variable also gets the
variance of the assessment set divided by the variance of the analysis
set. It is 1 when the spreads are equal, and values between 0.5 and 2
are often taken as good balance. The SMD can be 0 while the spreads
differ, and the variance ratio shows which variable differs. A variance
within rounding error of zero counts as zero: if both are zero, the
ratio is 1, and if one is, it is 0 or `Inf`. With fewer than two values
in a set, it is `NA`.

Missing values are dropped variable by variable for the SMD and the
variance ratio. A variable with missing values also gets an SMD for the
share of its values that are missing, with `level` `"(missing)"`. In
[`summary()`](https://rdrr.io/r/base/summary.html), this row counts as
one more level of the variable. The energy distance uses all rows. It
encodes missing values as the split functions do with `na = "include"`:
a numeric variable gets the mean of its observed values plus an
indicator of which values are missing, and a categorical variable gets a
level for them. So with missing values, it compares the encoded data,
not only the observed values.

The energy distance is the V-statistic
`2 E|X - Y| - E|X - X'| - E|Y - Y'|` on the standardized variables (one
indicator column per categorical level). It is 0 when the two sets have
the same distribution, and it also detects differences in spread and
shape.

Printing the result shows a short table. For one split, it has the SMD
of each variable and level. For up to 10 splits, it has one row per
split, as from [`summary()`](https://rdrr.io/r/base/summary.html). For
more splits, it has one row per variable, as from
`summary(by = "variable")`. Columns that don't fit the width of the
console are left out, and a note names them. Printing counts SMDs over
0.1; use [`summary()`](https://rdrr.io/r/base/summary.html) with
`threshold` for another value. Use
[`tibble::as_tibble()`](https://tibble.tidyverse.org/reference/as_tibble.html)
to see all rows.

[`summary()`](https://rdrr.io/r/base/summary.html) first reduces each
variable in each split to its largest absolute SMD, over its levels and
its `"(missing)"` row. So a variable with many levels counts once, like
a numeric variable. The largest absolute SMD of a split shows the worst
variable, but it tends to grow with the number of variables: in random
splits of 30 rows against 270, it averaged 0.21 with 2 variables and
0.48 with 40. The mean across variables stayed near 0.15 in such splits,
so it is better for comparing splits that check different numbers of
variables. The rule of thumb of 0.1 is hard to meet with small sets: in
the same random splits, one variable's absolute SMD was under 0.1 only
about 40% of the time. An `exact` column also can't do better than whole
rows allow.

## Examples

``` r
set.seed(1)
folds <- balanced_vfold_cv(
  sim_patients,
  v = 5,
  balance = c(age, income, diagnosis)
)
balance_check(folds)
#> # Balance check: 5 splits, 3 variables
#> # 0 of 5 splits have a variable with |SMD| > 0.1, mean energy distance 0.023
#> 
#> id     max |SMD|  variable         mean |SMD|  over 0.1  energy
#> Fold1    0.00927  diagnosis: mild     0.00318       0/3  0.0218
#> Fold2    0.00927  diagnosis: mild     0.00322       0/3  0.0152
#> Fold3    0.00927  diagnosis: mild     0.00349       0/3  0.0193
#> Fold4    0.00927  diagnosis: mild     0.00326       0/3  0.0243
#> Fold5    0.0373   diagnosis: mild     0.0125        0/3  0.0343
#> 
#> # summary() gives this table as a tibble, and tibble::as_tibble() gives all
#> # 30 rows.
summary(balance_check(folds))
#> # A tibble: 5 × 8
#>   id    max_abs_smd variable  level mean_abs_smd n_over n_variables energy
#>   <chr>       <dbl> <chr>     <chr>        <dbl>  <int>       <int>  <dbl>
#> 1 Fold1     0.00927 diagnosis mild       0.00318      0           3 0.0218
#> 2 Fold2     0.00927 diagnosis mild       0.00322      0           3 0.0152
#> 3 Fold3     0.00927 diagnosis mild       0.00349      0           3 0.0193
#> 4 Fold4     0.00927 diagnosis mild       0.00326      0           3 0.0243
#> 5 Fold5     0.0373  diagnosis mild       0.0125       0           3 0.0343
summary(balance_check(folds), by = "variable")
#> # A tibble: 3 × 7
#>   variable  median_abs_smd max_abs_smd level id    n_over n_splits
#>   <chr>              <dbl>       <dbl> <chr> <chr>  <int>    <int>
#> 1 age             0.000230    0.000482 NA    Fold3      0        5
#> 2 income          0.000242    0.000735 NA    Fold3      0        5
#> 3 diagnosis       0.00927     0.0373   mild  Fold5      0        5
summary(balance_check(folds, variance_ratio = TRUE))
#> # A tibble: 5 × 10
#>   id    max_abs_smd variable  level mean_abs_smd n_over n_variables energy
#>   <chr>       <dbl> <chr>     <chr>        <dbl>  <int>       <int>  <dbl>
#> 1 Fold1     0.00927 diagnosis mild       0.00318      0           3 0.0218
#> 2 Fold2     0.00927 diagnosis mild       0.00322      0           3 0.0152
#> 3 Fold3     0.00927 diagnosis mild       0.00349      0           3 0.0193
#> 4 Fold4     0.00927 diagnosis mild       0.00326      0           3 0.0243
#> 5 Fold5     0.0373  diagnosis mild       0.0125       0           3 0.0343
#> # ℹ 2 more variables: variance_ratio <dbl>, variance_ratio_variable <chr>

# Compare with ordinary folds
random_folds <- rsample::vfold_cv(sim_patients, v = 5)
summary(balance_check(random_folds, age, income, diagnosis))
#> # A tibble: 5 × 8
#>   id    max_abs_smd variable  level mean_abs_smd n_over n_variables energy
#>   <chr>       <dbl> <chr>     <chr>        <dbl>  <int>       <int>  <dbl>
#> 1 Fold1       0.280 diagnosis mild         0.173      3           3 0.0857
#> 2 Fold2       0.291 income    NA           0.237      3           3 0.102 
#> 3 Fold3       0.343 diagnosis none         0.190      2           3 0.133 
#> 4 Fold4       0.191 diagnosis mild         0.101      1           3 0.0567
#> 5 Fold5       0.207 diagnosis none         0.128      2           3 0.0671
```
