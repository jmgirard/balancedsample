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
  [`tune::fit_resamples()`](https://tune.tidymodels.org/reference/fit_resamples.html),
  [`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html),
  and
  [`tune::last_fit()`](https://tune.tidymodels.org/reference/last_fit.html).
  The inner calibration split is balanced with the same settings as the
  outer split. This needs rsample 1.3.1 or later.

- [`labels()`](https://rdrr.io/r/base/labels.html) of repeated folds now
  combines the repeat and fold IDs, as it does for
  [`rsample::vfold_cv()`](https://rsample.tidymodels.org/reference/vfold_cv.html).
