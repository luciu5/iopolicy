# iopolicy 0.0.0.9000

* Added the initial model-independent `SyntheticMarket` representation and
  reproducible fake-market generator.
* Added product-level ownership construction, reference-product bookkeeping,
  realization adapter generic, and deterministic Monte Carlo replication.
* `fake_market()` now takes a common `n_products` count for all inside firms
  and draws `dirichlet_alpha` directly over inside products. Firm shares are
  aggregates rather than equal within-firm allocations.
