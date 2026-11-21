#' Simulated patient data
#'
#' Simulated data from 300 patients at three sites. Age and income are
#' skewed, and diagnosis has a rare level. The README, the Get started
#' article (`vignette("balancedsample")`), and the examples use these data.
#'
#' The data are simulated and have no missing values. The outcome is
#'
#' `outcome = 0.05 * age + 0.3 * log(income) + 1.5 * severe + e`,
#'
#' where `severe` is 1 for a severe diagnosis and 0 otherwise, and `e` is
#' drawn from a standard normal distribution. The script that makes the data
#' is `data-raw/sim_patients.R` in the package's GitHub repository.
#'
#' @format A data frame with 300 rows and 5 columns:
#' \describe{
#'   \item{age}{Age in years, from a gamma distribution with shape 4 and
#'     rate 0.1 (mean 40).}
#'   \item{income}{Yearly income, from a lognormal distribution with
#'     `meanlog = 10` and `sdlog = 0.6`.}
#'   \item{diagnosis}{A factor with levels `"none"`, `"mild"`, and
#'     `"severe"`, drawn with probabilities 0.6, 0.3, and 0.1.}
#'   \item{site}{A factor with levels `"A"`, `"B"`, and `"C"`, drawn with
#'     equal probabilities.}
#'   \item{outcome}{A numeric outcome that depends on age, income, and
#'     diagnosis, as given above.}
#' }
#'
#' @examples
#' summary(sim_patients)
#' table(sim_patients$diagnosis, sim_patients$site)
"sim_patients"
