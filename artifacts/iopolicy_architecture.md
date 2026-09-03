# iopolicy architecture

## Source branch verification

The implementation was designed against the most recent checked-out refactor
branches:

* `luciu5/trade/refactor` is `d62bf03f8ccf8b2a23c4dc0d72775b00a70b8a4b` and
  contains the requested `eda4669f81d685c188f344407c99625b03b543d8` as an
  ancestor.
* `luciu5/antitrust/refactor` is
  `5903d50906017d87a8edff7a358ac4e582dddbb5` and contains the requested
  `33af668d4407e3caf9320e28bb38ac65a21432b8` as an ancestor.
* The current `master` branches do not contain their corresponding requested
  refactor commits, so the `refactor` branches are the architectural source
  of truth. The master branches were inspected only as legacy
  behavioral/economic oracles.

## Dependency direction

The intended dependency direction is:

```text
iopolicy <- antitrust
iopolicy <- trade
```

`iopolicy` has no dependency on either economic package. It uses base R and
`stats` only. Model-specific adapters are downstream methods on the generic
`realize_market()`.

## Economic boundary

The refactored economic packages retain their complete model registries,
`AntitrustFit`/`TradeFit` fitted-state contracts, `calibrate()`, `update()`,
`respecify()`, `counterfactual()`, and `simulate()` boundaries. In particular,
`update()` is recalibration and `respecify()` is a supplied-parameter
construction with provenance; this package does not duplicate or weaken those
semantics.

## Reference product decision

`n_firms` counts inside firms only. The generator adds one active reference
product owned by a separate reference firm. That firm is included in the
product-level ownership matrix, firm/product tables, HHI-ready bookkeeping,
and any model-specific equilibrium realization. The reference product has a
positive price and a draw-specific markup; only its mean utility is used as a
normalization by a Logit adapter.

This choice is explicit because the legacy `antitrust` constructors normally
represent an outside option outside the ownership matrix and normalize its
price to zero. The synthetic design intentionally differs: it supplies an
active reference product so its price, cost, markup, and FOC are genuine
market fields.
