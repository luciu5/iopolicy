.iopolicy_max_seed <- 2147483646L

.iopolicy_assert_scalar <- function(x, name, integer = FALSE) {
  if (length(x) != 1L || is.na(x) || !is.finite(x) ||
      (integer && x != as.integer(x))) {
    stop("'", name, "' must be a single finite ",
         if (integer) "integer" else "number")
  }
  invisible(x)
}

.iopolicy_validate_positive_vector <- function(x, name, length = NULL) {
  if (!is.numeric(x) || (!is.null(length) && base::length(x) != length) ||
      any(!is.finite(x)) || any(x <= 0)) {
    requirement <- if (is.null(length)) "finite and strictly positive" else
      paste0("a finite, strictly positive vector of length ", length)
    stop("'", name, "' must be ", requirement)
  }
  invisible(x)
}

.iopolicy_restore_rng <- function(had_seed, old_seed) {
  if (had_seed) {
    assign(".Random.seed", old_seed, envir = .GlobalEnv)
  } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    rm(".Random.seed", envir = .GlobalEnv)
  }
}

.iopolicy_begin_rng <- function(seed) {
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = .GlobalEnv) else NULL
  if (is.null(seed)) {
    ## Draw the effective seed from the caller's stream, then use it as an
    ## independent stream. Restoring the old state makes this helper local.
    actual_seed <- sample.int(.iopolicy_max_seed, 1L)
  } else {
    .iopolicy_assert_scalar(seed, "seed", integer = TRUE)
    actual_seed <- as.integer(seed)
    if (actual_seed < 1L || actual_seed > .iopolicy_max_seed) {
      stop("'seed' must be between 1 and ", .iopolicy_max_seed)
    }
  }
  set.seed(actual_seed)
  list(had_seed = had_seed, old_seed = old_seed, seed = actual_seed)
}

.iopolicy_weight_list <- function(products_per_firm, within_firm_weights) {
  n_firms <- length(products_per_firm)
  n_inside <- sum(products_per_firm)
  if (is.null(within_firm_weights)) {
    return(lapply(products_per_firm, function(n) rep(1 / n, n)))
  }

  if (is.list(within_firm_weights)) {
    if (length(within_firm_weights) != n_firms) {
      stop("'within_firm_weights' list must have one element per inside firm")
    }
    weights <- within_firm_weights
  } else if (is.numeric(within_firm_weights) &&
             length(within_firm_weights) == n_inside) {
    cuts <- cumsum(products_per_firm)
    starts <- c(1L, cuts[seq_len(length(cuts) - 1L)] + 1L)
    weights <- Map(function(start, end) within_firm_weights[start:end],
                   starts, cuts)
  } else {
    stop("'within_firm_weights' must be a list per firm or a vector over inside products")
  }

  for (f in seq_len(n_firms)) {
    w <- weights[[f]]
    if (!is.numeric(w) || length(w) != products_per_firm[f] ||
        any(!is.finite(w)) || any(w <= 0)) {
      stop("within-firm product weights must be finite and strictly positive with the requested lengths")
    }
    weights[[f]] <- unname(w / sum(w))
  }
  weights
}

