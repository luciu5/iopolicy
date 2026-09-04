# iopolicy architecture

## Source branch verification

The implementation was designed against the most recent checked-out refactor
branches:

* `luciu5/trade/refactor` was inspected at local head
  `5dc3b677e16a3c048846c0cb499342def05f9e59`; it contains the requested
  `eda4669f81d685c188f344407c99625b03b543d8` as an ancestor.
* `luciu5/antitrust/refactor` was inspected at head
  `f772ac57a1852a17d8aa786b602f92112055710b`; it contains the requested
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
`stats` only. Its public synthetic generator creates only the neutral market
design. Model-aware generators are package-local functions in `antitrust` and
`trade`; they invoke those packages' own calibration/specification methods.

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
normalization by the selected economic package. The common package does not
dispatch a demand or supply model.

This choice is explicit because the legacy `antitrust` constructors normally
represent an outside option outside the ownership matrix and normalize its
price to zero. The synthetic design intentionally differs: it supplies an
active reference product so its price, cost, markup, and FOC are genuine
market fields.
