# Balanced V-fold cross-validation

`balanced_vfold_cv()` splits the data into `v` folds of about equal size
that are similar on several variables at once. Each fold is used once as
the assessment set, and the other folds form the analysis set.

## Usage

``` r
balanced_vfold_cv(
  data,
  v = 10,
  repeats = 1,
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

- v:

  The number of folds.

- repeats:

  The number of times to repeat the V-fold partitioning.

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

A tibble with class `balanced_vfold_cv` and `rset`. It has a `splits`
column of `rsplit` objects and one or two ID columns.

## Methods

- `"anticlust"` (default) uses k-plus anticlustering (Papenberg, 2024)
  with
  [`anticlust::fast_anticlustering()`](https://m-py.github.io/anticlust/reference/fast_anticlustering.html).
  It makes the means and the variances of the sets similar. Options are:

  - `moments` (default 2): the highest moment to balance. 1 balances
    means only, 3 adds skewness, and 4 adds kurtosis.

  - `covariances` (default `FALSE`): also balance the product of each
    pair of `balance` columns.

  - `k_neighbours` (default `Inf`): the number of nearest neighbours
    each row may swap with. `Inf` tries every swap, so the run time
    grows quickly with the number of rows. A small number, such as 20,
    is much faster on large data, but categorical `balance` columns can
    end up less balanced. Check the result with
    [`balance_check()`](https://jmgirard.github.io/balancedsample/reference/balance_check.md).

  - `local_maximum` (default `TRUE`): repeat the exchange passes until a
    pass makes no swap (at most 100 passes). `FALSE` runs one pass.

  - `repetitions` (default 1): the number of random starts. The best
    result is kept.

- `"twinning"` uses
  [`twinning::multiplet()`](https://rdrr.io/pkg/twinning/man/multiplet.html)
  for folds, or
  [`twinning::twin()`](https://rdrr.io/pkg/twinning/man/twin.html) for
  `v = 2` with strategy 1 or 2, which then give the same result. Options
  are `strategy` (1, 2, or 3; strategy 2 needs `v` to be a power of 2)
  and `leaf_size`. Strata with fewer than `2 * v` rows (or groups) are
  assigned at random. The twinning package is required.

- `"rerandomize"` draws stratified random splits and keeps the first one
  whose Mahalanobis imbalance is under a threshold (Morgan and Rubin,
  2012). For folds, the imbalance is the largest over the "one fold
  versus the rest" comparisons. The threshold is the `p_accept` quantile
  of the imbalance over pilot draws made with the same `exact` and
  `group` constraints
  (`max(100, min(ceiling(10 / p_accept), max_draws))` draws). Draws that
  tie with the threshold are accepted at random, so that the acceptance
  rate is close to `p_accept` even for discrete data. If `p_accept` is
  below `1 / max(100, max_draws)`, the pilot draws can't resolve it, and
  the threshold is the best pilot draw. Options are `p_accept`, the
  target acceptance rate (default 0.1), and `max_draws` (default 1000).
  If no draw meets the threshold, the best draw is used with a warning.

- `"interaction"` cuts numeric columns into quantile bins, crosses all
  bins, and stratifies at random. It is a baseline that shows how
  crossed strata become sparse. Options are `n_bins` (default 4) and
  `pool` (default 0.1): cells with less than this fraction of the rows
  are pooled.

The method balances the columns left after standardizing: constant
columns are dropped, and with `group`, so are columns whose group means
are all equal up to rounding error (see Groups). If none are left, for
example with only `exact` columns and no `group`, the method doesn't run
and the sets are drawn at random, within the `exact` strata if there are
any. The limits the method itself checks, such as twinning's strategy 2
needing a power of 2, then don't apply. The options are still checked,
and the split functions still check that twinning can make `prop`.

## Groups

If you use `group`, each group becomes one row before the method runs.
This row holds the group means of the standardized `balance` columns and
the log of the group size. The group size is added only if a `balance`
column is left after standardizing or there are `exact` columns, and it
is dropped if all groups have the same size. The method assigns groups,
and then each row gets the set of its group. The number of groups per
set follows the target proportions, so the number of rows per set is
only approximate. `exact` columns must be constant within each group.

## Missing values

With `na = "include"`, rows with missing values stay in the split, and
the method also balances how often each column is missing. The data in
the split keep their missing values, so your model can handle them its
own way, for example with a recipe.

- In a numeric, logical, `Date`, `POSIXct`, or `difftime` column in
  `balance`, missing values get the mean of the observed values, and an
  indicator column of which values are missing is balanced too. With the
  share missing balanced, balancing the filled column also balances the
  mean of the observed values. The filled values all sit at the mean, so
  the spread of the observed values is balanced less closely.

- In a factor or character column in `balance`, a missing value is one
  more level.

- In `exact`, a missing value is one more level, so the rows with a
  missing value in a column are spread over the sets by exact counts
  like any other stratum. With `group`, a missing value counts as a
  level when `exact` columns are checked for being constant within each
  group, so a group with some rows at site "A" and some with a missing
  site is an error.

Each indicator column is standardized like the other columns. When few
values are missing, the rows with a missing value are far from the rest
on that column (about 10 standard deviations at 1% missing), as rows of
a rare level are. A column with no observed values is an error.

Rows with a missing `group` ID could belong to one unit or to several,
so `group` must not have missing values. Give those rows their own IDs,
or one shared ID, depending on which is true.

## Use with tune

tune and
[`rsample::reshuffle_rset()`](https://rsample.tidymodels.org/reference/reshuffle_rset.html)
find the function that made an `rset` by its class name. They only find
`balanced_vfold_cv()` when balancedsample is attached with
[`library(balancedsample)`](https://github.com/jmgirard/balancedsample).
If you call `balancedsample::balanced_vfold_cv()` without attaching the
package,
[`tune::fit_resamples()`](https://tune.tidymodels.org/reference/fit_resamples.html)
and
[`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html)
fail with "Could not find function".

