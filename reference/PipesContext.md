# Pipes Context

Pipes Context

Pipes Context

## Details

Holds the execution context received from Dagster and provides methods
to report materializations, asset checks, logs, and custom messages back
to the orchestrator.

## Active bindings

- `asset_keys`:

  The list of asset keys from the context.

- `asset_key`:

  The single asset key. Errors if there is not exactly one.

- `run_id`:

  The Dagster run ID.

- `job_name`:

  The Dagster job name.

- `retry_number`:

  The current retry number.

- `extras`:

  The extras dictionary passed from Dagster.

- `partition_key`:

  The partition key, or `NULL`.

- `partition_key_range`:

  The partition key range, or `NULL`.

- `partition_time_window`:

  The partition time window, or `NULL`.

- `is_asset_step`:

  Whether this step involves assets.

- `is_partition_step`:

  Whether this step involves partitions.

- `provenance`:

  The provenance info by asset key.

- `code_version`:

  The code version info by asset key.

## Methods

### Public methods

- [`PipesContext$new()`](#method-PipesContext-new)

- [`PipesContext$get_extra()`](#method-PipesContext-get_extra)

- [`PipesContext$log()`](#method-PipesContext-log)

- [`PipesContext$log_external_stream()`](#method-PipesContext-log_external_stream)

- [`PipesContext$report_asset_materialization()`](#method-PipesContext-report_asset_materialization)

- [`PipesContext$report_asset_check()`](#method-PipesContext-report_asset_check)

- [`PipesContext$report_custom_message()`](#method-PipesContext-report_custom_message)

- [`PipesContext$close()`](#method-PipesContext-close)

- [`PipesContext$clone()`](#method-PipesContext-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new PipesContext.

#### Usage

    PipesContext$new(context_data, message_channel)

#### Arguments

- `context_data`:

  A list of context data from Dagster.

- `message_channel`:

  A `PipesFileMessageWriterChannel` instance.

------------------------------------------------------------------------

### Method `get_extra()`

Get an extra value by key.

#### Usage

    PipesContext$get_extra(key)

#### Arguments

- `key`:

  The extra key to look up.

#### Returns

The value associated with the key, or an error if not found.

------------------------------------------------------------------------

### Method [`log()`](https://rdrr.io/r/base/Log.html)

Send a log message to Dagster.

#### Usage

    PipesContext$log(message, level = "INFO")

#### Arguments

- `message`:

  The log message text.

- `level`:

  The log level. One of `"DEBUG"`, `"INFO"`, `"WARNING"`, `"ERROR"`,
  `"CRITICAL"`.

------------------------------------------------------------------------

### Method `log_external_stream()`

Send a raw external stream log (e.g. captured stdout or stderr) to
Dagster via the `log_external_stream` message method.

#### Usage

    PipesContext$log_external_stream(stream, text, extras = NULL)

#### Arguments

- `stream`:

  The stream name (character scalar), typically `"stdout"` or
  `"stderr"`, but any string is allowed.

- `text`:

  The log text (character scalar).

- `extras`:

  Optional named list of extras. Defaults to an empty list.

------------------------------------------------------------------------

### Method `report_asset_materialization()`

Report an asset materialization to Dagster.

#### Usage

    PipesContext$report_asset_materialization(
      metadata = NULL,
      asset_key = NULL,
      data_version = NULL
    )

#### Arguments

- `metadata`:

  A named list of metadata values. Each value may be either a raw R
  value (which will be auto-wrapped with type `"__infer__"`) or an
  explicit
  [`pipes_metadata_value()`](https://joekirincic.github.io/dagsterpipes/reference/pipes_metadata_value.md)
  result.

- `asset_key`:

  The asset key. If `NULL`, uses the single asset key from context.

- `data_version`:

  Optional data version string.

------------------------------------------------------------------------

### Method `report_asset_check()`

Report an asset check result to Dagster.

#### Usage

    PipesContext$report_asset_check(
      check_name,
      passed,
      asset_key = NULL,
      severity = "ERROR",
      metadata = NULL
    )

#### Arguments

- `check_name`:

  The name of the check.

- `passed`:

  Whether the check passed.

- `asset_key`:

  The asset key. If `NULL`, uses the single asset key from context.

- `severity`:

  The severity level (`"ERROR"` or `"WARN"`).

- `metadata`:

  A named list of metadata values. Each value may be either a raw R
  value (which will be auto-wrapped with type `"__infer__"`) or an
  explicit
  [`pipes_metadata_value()`](https://joekirincic.github.io/dagsterpipes/reference/pipes_metadata_value.md)
  result.

------------------------------------------------------------------------

### Method `report_custom_message()`

Report a custom message to Dagster.

#### Usage

    PipesContext$report_custom_message(payload)

#### Arguments

- `payload`:

  An arbitrary R object to send as the message payload.

------------------------------------------------------------------------

### Method [`close()`](https://rdrr.io/r/base/connections.html)

Close the Pipes session. Optionally report an exception to Dagster by
passing an error/condition object; the exception will be serialized into
the `closed` message params per the Pipes protocol.

#### Usage

    PipesContext$close(exception = NULL)

#### Arguments

- `exception`:

  Optional condition/error object. When supplied, its message, class,
  and formatted stack are attached to the `closed` message sent to
  Dagster. When `NULL` (default), a clean `closed` message with empty
  params is sent.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    PipesContext$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
ctx <- open_dagster_pipes()

tryCatch({
  output_path <- ctx$get_extra("output_path")
  ctx$log("starting work", level = "INFO")

  # ... do work that may fail ...

  ctx$report_asset_materialization(
    metadata = list(
      row_count  = pipes_metadata_value(1000L, "int"),
      output_path = pipes_metadata_value(output_path, "path")
    )
  )
  ctx$close()
}, error = function(e) {
  # Forward the exception to Dagster via the `closed` message.
  ctx$close(exception = e)
  stop(e)
})
} # }
```
