.onLoad <- function(libname, pkgname) {
  register_balance_method(
    "anticlust",
    method_anticlust,
    pass_through = TRUE,
    package = "anticlust",
    reserved = c("x", "K", "categories", "must_link")
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
