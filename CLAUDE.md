
# R package {dagsterpipes}

## Overview

This R package implements the Dagster Pipes protocol, enabling R scripts to run as
external processes orchestrated by Dagster. It communicates bidirectionally with Dagster:
receiving execution context (asset keys, partition info, extras) and reporting back
materializations, asset checks, logs, and custom messages.

## Design Principles

- **Minimal dependencies**: Only {R6} and {jsonlite} are allowed as Imports dependencies.
  All other functionality must use base R only (no {httr}, no {curl}, etc.).
- **Single transport**: File-based message writing only (newline-delimited JSON appended
  to a temp file). This matches the default `PipesSubprocessClient` / `PipesTempFileMessageReader`
  on the Dagster side.
- **Graceful degradation**: When `DAGSTER_PIPES_CONTEXT` is not set (i.e., script is run
  outside Dagster), `open_dagster_pipes()` returns a no-op context that logs to the
  console and silently ignores materializations. This allows scripts to be tested standalone.
- **R6 class system**: Use R6 for stateful objects (PipesContext, message writer channel).

## Dagster Pipes Protocol Specification

### Environment Variables

Dagster injects two environment variables into the subprocess:

| Variable | Purpose |
|----------|---------|
| `DAGSTER_PIPES_CONTEXT` | Base64-encoded, zlib-compressed JSON. Decodes to `{"path": "<tempfile>"}` pointing to context data. |
| `DAGSTER_PIPES_MESSAGES` | Base64-encoded, zlib-compressed JSON. Decodes to `{"path": "<tempfile>"}` pointing to where messages should be written. |

### Decoding Bootstrap Params

```
env_var_value -> base64_decode -> zlib_decompress -> JSON_parse -> {"path": "/tmp/xxx"}
```

In R:
```r
decode_param <- function(encoded) {
  raw_bytes <- jsonlite::base64_dec(encoded)               # {jsonlite}
  decompressed <- memDecompress(raw_bytes, type = "gzip")  # base R
  jsonlite::fromJSON(rawToChar(decompressed), simplifyVector = FALSE)
}
```

Use `jsonlite::base64_dec()` for base64 decoding, `base::memDecompress()` for zlib
decompression, and `jsonlite::fromJSON()` for JSON parsing.

### Context Data Structure

The file at the context path contains JSON:

```json
{
  "asset_keys": ["my_asset"],
  "code_version_by_asset_key": {"my_asset": null},
  "provenance_by_asset_key": {"my_asset": null},
  "partition_key": null,
  "partition_key_range": null,
  "partition_time_window": null,
  "run_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "job_name": "my_job",
  "retry_number": 0,
  "extras": {}
}
```

### Message Format

Every message written to the messages file is a single-line JSON object:

```json
{"__dagster_pipes_version": "0.1", "method": "<method>", "params": {<params>}}
```

### Message Types

#### `opened` — First message, sent on session init
```json
{"__dagster_pipes_version": "0.1", "method": "opened", "params": {}}
```

#### `closed` — Last message, sent on session teardown
```json
{"__dagster_pipes_version": "0.1", "method": "closed", "params": {}}
```

#### `log` — Log message
```json
{
  "__dagster_pipes_version": "0.1",
  "method": "log",
  "params": {"message": "...", "level": "INFO"}
}
```
Valid levels: `"DEBUG"`, `"INFO"`, `"WARNING"`, `"ERROR"`, `"CRITICAL"`

#### `report_asset_materialization` — Report asset completion
```json
{
  "__dagster_pipes_version": "0.1",
  "method": "report_asset_materialization",
  "params": {
    "asset_key": "my_asset",
    "data_version": null,
    "metadata": {
      "row_count": {"raw_value": 1000, "type": "int"},
      "path": {"raw_value": "/data/output.csv", "type": "path"}
    }
  }
}
```

#### `report_asset_check` — Report check result
```json
{
  "__dagster_pipes_version": "0.1",
  "method": "report_asset_check",
  "params": {
    "asset_key": "my_asset",
    "check_name": "row_count_check",
    "passed": true,
    "severity": "ERROR",
    "metadata": {}
  }
}
```

#### `report_custom_message` — Arbitrary payload
```json
{
  "__dagster_pipes_version": "0.1",
  "method": "report_custom_message",
  "params": {"payload": {}}
}
```

