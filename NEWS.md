# balancesample 0.1.0

* First CRAN release.

* `balanced_vfold_cv()`, `balanced_initial_split()`, and
  `balanced_initial_validation_split()` make v-fold cross-validation folds,
  training/testing splits, and training/validation/testing splits that are
  balanced on several variables at once. The three sets of a three-way split
  are balanced in one pass. Columns in `exact` are stratified exactly: in
  each set, the count of each stratum is its proportional share rounded up
  or down. `group` keeps the rows of a group in the same set; then the
  proportions and the exact counts are numbers of groups, not rows. Selected
  columns must not have missing values.

* Four balancing methods: `"anticlust"` (k-plus anticlustering, the
  default), `"twinning"` (data twinning; needs the twinning package),
  `"rerandomize"` (the first of many stratified random splits with a small
  Mahalanobis imbalance), and `"interaction"` (crosses quantile bins of the
  numeric columns with the levels of the categorical ones, pools sparse
  cells, and stratifies at random).

* With `method = "twinning"`, each set is a whole number of similar parts.
  For a training/testing split, `prop` must be `1/r` or `1 - 1/r` for a whole
  number `r`: write `2 / 3`, not `0.67`. For a three-way split, each
  proportion must be a multiple of `1/m` for one whole number `m` up to 20.
  Strata too small for twinning are split at random. See
  `?balanced_initial_split` and `?balanced_vfold_cv` for the limits.

* `balance_check()` reports standardized mean differences and the energy
  distance of balanced splits and of rsample's own splits and resamples. For
  objects that don't store `balance` or `exact` columns, such as those from
  `rsample::vfold_cv()`, name the columns to check. A three-way split is
  checked as the validation set and the testing set, each against the
  training set. `autoplot()` plots the result with ggplot2.

* The results work with `tune::fit_resamples()`, `tune::tune_grid()`,
  `tune::last_fit()`, and `rsample::validation_set()`. To tune on balanced
  folds, attach balancesample with `library()`: rsample finds the function
  that made the folds by its name (tidymodels/rsample#619).

* With tune 2.0.0 or later, a postprocessor that must be trained (for
  example, a tailor calibration) needs an inner split of the analysis set.
  * For balanced folds and a balanced training/testing split, the inner split
    is balanced in the same way as the outer one. If it can't be made (for
    example, if there are too few rows or groups), you get a warning and an
    empty calibration set, as in rsample.
  * Through `rsample::validation_set()`, rsample makes the inner split at
    random, so it is not balanced and can split groups
    (tidymodels/rsample#620).
  * `tune::last_fit()` gives an error on any three-way split
    (tidymodels/tune#1213). Calling `rsample::internal_calibration_split()`
    on a balanced three-way split yourself gives a balanced split of its
    training set.
