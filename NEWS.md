# balancesample 0.1.0

* First CRAN release.

* `balanced_vfold_cv()`, `balanced_initial_split()`, and
  `balanced_initial_validation_split()` make v-fold cross-validation folds,
  training/testing splits, and training/validation/testing splits that are
  balanced on several variables at once. The three sets of a three-way split
  are balanced in one pass. Columns in `exact` are stratified exactly: each
  combination of their levels is a stratum, and its count in each set is its
  share of that set's actual size, rounded up or down. `group` keeps the rows
  of a group in the same set; then the proportions and the exact counts are
  numbers of groups, and `exact` columns must be constant within each group.
  Selected columns must not have missing values.

* Four balancing methods: `"anticlust"` (k-plus anticlustering, the
  default), `"twinning"` (data twinning; needs the twinning package),
  `"rerandomize"` (keeps the first stratified random split whose Mahalanobis
  imbalance is under a threshold set from pilot draws), and `"interaction"`
  (crosses quantile bins of the balance columns and stratifies at random).

* With `method = "twinning"`, a training/testing split needs `prop = 1/r` or
  `1 - 1/r` for a whole number `r`: write `2 / 3`, not `0.67`. In a
  three-way split, each proportion must be a multiple of `1/m` for one whole
  number `m` up to 20. Strata with fewer than twice as many rows (or groups)
  as parts are split at random.

* `balance_check()` reports standardized mean differences and the energy
  distance of balanced splits and of rsample's own splits and resamples. For
  objects that don't store `balance` or `exact` columns, such as those from
  `rsample::vfold_cv()`, name the columns to check. A three-way split is
  checked as the validation set and the testing set, each against the
  training set. `autoplot()` plots the result with ggplot2.

* Balanced folds work with `tune::fit_resamples()` and `tune::tune_grid()`,
  and balanced splits with `tune::last_fit()`. To tune on the validation set
  of a balanced three-way split, pass it to `rsample::validation_set()`
  first. To tune on balanced folds, attach balancesample with `library()`:
  rsample finds the function that made the folds by its name
  ([tidymodels/rsample#619](https://github.com/tidymodels/rsample/issues/619)).

* With tune 2.0.0 or later, a postprocessor that must be trained (for
  example, a tailor calibration) needs an inner split of the analysis set.
  * For balanced folds and a balanced training/testing split, the inner split
    uses the outer split's method, columns, and options (without twinning's
    `strategy`). If it can't be made (for example, if there are too few rows
    or groups), you get a warning and an empty calibration set, as in
    rsample.
  * Through `rsample::validation_set()`, rsample makes the inner split at
    random, so it is not balanced and can split groups
    ([tidymodels/rsample#620](https://github.com/tidymodels/rsample/issues/620)).
  * `tune::last_fit()` can't train such a postprocessor on any three-way
    split
    ([tidymodels/tune#1213](https://github.com/tidymodels/tune/issues/1213)).
