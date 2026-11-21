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
  Factor, character, and logical columns become one indicator column per
  level.

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
  need exact counts within ranges.

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
    each row may swap with. `Inf` tries every swap. A small number, such
    as 20, is faster on large data.

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

The method balances the columns left after standardizing: constant and
nearly constant columns (standard deviation up to 1e-12) are dropped,
and with `group`, so are columns whose group means are all equal (see
Groups). If none are left, for example with only `exact` columns and no
`group`, the method doesn't run and the sets are drawn at random, within
the `exact` strata if there are any. The limits the method itself
checks, such as twinning's strategy 2 needing a power of 2, then don't
apply. The options are still checked, and the split functions still
check that twinning can make `prop`.

## Groups

If you use `group`, each group becomes one row before the method runs.
This row holds the group means of the standardized `balance` columns and
the log of the group size. The group size is added only if a `balance`
column is left after standardizing or there are `exact` columns, and it
is dropped if all groups have the same size. The method assigns groups,
and then each row gets the set of its group. The number of groups per
set follows the target proportions, so the number of rows per set is
only approximate. `exact` columns must be constant within each group.

## Use with tune

tune and
[`rsample::reshuffle_rset()`](https://rsample.tidymodels.org/reference/reshuffle_rset.html)
find the function that made an `rset` by its class name. They only find
`balanced_vfold_cv()` when balancesample is attached with
[`library(balancesample)`](https://github.com/jmgirard/balancesample).
If you call `balancesample::balanced_vfold_cv()` without attaching the
package,
[`tune::fit_resamples()`](https://tune.tidymodels.org/reference/fit_resamples.html)
and
[`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html)
fail with "Could not find function".

If a workflow has a postprocessor that must be trained, such as a
calibration from the tailor package, tune splits each analysis set
again. That inner split is a
[`balanced_initial_split()`](https://jmgirard.github.io/balancesample/reference/balanced_initial_split.md)
with the same `balance`, `exact`, `group`, `method`, and `options`
(without twinning's `strategy`), and with `prop = 1 - 1/v`.

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

[`balanced_initial_split()`](https://jmgirard.github.io/balancesample/reference/balanced_initial_split.md),
[`balance_check()`](https://jmgirard.github.io/balancesample/reference/balance_check.md)

## Examples

``` r
set.seed(1)
folds <- balanced_vfold_cv(
  mtcars,
  v = 4,
  balance = c(mpg, hp, wt),
  exact = am
)
folds
#> # 4-fold balanced cross-validation (anticlust), stratified by am
#> # A tibble: 4 × 2
#>   splits         id   
#>   <list>         <chr>
#> 1 <split [24/8]> Fold1
#> 2 <split [24/8]> Fold2
#> 3 <split [24/8]> Fold3
#> 4 <split [24/8]> Fold4
balance_check(folds)
#> # Balance check: 4 splits, max |SMD| = 0.243, mean energy distance = 0.188
#> # A tibble: 20 × 5
#>    id    variable level statistic    value
#>    <chr> <chr>    <chr> <chr>        <dbl>
#>  1 Fold1 mpg      NA    smd       -0.0550 
#>  2 Fold1 hp       NA    smd       -0.0404 
#>  3 Fold1 wt       NA    smd       -0.0601 
#>  4 Fold1 am       NA    smd       -0.0816 
#>  5 Fold1 NA       NA    energy     0.234  
#>  6 Fold2 mpg      NA    smd       -0.0142 
#>  7 Fold2 hp       NA    smd        0.0442 
#>  8 Fold2 wt       NA    smd        0.0234 
#>  9 Fold2 am       NA    smd        0.243  
#> 10 Fold2 NA       NA    energy     0.129  
#> 11 Fold3 mpg      NA    smd        0.0614 
#> 12 Fold3 hp       NA    smd        0.0481 
#> 13 Fold3 wt       NA    smd       -0.00323
#> 14 Fold3 am       NA    smd       -0.0816 
#> 15 Fold3 NA       NA    energy     0.248  
#> 16 Fold4 mpg      NA    smd        0.00727
#> 17 Fold4 hp       NA    smd       -0.0563 
#> 18 Fold4 wt       NA    smd        0.0382 
#> 19 Fold4 am       NA    smd       -0.0816 
#> 20 Fold4 NA       NA    energy     0.140  

# Other methods
balanced_vfold_cv(
  mtcars,
  v = 4,
  balance = c(mpg, hp),
  method = "rerandomize"
)
#> # 4-fold balanced cross-validation (rerandomize)
#> # A tibble: 4 × 2
#>   splits         id   
#>   <list>         <chr>
#> 1 <split [24/8]> Fold1
#> 2 <split [24/8]> Fold2
#> 3 <split [24/8]> Fold3
#> 4 <split [24/8]> Fold4
balanced_vfold_cv(mtcars, v = 4, balance = c(mpg, hp), method = "twinning")
#> # 4-fold balanced cross-validation (twinning)
#> # A tibble: 4 × 2
#>   splits         id   
#>   <list>         <chr>
#> 1 <split [24/8]> Fold1
#> 2 <split [24/8]> Fold2
#> 3 <split [24/8]> Fold3
#> 4 <split [24/8]> Fold4
```
