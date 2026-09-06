# Deferred shared architecture

The current refactor keeps `AntitrustFit` and `TradeFit` separate while their
APIs settle. Both packages duplicate parts of the counterfactual/path
infrastructure, and `trade` currently reuses counterfactual classes defined in
`antitrust`. Those pieces are candidates for a later move into `iopolicy` only
when their semantics are demonstrably identical.

A possible future `IOFit` abstraction could hold shared provenance, observed
inputs, structural parameters, and diagnostics. It would need explicit
translation rules for model-specific state and would introduce dependency and
S4 class-identity risks for existing `AntitrustFit` and `TradeFit` users.

If extraction proceeds, common path state and truly neutral fit/provenance
fields should move downward first; model registries and economic realization
must remain in their current model-specific packages. Backward-compatible
coercion or subclasses would be required before changing any public S4 class
identity. No extraction is made in this pass.
