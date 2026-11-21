# Simulates the `sim_patients` data used in the README, the Get started
# article, and the examples. Run from the package root.

# The generators are stated so that a session with another RNGkind() gets
# the same draws.
set.seed(
  2026,
  kind = "Mersenne-Twister",
  normal.kind = "Inversion",
  sample.kind = "Rejection"
)
n <- 300
sim_patients <- data.frame(
  age = rgamma(n, shape = 4, rate = 0.1),
  income = rlnorm(n, meanlog = 10, sdlog = 0.6),
  diagnosis = factor(
    sample(
      c("none", "mild", "severe"),
      n,
      replace = TRUE,
      prob = c(0.6, 0.3, 0.1)
    ),
    levels = c("none", "mild", "severe")
  ),
  site = factor(sample(c("A", "B", "C"), n, replace = TRUE))
)
sim_patients$outcome <- with(
  sim_patients,
  0.05 * age + 0.3 * log(income) + 1.5 * (diagnosis == "severe") + rnorm(n)
)

usethis::use_data(sim_patients, overwrite = TRUE)
