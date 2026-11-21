# Balanced training/testing split

`balanced_initial_split()` makes one training/testing split in which the
two sets are similar on several variables at once. Use
[`rsample::training()`](https://rsample.tidymodels.org/reference/initial_split.html)
and
[`rsample::testing()`](https://rsample.tidymodels.org/reference/initial_split.html)
to get the two data sets.

## Usage

``` r
balanced_initial_split(
  data,
  prop = 3/4,
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

- prop:

  The proportion of data (or of groups, if you use `group`) for the
  training set. With `method = "twinning"`, `prop` must be `1 - 1/r` or
  `1/r` for a whole number `r`, for example 1/2, 2/3, 3/4, 9/10, or 1/4.
  Write it as a fraction such as `2 / 3`, not a rounded decimal such as
  `0.67`. A value within a relative 1e-8 of such a fraction counts as
  that fraction.

- balance:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Columns to balance across the sets. Numeric columns are standardized.
  So are `Date`, `POSIXct`, and `difftime` columns, as numbers of days
  or seconds. Factor, character, and logical columns become one
  indicator column per level.

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
  need exact counts within ranges. A stratum whose share of the smallest
  set is under one row (or group) can be missing from some sets. If more
  than half of the strata are missing from at least one set, you get a
  warning.

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

An `rsplit` object with class `balanced_initial_split` and
`initial_split`.

## Details

The methods, options, and group handling are the same as for
[`balanced_vfold_cv()`](https://jmgirard.github.io/balancesample/reference/balanced_vfold_cv.md).
With `method = "twinning"`, the split uses
[`twinning::twin()`](https://rdrr.io/pkg/twinning/man/twin.html), and
the options are `leaf_size` only. Strata with fewer than `2 * r` rows
(or groups) are split at random.

If a workflow has a postprocessor that must be trained,
[`tune::last_fit()`](https://tune.tidymodels.org/reference/last_fit.html)
splits the training set again with `balanced_initial_split()`, using the
same arguments.

## See also

[`balanced_vfold_cv()`](https://jmgirard.github.io/balancesample/reference/balanced_vfold_cv.md),
[`balance_check()`](https://jmgirard.github.io/balancesample/reference/balance_check.md)

## Examples

``` r
set.seed(1)
split <- balanced_initial_split(
  mtcars,
  prop = 3 / 4,
  balance = c(mpg, hp, wt),
  exact = am
)
split
#> # Balanced training/testing split (anticlust), balancing mpg, hp, wt,
#> # stratified by am
#> <Training/Testing/Total>
#> <24/8/32>
rsample::training(split)
#>                     mpg cyl  disp  hp drat    wt  qsec vs am gear carb
#> Mazda RX4 Wag      21.0   6 160.0 110 3.90 2.875 17.02  0  1    4    4
#> Datsun 710         22.8   4 108.0  93 3.85 2.320 18.61  1  1    4    1
#> Hornet 4 Drive     21.4   6 258.0 110 3.08 3.215 19.44  1  0    3    1
#> Hornet Sportabout  18.7   8 360.0 175 3.15 3.440 17.02  0  0    3    2
#> Valiant            18.1   6 225.0 105 2.76 3.460 20.22  1  0    3    1
#> Merc 230           22.8   4 140.8  95 3.92 3.150 22.90  1  0    4    2
#> Merc 280           19.2   6 167.6 123 3.92 3.440 18.30  1  0    4    4
#> Merc 280C          17.8   6 167.6 123 3.92 3.440 18.90  1  0    4    4
#> Merc 450SE         16.4   8 275.8 180 3.07 4.070 17.40  0  0    3    3
#> Merc 450SLC        15.2   8 275.8 180 3.07 3.780 18.00  0  0    3    3
#> Cadillac Fleetwood 10.4   8 472.0 205 2.93 5.250 17.98  0  0    3    4
#> Chrysler Imperial  14.7   8 440.0 230 3.23 5.345 17.42  0  0    3    4
#> Honda Civic        30.4   4  75.7  52 4.93 1.615 18.52  1  1    4    2
#> Toyota Corolla     33.9   4  71.1  65 4.22 1.835 19.90  1  1    4    1
#> Dodge Challenger   15.5   8 318.0 150 2.76 3.520 16.87  0  0    3    2
#> AMC Javelin        15.2   8 304.0 150 3.15 3.435 17.30  0  0    3    2
#> Camaro Z28         13.3   8 350.0 245 3.73 3.840 15.41  0  0    3    4
#> Pontiac Firebird   19.2   8 400.0 175 3.08 3.845 17.05  0  0    3    2
#> Fiat X1-9          27.3   4  79.0  66 4.08 1.935 18.90  1  1    4    1
#> Porsche 914-2      26.0   4 120.3  91 4.43 2.140 16.70  0  1    5    2
#> Lotus Europa       30.4   4  95.1 113 3.77 1.513 16.90  1  1    5    2
#> Ford Pantera L     15.8   8 351.0 264 4.22 3.170 14.50  0  1    5    4
#> Maserati Bora      15.0   8 301.0 335 3.54 3.570 14.60  0  1    5    8
#> Volvo 142E         21.4   4 121.0 109 4.11 2.780 18.60  1  1    4    2
```
