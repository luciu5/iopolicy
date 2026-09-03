test_that("Dirichlet shares use a positive vector and preserve totals", {
  expect_error(fake_market(n_firms = 3, dirichlet_alpha = c(1, 2)),
               "dirichlet_alpha.*length 3")
  expect_error(fake_market(n_firms = 3, dirichlet_alpha = c(1, 0, 2)),
               "dirichlet_alpha")
  expect_error(fake_market(n_firms = 3, dirichlet_alpha = c(1, Inf, 2)),
               "dirichlet_alpha")

  market <- fake_market(
    n_firms = 3, dirichlet_alpha = c(1, 2, 5), outside_beta = c(2, 3),
    seed = 10
  )
  expect_equal(length(market$design$dirichlet_alpha), 3)
  expect_equal(sum(market$design$relative_firm_shares), 1, tolerance = 1e-14)
  expect_equal(sum(market$design$firm_shares), 1 - market$design$outside_share,
               tolerance = 1e-14)
  expect_equal(sum(market$shares), 1, tolerance = 1e-14)
  expect_equal(sum(market$products$product_share), 1, tolerance = 1e-14)
  expect_true(market$design$outside_share > 0)
  expect_true(market$design$outside_share < 1)
})

test_that("symmetric and asymmetric Dirichlet designs are reproducible", {
  symmetric_a <- fake_market(n_firms = 4, dirichlet_alpha = rep(2, 4), seed = 123)
  symmetric_b <- fake_market(n_firms = 4, dirichlet_alpha = rep(2, 4), seed = 123)
  asymmetric <- fake_market(n_firms = 4, dirichlet_alpha = c(1, 2, 3, 8), seed = 123)

  expect_equal(symmetric_a$shares, symmetric_b$shares)
  expect_equal(symmetric_a$prices, symmetric_b$prices)
  expect_equal(symmetric_a$observed$reference_markup,
               symmetric_b$observed$reference_markup)
  expect_false(isTRUE(all.equal(symmetric_a$shares, asymmetric$shares)))
})

test_that("outside share Beta parameters are explicit and validated", {
  expect_error(fake_market(outside_beta = c(1)), "outside_beta.*length 2")
  expect_error(fake_market(outside_beta = c(1, 0)), "outside_beta")
  expect_error(fake_market(outside_beta = c(1, NA)), "outside_beta")
  a <- fake_market(outside_beta = c(1, 9), seed = 33)
  b <- fake_market(outside_beta = c(1, 9), seed = 33)
  expect_equal(a$design$outside_share, b$design$outside_share)
})

test_that("product allocation supports one, equal multiple, heterogeneous, and weighted products", {
  one <- fake_market(n_firms = 2, products_per_firm = 1, seed = 1)
  expect_equal(nrow(one$products), 3)
  expect_equal(one$firms$n_products, c(1, 1, 1))

  equal <- fake_market(n_firms = 2, products_per_firm = 2, seed = 1)
  expect_equal(nrow(equal$products), 5)
  expect_equal(equal$firms$n_products, c(2, 2, 1))
  for (f in 1:2) {
    idx <- equal$products$firm_id == f
    expect_equal(equal$products$product_share[idx],
                 rep(equal$firms$firm_share[f] / 2, 2), tolerance = 1e-14)
  }

  heterogeneous <- fake_market(n_firms = 3, products_per_firm = c(1, 2, 3), seed = 2)
  expect_equal(heterogeneous$firms$n_products, c(1, 2, 3, 1))
  expect_equal(nrow(heterogeneous$products), 7)

  weighted <- fake_market(
    n_firms = 2, products_per_firm = c(2, 1),
    within_firm_weights = list(c(1, 3), 1), seed = 2
  )
  expect_equal(weighted$design$within_firm_weights[[1]], c(.25, .75))
  expect_equal(sum(weighted$products$product_share[weighted$products$firm_id == 1]),
               weighted$firms$firm_share[1], tolerance = 1e-14)
  expect_error(fake_market(n_firms = 2, products_per_firm = c(2, 1),
                            within_firm_weights = list(c(1), 1)),
               "within-firm product weights")
})

test_that("reference product is active, priced, and separately owned", {
  market <- fake_market(n_firms = 2, products_per_firm = c(2, 1),
                        price_level = 25, seed = 4)
  ref <- market$design$reference_product
  expect_equal(market$products$reference_product, seq_len(nrow(market$products)) == ref)
  expect_equal(market$products$price[ref], 25)
  expect_equal(market$products$firm_id[ref], market$design$reference_firm)
  expect_equal(market$reference_product, ref)
  expect_equal(market$reference_share, market$shares[ref])
  expect_equal(market$reference_price, market$prices[ref])
  expect_equal(unname(market$ownership[ref, -ref]), rep(0, nrow(market$products) - 1))
  expect_equal(market$ownership[ref, ref], 1)
  expect_equal(market$observed$reference_share, market$shares[ref])
  expect_equal(market$metadata$reference_normalization,
               "mean utility only; reference price is real")
})

test_that("prices and open-boundary level markup conventions are explicit", {
  supplied <- fake_market(n_firms = 2, prices = c(10, 20), reference_price = 30,
                          seed = 5)
  expect_equal(supplied$prices, c(10, 20, 30))
  expect_equal(supplied$design$price_rule, "user-supplied-inside")

  all_prices <- fake_market(n_firms = 2, prices = c(10, 20, 30), seed = 5)
  expect_equal(all_prices$design$price_rule, "user-supplied")
  expect_error(fake_market(n_firms = 2, prices = c(0, 2, 3)), "prices")

  market <- fake_market(n_firms = 2, price_level = 100, seed = 5)
  markup <- market$observed$reference_markup
  expect_true(markup > 0 && markup < 100)
  expect_equal(market$metadata$units$markup, "price level")
  expect_equal(market$design$markup_rule, "uniform-open-U(0,100)")
  expect_equal(market$products$observed_markup[market$design$reference_product], markup)
  expect_equal(fake_market(mode = "observed_information", seed = 5)$design$mode,
               "observed")
  expect_equal(fake_market(mode = "known_primitives", parameters = list(alpha = -1),
                           seed = 5)$design$mode, "primitives")
})

test_that("RNG state is preserved and Monte Carlo seeds are deterministic", {
  set.seed(99)
  expected <- runif(1)
  set.seed(99)
  invisible(fake_market(seed = 101))
  observed <- runif(1)
  expect_equal(observed, expected)

  first <- simulate_markets(3, fake_market, seed = 8,
                            n_firms = 2, dirichlet_alpha = c(1, 3))
  second <- simulate_markets(3, fake_market, seed = 8,
                             n_firms = 2, dirichlet_alpha = c(1, 3))
  expect_equal(first$seeds, second$seeds)
  expect_equal(first$diagnostics$rejection_rate, 0)
  expect_equal(lapply(first$markets, `[[`, "shares"),
               lapply(second$markets, `[[`, "shares"))
  expect_equal(length(first$markets), 3)
})
