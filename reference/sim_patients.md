# Simulated patient data

Simulated data from 300 patients at three sites. Age and income are
skewed, and diagnosis has a rare level. The README, the Get started
article
([`vignette("balancedsample")`](https://jmgirard.github.io/balancedsample/articles/balancedsample.md)),
and the examples use these data.

## Usage

``` r
sim_patients
```

## Format

A data frame with 300 rows and 5 columns:

- age:

  Age in years, from a gamma distribution with shape 4 and rate 0.1
  (mean 40).

- income:

  Yearly income, from a lognormal distribution with `meanlog = 10` and
  `sdlog = 0.6`.

- diagnosis:

  A factor with levels `"none"`, `"mild"`, and `"severe"`, drawn with
  probabilities 0.6, 0.3, and 0.1.

- site:

  A factor with levels `"A"`, `"B"`, and `"C"`, drawn with equal
  probabilities.

- outcome:

  A numeric outcome that depends on age, income, and diagnosis, as given
  above.

## Details

The data are simulated and have no missing values. The outcome is

`outcome = 0.05 * age + 0.3 * log(income) + 1.5 * severe + e`,

where `severe` is 1 for a severe diagnosis and 0 otherwise, and `e` is
drawn from a standard normal distribution. The script that makes the
data is `data-raw/sim_patients.R` in the package's GitHub repository.

## Examples

``` r
summary(sim_patients)
#>       age              income        diagnosis   site       outcome     
#>  Min.   :  7.474   Min.   :  4619   none  :176   A:107   Min.   :1.100  
#>  1st Qu.: 27.129   1st Qu.: 14532   mild  : 84   B: 86   1st Qu.:4.111  
#>  Median : 38.965   Median : 23032   severe: 40   C:107   Median :5.185  
#>  Mean   : 40.921   Mean   : 27188                        Mean   :5.238  
#>  3rd Qu.: 50.277   3rd Qu.: 32883                        3rd Qu.:6.239  
#>  Max.   :135.302   Max.   :145222                        Max.   :9.407  
table(sim_patients$diagnosis, sim_patients$site)
#>         
#>           A  B  C
#>   none   68 43 65
#>   mild   24 33 27
#>   severe 15 10 15
```
