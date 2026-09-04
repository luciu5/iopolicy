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
  n_products = 2,
  dirichlet_alpha = c(2, 5, 1, 3),
  outside_beta = c(2, 8),
  seed = 42
)

market$products
market$design$seed
```

`n_firms` counts inside firms. `n_products` is the common number of products
owned by each inside firm, and the Dirichlet draw is over all inside products
(`n_firms * n_products`). Firm shares are aggregates of those product shares.
The reference product is an additional one-product firm and remains in the
product-level ownership matrix. Its price is real and positive; normalization
is applied only to its mean utility by an economic adapter.

The `mode = "observed"` route draws the share/ownership design and records a
reference-product markup and price as design inputs. It does not infer an
economic primitive in the common package. The model-aware entry points live in
the economic packages: `antitrust::synthetic_market()` returns an
`AntitrustFit`, and `trade::synthetic_market()` returns a `TradeFit`. They call
their own `calibrate()`/`specify()` paths and can therefore be passed directly
to their native `simulate()` methods. The generic `realize_market()` hook is
retained only as a neutral extension point; it is not the primary generation
workflow.

For model-aware generation, prices are not independently drawn. The positive
reference-product price, all product shares, ownership, selected demand/supply
model, and one reference level markup determine the model-consistent baseline.
In primitives mode, supplied structural parameters are passed through the
economic package's explicit `specify()` path.

These distributions are experimental-design devices, not claims about the
empirical distribution of real markets.
