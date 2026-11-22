# Balanced training/testing split

`balanced_initial_split()` makes one training/testing split in which the
two sets are similar on several variables at once. Use
[`rsample::training()`](https://rsample.tidymodels.org/reference/initial_split.html)
and
[`rsample::testing()`](https://rsample.tidymodels.org/reference/initial_split.html)
to get the two data sets.

## Usage

``` r
balanced_initial_split(
  data,
  prop = 3/4,
  balance = NULL,
  exact = NULL,
  group = NULL,
  method = "anticlust",
  options = list(),
  na = "error",
  ...
)
```

## Arguments

- data:

  A data frame.

- prop:

  The proportion of data (or of groups, if you use `group`) for the
  training set. With `method = "twinning"`, `prop` must be `1 - 1/r` or
  `1/r` for a whole number `r`, for example 1/2, 2/3, 3/4, 9/10, or 1/4.
  Write it as a fraction such as `2 / 3`, not a rounded decimal such as
  `0.67`. A value within a relative 1e-8 of such a fraction counts as
  that fraction.

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

- na:

  What to do with missing values in the `balance` and `exact` columns.
  `"error"` (the default) stops with an error. `"include"` balances on
  which values are missing; see Missing values. The `group` column must
  not have missing values either way.

- ...:

  Not used. Must be empty.

## Value

An `rsplit` object with class `balanced_initial_split` and
`initial_split`.

## Details

The methods, options, and group handling are the same as for
[`balanced_vfold_cv()`](https://jmgirard.github.io/balancedsample/reference/balanced_vfold_cv.md).
With `method = "twinning"`, the split uses
[`twinning::twin()`](https://rdrr.io/pkg/twinning/man/twin.html), and
the options are `leaf_size` only. Strata with fewer than `2 * r` rows
(or groups) are split at random.

If a workflow has a postprocessor that must be trained,
[`tune::last_fit()`](https://tune.tidymodels.org/reference/last_fit.html)
splits the training set again with `balanced_initial_split()`, using the
same arguments.

## See also

[`balanced_vfold_cv()`](https://jmgirard.github.io/balancedsample/reference/balanced_vfold_cv.md),
[`balance_check()`](https://jmgirard.github.io/balancedsample/reference/balance_check.md)

## Examples

``` r
set.seed(1)
split <- balanced_initial_split(
  sim_patients,
  prop = 3 / 4,
  balance = c(age, income),
  exact = c(diagnosis, site)
)
split
#> # Balanced training/testing split (anticlust), balancing age, income,
#> # stratified by diagnosis, site
#> <Training/Testing/Total>
#> <225/75/300>
head(rsample::training(split))
#>        age    income diagnosis site  outcome
#> 1 45.41686 10059.820      none    A 4.869271
#> 2 23.63934  8132.757      none    C 5.043892
#> 3 45.00346 31997.909      none    C 4.053658
#> 4 56.92559 22235.349      mild    B 8.176950
#> 5 28.47077 14181.133      mild    C 3.617587
#> 6 27.86498  7221.059      none    A 4.605030
```
