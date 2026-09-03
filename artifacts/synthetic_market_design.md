# Synthetic market design

## Scope

`SyntheticMarket` is a reproducible market-design object. It is not an
economic model object and does not promise empirical representativeness.
Dirichlet and Beta draws are controlled experimental-design devices.

## Share construction

For `n_firms = F`, the vector `dirichlet_alpha` must have length `F`, be finite,
and be strictly positive. The inside relative shares are drawn as

\[
(\tilde S_1,\ldots,\tilde S_F)\sim Dirichlet(\eta_1,\ldots,\eta_F).
\]

The reference share is independently drawn as

\[
s_0\sim Beta(a_0,b_0),
\]

and inside firm shares are `(1 - s0) * tilde_S`. Thus the product shares,
including the reference product, sum to one.

The reference product is an additional firm, so `n_firms` excludes that firm.
This makes the reference product strategically active without treating it as
a passive Logit outside option with price zero.

## Product structure

`products_per_firm` is a scalar or a length-`n_firms` positive integer vector.
Firm shares are allocated by equal within-firm weights by default. A user may
provide `within_firm_weights` as a list with one numeric vector per inside firm
or as a numeric vector of total length equal to the number of inside products.
Weights are normalized within each firm only after validation that they are
finite and strictly positive. The allocation interface is intentionally
simple so a future within-firm Dirichlet draw can be added without changing
the market representation.

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
seed, distribution parameters, allocation rule, price rule, markup draw, and
ownership map are stored in `market$design`. `simulate_markets()` derives a
deterministic integer seed for each replication and retains every market
object.

The model-specific realization step is the point at which singular
FOC systems, invalid domains, and negative implied costs are diagnosed. It
must fail explicitly or reject/redraw according to that model's policy; the
common package never silently clips structural parameters.
