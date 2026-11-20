.onLoad <- function(libname, pkgname) {
  register_balance_method(
    "anticlust",
    method_anticlust,
    options = c(
      "moments",
      "covariances",
      "k_neighbours",
      "local_maximum",
      "repetitions"
    )
  )
  register_balance_method(
    "twinning",
    method_twinning,
    options = c("strategy", "leaf_size"),
    package = "twinning"
  )
  register_balance_method(
    "rerandomize",
    method_rerandomize,
    options = c("p_accept", "max_draws")
  )
  register_balance_method(
    "interaction",
    method_interaction,
    options = c("n_bins", "pool")
  )
  invisible()
}