### Metadata Value Types

Metadata values are typed:
```json
{"raw_value": <value>, "type": "<type>"}
```

Supported types: `"text"`, `"url"`, `"path"`, `"notebook"`, `"json"`, `"md"`,
`"float"`, `"int"`, `"bool"`, `"dagster_run"`, `"asset"`, `"null"`, `"table"`,
`"table_schema"`, `"table_column_lineage"`, `"timestamp"`, `"__infer__"`

When type is `"__infer__"`, Dagster infers the type from the raw_value.

## Package Architecture

### File Layout

```
R/
  dagsterpipes-package.R     # Package-level docs, @importFrom R6 R6Class, @importFrom jsonlite fromJSON toJSON base64_dec
  utils.R                    # decode_param(), json_serialize() wrapper
  context.R                  # PipesContext R6 class
  message_writer.R           # PipesFileMessageWriterChannel R6 class
  open.R                     # open_dagster_pipes() entry point
  metadata.R                 # pipes_metadata_value() helper, type inference
tests/
  testthat/
    test-utils.R             # Unit tests for base64, JSON, decode_param
    test-context.R           # Tests for PipesContext methods
    test-message_writer.R    # Tests for message writing
    test-open.R              # Integration tests for open_dagster_pipes
    test-metadata.R          # Tests for metadata helpers
  testthat.R                 # Test runner
man/                          # Generated by roxygen2
DESCRIPTION
NAMESPACE
```

### Core Components

#### 1. `utils.R` — Low-level Protocol Helpers

- `decode_param(env_var_value)` — Full decode pipeline: `jsonlite::base64_dec()` -> `memDecompress()` -> `jsonlite::fromJSON()`
- `json_serialize(obj)` — Thin wrapper around `jsonlite::toJSON()` with appropriate defaults
  (`auto_unbox = TRUE`, `null = "null"`, `digits = NA`) to produce Dagster-compatible JSON

#### 2. `context.R` — PipesContext R6 Class

```r
PipesContext <- R6::R6Class("PipesContext",
  public = list(
    initialize = function(context_data, message_channel) { ... },

    # Properties (active bindings)
    # asset_keys, asset_key, run_id, job_name, retry_number,
    # extras, partition_key, partition_key_range, partition_time_window,
    # is_asset_step, is_partition_step, provenance, code_version

    # Methods
    get_extra = function(key) { ... },
    log = function(message, level = "INFO") { ... },
    report_asset_materialization = function(metadata = NULL, asset_key = NULL, data_version = NULL) { ... },
    report_asset_check = function(check_name, passed, asset_key = NULL, severity = "ERROR", metadata = NULL) { ... },
    report_custom_message = function(payload) { ... },
    close = function() { ... }
  ),
  active = list(
    asset_keys = function() private$.context_data$asset_keys,
    asset_key = function() { ... },  # error if length != 1
    run_id = function() private$.context_data$run_id,
    job_name = function() private$.context_data$job_name,
    retry_number = function() private$.context_data$retry_number,
    extras = function() private$.context_data$extras,
    partition_key = function() private$.context_data$partition_key,
    is_asset_step = function() length(private$.context_data$asset_keys) > 0,
    is_partition_step = function() !is.null(private$.context_data$partition_key)
  ),
  private = list(
    .context_data = NULL,
    .message_channel = NULL,
    .closed = FALSE,
    write_message = function(method, params = NULL) { ... }
  )
)
```

#### 3. `message_writer.R` — PipesFileMessageWriterChannel R6 Class

```r
PipesFileMessageWriterChannel <- R6::R6Class("PipesFileMessageWriterChannel",
  public = list(
    initialize = function(path) { ... },
    write_message = function(message) {
      # message is a list: list(`__dagster_pipes_version` = "0.1", method = ..., params = ...)
      json_line <- jsonlite::toJSON(message, auto_unbox = TRUE, null = "null")
      cat(json_line, "\n", file = private$.path, append = TRUE, sep = "")
    },
    close = function() { ... }
  ),
  private = list(
    .path = NULL
  )
)
```

#### 4. `open.R` — Entry Point