.iopolicy_price_vector <- function(n_products, n_inside, prices, price_rule,
                                   price_level, price_range, reference_price) {
  if (!is.null(prices)) {
    if (!is.numeric(prices) || !all(is.finite(prices)) || any(prices <= 0) ||
        !length(prices) %in% c(n_inside, n_products)) {
      stop("'prices' must be a finite, strictly positive vector of inside or all-product length")
    }
    if (length(prices) == n_products) {
      if (!is.null(reference_price) &&
          !isTRUE(all.equal(prices[n_products], reference_price))) {
        stop("'reference_price' conflicts with the supplied all-product 'prices'")
      }
      return(list(values = unname(prices), rule = "user-supplied"))
    }
    ref <- if (is.null(reference_price)) price_level else reference_price
    if (length(ref) != 1L || !is.finite(ref) || ref <= 0) {
      stop("'reference_price' must be a finite, strictly positive number")
    }
    return(list(values = c(unname(prices), ref), rule = "user-supplied-inside"))
  }

  price_rule <- match.arg(price_rule, c("common", "uniform"))
  if (price_rule == "common") {
    .iopolicy_assert_scalar(price_level, "price_level")
    if (price_level <= 0) stop("'price_level' must be strictly positive")
    return(list(values = rep(price_level, n_products), rule = "common"))
  }
  if (!is.numeric(price_range) || length(price_range) != 2L ||
      any(!is.finite(price_range)) || any(price_range <= 0) ||
      price_range[1] >= price_range[2]) {
    stop("'price_range' must contain two finite positive values in increasing order")
  }
  list(values = runif(n_products, min = price_range[1], max = price_range[2]),
       rule = "uniform")
}

.iopolicy_open_uniform <- function(n, support) {
  if (!is.numeric(support) || length(support) != 2L ||
      any(!is.finite(support)) || support[1] < 0 || support[1] >= support[2]) {
    stop("'markup_range' must contain two finite values with 0 <= lower < upper")
  }
  width <- diff(support)
  eps <- max(.Machine$double.eps * max(1, width), 1e-12)
  if (width <= 2 * eps) stop("'markup_range' is too narrow for an open-boundary draw")
  runif(n, min = support[1] + eps, max = support[2] - eps)
}

