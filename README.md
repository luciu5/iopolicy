# iopolicy

`iopolicy` is a small, model-independent R package for designing and testing
industrial-organization policy models. Its initial feature is reproducible
synthetic market generation for Monte Carlo studies and package QA.

The package deliberately does not implement demand equations, conduct FOCs,
cost recovery, calibration, or equilibrium solvers. Those remain the
responsibility of economic packages such as `antitrust` and `trade`.

```r
library(iopolicy)

market <- fake_market(
  mode = "observed",
  n_firms = 2,
  dirichlet_alpha = c(2, 5),
  outside_beta = c(2, 8),
  products_per_firm = c(2, 1),
  seed = 42
)

market$products
market$design$seed
```

`n_firms` counts inside firms. The reference product is an additional
one-product firm and remains in the product-level ownership matrix. Its price
is real and positive; normalization is applied only to its mean utility by an
economic adapter.

The `mode = "observed"` route draws shares, prices, and one observed
reference-product level markup. It does not infer an economic primitive in the
common package. A model package can call `realize_market(market, spec)` to
apply its own equations. The `mode = "primitives"` route records supplied
portable primitives as truth for that model-specific realization.

These distributions are experimental-design devices, not claims about the
empirical distribution of real markets.
