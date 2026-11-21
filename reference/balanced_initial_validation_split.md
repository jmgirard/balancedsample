# Balanced training/validation/testing split

`balanced_initial_validation_split()` makes one three-way split in which
the training, validation, and testing sets are similar on several
variables at once. Use
[`rsample::training()`](https://rsample.tidymodels.org/reference/initial_split.html),
[`rsample::validation()`](https://rsample.tidymodels.org/reference/initial_validation_split.html),
and
[`rsample::testing()`](https://rsample.tidymodels.org/reference/initial_split.html)
to get the three data sets, and
[`rsample::validation_set()`](https://rsample.tidymodels.org/reference/validation_set.html)
to tune on the validation set.

## Usage

``` r
balanced_initial_validation_split(
  data,
  prop = c(0.6, 0.2),
  balance = NULL,
  exact = NULL,
  group = NULL,
  method = "anticlust",
  options = list(),
  ...
)
```

## Arguments

- data:

  A data frame.

- prop:

  A vector of two proportions: the first for the training set and the
  second for the validation set. The rest of the data goes to the
  testing set. With `group`, these are proportions of groups. With
  `method = "twinning"`, each of the three proportions must be a
  multiple of `1/m` for one whole number `m` up to 20, for example
  `c(0.6, 0.2)` (`m = 5`) or `c(0.5, 0.25)` (`m = 4`).

- balance:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Columns to balance across the sets. Numeric columns are standardized.
  So are `Date`, `POSIXct`, and `difftime` columns, as numbers of days
  or seconds. Factor, character, and logical columns become one
  indicator column per level.

- exact:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Categorical columns to stratify exactly. Each combination of levels is
  one stratum. In each stratum, the count in every set is the floor or
  the ceiling of its proportional share, based on the actual size of
  that set. For folds, the counts of a stratum also differ by at most
  one over the folds whenever both rules can hold at once. With `group`,
  these counts are numbers of groups, not rows. `exact` does the job of
  `strata` in rsample, but it takes several columns and its counts are
  exact. Numeric columns with whole-number values are treated as
  categories. Put continuous columns in `balance`, or use
  [`cut()`](https://rdrr.io/r/base/cut.html) to make a factor if you
  need exact counts within ranges. A stratum whose share of the smallest
  set is under one row (or group) can be missing from some sets. If more
  than half of the strata are missing from at least one set, you get a
  warning.

- group:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  One column with group IDs. All rows of a group go to the same set. See
  Details.

- method:

  The balancing method: `"anticlust"`, `"twinning"`, `"rerandomize"`, or
  `"interaction"`. See Details.

- options:

  A named list of options for the method. See Details.

- ...:

  Not used. Must be empty.

## Value

A `three_way_split` object with class
`balanced_initial_validation_split` and `initial_validation_split`.

## Details

The three sets are made in one pass, so each one is balanced against the
other two. rsample's
[`rsample::initial_validation_split()`](https://rsample.tidymodels.org/reference/initial_validation_split.html)
instead splits off the training set first and then splits the rest.

The methods, options, and group handling are the same as for
[`balanced_vfold_cv()`](https://jmgirard.github.io/balancesample/reference/balanced_vfold_cv.md).
With `method = "twinning"`, the data are split into `m` similar parts
with
[`twinning::multiplet()`](https://rdrr.io/pkg/twinning/man/multiplet.html),
and each set gets a whole number of parts. `strategy` 2 needs `m` to be
a power of 2. Strata with fewer than `2 * m` rows (or groups) are split
at random.

## Use with tune

[`rsample::validation_set()`](https://rsample.tidymodels.org/reference/validation_set.html)
turns the split into an `rset` for
[`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html)
and
[`tune::fit_resamples()`](https://tune.tidymodels.org/reference/fit_resamples.html).
[`tune::last_fit()`](https://tune.tidymodels.org/reference/last_fit.html)
(tune 1.1.2 or later) takes the split itself and fits on the training
set, or on the training and validation sets with
`add_validation_set = TRUE`.

If a workflow has a postprocessor that must be trained, tune splits the
training set again. Through
[`rsample::validation_set()`](https://rsample.tidymodels.org/reference/validation_set.html),
rsample makes that inner split at random, without balancing.
[`tune::last_fit()`](https://tune.tidymodels.org/reference/last_fit.html)
can't train such a postprocessor on any three-way split, including those
from
[`rsample::initial_validation_split()`](https://rsample.tidymodels.org/reference/initial_validation_split.html)
(as of tune 2.1.0).

Calling
[`rsample::internal_calibration_split()`](https://rsample.tidymodels.org/reference/internal_calibration_split.html)
on this split yourself gives a balanced split of the training set. As in
rsample, `prop[1] / sum(prop)` of the training set goes to the first
part and the rest to the calibration set. With `method = "twinning"`,
this share is rounded to the nearest `1 - 1/r` (or `1/r`, below 1/2) for
a whole number `r`, for example 14/17 to 5/6. As in rsample, if the
training set can't be split, you get a warning and an empty calibration
set.

## See also

[`balanced_initial_split()`](https://jmgirard.github.io/balancesample/reference/balanced_initial_split.md),
[`balance_check()`](https://jmgirard.github.io/balancesample/reference/balance_check.md)

## Examples

``` r
set.seed(1)
split <- balanced_initial_validation_split(
  mtcars,
  prop = c(0.6, 0.2),
  balance = c(mpg, hp, wt),
  exact = am
)
split
#> # Balanced training/validation/testing split (anticlust), balancing mpg, hp, wt,
#> # stratified by am
#> <Training/Validation/Testing/Total>
#> <19/7/6/32>
balance_check(split)
#> # Balance check: 2 splits, max |SMD| = 0.286, mean energy distance = 0.32
#> # A tibble: 12 × 5
#>    id         variable level statistic    value
#>    <chr>      <chr>    <chr> <chr>        <dbl>
#>  1 Validation mpg      NA    smd        0.00158
#>  2 Validation hp       NA    smd       -0.105  
#>  3 Validation wt       NA    smd       -0.0231 
#>  4 Validation am       0     smd        0.286  
#>  5 Validation am       1     smd       -0.286  
#>  6 Validation NA       NA    energy     0.408  
#>  7 Testing    mpg      NA    smd        0.0343 
#>  8 Testing    hp       NA    smd       -0.0188 
#>  9 Testing    wt       NA    smd        0.124  
#> 10 Testing    am       0     smd       -0.159  
#> 11 Testing    am       1     smd        0.159  
#> 12 Testing    NA       NA    energy     0.232  
rsample::validation_set(split)
#> # A tibble: 1 × 2
#>   splits         id        
#>   <list>         <chr>     
#> 1 <split [19/7]> validation
```
