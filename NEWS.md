# balancesample 0.1.0

* First CRAN release.

* `balanced_vfold_cv()`, `balanced_initial_split()`, and
  `balanced_initial_validation_split()` make v-fold cross-validation folds,
  training/testing splits, and training/validation/testing splits that are
  balanced on several variables at once. The three sets of a three-way split
  are balanced in one pass. `exact` stratifies categorical columns exactly,
  and `group` keeps the rows of a group in the same set.

* Four balancing methods: `"anticlust"` (k-plus anticlustering, the
  default), `"twinning"` (data twinning; needs the twinning package),
  `"rerandomize"`, and `"interaction"` (crossed strata, as a baseline).

* With `method = "twinning"`, each set is a whole number of similar parts.
  For a training/testing split, `prop` must be `1/r` or `1 - 1/r` for a whole
  number `r`: write `2 / 3`, not `0.67`. For a three-way split, each
  proportion must be a multiple of `1/m` for one whole number `m` up to 20.

* `balance_check()` reports standardized mean differences and the energy
  distance of balanced splits and of rsample's own splits and resamples. For
  rsample's objects, name the columns to check. A three-way split is checked
  as the validation set and the testing set, each against the training set.
  `autoplot()` plots the result with ggplot2.

* The results work with `tune::fit_resamples()`, `tune::tune_grid()`,
  `tune::last_fit()`, and `rsample::validation_set()`. To tune on balanced
  folds, attach balancesample with `library()`: rsample finds the function
  that made the folds by its name (tidymodels/rsample#619).

* With tune 2.0.0 or later, a postprocessor that must be trained (for
  example, a tailor calibration) is trained on a balanced inner split of each
  balanced fold and of a balanced training/testing split. Two cases are not
  balanced: through `rsample::validation_set()`, the inner split is random
  (tidymodels/rsample#620), and `tune::last_fit()` can't train such a
  postprocessor on any three-way split (tidymodels/tune#1213). Calling
  `rsample::internal_calibration_split()` on a balanced three-way split
  yourself gives a balanced split of its training set.
