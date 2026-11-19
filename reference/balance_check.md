# Check the balance of a split or of a set of resamples

`balance_check()` compares the assessment set of each split with its
analysis set. It reports a standardized mean difference (SMD) for each
variable and the energy distance for all variables together. It works
with any `rset` or `rsplit`, so you can compare balanced folds with
ordinary
[`rsample::vfold_cv()`](https://rsample.tidymodels.org/reference/vfold_cv.html)
folds.

## Usage

``` r
balance_check(x, ..., max_n = 2000)

# S3 method for class 'rset'
balance_check(x, ..., max_n = 2000)

# S3 method for class 'rsplit'
balance_check(x, ..., max_n = 2000)
```

## Arguments

- x:

  An `rset` (for example from
  [`balanced_vfold_cv()`](https://jmgirard.github.io/balancesample/reference/balanced_vfold_cv.md))
  or an `rsplit` (for example from
  [`balanced_initial_split()`](https://jmgirard.github.io/balancesample/reference/balanced_initial_split.md)).

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Columns to check. If empty, the `balance` and `exact` columns stored
  in `x` are used.

- max_n:

  The largest number of rows per set for the energy distance. Larger
  sets are subsampled at random to keep memory use low.

## Value

A tibble with class `balance_check`. It has the ID columns of `x`, and
the columns `variable`, `level`, `statistic` (`"smd"` or `"energy"`),
and `value`. Energy rows have `NA` in `variable` and `level`.

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

## Examples

``` r
set.seed(1)
folds <- balanced_vfold_cv(
  mtcars, v = 4, balance = c(mpg, hp, wt), method = "rerandomize"
)
balance_check(folds)
#> # Balance check: 4 splits, max |SMD| = 0.508, mean energy distance = 0.313
#> # A tibble: 16 × 5
#>    id    variable level statistic  value
#>    <chr> <chr>    <chr> <chr>      <dbl>
#>  1 Fold1 mpg      NA    smd       -0.242
#>  2 Fold1 hp       NA    smd        0.244
#>  3 Fold1 wt       NA    smd        0.317
#>  4 Fold1 NA       NA    energy     0.220
#>  5 Fold2 mpg      NA    smd        0.223
#>  6 Fold2 hp       NA    smd       -0.168
#>  7 Fold2 wt       NA    smd       -0.380
#>  8 Fold2 NA       NA    energy     0.164
#>  9 Fold3 mpg      NA    smd        0.425
#> 10 Fold3 hp       NA    smd       -0.154
#> 11 Fold3 wt       NA    smd       -0.332
#> 12 Fold3 NA       NA    energy     0.496
#> 13 Fold4 mpg      NA    smd       -0.508
#> 14 Fold4 hp       NA    smd        0.118
#> 15 Fold4 wt       NA    smd        0.424
#> 16 Fold4 NA       NA    energy     0.371

# Compare with ordinary folds
balance_check(rsample::vfold_cv(mtcars, v = 4), mpg, hp, wt)
#> # Balance check: 4 splits, max |SMD| = 0.461, mean energy distance = 0.224
#> # A tibble: 16 × 5
#>    id    variable level statistic   value
#>    <chr> <chr>    <chr> <chr>       <dbl>
#>  1 Fold1 mpg      NA    smd        0.437 
#>  2 Fold1 hp       NA    smd       -0.339 
#>  3 Fold1 wt       NA    smd       -0.461 
#>  4 Fold1 NA       NA    energy     0.345 
#>  5 Fold2 mpg      NA    smd       -0.232 
#>  6 Fold2 hp       NA    smd        0.236 
#>  7 Fold2 wt       NA    smd        0.0354
#>  8 Fold2 NA       NA    energy     0.191 
#>  9 Fold3 mpg      NA    smd        0.0839
#> 10 Fold3 hp       NA    smd       -0.0976
#> 11 Fold3 wt       NA    smd        0.0562
#> 12 Fold3 NA       NA    energy     0.0758
#> 13 Fold4 mpg      NA    smd       -0.272 
#> 14 Fold4 hp       NA    smd        0.184 
#> 15 Fold4 wt       NA    smd        0.301 
#> 16 Fold4 NA       NA    energy     0.282 
```
