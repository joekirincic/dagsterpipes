# dagsterpipes

Dagster Pipes protocol for R — run R scripts as external processes
orchestrated by Dagster.

## Overview

[dagsterpipes](https://github.com/joekirincic/dagsterpipes) implements
the [Dagster
Pipes](https://docs.dagster.io/integrations/external-pipelines/dagster-pipes-details-and-customization)
protocol in R. It lets R scripts receive execution context from Dagster
(asset keys, partitions, extras) and report materializations, asset
checks, logs, and custom messages back to the orchestrator. It is the R
counterpart to Python’s `dagster-pipes` and the JavaScript reference
implementation.

## Installation

Install from GitHub with either `remotes` or `pak`:

``` r
# install.packages("remotes")
remotes::install_github("joekirincic/dagsterpipes")

# or
# install.packages("pak")
pak::pak("joekirincic/dagsterpipes")
```

## Quick start

On the Python / Dagster side, define an asset that runs an R script via
`PipesSubprocessClient`:

``` python
import dagster as dg

@dg.asset(compute_kind="R")
def my_r_asset(
    context: dg.AssetExecutionContext,
    pipes_subprocess_client: dg.PipesSubprocessClient,
):
    return pipes_subprocess_client.run(
        command=["Rscript", "my_script.R"],
        context=context,
        extras={"threshold": 0.5, "output_path": "/tmp/results.csv"},
    ).get_materialize_result()

defs = dg.Definitions(
    assets=[my_r_asset],
    resources={"pipes_subprocess_client": dg.PipesSubprocessClient()},
)
```

On the R side (`my_script.R`), open a pipes session, read extras, do the
work, and report back:

``` r
library(dagsterpipes)

ctx <- open_dagster_pipes()

threshold <- ctx$get_extra("threshold")
output_path <- ctx$get_extra("output_path")

# ... do work ...

ctx$report_asset_materialization(
  metadata = list(
    row_count   = pipes_metadata_value(1000L, "int"),
    output_path = pipes_metadata_value(output_path, "path")
  )
)

ctx$log("Processing complete", level = "INFO")
ctx$close()
```

## Key features

- Minimal dependencies: only `R6` and `jsonlite`.
- File-based message transport (newline-delimited JSON), matching
  Dagster’s default `PipesSubprocessClient` /
  `PipesTempFileMessageReader`.
- Graceful degradation: when the Dagster env vars are absent,
  [`open_dagster_pipes()`](https://joekirincic.github.io/dagsterpipes/reference/open_dagster_pipes.md)
  returns a no-op `NullPipesContext` so scripts can be run and tested
  outside Dagster.
- R6-based API with active bindings for context fields (`asset_key`,
  `run_id`, `partition_key`, `extras`, etc.).

## Running standalone

When `DAGSTER_PIPES_CONTEXT` and `DAGSTER_PIPES_MESSAGES` are not set,
[`open_dagster_pipes()`](https://joekirincic.github.io/dagsterpipes/reference/open_dagster_pipes.md)
returns a `NullPipesContext`. It logs to the R console via
[`message()`](https://rdrr.io/r/base/message.html) and silently ignores
materialization, check, and custom-message reports. This means the same
script can be run interactively or from a plain `Rscript` invocation
without any Dagster machinery.

## Supported message types

| Method                         | Purpose                                                                              |
|--------------------------------|--------------------------------------------------------------------------------------|
| `opened`                       | Sent automatically when the session is initialized.                                  |
| `closed`                       | Sent by `ctx$close()` to end the session.                                            |
| `log`                          | `ctx$log(message, level)` — levels: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`. |
| `report_asset_materialization` | `ctx$report_asset_materialization(metadata, asset_key, data_version)`.               |
| `report_asset_check`           | `ctx$report_asset_check(check_name, passed, asset_key, severity, metadata)`.         |
| `report_custom_message`        | `ctx$report_custom_message(payload)`.                                                |

## Metadata

Metadata values reported to Dagster are typed. Use
`pipes_metadata_value(raw_value, type)` to wrap a value with a type
annotation:

``` r
pipes_metadata_value(1000L, "int")
pipes_metadata_value("/tmp/out.csv", "path")
pipes_metadata_value("https://example.com", "url")
```

Supported types: `text`, `url`, `path`, `notebook`, `json`, `md`,
`float`, `int`, `bool`, `dagster_run`, `asset`, `null`, `table`,
`table_schema`, `table_column_lineage`, `timestamp`, and `__infer__`
(the default, which lets Dagster infer the type from the raw value).

## Links

- Dagster Pipes documentation:
  <https://docs.dagster.io/integrations/external-pipelines/dagster-pipes-details-and-customization>
- Python reference implementation:
  <https://github.com/dagster-io/dagster/blob/master/python_modules/dagster-pipes/dagster_pipes/__init__.py>

## Code of Conduct

Please note that the dagsterpipes project is released with a
[Contributor Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.

## License

MIT.
