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

* New "Get started" article that walks through a full tidymodels workflow.

* `balanced_vfold_cv()` and `balanced_initial_split()` now reject unknown
  arguments. If you pass `strata`, the error tells you to use `exact`.

* New `balanced_initial_validation_split()` makes a training/validation/testing
  split. All three sets are balanced in one pass. It works with
  `rsample::validation_set()`, `tune::tune_grid()`, and `tune::last_fit()`.

* `balance_check()` now works on three-way splits, including those from
  `rsample::initial_validation_split()`. It compares the validation and
  testing sets each with the training set.

* `method = "twinning"` can now make sets of unequal size from whole numbers
  of similar parts.
