# balancesample 0.1.0

* First CRAN release. Later entries in this file list changes from this
  version on.

* `balanced_vfold_cv()`, `balanced_initial_split()`, and
  `balanced_initial_validation_split()` make v-fold cross-validation folds,
  training/testing splits, and training/validation/testing splits that are
  balanced on several variables at once. The three sets of a three-way split
  are balanced in one pass. `exact` stratifies categorical columns exactly,
  and `group` keeps the rows of a group in the same set.

* Four balancing methods: `"anticlust"` (k-plus anticlustering, the
  default), `"twinning"` (data twinning; needs the twinning package),
  `"rerandomize"`, and `"interaction"` (crossed strata, as a baseline).

* `balance_check()` reports standardized mean differences and the energy
  distance for any `rset`, `rsplit`, or three-way split, including those from
  rsample, and `autoplot()` plots them.

* The results work with `tune::fit_resamples()`, `tune::tune_grid()`,
  `tune::last_fit()`, and `rsample::validation_set()`. With tune 2.0.0 or
  later, a postprocessor that must be trained (for example, a tailor
  calibration) is trained on a balanced inner split. Two limits come from
  tune and rsample: attach balancesample with `library()` before tuning
  (tidymodels/rsample#619), and `tune::last_fit()` can't train such a
  postprocessor on any three-way split (tidymodels/tune#1213).