#' Generate a reproducible synthetic market design
#'
#' The generator has two conceptually distinct modes. `mode = "observed"`
#' draws shares, prices, and one observed reference-product level markup. It
#' does not infer a demand or conduct primitive. `mode = "primitives"` records
#' supplied portable primitives as truth for a downstream economic adapter.
#'
#' `n_firms` counts inside firms. The active reference product is an additional
#' one-product firm and is included in the ownership matrix.
#'
#' @param mode Either `"observed"` or `"primitives"`.
#' @param n_firms Number of inside firms; the reference firm is additional.
#' @param dirichlet_alpha A positive finite vector of length `n_firms`.
#' @param outside_beta A positive finite length-two vector of Beta shapes.
#' @param products_per_firm A positive scalar recycled across firms or a
#'   positive vector of length `n_firms`.
#' @param within_firm_weights A list with one positive vector per firm, or a
#'   positive vector over all inside products. Defaults to equal allocation.
#' @param prices Optional positive prices for inside products or all products.
#' @param reference_price Price appended when only inside prices are supplied.
#' @param price_rule Either `"common"` or `"uniform"` when prices are not
#'   supplied.
#' @param price_level Common positive price and default reference price.
#' @param price_range Two positive endpoints for the uniform price rule.
#' @param observed_markup Optional reference-product level markup in observed
#'   mode. If omitted it is drawn from the open numerical implementation of
#'   `U(0, 100)`.
#' @param reference_markup Alias for `observed_markup`.
#' @param markup_range Two endpoints for the observed markup draw.
#' @param parameters A list of model-specific known primitives in primitives
#'   mode, such as `list(alpha = -1)`.
#' @param alpha Optional shorthand for `parameters$alpha`.
#' @param seed An optional explicit integer seed. The generated effective seed
#'   is always recorded in the returned object.
#' @return A `SyntheticMarket` object.
#' @export
fake_market <- function(
    mode = "observed",
    n_firms = 3L,
    dirichlet_alpha = rep(1, n_firms),
    outside_beta = c(2, 8),
    products_per_firm = 1L,
    within_firm_weights = NULL,
    prices = NULL,
    reference_price = NULL,
    price_rule = c("common", "uniform"),
    price_level = 100,
    price_range = c(50, 150),
    observed_markup = NULL,
    reference_markup = NULL,
    markup_range = c(0, 100),
    parameters = list(),
    alpha = NULL,
    seed = NULL) {
  mode <- match.arg(mode, c("observed", "primitives",
                            "observed_information", "known_primitives"))
  mode <- switch(mode,
                 observed_information = "observed",
                 known_primitives = "primitives",
                 mode)
  n_firms <- as.numeric(n_firms)
  .iopolicy_assert_scalar(n_firms, "n_firms", integer = TRUE)
  n_firms <- as.integer(n_firms)
  if (n_firms < 1L) stop("'n_firms' must be at least one")
  .iopolicy_validate_positive_vector(dirichlet_alpha, "dirichlet_alpha", n_firms)
  .iopolicy_validate_positive_vector(outside_beta, "outside_beta", 2L)
  if (!is.numeric(markup_range) || length(markup_range) != 2L ||
      any(!is.finite(markup_range)) || markup_range[1] < 0 ||
      markup_range[1] >= markup_range[2]) {
    stop("'markup_range' must contain two finite values with 0 <= lower < upper")
  }

  products_per_firm <- as.numeric(products_per_firm)
  if (length(products_per_firm) == 1L) products_per_firm <- rep(products_per_firm, n_firms)
  if (length(products_per_firm) != n_firms ||
      any(!is.finite(products_per_firm)) || any(products_per_firm < 1) ||
      any(products_per_firm != as.integer(products_per_firm))) {
    stop("'products_per_firm' must be a positive integer scalar or vector of length n_firms")
  }
  products_per_firm <- as.integer(products_per_firm)
  weights <- .iopolicy_weight_list(products_per_firm, within_firm_weights)
  n_inside <- sum(products_per_firm)
  n_products <- n_inside + 1L

  if (!is.list(parameters)) stop("'parameters' must be a list")
  if (!is.null(alpha)) {
    if (length(alpha) != 1L || !is.finite(alpha)) stop("'alpha' must be a finite scalar")
    if (!is.null(parameters$alpha) && !isTRUE(all.equal(parameters$alpha, alpha))) {
      stop("'alpha' conflicts with 'parameters$alpha'")
    }
    parameters$alpha <- alpha
  }
  if (mode == "primitives" && !length(parameters)) {
    stop("'parameters' must contain the known structural primitives in primitives mode")
  }
  if (mode == "primitives" &&
      (!is.null(observed_markup) || !is.null(reference_markup))) {
    stop("observed markup arguments are only valid in observed mode")
  }
  if (!is.null(reference_markup)) {
    if (!is.null(observed_markup) &&
        !isTRUE(all.equal(observed_markup, reference_markup))) {
      stop("'reference_markup' conflicts with 'observed_markup'")
    }
    observed_markup <- reference_markup
  }
  if (!is.null(observed_markup) &&
      (length(observed_markup) != 1L || !is.finite(observed_markup) ||
       observed_markup <= markup_range[1] || observed_markup >= markup_range[2])) {
    stop("'observed_markup' must lie strictly inside 'markup_range'")
  }

  rng <- .iopolicy_begin_rng(seed)
  on.exit(.iopolicy_restore_rng(rng$had_seed, rng$old_seed), add = TRUE)

  relative_firm_shares <- rgamma(n_firms, shape = dirichlet_alpha, rate = 1)
  relative_firm_shares <- relative_firm_shares / sum(relative_firm_shares)
  outside_share <- rbeta(1L, shape1 = outside_beta[1], shape2 = outside_beta[2])
  firm_shares <- (1 - outside_share) * relative_firm_shares
  product_shares <- unlist(Map(`*`, firm_shares, weights), use.names = FALSE)
  product_shares <- c(product_shares, outside_share)

  price_info <- .iopolicy_price_vector(
    n_products, n_inside, prices, price_rule, price_level, price_range,
    reference_price
  )
  price_values <- price_info$values

  if (mode == "observed") {
    if (is.null(observed_markup)) {
      observed_markup <- .iopolicy_open_uniform(1L, markup_range)
      markup_rule <- "uniform-open-U(0,100)"
    } else {
      markup_rule <- "user-supplied"
    }
  } else {
    observed_markup <- NULL
    markup_rule <- "not-drawn"
  }
  observed_markup_product <- if (is.null(observed_markup)) {
    NA_real_
  } else {
    unname(observed_markup)
  }

  firm_id <- c(rep(seq_len(n_firms), products_per_firm), n_firms + 1L)
  product_id <- seq_len(n_products)
  reference_product <- n_products
  firm_share_by_product <- c(
    unlist(Map(function(s, w) rep(s, length(w)), firm_shares, weights),
            use.names = FALSE),
    outside_share
  )
  reference_firm <- n_firms + 1L
  ownership <- outer(firm_id, firm_id, FUN = "==") * 1
  dimnames(ownership) <- list(product_id, product_id)

  products <- data.frame(
    product_id = product_id,
    firm_id = firm_id,
    firm_share = unname(firm_share_by_product),
    product_share = unname(product_shares),
    price = unname(price_values),
    cost = rep(NA_real_, n_products),
    markup = rep(NA_real_, n_products),
    observed_markup = c(rep(NA_real_, n_inside), observed_markup_product),
    reference_product = product_id == reference_product,
    stringsAsFactors = FALSE
  )
  firms <- data.frame(
    firm_id = seq_len(reference_firm),
    reference_firm = seq_len(reference_firm) == reference_firm,
    firm_share = c(firm_shares, outside_share),
    n_products = c(products_per_firm, 1L),
    stringsAsFactors = FALSE
  )

  design <- list(
    mode = mode,
    seed = rng$seed,
    n_firms = n_firms,
    n_inside_products = n_inside,
    n_products = n_products,
    reference_product = reference_product,
    reference_firm = reference_firm,
    dirichlet_alpha = unname(dirichlet_alpha),
    outside_beta = unname(outside_beta),
    outside_share = unname(outside_share),
    relative_firm_shares = unname(relative_firm_shares),
    firm_shares = unname(firm_shares),
    products_per_firm = unname(products_per_firm),
    within_firm_allocation = if (all(vapply(weights, function(w) {
      isTRUE(all.equal(w, rep(1 / length(w), length(w))))
    }, logical(1)))) "equal" else "user-supplied",
    within_firm_weights = weights,
    ownership_map = data.frame(product_id = product_id, firm_id = firm_id),
    price_rule = price_info$rule,
    price_level = price_level,
    price_range = unname(price_range),
    reference_price = unname(price_values[reference_product]),
    markup_rule = markup_rule,
    markup_range = unname(markup_range),
    observed_reference_markup = observed_markup,
    parameters = parameters
  )

  observed <- list(
    shares = unname(product_shares),
    prices = unname(price_values),
    ownership = ownership,
    reference_product = reference_product,
    reference_share = unname(outside_share),
    reference_price = unname(price_values[reference_product]),
    reference_markup = observed_markup
  )
  truth <- if (mode == "primitives") parameters else list()
  diagnostics <- list(
    equilibrium_status = "design-only",
    foc_residual = NA_real_,
    rejection_reason = NULL,
    costs_status = "not-realized"
  )
  metadata <- list(
    class = "SyntheticMarket",
    shares_sum = sum(product_shares),
    units = list(price = "price level", markup = "price level"),
    reference_normalization = "mean utility only; reference price is real"
  )

  SyntheticMarket(
    design = design, firms = firms, products = products,
    ownership = ownership, shares = product_shares, prices = price_values,
    observed = observed, truth = truth, diagnostics = diagnostics,
    metadata = metadata
  )
}

#' @rdname fake_market
#' @param ... Arguments passed to [fake_market()].
#' @export
synthetic_market <- function(...) fake_market(...)
