# Get started with balancesample

This article walks through a modeling project with balancesample: a
balanced training/testing split, balanced folds on the training set,
tuning with tune, and a final fit. It also shows how to choose the
columns to balance, how to check the result, and how to choose a method.

## The data

The example uses simulated data from 300 patients at three sites. Age
and income are skewed, and diagnosis has a rare level. The outcome
depends on age, income, and diagnosis.

``` r

library(balancesample)

set.seed(2026)
n <- 300
d <- data.frame(
  age = rgamma(n, shape = 4, rate = 0.1),
  income = rlnorm(n, meanlog = 10, sdlog = 0.6),
  diagnosis = factor(sample(
    c("none", "mild", "severe"),
    n,
    replace = TRUE,
    prob = c(0.6, 0.3, 0.1)
  )),
  site = factor(sample(c("A", "B", "C"), n, replace = TRUE))
)
severe <- d$diagnosis == "severe"
d$outcome <- 0.05 * d$age + 0.3 * log(d$income) + 1.5 * severe + rnorm(n)
```

## Why balance?

In tidymodels, a modeling project usually starts with
[`rsample::initial_split()`](https://rsample.tidymodels.org/reference/initial_split.html),
which holds out a test set, and
[`rsample::vfold_cv()`](https://rsample.tidymodels.org/reference/vfold_cv.html),
which makes cross-validation folds from the training set. Both take
`strata`, which stratifies on one column: each set gets about the same
share of each of its levels. (By default, a numeric column with more
than five distinct values is first cut into up to four bins. Otherwise,
the rows of levels with under 10% of the rows are spread at random over
the other levels.) But what if you want the sets to be similar on
several variables at once? Here, we might want every fold to have
similar ages, incomes, diagnoses, and sites. With 300 rows and 10 folds,
each held-out fold has only about 30 rows, so folds stratified on
diagnosis alone can still differ on the other variables, as the output
below shows.

[`balance_check()`](https://jmgirard.github.io/balancesample/reference/balance_check.md)
measures how similar the sets are. For each fold, it compares the
held-out rows with the other rows in two ways:

- The standardized mean difference (SMD) is computed for each variable
  on its own. It is the difference in means (held-out rows minus the
  other rows) divided by the pooled standard deviation. For a
  categorical variable, there is one SMD per level, from the proportions
  of that level. An absolute SMD under 0.1 is a common rule of thumb for
  good balance.
- The energy distance compares all the variables at once. It turns each
  level of a categorical variable into a 0/1 column, standardizes all
  the columns, and then looks at the distances between rows. It is twice
  the average distance between a row of one set and a row of the other,
  minus the average distance between two rows of the same set (once for
  each set, counting each row paired with itself). It is 0 when the two
  sets have the same distribution, and it grows as they differ. Unlike
  the SMD, it also picks up differences in spread and shape, and in how
  the variables relate to each other. It has no fixed cutoff like 0.1,
  so use it to compare splits of the same data on the same variables.

For each fold,
[`balance_check()`](https://jmgirard.github.io/balancesample/reference/balance_check.md)
returns one SMD row per numeric variable, one per level of each
categorical variable, and one energy row. Printing the result shows one
row per fold. Each variable first counts with its largest absolute SMD,
so a variable with three levels counts once, like a numeric one. The row
then gives the largest absolute SMD and the variable it belongs to, the
mean over the variables, how many of them are over 0.1, and the energy
distance. [`summary()`](https://rdrr.io/r/base/summary.html) returns the
same numbers as a tibble. The largest SMD shows which variable to look
at. The mean is steadier for comparing splits, because the largest grows
with the number of variables checked. Here are ordinary folds from
rsample, stratified on diagnosis. For these, you list the columns to
check:

``` r

random_folds <- rsample::vfold_cv(d, v = 10, strata = diagnosis)
random_check <- balance_check(random_folds, age, income, diagnosis, site)
random_check
#> # Balance check: 10 splits, 4 variables
#> # 10 of 10 splits have a variable with |SMD| > 0.1,
#> # mean energy distance 0.105
#> 
#> id      max |SMD|  variable  mean |SMD|  over 0.1  energy
#> Fold01      0.349  income        0.158        3/4  0.0695
#> Fold02      0.171  age           0.126        3/4  0.0696
#> Fold03      0.158  site: C       0.112        3/4  0.0707
#> Fold04      0.239  site: A       0.0774       1/4  0.0771
#> Fold05      0.191  site: B       0.0994       2/4  0.0946
#> Fold06      0.198  age           0.146        3/4  0.0877
#> Fold07      0.109  site: A       0.0715       2/4  0.0943
#> Fold08      0.575  site: A       0.227        2/4  0.204
#> Fold09      0.527  site: A       0.172        1/4  0.193
#> Fold10      0.258  income        0.143        3/4  0.0925
#> 
#> # summary() gives this table as a tibble, and tibble::as_tibble() gives
#> # all 90 rows.
```

And here are balanced folds. `balance` lists the columns to make
similar, and `exact` takes the place of `strata`. The next section
explains both. Balanced folds remember these columns, so
[`balance_check()`](https://jmgirard.github.io/balancesample/reference/balance_check.md)
needs no column list:

``` r

folds <- balanced_vfold_cv(
  d,
  v = 10,
  balance = c(age, income),
  exact = c(diagnosis, site)
)
balanced_check <- balance_check(folds)
balanced_check
#> # Balance check: 10 splits, 4 variables
#> # 5 of 10 splits have a variable with |SMD| > 0.1,
#> # mean energy distance 0.0544
#> 
#> id      max |SMD|  variable           mean |SMD|  over 0.1  energy
#> Fold01     0.115   diagnosis: severe      0.0421       1/4  0.0528
#> Fold02     0.119   diagnosis: mild        0.0483       1/4  0.0634
#> Fold03     0.0545  site: C                0.0286       0/4  0.0412
#> Fold04     0.115   diagnosis: severe      0.0442       1/4  0.0687
#> Fold05     0.0545  site: A                0.0224       0/4  0.0442
#> Fold06     0.0995  site: C                0.0373       0/4  0.0663
#> Fold07     0.113   site: B                0.0549       2/4  0.0627
#> Fold08     0.0496  site: B                0.0231       0/4  0.0488
#> Fold09     0.0496  site: B                0.0255       0/4  0.0454
#> Fold10     0.104   diagnosis: severe      0.0546       1/4  0.0501
#> 
#> # summary() gives this table as a tibble, and tibble::as_tibble() gives
#> # all 90 rows.
```

The largest absolute SMD in any fold fell from 0.58 to 0.12, the mean
absolute SMD over folds fell from 0.133 to 0.038, and the mean energy
distance fell from 0.105 to 0.054. With `by = "variable"`,
[`summary()`](https://rdrr.io/r/base/summary.html) shows where what is
left comes from:

``` r

summary(balanced_check, by = "variable")
#> # A tibble: 4 × 7
#>   variable  median_abs_smd max_abs_smd level id     n_over n_splits
#>   <chr>              <dbl>       <dbl> <chr> <chr>   <int>    <int>
#> 1 age              0.00127     0.00527 NA    Fold02      0       10
#> 2 income           0.00382     0.0148  NA    Fold02      0       10
#> 3 diagnosis        0.0767      0.119   mild  Fold02      5       10
#> 4 site             0.0545      0.113   B     Fold07      1       10
```

It is mostly in the category proportions of the `exact` columns. These
can’t come out exactly equal when a level’s count doesn’t divide evenly
into 10 folds. In a fold of 30 rows, one row more or less of a level
moves its SMD by 0.075 to 0.11 for the levels here, so 0.1 is not always
within reach.

## Choosing columns: `balance` and `exact`

`balance` takes numeric and categorical columns. To compare the sets,
the method turns each level of a categorical column into a 0/1 column
and standardizes all the columns. This happens only inside the method:
your data and the splits keep the original columns. The method then
makes the sets as similar as it can on all of these columns at once.
This is a goal, not a rule, so the method may trade a little balance on
one column for more balance on another.

`exact` takes categorical columns and is a rule. Each combination of
levels is one stratum. In each set, the count of each stratum is its
share of that set, rounded up or down to a whole row. This is fixed
before the method runs, so it holds for every method.

`exact` does the job of `strata` in rsample, with two differences. It
can take several columns, which it crosses, and its counts are exact
rather than approximate. If you write `strata` out of habit,
balancesample stops and tells you to use `exact`.

A categorical column can go in either argument. Use `exact` when you
need the counts as close as whole rows allow. Use `balance` when close
is enough. In the folds above, diagnosis is in `exact` because the
outcome depends on it, and severe cases are rare. Site is in `exact` so
that each site is represented in proportion in every fold, and later in
the test set. If a slightly uneven mix of sites were fine, site could go
in `balance` instead.

Continuous columns belong in `balance`. If you need exact counts within
ranges of a continuous column, make a factor of those ranges and put
that in `exact`. Base R has [`cut()`](https://rdrr.io/r/base/cut.html).
In the tidyverse,
[`ggplot2::cut_number()`](https://ggplot2.tidyverse.org/reference/cut_interval.html)
makes ranges with about the same number of rows, and
[`ggplot2::cut_interval()`](https://ggplot2.tidyverse.org/reference/cut_interval.html)
and
[`ggplot2::cut_width()`](https://ggplot2.tidyverse.org/reference/cut_interval.html)
make ranges of the same width.
[`dplyr::ntile()`](https://dplyr.tidyverse.org/reference/ntile.html)
also works: it returns whole numbers, which `exact` treats as
categories.

What about the outcome? In rsample, `strata` is usually the outcome, so
that every set has a similar mix of outcomes. You can do the same here.
A numeric outcome can go in `balance`, next to the predictors, and a
class outcome can go in `exact` if the class counts matter and every
class has enough rows for every set. The outcome is used only to assign
rows to sets, as with `strata`. This assumes you have the outcome when
you make the split. If the evaluation must hold out whole time periods
or whole sites, split by those instead: put the site in `group`, or use
rsample’s time-based splits. In this article, the outcome depends on
age, income, and diagnosis, so balancing those already keeps the outcome
similar across the sets, and it is left out.

Each column you add to `exact` splits the strata further. Here diagnosis
and site together make 9 strata:

``` r

tab <- table(d$diagnosis, d$site)
tab
#>         
#>           A  B  C
#>   mild   24 33 27
#>   none   68 43 65
#>   severe 15 10 15
```

The smallest stratum is severe cases at site B, with 10 patients. After
an 80% training split, 8 of them are spread over 5 folds, so each fold
gets 1 or 2. A stratum with fewer rows than folds is missing from some
folds. Small strata also leave the method less room to balance the other
columns.

### Missing values

By default, the columns in `balance`, `exact`, and `group` must not have
missing values. With `na = "include"`, the rows with missing values stay
in, and the method also balances which values are missing. Here, 30
incomes and 15 sites are missing:

``` r

d_na <- d
d_na$income[sample(n, 30)] <- NA
d_na$site[sample(n, 15)] <- NA
folds_na <- balanced_vfold_cv(
  d_na,
  v = 10,
  balance = c(age, income),
  exact = c(diagnosis, site),
  na = "include"
)
```

Each column type is handled in its own way:

- In a numeric `balance` column such as income, the missing values get
  the mean of the observed values, and a 0/1 column of which values are
  missing is balanced too. Once the share missing is balanced, balancing
  the filled column also balances the mean of the observed incomes. The
  filled values all sit at the mean, so the spread of the observed
  incomes is balanced less closely.
- In a categorical `balance` column, a missing value is one more level.
- In an `exact` column such as site, a missing value is one more level
  too, so the 15 rows are spread over the folds by exact counts. With
  `group`, a group with some rows at site A and some with a missing site
  is an error, because a missing value counts as a level of its own.

These encodings are used only to make the split. The data in the folds
keep their missing values, so your model can handle them its own way,
for example with a recipe.

[`balance_check()`](https://jmgirard.github.io/balancesample/reference/balance_check.md)
adds a row with `level` `"(missing)"` for each column with missing
values. It gives the SMD of the share of values that are missing. In the
summaries, it counts as one more level of its column. The other SMDs use
the observed values only. The energy distance uses all rows, encoded as
above.

``` r

na_check <- balance_check(folds_na)
na_rows <- tibble::as_tibble(na_check)
head(na_rows[na_rows$level %in% "(missing)", ], 4)
#> # A tibble: 4 × 5
#>   id     variable level     statistic   value
#>   <chr>  <chr>    <chr>     <chr>       <dbl>
#> 1 Fold01 income   (missing) smd        0     
#> 2 Fold01 site     (missing) smd       -0.0918
#> 3 Fold02 income   (missing) smd        0     
#> 4 Fold02 site     (missing) smd       -0.0918
na_check
#> # Balance check: 10 splits, 4 variables
#> # 5 of 10 splits have a variable with |SMD| > 0.1,
#> # mean energy distance 0.0658
#> 
#> id      max |SMD|  variable           mean |SMD|  over 0.1  energy
#> Fold01     0.0918  site: (missing)        0.0425       0/4  0.0749
#> Fold02     0.119   diagnosis: mild        0.0574       1/4  0.0782
#> Fold03     0.0797  site: (missing)        0.0356       0/4  0.0631
#> Fold04     0.115   diagnosis: severe      0.0525       1/4  0.0612
#> Fold05     0.115   diagnosis: severe      0.0503       1/4  0.0746
#> Fold06     0.0918  site: (missing)        0.0338       0/4  0.0578
#> Fold07     0.104   diagnosis: severe      0.0524       1/4  0.0665
#> Fold08     0.0797  site: (missing)        0.0296       0/4  0.0665
#> Fold09     0.104   diagnosis: severe      0.0474       1/4  0.053
#> Fold10     0.0918  site: (missing)        0.0363       0/4  0.0627
#> 
#> # summary() gives this table as a tibble, and tibble::as_tibble() gives
#> # all 110 rows.
```

A column with no observed values is an error. A `group` column must not
have missing values even with `na = "include"`, because rows with a
missing ID could come from one unit or from several. Give them their own
IDs, or one shared ID, depending on which is true. For a character ID
column `id`:

``` r

# One group per row with a missing ID
d$id[is.na(d$id)] <- paste0("unknown_", seq_len(sum(is.na(d$id))))
# Or one group for all of them
d$id[is.na(d$id)] <- "unknown"
```

To fill in another way, for example with the median, make the filled
copy and the 0/1 column yourself and put both in `balance`.

## A full tidymodels workflow

Start with a balanced training/testing split, with the same columns as
above. Then make balanced folds from the training set only, so the test
set plays no part in tuning.

``` r

split <- balanced_initial_split(
  d,
  prop = 0.8,
  balance = c(age, income),
  exact = c(diagnosis, site)
)
train <- rsample::training(split)
balance_check(split)
#> # Balance check: 1 split, 4 variables
#> # |SMD| > 0.1 in 0 of 4 variables, energy distance 0.0291
#> 
#> variable   level         SMD
#> age                -0.000652
#> income             -9.91e-05
#> diagnosis  mild     0.00927
#> diagnosis  none    -0.00846
#> diagnosis  severe   0
#> site       A       -0.0174
#> site       B        0.0367
#> site       C       -0.0174
#> 
#> # tibble::as_tibble() gives all 9 rows.
```

For a single split, the table shows the signed SMD of each variable and
level, and the header gives the energy distance.

To tune on one validation set instead of folds, use
[`balanced_initial_validation_split()`](https://jmgirard.github.io/balancesample/reference/balanced_initial_validation_split.md),
which makes a balanced training/validation/testing split. Pass it to
[`rsample::validation_set()`](https://rsample.tidymodels.org/reference/validation_set.html)
to get an `rset` for tune.

``` r

folds <- balanced_vfold_cv(
  train,
  v = 5,
  balance = c(age, income),
  exact = c(diagnosis, site)
)
```

Use
[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html) to
see the SMD of every variable in every fold. The dashed lines are at
-0.1 and 0.1.

``` r

library(ggplot2)
autoplot(balance_check(folds))
```

![](balancesample_files/figure-html/plot-1.png)

A diagnosis level can land outside the lines even though diagnosis is in
`exact`. The counts are exact for each diagnosis and site combination. A
fold can be one row off in each of the three sites, and these rows add
up for the diagnosis as a whole. Rare levels show this most, because one
row is a large share of a small level.

The folds work with tune like any other `rset`, as long as balancesample
is attached with [`library()`](https://rdrr.io/r/base/library.html), as
in the chunk below. tune finds the function that made the folds by its
name, so it fails if you only call
[`balancesample::balanced_vfold_cv()`](https://jmgirard.github.io/balancesample/reference/balanced_vfold_cv.md).

This example tunes the depth and the minimum node size of a decision
tree:

``` r

library(balancesample)
library(parsnip)
library(tune)
library(workflows)

wf <- workflow(
  outcome ~ age + income + diagnosis + site,
  decision_tree(
    tree_depth = tune(),
    min_n = tune(),
    mode = "regression"
  )
)
res <- tune_grid(wf, resamples = folds, grid = 6)
show_best(res, metric = "rmse", n = 3)
#> # A tibble: 3 × 8
#>   tree_depth min_n .metric .estimator  mean     n std_err .config        
#>        <int> <int> <chr>   <chr>      <dbl> <int>   <dbl> <chr>          
#> 1         12     9 rmse    standard    1.14     5  0.0751 pre0_mod5_post0
#> 2          6     2 rmse    standard    1.16     5  0.0837 pre0_mod3_post0
#> 3          9    24 rmse    standard    1.16     5  0.0558 pre0_mod4_post0
```

Finalize the workflow with the settings that had the lowest
cross-validated RMSE. Then
[`last_fit()`](https://tune.tidymodels.org/reference/last_fit.html) fits
it on the whole training set and evaluates it on the test set:

``` r

final <- finalize_workflow(wf, select_best(res, metric = "rmse"))
final_fit <- last_fit(final, split)
collect_metrics(final_fit)
#> # A tibble: 2 × 4
#>   .metric .estimator .estimate .config        
#>   <chr>   <chr>          <dbl> <chr>          
#> 1 rmse    standard       1.10  pre0_mod0_post0
#> 2 rsq     standard       0.509 pre0_mod0_post0
```

## Choosing a method

balancesample has four methods. All of them keep the `exact` counts.
They differ in how they make the sets similar on the `balance` columns:

- `"anticlust"` (the default) uses k-plus anticlustering from the
  [anticlust](https://cran.r-project.org/package=anticlust) package
  ([Papenberg, 2024](https://doi.org/10.1111/bmsp.12315)). It starts
  from a random assignment and swaps rows of the same `exact` stratum
  between sets when the swap improves one score for how similar the
  means and variances of the sets are. By default, it considers every
  row of the same stratum as a swap partner, so its run time grows
  quickly with the number of rows.
- `"twinning"` uses data twinning from the
  [twinning](https://cran.r-project.org/package=twinning) package
  ([Vakayil and Joseph, 2022](https://doi.org/10.1002/sam.11574)). It
  takes one set out of the data at a time. It takes a row and its
  nearest unused neighbours as a small group and keeps that first row
  for the set. The next group starts at the unused row closest to the
  last group’s farthest neighbour, so the set covers the data the way
  the whole data does. It does this within each `exact` stratum. For
  folds, the default strategy repeats this on the rows that are left. It
  needs the twinning package, allows only some split proportions, and
  splits small strata at random (for folds, strata with fewer than
  `2 * v` rows).
- `"rerandomize"` uses rerandomization ([Morgan and Rubin,
  2012](https://doi.org/10.1214/12-AOS1008)). It draws stratified random
  splits and scores each one by its Mahalanobis imbalance: a distance
  between the means of the sets that takes the correlations between the
  columns into account. For folds, the score is the largest imbalance of
  any fold against the rest. It keeps the first draw that scores under a
  cutoff, set from 100 pilot draws so that about 10% of draws pass. If
  none of 1,000 draws passes, it uses the best one, with a warning. It
  balances means only, and needs no extra package.
- `"interaction"` cuts each numeric column into up to four bins by rank,
  crosses them with the levels of the categorical columns, and
  stratifies at random on the result. Within each `exact` stratum, cells
  with fewer than 10% of all the rows are pooled. Crossed cells get
  small fast: here, with age and income in quartiles and 9 `exact`
  strata, the largest cell has 8 rows and the cutoff is 30, so every
  cell is pooled and the folds are random within the `exact` strata. It
  is a baseline that shows how crossed strata become sparse.

This compares all four on the full data with 10 folds:

``` r

methods <- c("anticlust", "twinning", "rerandomize", "interaction")
by_method <- lapply(methods, function(m) {
  f <- balanced_vfold_cv(
    d,
    v = 10,
    balance = c(age, income),
    exact = c(diagnosis, site),
    method = m
  )
  s <- summary(balance_check(f))
  data.frame(
    method = m,
    max_abs_smd = max(s$max_abs_smd),
    mean_abs_smd = mean(s$mean_abs_smd),
    mean_energy = mean(s$energy)
  )
})
by_method <- do.call(rbind, by_method)
shown <- by_method
shown[-1] <- round(shown[-1], 3)
shown
#>        method max_abs_smd mean_abs_smd mean_energy
#> 1   anticlust       0.119        0.037       0.054
#> 2    twinning       0.426        0.099       0.045
#> 3 rerandomize       0.268        0.087       0.055
#> 4 interaction       0.419        0.104       0.066
```

In this run, the smallest `max_abs_smd` came from anticlust (0.119), the
smallest `mean_abs_smd` from anticlust (0.037), and the smallest
`mean_energy` from twinning (0.045). These come from one run of each
method on one data set, so they don’t show which method does best in
general, and small differences may be noise.

Start with anticlust, but watch its run time on large data. In one test
on one computer, with 10 folds and four numeric variables, it took 0.5
seconds for 1,000 rows, 3.7 seconds for 3,000 rows, 25 seconds for
10,000 rows, and 3.6 minutes for 30,000 rows. With
`options = list(k_neighbours = 20)`, each row can only swap with its 20
nearest neighbours, and the same runs took 0.3, 1.6, 4.1, and 11.7
seconds. Twinning took under 0.5 seconds for all four sizes. On large
data, use `k_neighbours` or twinning, then check the balance again. With
`k_neighbours = 20`, look at the categorical columns in particular: in
one test with 5,000 rows, their largest SMD rose from about 0.005 to
about 0.1, while the numeric columns stayed as well balanced. See
[`?balanced_vfold_cv`](https://jmgirard.github.io/balancesample/reference/balanced_vfold_cv.md)
for the options of each method.

## Groups

If the data have several rows per person, put the person ID in `group`.
All of a person’s rows then go to the same set. Columns in `exact` must
be constant within each person, and the exact counts are counts of
people, not rows. `group` works the same way in
[`balanced_initial_split()`](https://jmgirard.github.io/balancesample/reference/balanced_initial_split.md).

``` r

d$person <- seq_len(n)
long <- d[rep(seq_len(n), times = sample(1:4, n, replace = TRUE)), ]
grouped <- balanced_vfold_cv(
  long,
  v = 5,
  balance = c(age, income),
  exact = c(diagnosis, site),
  group = person
)
grouped
#> # 5-fold balanced cross-validation (anticlust), balancing age, income,
#> # stratified by diagnosis, site, grouped by person
#> # A tibble: 5 × 2
#>   splits            id   
#>   <list>            <chr>
#> 1 <split [578/145]> Fold1
#> 2 <split [578/145]> Fold2
#> 3 <split [579/144]> Fold3
#> 4 <split [579/144]> Fold4
#> 5 <split [578/145]> Fold5
```

The split sizes are numbers of rows. Each fold gets about the same
number of people, so the number of rows per fold varies with how many
rows each person has.
[`balance_check()`](https://jmgirard.github.io/balancesample/reference/balance_check.md)
also compares rows.

To make the split, the method sees each person as one row, with the
person’s means of the `balance` columns and the log of their number of
rows. anticlust has a `must_link` argument for groups. balancesample
does not use it, because it needs fold sizes that the groups can fill
exactly, and it was slow in tests.
