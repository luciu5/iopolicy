#' Realize a synthetic market under a model-specific specification
#'
#' `iopolicy` supplies only the market design. Economic packages register S3
#' methods for this generic and own all model equations, parameter inversion,
#' cost recovery, and equilibrium diagnostics.
#'
#' @param market A `SyntheticMarket` object.
#' @param spec A model-specific specification or lightweight model descriptor.
#' @param ... Additional model-specific arguments.
#' @return A model-specific realized market or fit object.
#' @export
realize_market <- function(market, spec, ...) {
  UseMethod("realize_market")
}

#' @export
realize_market.default <- function(market, spec, ...) {
  stop("no model-specific realization adapter is registered for this object")
}
