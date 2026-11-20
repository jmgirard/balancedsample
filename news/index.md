# Changelog

## balancesample 0.0.0.9000

- First draft of the package:
  [`balanced_vfold_cv()`](https://jmgirard.github.io/balancesample/reference/balanced_vfold_cv.md),
  [`balanced_initial_split()`](https://jmgirard.github.io/balancesample/reference/balanced_initial_split.md),
  [`balance_check()`](https://jmgirard.github.io/balancesample/reference/balance_check.md),
  and four balancing methods (`"anticlust"`, `"twinning"`,
  `"rerandomize"`, `"interaction"`).

- Workflows with a postprocessor that must be trained (for example, a
  tailor calibration) now work with
  [`tune::fit_resamples()`](https://tune.tidymodels.org/reference/fit_resamples.html)
  and
  [`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html)
  on balanced folds, and with
  [`tune::last_fit()`](https://tune.tidymodels.org/reference/last_fit.html)
  on balanced training/testing splits. The inner calibration split uses
  the same balance columns, exact strata, groups, method, and options as
  the outer split, without twinning’s `strategy` option. This needs
  rsample 1.3.1 or later.

- [`labels()`](https://rdrr.io/r/base/labels.html) of repeated folds now
  combines the repeat and fold IDs, as it does for
  [`rsample::vfold_cv()`](https://rsample.tidymodels.org/reference/vfold_cv.html).

- New “Get started” article that walks through a full tidymodels
  workflow.

- [`balanced_vfold_cv()`](https://jmgirard.github.io/balancesample/reference/balanced_vfold_cv.md)
  and
  [`balanced_initial_split()`](https://jmgirard.github.io/balancesample/reference/balanced_initial_split.md)
  now reject unknown arguments. If you pass `strata`, the error tells
  you to use `exact`.

- New
  [`balanced_initial_validation_split()`](https://jmgirard.github.io/balancesample/reference/balanced_initial_validation_split.md)
  makes a training/validation/testing split. All three sets are balanced
  in one pass. It works with
  [`rsample::validation_set()`](https://rsample.tidymodels.org/reference/validation_set.html),
  [`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html),
  and
  [`tune::last_fit()`](https://tune.tidymodels.org/reference/last_fit.html).

- [`balance_check()`](https://jmgirard.github.io/balancesample/reference/balance_check.md)
  now works on three-way splits, including those from
  [`rsample::initial_validation_split()`](https://rsample.tidymodels.org/reference/initial_validation_split.html).
  It compares the validation and testing sets each with the training
  set.

- `method = "twinning"` can now make sets of unequal size from whole
  numbers of similar parts.

- With `method = "twinning"`,
  [`balanced_initial_split()`](https://jmgirard.github.io/balancesample/reference/balanced_initial_split.md)
  now checks that `prop` is a fraction twinning can make before it
  rounds the set sizes, so the check no longer depends on the data size.
  Before, a `prop` such as 0.7 could pass on small data because of
  rounding. Write `prop` as a fraction, such as `2 / 3`, not `0.67`. A
  value within a relative 1e-8 of a fraction counts as that fraction.

- [`rsample::internal_calibration_split()`](https://rsample.tidymodels.org/reference/internal_calibration_split.html)
  on a twinning three-way split now uses the nearest training share that
  twinning can make (for example 5/6 instead of 14/17). Before, such
  shares gave a warning and an empty calibration set. That still happens
  when the training set can’t be split, for example when it has fewer
  than two groups.
