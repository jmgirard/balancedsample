# balancesample 0.0.0.9000

* First draft of the package: `balanced_vfold_cv()`, `balanced_initial_split()`,
  `balance_check()`, and four balancing methods (`"anticlust"`, `"twinning"`,
  `"rerandomize"`, `"interaction"`).

* Workflows with a postprocessor that must be trained (for example, a tailor
  calibration) now work with `tune::fit_resamples()`, `tune::tune_grid()`, and
  `tune::last_fit()`. The inner calibration split is balanced with the same
  settings as the outer split. This needs rsample 1.3.1 or later.

* `labels()` of repeated folds now combines the repeat and fold IDs, as it
  does for `rsample::vfold_cv()`.
