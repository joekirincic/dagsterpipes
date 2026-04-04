# Contributing to dagsterpipes

Thanks for your interest in contributing! This is a small package, and contributions of
all kinds are welcome: bug reports, bug fixes, updates to track changes in the Dagster
Pipes protocol, and documentation improvements.

## Reporting bugs

Please open a GitHub issue at <https://github.com/joekirincic/dagsterpipes/issues>. A
good bug report includes:

- Your R version (`R.version.string`) and the installed version of `dagsterpipes`
- A minimal reproducible example
- What you expected to happen
- What actually happened (including any error messages or stack traces)

## Pull requests

1. Fork the repository and create a topic branch from `main`.
2. Make your change, keeping the PR focused on a single concern.
3. Before submitting, run:
   - `devtools::test()` — all tests should pass
   - `devtools::check()` — should complete with no errors or warnings
4. Open a pull request describing the change and linking to any related issue.

## Development setup

```r
# Clone the repo, then from the package root:
devtools::load_all()          # interactive development
devtools::test()              # run the test suite
devtools::document()          # regenerate NAMESPACE and man/ pages after editing roxygen comments
```

## Code style

- Follow the [tidyverse style guide](https://style.tidyverse.org/).
- Keep dependencies minimal. The package intentionally depends only on `R6` and
  `jsonlite`. Please don't add new `Imports` without opening an issue to discuss first.

## Protocol compliance

This package implements the Dagster Pipes protocol. See the
[protocol reference](https://docs.dagster.io/integrations/external-pipelines/dagster-pipes-details-and-customization)
for details. Any changes to message formats or bootstrap decoding must match the
behavior of the Python reference implementation (`dagster-pipes` on PyPI).
