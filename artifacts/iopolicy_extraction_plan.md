# Extraction roadmap

This is a roadmap, not a claim that all listed code belongs in the common
package.

1. **Phase 1:** `SyntheticMarket` and market-design utilities.
2. **Phase 2:** reassess and, if the package contracts are genuinely identical,
   extract a shared `Counterfactual` representation.
3. **Phase 3:** reassess a common `IOFit`/base fitted-state contract.
4. **Phase 4:** reassess transition and provenance metadata helpers.
5. **Phase 5:** stop and reassess before extracting anything economic.

Demand equations, conduct FOCs, marginal-cost recovery, admissibility
restrictions, translation formulas, and equilibrium solvers remain in
`antitrust` and `trade`.
