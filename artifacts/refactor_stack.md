# Refactor development stack

The development branches are installed in dependency order:

```text
iopolicy/main -> antitrust/refactor -> trade/refactor
```

For a clean validation library, install the packages from local checkouts rather
than relying on a released or cached copy of `iopolicy`:

```sh
R CMD INSTALL /path/to/iopolicy
R CMD INSTALL /path/to/antitrust
R CMD INSTALL /path/to/trade
```

Run the test suite after each installation. The antitrust CI workflow checks out
and installs `iopolicy/main` before dependency resolution and package checking.
The trade QA workflow checks out both development dependencies, installs them in
the same order, and then runs `R CMD check --as-cran` for `trade/refactor`.

The package boundaries are intentional: `iopolicy` supplies neutral market
design and realization dispatch, while demand, conduct, policy, and equilibrium
economics remain in `antitrust` or `trade`.
