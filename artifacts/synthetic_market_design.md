# Synthetic market design

## Scope

`SyntheticMarket` is a reproducible market-design object. It is not an
economic model object and does not promise empirical representativeness.
Dirichlet and Beta draws are controlled experimental-design devices.

## Share construction

For `n_firms = F` and `n_products = J`, the vector `dirichlet_alpha` must have
length `F * J`, be finite, and be strictly positive. The inside relative
product shares are drawn from `Dirichlet(dirichlet_alpha)`, with products
ordered in firm blocks.

The reference share is independently drawn as `s0 ~ Beta(a0, b0)`, and the
inside product shares are `(1 - s0) * relative_product_shares`. Firm shares
are the sums of the product shares owned by each firm. Thus all product
shares, including the reference product, sum to one. A symmetric design is
`dirichlet_alpha = rep(a, n_firms * n_products)`; an asymmetric design uses a
nonconstant vector.


The reference product is an additional firm, so `n_firms` excludes that firm.
This makes the reference product strategically active without treating it as
a passive Logit outside option with price zero.

## Product structure

All inside firms have the same number of products, controlled by the positive
integer `n_products` (default `1`). There is no equal-within-firm allocation:
product shares are drawn directly, and the resulting firm shares are
aggregates. The product-level ownership matrix is constructed from the
firm/product mapping, so multi-product ownership is explicit.

## Prices and markups

Prices are positive levels. Supplying `prices` is the most direct route. If
omitted, `price_rule = "common"` uses `price_level` for every product and
`price_rule = "uniform"` draws independently from `price_range`. In observed
mode, `observed_markup` is a level markup `p_r - c_r`, drawn from the open
numerical implementation of `U(0, 100)` unless supplied. It is not a
proportional margin in `[0, 1]`.

The common package does not turn observed information into a structural
parameter. A downstream economic adapter owns that inversion. Likewise,
known primitives are stored as truth and are interpreted only by the selected
model adapter.

## Reproducibility and rejection

Random generation runs under a locally preserved RNG state. The requested
seed, distribution parameters, product count, price rule, markup draw, and
ownership map are stored in `market$design`. `simulate_markets()` derives a
deterministic integer seed for each replication and retains every market
object.

The model-specific realization step is the point at which singular
FOC systems, invalid domains, and negative implied costs are diagnosed. It
must fail explicitly or reject/redraw according to that model's policy; the
common package never silently clips structural parameters.