```r
#' Open a Dagster Pipes session
#'
#' @return A PipesContext object (or a no-op mock if not running under Dagster)
#' @export
open_dagster_pipes <- function() {
  context_env <- Sys.getenv("DAGSTER_PIPES_CONTEXT", unset = "")
  messages_env <- Sys.getenv("DAGSTER_PIPES_MESSAGES", unset = "")

  if (context_env == "" || messages_env == "") {
    message("Not running under Dagster Pipes. Returning no-op context.")
    return(NullPipesContext$new())
  }

  context_params <- decode_param(context_env)
  messages_params <- decode_param(messages_env)

  context_data <- jsonlite::fromJSON(context_params$path, simplifyVector = FALSE)
  message_channel <- PipesFileMessageWriterChannel$new(messages_params$path)

  ctx <- PipesContext$new(context_data, message_channel)
  # Send "opened" message
  ctx
}
```

#### 5. `metadata.R` — Metadata Helpers

```r
#' Create a typed metadata value
#' @export
pipes_metadata_value <- function(raw_value, type = "__infer__") {
  list(raw_value = raw_value, type = type)
}
```

### NullPipesContext (No-op for standalone testing)

A lightweight R6 class that mirrors PipesContext's interface but does nothing.
Log calls go to `message()`, report calls are silently ignored.

## DESCRIPTION File

```
Package: dagsterpipes
Title: Dagster Pipes Protocol for R
Version: 0.1.0
Authors@R: person("Joseph", "Kirincic", role = c("aut", "cre"))
Description: Implements the Dagster Pipes protocol, enabling R scripts to
    communicate with the Dagster orchestrator. R scripts can receive execution
    context and report asset materializations, check results, and log messages
    back to Dagster.
License: MIT + file LICENSE
Encoding: UTF-8
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.3.3
Imports: R6, jsonlite
Suggests: testthat (>= 3.0.0)
Config/testthat/edition: 3
```

## jsonlite Usage Notes

- Use `jsonlite::fromJSON(txt, simplifyVector = FALSE)` when parsing context data to
  preserve the list-of-lists structure (avoid R auto-simplifying to data frames/vectors).
- Use `jsonlite::toJSON(x, auto_unbox = TRUE, null = "null")` when serializing messages
  so that single values are not wrapped in arrays and NULLs become JSON `null`.
- Use `jsonlite::base64_dec()` for decoding bootstrap env var values.

## Development Workflow

- Use `devtools::load_all()` for interactive development
- Use `devtools::test()` to run tests
- Use `devtools::document()` to regenerate NAMESPACE and man/ pages
- Use `devtools::check()` for full R CMD check
- Roxygen2 with markdown enabled for documentation

## Testing Strategy

- Unit test decode_param (mock base64+zlib-compressed input, verify correct output)
- Test PipesContext with mock context data and a temp file message channel
- Integration test: simulate full Dagster Pipes flow by setting env vars, calling
  `open_dagster_pipes()`, reporting a materialization, closing, then reading the
  messages file to verify correct JSON output
- Test no-op/null context behavior when env vars are absent

## Python-Side Usage Example

```python
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

## R-Side Usage Example

```r
library(dagsterpipes)

ctx <- open_dagster_pipes()

threshold <- ctx$get_extra("threshold")
output_path <- ctx$get_extra("output_path")

# ... do work ...

ctx$report_asset_materialization(
  metadata = list(
    row_count = pipes_metadata_value(1000L, "int"),
    output_path = pipes_metadata_value(output_path, "path")
  )
)

ctx$log("Processing complete", level = "INFO")
ctx$close()
```

## Reference Sources

- Python source: https://github.com/dagster-io/dagster/blob/master/python_modules/dagster-pipes/dagster_pipes/__init__.py
- Protocol docs: https://docs.dagster.io/guides/build/external-pipelines/dagster-pipes-details-and-customization
- JavaScript example: https://docs.dagster.io/guides/build/external-pipelines/javascript-pipeline

## Implementation Order

1. `utils.R` — `decode_param()`, `json_serialize()` wrapper
2. `message_writer.R` — `PipesFileMessageWriterChannel`
3. `context.R` — `PipesContext` (depends on message writer)
4. `open.R` — `open_dagster_pipes()` (depends on context + utils)
5. `metadata.R` — `pipes_metadata_value()` helper
6. Null/no-op context for standalone usage
7. Tests for each component
8. Update DESCRIPTION, NAMESPACE (via roxygen2), write LICENSE file
9. R CMD check clean
