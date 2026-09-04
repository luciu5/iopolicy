.iopolicy_derived_seed <- function(seed, index) {
  as.integer(((as.double(seed) + as.double(index) - 1) %% .iopolicy_max_seed) + 1)
}

#' Generate deterministic synthetic-market replications
#'
#' Each replication receives a deterministic derived seed. Individual market
#' objects are retained in the returned list so their design metadata is not
#' discarded. Failed generator attempts are recorded and retried up to
#' `max_attempts` times.
#'
#' @param n Number of requested replications.
#' @param generator A function such as [fake_market].
#' @param seed Optional base integer seed.
#' @param max_attempts Maximum attempts per requested replication.
#' @param realizer Optional model-specific function applied to each generated
#'   market. This is the hook for a downstream economic package to use a
#'   demand/supply specification and recover or construct structural objects.
#' @param ... Arguments passed to `generator`; `seed` is supplied by this
#'   function and must not be included here.
#' @return A list with `markets`, `seeds`, and rejection `diagnostics`.
#' @export
simulate_markets <- function(n, generator = fake_market, seed = NULL,
                             max_attempts = 1L, realizer = NULL, ...) {
  .iopolicy_assert_scalar(n, "n", integer = TRUE)
  .iopolicy_assert_scalar(max_attempts, "max_attempts", integer = TRUE)
  n <- as.integer(n)
  max_attempts <- as.integer(max_attempts)
  if (n < 1L) stop("'n' must be at least one")
  if (max_attempts < 1L) stop("'max_attempts' must be at least one")
  if (!is.function(generator)) stop("'generator' must be a function")
  if (!is.null(realizer) && !is.function(realizer)) {
    stop("'realizer' must be NULL or a function")
  }

  rng <- .iopolicy_begin_rng(seed)
  on.exit(.iopolicy_restore_rng(rng$had_seed, rng$old_seed), add = TRUE)
  base_seed <- rng$seed

  markets <- vector("list", n)
  used_seeds <- vector("list", n)
  rejection_reasons <- vector("list", n)
  for (i in seq_len(n)) {
    reasons <- character()
    for (attempt in seq_len(max_attempts)) {
      attempt_index <- (i - 1L) * max_attempts + attempt
      draw_seed <- .iopolicy_derived_seed(base_seed, attempt_index)
      used_seeds[[i]] <- draw_seed
      result <- tryCatch({
        generated <- do.call(generator, c(list(seed = draw_seed), list(...)))
        if (is.null(realizer)) generated else realizer(generated)
      }, error = function(e) e)
      if (!inherits(result, "error")) {
        markets[[i]] <- result
        break
      }
      reasons <- c(reasons, conditionMessage(result))
    }
    rejection_reasons[[i]] <- reasons
  }

  rejected <- vapply(markets, is.null, logical(1))
  structure(
    list(
      markets = markets,
      seeds = unlist(used_seeds, use.names = FALSE),
      diagnostics = list(
        n_requested = n,
        n_success = sum(!rejected),
        n_rejected = sum(rejected),
        rejection_rate = mean(rejected),
        rejection_reasons = rejection_reasons,
        base_seed = base_seed,
        max_attempts = max_attempts,
        realized = !is.null(realizer)
      )
    ),
    class = c("SyntheticMarketBatch", "list")
  )
}

#' @export
print.SyntheticMarketBatch <- function(x, ...) {
  d <- x$diagnostics
  cat("SyntheticMarketBatch\n")
  cat("  requested: ", d$n_requested, "\n", sep = "")
  cat("  successful: ", d$n_success, "\n", sep = "")
  cat("  rejected: ", d$n_rejected, " (", format(d$rejection_rate), ")\n", sep = "")
  invisible(x)
}
