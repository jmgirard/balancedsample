# Plot a balance check

Plot the output of
[`balance_check()`](https://jmgirard.github.io/balancedsample/reference/balance_check.md).
`type = "smd"` shows the standardized mean difference of each variable
in each split. A grey band around each variable shows how far its
largest absolute SMD went in 95% of random sets of the same sizes
(`"chance_q95"`, the median over the splits), so points well inside the
band are better balanced than chance. Without the chance reference (with
`chance = 0`), dashed lines at -0.1 and 0.1 are drawn instead. For a
three-way split, the validation and testing sets have different shapes.
`type = "energy"` shows the energy distance of each split.

## Usage

``` r
# S3 method for class 'balance_check'
autoplot(object, type = c("smd", "energy"), ...)
```

## Arguments

- object:

  A `balance_check` object.

- type:

  `"smd"` or `"energy"`.

- ...:

  Not used.

## Value

A ggplot object.

## Examples

``` r
library(ggplot2)
set.seed(1)
folds <- balanced_vfold_cv(
  sim_patients,
  v = 5,
  balance = c(age, income, diagnosis)
)
autoplot(balance_check(folds))

autoplot(balance_check(folds), type = "energy")
```
