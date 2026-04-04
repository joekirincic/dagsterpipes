# Null Pipes Context (no-op)

Null Pipes Context (no-op)

Null Pipes Context (no-op)

## Details

A lightweight stand-in for
[PipesContext](https://joekirincic.github.io/dagsterpipes/reference/PipesContext.md)
used when running outside Dagster. Log calls go to
[`message()`](https://rdrr.io/r/base/message.html); report calls are
silently ignored.

## Active bindings

- `asset_keys`:

  Always [`list()`](https://rdrr.io/r/base/list.html).

- `asset_key`:

  Always errors.

- `run_id`:

  Always `NULL`.

- `job_name`:

  Always `NULL`.

- `retry_number`:

  Always `0`.

- `extras`:

  Always empty list.

- `partition_key`:

  Always `NULL`.

- `partition_key_range`:

  Always `NULL`.

- `partition_time_window`:

  Always `NULL`.

- `is_asset_step`:

  Always `FALSE`.

- `is_partition_step`:

  Always `FALSE`.

- `provenance`:

  Always `NULL`.

- `code_version`:

  Always `NULL`.

## Methods

### Public methods

- [`NullPipesContext$new()`](#method-NullPipesContext-new)

- [`NullPipesContext$get_extra()`](#method-NullPipesContext-get_extra)

- [`NullPipesContext$log()`](#method-NullPipesContext-log)

- [`NullPipesContext$log_external_stream()`](#method-NullPipesContext-log_external_stream)

- [`NullPipesContext$report_asset_materialization()`](#method-NullPipesContext-report_asset_materialization)

- [`NullPipesContext$report_asset_check()`](#method-NullPipesContext-report_asset_check)

- [`NullPipesContext$report_custom_message()`](#method-NullPipesContext-report_custom_message)

- [`NullPipesContext$close()`](#method-NullPipesContext-close)

- [`NullPipesContext$clone()`](#method-NullPipesContext-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new NullPipesContext.

#### Usage

    NullPipesContext$new()

------------------------------------------------------------------------

### Method `get_extra()`

Get an extra value by key. Always returns `NULL`.

#### Usage

    NullPipesContext$get_extra(key)

#### Arguments

- `key`:

  The extra key.

------------------------------------------------------------------------

### Method [`log()`](https://rdrr.io/r/base/Log.html)

Log a message to the R console.

#### Usage

    NullPipesContext$log(message, level = "INFO")

#### Arguments

- `message`:

  The log message text.

- `level`:

  The log level.

------------------------------------------------------------------------

### Method `log_external_stream()`

No-op external stream log.

#### Usage

    NullPipesContext$log_external_stream(stream, text, extras = NULL)

#### Arguments

- `stream`:

  Ignored.

- `text`:

  Ignored.

- `extras`:

  Ignored.

------------------------------------------------------------------------

### Method `report_asset_materialization()`

No-op materialization report.

#### Usage

    NullPipesContext$report_asset_materialization(
      metadata = NULL,
      asset_key = NULL,
      data_version = NULL
    )

#### Arguments

- `metadata`:

  Ignored.

- `asset_key`:

  Ignored.

- `data_version`:

  Ignored.

------------------------------------------------------------------------

### Method `report_asset_check()`

No-op asset check report.

#### Usage

    NullPipesContext$report_asset_check(
      check_name,
      passed,
      asset_key = NULL,
      severity = "ERROR",
      metadata = NULL
    )

#### Arguments

- `check_name`:

  Ignored.

- `passed`:

  Ignored.

- `asset_key`:

  Ignored.

- `severity`:

  Ignored.

- `metadata`:

  Ignored.

------------------------------------------------------------------------

### Method `report_custom_message()`

No-op custom message report.

#### Usage

    NullPipesContext$report_custom_message(payload)

#### Arguments

- `payload`:

  Ignored.

------------------------------------------------------------------------

### Method [`close()`](https://rdrr.io/r/base/connections.html)

No-op close.

#### Usage

    NullPipesContext$close(exception = NULL)

#### Arguments

- `exception`:

  Ignored (accepted for interface parity with
  [PipesContext](https://joekirincic.github.io/dagsterpipes/reference/PipesContext.md)).

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    NullPipesContext$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
ctx <- NullPipesContext$new()
ctx$log("running standalone", level = "INFO")
#> [INFO] running standalone
ctx$report_asset_materialization(metadata = list())
ctx$close()
```