If a workflow has a postprocessor that must be trained, such as a
calibration from the tailor package, tune splits each analysis set
again. That inner split is a
[`balanced_initial_split()`](https://jmgirard.github.io/balancedsample/reference/balanced_initial_split.md)
with the same `balance`, `exact`, `group`, `na`, `method`, and `options`
(without twinning's `strategy`), and with `prop = 1 - 1/v`. With
`na = "include"`, a column with no observed values in the analysis set
is left out of the inner split.

## References

Morgan, K. L., & Rubin, D. B. (2012). Rerandomization to improve
covariate balance in experiments. *The Annals of Statistics, 40*(2),
1263-1282. [doi:10.1214/12-AOS1008](https://doi.org/10.1214/12-AOS1008)

Papenberg, M. (2024). K-plus anticlustering: An improved k-means
criterion for maximizing between-group similarity. *British Journal of
Mathematical and Statistical Psychology, 77*(1), 80-102.
[doi:10.1111/bmsp.12315](https://doi.org/10.1111/bmsp.12315)

Papenberg, M., & Klau, G. W. (2021). Using anticlustering to partition
data sets into equivalent parts. *Psychological Methods, 26*(2),
161-174. [doi:10.1037/met0000301](https://doi.org/10.1037/met0000301)

Vakayil, A., & Joseph, V. R. (2022). Data twinning. *Statistical
Analysis and Data Mining, 15*(5), 598-610.
[doi:10.1002/sam.11574](https://doi.org/10.1002/sam.11574)

## See also

[`balanced_initial_split()`](https://jmgirard.github.io/balancedsample/reference/balanced_initial_split.md),
[`balance_check()`](https://jmgirard.github.io/balancedsample/reference/balance_check.md)

## Examples

``` r
set.seed(1)
folds <- balanced_vfold_cv(
  sim_patients,
  v = 5,
  balance = c(age, income),
  exact = c(diagnosis, site)
)
folds
#> # 5-fold balanced cross-validation (anticlust), balancing age, income,
#> # stratified by diagnosis, site
#> # A tibble: 5 × 2
#>   splits           id   
#>   <list>           <chr>
#> 1 <split [240/60]> Fold1
#> 2 <split [240/60]> Fold2
#> 3 <split [240/60]> Fold3
#> 4 <split [240/60]> Fold4
#> 5 <split [240/60]> Fold5
balance_check(folds)
#> # Balance check: 5 splits, 4 variables
#> # 0 of 5 splits have a variable with |SMD| > 0.1, mean energy distance 0.031
#> 
#> id     max |SMD|  variable         mean |SMD|  over 0.1  energy
#> Fold1     0.026   site: C             0.00967       0/4  0.0277
#> Fold2     0.026   site: A             0.00941       0/4  0.0361
#> Fold3     0.0373  diagnosis: mild     0.0187        0/4  0.0276
#> Fold4     0.026   site: C             0.00955       0/4  0.0309
#> Fold5     0.026   site: A             0.0091        0/4  0.0327
#> 
#> # summary() gives this table as a tibble, and tibble::as_tibble() gives all
#> # 45 rows.

# Other methods
balanced_vfold_cv(
  sim_patients,
  v = 5,
  balance = c(age, income),
  method = "rerandomize"
)
#> # 5-fold balanced cross-validation (rerandomize), balancing age, income
#> # A tibble: 5 × 2
#>   splits           id   
#>   <list>           <chr>
#> 1 <split [240/60]> Fold1
#> 2 <split [240/60]> Fold2
#> 3 <split [240/60]> Fold3
#> 4 <split [240/60]> Fold4
#> 5 <split [240/60]> Fold5
balanced_vfold_cv(
  sim_patients,
  v = 5,
  balance = c(age, income),
  method = "twinning"
)
#> # 5-fold balanced cross-validation (twinning), balancing age, income
#> # A tibble: 5 × 2
#>   splits           id   
#>   <list>           <chr>
#> 1 <split [240/60]> Fold1
#> 2 <split [240/60]> Fold2
#> 3 <split [240/60]> Fold3
#> 4 <split [240/60]> Fold4
#> 5 <split [240/60]> Fold5
```
