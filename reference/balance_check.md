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
balance_check(x, ..., max_n = 2000)

# S3 method for class 'rset'
balance_check(x, ..., max_n = 2000)

# S3 method for class 'rsplit'
balance_check(x, ..., max_n = 2000)

# S3 method for class 'three_way_split'
balance_check(x, ..., max_n = 2000)

# S3 method for class 'balance_check'
summary(object, ...)
```

## Arguments

- x:

  An `rset` (for example from
  [`balanced_vfold_cv()`](https://jmgirard.github.io/balancesample/reference/balanced_vfold_cv.md)),
  an `rsplit` (for example from
  [`balanced_initial_split()`](https://jmgirard.github.io/balancesample/reference/balanced_initial_split.md)),
  or a three-way split (from
  [`balanced_initial_validation_split()`](https://jmgirard.github.io/balancesample/reference/balanced_initial_validation_split.md)
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

- object:

  A `balance_check` object.

## Value

A tibble with class `balance_check`. It has the ID columns of `x`, and
the columns `variable`, `level`, `statistic` (`"smd"` or `"energy"`),
and `value`. Energy rows have `NA` in `variable` and `level`.

[`summary()`](https://rdrr.io/r/base/summary.html) returns a tibble with
one row per split. It has the ID columns, `max_abs_smd` (the largest
absolute SMD in the split), the `variable` and `level` with that SMD
(the first one if several tie), and `energy`. If the split has no SMD
that isn't missing, `max_abs_smd`, `variable`, and `level` are `NA`. If
it has no energy row, `energy` is `NA`. Each split must have its own ID,
so no ID may have more than one energy row. Only the ID columns that
`balance_check()` made are used, so columns you add are ignored. If you
rename or drop an ID column, the columns whose names start with `id` are
used instead.

## Details

For a numeric variable, the SMD is the difference in means (assessment
minus analysis) divided by the pooled standard deviation,
`sqrt((var_assessment + var_analysis) / 2)`. For a categorical variable,
there is one SMD per level, from the proportions of that level. Values
under 0.1 in absolute size are often taken as good balance. If both sets
have zero variance but different means, the SMD is `Inf` or `-Inf`; the
plot shows these values at the edge of the panel.

Missing values are dropped variable by variable for the SMD. The energy
distance uses the rows that have no missing values in any checked
column.

The energy distance is the V-statistic
`2 E|X - Y| - E|X - X'| - E|Y - Y'|` on the standardized variables (one
indicator column per categorical level). It is 0 when the two sets have
the same distribution, and it also detects differences in spread and
shape.

Use [`summary()`](https://rdrr.io/r/base/summary.html) on the result to
get one row per split.

## Examples

``` r
set.seed(1)
folds <- balanced_vfold_cv(mtcars, v = 4, balance = c(mpg, hp, wt))
balance_check(folds)
#> # Balance check: 4 splits, max |SMD| = 0.138, mean energy distance = 0.133
#> # A tibble: 16 × 5
#>    id    variable level statistic     value
#>    <chr> <chr>    <chr> <chr>         <dbl>
#>  1 Fold1 mpg      NA    smd       -0.0998  
#>  2 Fold1 hp       NA    smd        0.109   
#>  3 Fold1 wt       NA    smd       -0.138   
#>  4 Fold1 NA       NA    energy     0.212   
#>  5 Fold2 mpg      NA    smd        0.0759  
#>  6 Fold2 hp       NA    smd        0.00594 
#>  7 Fold2 wt       NA    smd        0.0691  
#>  8 Fold2 NA       NA    energy     0.118   
#>  9 Fold3 mpg      NA    smd        0.0154  
#> 10 Fold3 hp       NA    smd       -0.0498  
#> 11 Fold3 wt       NA    smd        0.0603  
#> 12 Fold3 NA       NA    energy     0.0961  
#> 13 Fold4 mpg      NA    smd        0.00471 
#> 14 Fold4 hp       NA    smd       -0.0734  
#> 15 Fold4 wt       NA    smd        0.000164
#> 16 Fold4 NA       NA    energy     0.105   
summary(balance_check(folds))
#> # A tibble: 4 × 5
#>   id    max_abs_smd variable level energy
#>   <chr>       <dbl> <chr>    <chr>  <dbl>
#> 1 Fold1      0.138  wt       NA    0.212 
#> 2 Fold2      0.0759 mpg      NA    0.118 
#> 3 Fold3      0.0603 wt       NA    0.0961
#> 4 Fold4      0.0734 hp       NA    0.105 

# Compare with ordinary folds
summary(balance_check(rsample::vfold_cv(mtcars, v = 4), mpg, hp, wt))
#> # A tibble: 4 × 5
#>   id    max_abs_smd variable level energy
#>   <chr>       <dbl> <chr>    <chr>  <dbl>
#> 1 Fold1       0.518 hp       NA     0.401
#> 2 Fold2       0.904 hp       NA     0.687
#> 3 Fold3       0.510 wt       NA     0.291
#> 4 Fold4       0.232 hp       NA     0.333
```
