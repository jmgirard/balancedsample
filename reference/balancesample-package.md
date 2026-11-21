# balancesample: Multivariate Balanced Data Splitting for 'rsample'

Creates training/testing splits, training/validation/testing splits, and
cross-validation folds that are balanced on several variables at once.
Numeric and categorical variables are balanced with anticlustering as in
Papenberg and Klau (2021)
[doi:10.1037/met0000301](https://doi.org/10.1037/met0000301) and
Papenberg (2024)
[doi:10.1111/bmsp.12315](https://doi.org/10.1111/bmsp.12315) , data
twinning as in Vakayil and Joseph (2022)
[doi:10.1002/sam.11574](https://doi.org/10.1002/sam.11574) ,
rerandomization as in Morgan and Rubin (2012)
[doi:10.1214/12-AOS1008](https://doi.org/10.1214/12-AOS1008) , or
crossed strata. Categorical variables can also be stratified exactly,
and rows from the same group can be kept together. Results are 'rsample'
objects for resampling and tuning with 'tune'.

## See also

Useful links:

- <https://github.com/jmgirard/balancesample>

- <https://jmgirard.github.io/balancesample/>

- Report bugs at <https://github.com/jmgirard/balancesample/issues>

## Author

**Maintainer**: Jeffrey M. Girard <jeffgirard@gmail.com>
([ORCID](https://orcid.org/0000-0002-7359-3746))

Authors:

- Jeffrey M. Girard <jeffgirard@gmail.com>
  ([ORCID](https://orcid.org/0000-0002-7359-3746))
