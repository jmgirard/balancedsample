# balancesample

balancesample makes training/testing splits and cross-validation folds
that are similar on several variables at once. The results are
[rsample](https://rsample.tidymodels.org) objects, so you can use them
with tune and the rest of tidymodels.

rsample can stratify on one variable. If you need folds that match on
age, income, and diagnosis together, rsample cannot do that.
balancesample fills this gap with four methods:

| Method | What it does | Package |
|----|----|----|
| `"anticlust"` (default) | Anticlustering with the k-plus objective ([`anticlust::fast_anticlustering()`](https://m-py.github.io/anticlust/reference/fast_anticlustering.html)), which matches the means and variances of the sets. | [anticlust](https://cran.r-project.org/package=anticlust) |
| `"twinning"` | Data twinning, which splits the data into sets with similar distributions. | [twinning](https://cran.r-project.org/package=twinning) |
| `"rerandomize"` | Draws random splits and keeps the first one with a small Mahalanobis imbalance (Morgan and Rubin, 2012). | none |
| `"interaction"` | Crosses quantile bins of all variables and stratifies at random. This is a baseline. | none |

twinning is a suggested package. If you select `method = "twinning"` and
it is not installed, balancesample asks you to install it.

## Installation

Install the development version from GitHub:

``` r

# install.packages("pak")
pak::pak("jmgirard/balancesample")
```

## Example

This example uses `sim_patients`, a simulated data set that comes with
the package. It has 300 patients with two skewed numeric variables
(`age` and `income`), a diagnosis with a rare level, three sites, and an
outcome.

``` r

library(balancesample)

head(sim_patients)
#>         age    income diagnosis site  outcome
#> 1 45.416862 10059.820      none    A 4.869271
#> 2 17.715166 29593.157      none    B 4.029893
#> 3  7.956037 16209.254      none    A 3.903540
#> 4 23.639336  8132.757      none    C 5.043892
#> 5 45.003459 31997.909      none    C 4.053658
#> 6 56.925594 22235.349      mild    B 8.176950
```

[`balanced_vfold_cv()`](https://jmgirard.github.io/balancesample/reference/balanced_vfold_cv.md)
makes folds that are similar on the columns in `balance`. Categorical
columns in `exact` are stratified exactly: in each fold, the count of
each level combination is as close to its proportional share as whole
rows allow.

``` r

set.seed(2026)
folds <- balanced_vfold_cv(
  sim_patients,
  v = 5,
  balance = c(age, income, diagnosis),
  exact = site
)
folds
#> # 5-fold balanced cross-validation (anticlust), balancing age, income,
#> # diagnosis, stratified by site
#> # A tibble: 5 × 2
#>   splits           id   
#>   <list>           <chr>
#> 1 <split [240/60]> Fold1
#> 2 <split [240/60]> Fold2
#> 3 <split [240/60]> Fold3
#> 4 <split [240/60]> Fold4
#> 5 <split [240/60]> Fold5
```

[`balance_check()`](https://jmgirard.github.io/balancesample/reference/balance_check.md)
compares the held-out rows of each fold with the other rows. The printed
table gives the largest and the mean absolute standardized mean
difference (SMD) over the variables, how many variables are over 0.1,
and the energy distance, which compares all the variables at once. The
function works with any rsample object, so you can compare balanced
folds with ordinary folds.

``` r

balance_check(folds)
#> # Balance check: 5 splits, 4 variables
#> # 0 of 5 splits have a variable with |SMD| > 0.1, mean energy distance 0.032
#> 
#> id     max |SMD|  variable         mean |SMD|  over 0.1  energy
#> Fold1     0.0367  site: B             0.0126        0/4  0.0341
#> Fold2     0.026   site: C             0.00922       0/4  0.0261
#> Fold3     0.026   site: A             0.0091        0/4  0.04
#> Fold4     0.026   site: C             0.00992       0/4  0.0291
#> Fold5     0.0373  diagnosis: mild     0.0159        0/4  0.0306
#> 
#> # summary() gives this table as a tibble, and tibble::as_tibble() gives all
#> # 45 rows.

random_folds <- rsample::vfold_cv(sim_patients, v = 5)
balance_check(random_folds, age, income, diagnosis, site)
#> # Balance check: 5 splits, 4 variables
#> # 5 of 5 splits have a variable with |SMD| > 0.1, mean energy distance 0.0789
#> 
#> id     max |SMD|  variable         mean |SMD|  over 0.1  energy
#> Fold1      0.305  site: B               0.148       2/4  0.0827
#> Fold2      0.411  site: B               0.165       2/4  0.101
#> Fold3      0.177  diagnosis: none       0.105       2/4  0.054
#> Fold4      0.277  income                0.201       3/4  0.0883
#> Fold5      0.282  income                0.136       3/4  0.0684
#> 
#> # summary() gives this table as a tibble, and tibble::as_tibble() gives all
#> # 45 rows.
```

The folds work with tune. Attach balancesample with
[`library()`](https://rdrr.io/r/base/library.html) first, because tune
finds the function that made the folds by its name.

## Learn more

The [Get started
article](https://jmgirard.github.io/balancesample/articles/balancesample.html)
([`vignette("balancesample")`](https://jmgirard.github.io/balancesample/articles/balancesample.md))
goes through a full modeling project: a balanced training/testing split,
balanced folds, tuning with tune, and a final fit. It also shows how to
choose the columns for `balance` and `exact`, how to handle missing
values and repeated rows per person, and how to choose a method, with
run times for large data.

## Background

In 2021, I asked for multivariate stratification in rsample
([tidymodels/rsample#266](https://github.com/tidymodels/rsample/issues/266)).
Julia Silge suggested an extension package, and balancesample is that
package. Its design follows
[spatialsample](https://spatialsample.tidymodels.org): it builds folds
with
[`rsample::make_splits()`](https://rsample.tidymodels.org/reference/make_splits.html)
and
[`rsample::new_rset()`](https://rsample.tidymodels.org/reference/new_rset.html).

Two other rsample issues are related.
[tidymodels/rsample#371](https://github.com/tidymodels/rsample/issues/371)
proposes twinning as the multi-variable strata method for rsample.
[tidymodels/rsample#109](https://github.com/tidymodels/rsample/issues/109)
records Max Kuhn’s concern that crossed strata become sparse. The
`"interaction"` method is in balancesample so that you can see this
problem next to the other methods.

## Prior art

- `groupdata2::fold()` makes folds that balance one numeric variable,
  stratify one categorical variable, and keep groups together.
- `groupdata2::collapse_groups()` combines existing groups into fewer
  groups that are similar in size and in several numeric and categorical
  variables.
- `splitTools::multi_strata()` makes one stratification variable from
  several variables, by crossing them or by k-means clustering.

## References

Morgan, K. L., & Rubin, D. B. (2012). Rerandomization to improve
covariate balance in experiments. *The Annals of Statistics, 40*(2),
1263-1282.

Papenberg, M. (2024). K-plus anticlustering: An improved k-means
criterion for maximizing between-group similarity. *British Journal of
Mathematical and Statistical Psychology, 77*(1), 80-102.

Papenberg, M., & Klau, G. W. (2021). Using anticlustering to partition
data sets into equivalent parts. *Psychological Methods, 26*(2),
161-174.

Vakayil, A., & Joseph, V. R. (2022). Data twinning. *Statistical
Analysis and Data Mining, 15*(5), 598-610.
