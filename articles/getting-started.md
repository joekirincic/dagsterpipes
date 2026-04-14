# Getting started with dagsterpipes

## Introduction

[Dagster](https://dagster.io/) is a Python-based orchestrator for data
pipelines. [Dagster
Pipes](https://docs.dagster.io/guides/build/external-pipelines/dagster-pipes-details-and-customization)
is the protocol it uses to run external processes (in any language) as
part of a pipeline, while still collecting structured information —
asset materializations, asset checks, logs, metadata — back from those
processes.

[dagsterpipes](https://github.com/joekirincic/dagsterpipes) implements
the Dagster Pipes Protocol for the R language. It lets you write
ordinary R scripts that Dagster can launch as subprocesses, receive
execution context from Dagster (asset keys, partition info,
user-supplied “extras”), and report results back in a way that Dagster
understands natively.

At a high level, the workflow is:

1.  A Dagster asset in Python calls `PipesSubprocessClient.run()` with a
    command like `Rscript my_script.R`.
2.  Dagster launches the R subprocess, injecting two environment
    variables (`DAGSTER_PIPES_CONTEXT` and `DAGSTER_PIPES_MESSAGES`)
    that point at two temp files, one the R script reads from and one it
    writes to.
3.  The R script calls
    [`with_dagster_pipes()`](https://joekirincic.github.io/dagsterpipes/reference/with_dagster_pipes.md),
    which reads the context file, runs the user-supplied function with a
    `PipesContext`, and closes the session automatically (forwarding any
    error to Dagster).
4.  Inside the function, the R script does its work, logs, and reports a
    materialization.
5.  Dagster tails the messages file and turns each line of JSON into the
    corresponding Dagster event (AssetMaterialization, AssetCheckResult,
    log entry, etc.).

Why use it? If your team has R-based models, scoring pipelines, or
reporting jobs that you want to schedule and monitor alongside Python
assets — without porting the R code to Python or wrapping it in an
opaque shell step — Pipes is the tool for you.

## The protocol at a glance

Dagster passes two environment variables into the R subprocess:

| Variable                 | Contents                                                                                       |
|--------------------------|------------------------------------------------------------------------------------------------|
| `DAGSTER_PIPES_CONTEXT`  | Base64-encoded, zlib-compressed JSON pointing at a **context file** the R process reads.       |
| `DAGSTER_PIPES_MESSAGES` | Base64-encoded, zlib-compressed JSON pointing at a **messages file** the R process appends to. |

The context file contains a JSON object with the asset keys for the
step, the run ID, the job name, partition info, and any extras the
Python asset supplied.

The messages file is newline-delimited JSON. Every message the R process
writes is a single line shaped like:

    {"__dagster_pipes_version": "0.1", "method": "<name>", "params": {...}}

Pictorially:

        Python (Dagster)                                R subprocess
        ----------------                                ------------
        PipesSubprocessClient.run()
             |
             | sets env vars,
             | spawns Rscript
             v
                                                 Rscript my_script.R
                                                       |
                                                       | open_dagster_pipes()
                                                       v
                                               reads <context file>
                                                       |
                                                       | ctx$log(...)
                                                       | ctx$report_asset_materialization(...)
                                                       | ctx$close()
                                                       v
                                              appends to <messages file>
             ^
             | tails messages file,
             | turns lines into Dagster events
             |
        AssetMaterialization / logs / checks

You don’t have to deal with any of the encoding, decoding, or file I/O
yourself:
[`open_dagster_pipes()`](https://joekirincic.github.io/dagsterpipes/reference/open_dagster_pipes.md)
and the `PipesContext` methods handle it for you.

## Writing your first R Pipes script

Let’s consider a simple example. Save this as `my_script.R` in the root
of your Dagster project:

``` r
library(dagsterpipes)

with_dagster_pipes(function(ctx) {
  # Read inputs supplied by the Python asset via `extras=...`
  threshold   <- ctx$get_extra("threshold")
  output_path <- ctx$get_extra("output_path")

  ctx$log(
    sprintf("Starting run with threshold = %s", threshold),
    level = "INFO"
  )

  # --- do real work here ---
  df <- data.frame(x = runif(1000), y = runif(1000))
  df <- df[df$x > threshold, ]
  write.csv(df, output_path, row.names = FALSE)

  # Report the materialization with typed metadata
  ctx$report_asset_materialization(
    metadata = list(
      row_count   = pipes_metadata_value(nrow(df), "int"),
      output_path = pipes_metadata_value(output_path, "path"),
      threshold   = pipes_metadata_value(threshold, "float")
    )
  )

  ctx$log("Done", level = "INFO")
})
```

A few things worth noting:

- [`with_dagster_pipes()`](https://joekirincic.github.io/dagsterpipes/reference/with_dagster_pipes.md)
  opens the session, runs your function, and closes it for you —
  including forwarding any error to Dagster (see [Handling
  errors](#handling-errors) below).
- The `opened` message is sent automatically when the session starts;
  the `closed` message is sent when your function returns (or throws).
- `ctx$log()` accepts levels `"DEBUG"`, `"INFO"`, `"WARNING"`,
  `"ERROR"`, `"CRITICAL"`. These are mapped to Dagster’s log levels.

## The Python side

On the Dagster side, define an asset that runs the script via
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
        extras={
            "threshold": 0.5,
            "output_path": "/tmp/results.csv",
        },
    ).get_materialize_result()

defs = dg.Definitions(
    assets=[my_r_asset],
    resources={"pipes_subprocess_client": dg.PipesSubprocessClient()},
)
```

The `extras` dict is what shows up on the R side via
`ctx$get_extra("...")`. The asset key comes from the Python decorator
(`my_r_asset` here), and you can access it on the R side as
`ctx$asset_key`.

## Running it

Assuming your Python code lives in `defs.py` and `my_script.R` is on a
path Dagster can see, start Dagster locally:

``` bash
dagster dev -f defs.py
```

Open the Dagster UI (usually at `http://localhost:3000`), navigate to
the asset `my_r_asset`, and click **Materialize**. Dagster will:

1.  Spawn `Rscript my_script.R` as a subprocess.
2.  Inject the two Pipes env vars.
3.  Stream log lines and the materialization event back into the UI as
    the R process writes them.

You’ll see an AssetMaterialization with the metadata you reported, plus
any `ctx$log()` messages in the log viewer.

## Reporting asset checks

Dagster has [asset
checks](https://docs.dagster.io/guides/test/asset-checks) for assessing
the quality of your assets. If you want to run asset checks using R,
[dagsterpipes](https://github.com/joekirincic/dagsterpipes) has you
covered. Just use `report_asset_check()`:

``` r
ctx$report_asset_check(
  check_name = "row_count_above_zero",
  passed     = nrow(df) > 0,
  severity   = "ERROR",
  metadata   = list(
    row_count = pipes_metadata_value(nrow(df), "int")
  )
)
```

On the Python side, you declare the check with `@dg.asset_check` or via
the `check_specs=` argument on the asset, and Dagster will match up the
`check_name` you report with the declared spec.

## Sending a custom payload back to Dagster

Sometimes you need to return a value from the R subprocess that doesn’t
fit into a materialization or a check — a model object summary, a row of
results to pass to a downstream Dagster asset, or any other arbitrary
structured payload. `ctx$report_custom_message()` sends a free-form
JSON-serializable payload back to Dagster:

``` r
ctx$report_custom_message(
  payload = list(
    model       = "glm",
    coefficients = list(intercept = 0.12, slope = 0.87),
    auc         = 0.91,
    n_train     = 10000L
  )
)
```

The `payload` can be any R value that
[`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
can serialize — a scalar, a named list, a nested structure.

On the Python side, the Dagster asset can collect these messages by
passing a `custom_message_handler` to `PipesSubprocessClient.run()`, or
by reading them off the `PipesClientCompletedInvocation` returned by
`.run()`. For example:

``` python
@dg.asset(compute_kind="R")
def my_r_asset(
    context: dg.AssetExecutionContext,
    pipes_subprocess_client: dg.PipesSubprocessClient,
):
    result = pipes_subprocess_client.run(
        command=["Rscript", "my_script.R"],
        context=context,
    )
    custom_messages = result.get_custom_messages()
    # custom_messages is a list of the payloads sent from R
    return result.get_materialize_result()
```

Use `report_custom_message()` when you need to pass something structured
between the R subprocess and the calling Python asset that isn’t a
first-class Dagster event. For typed metadata that should appear on the
materialization itself, use the `metadata` argument on
`report_asset_materialization()` instead.

## Handling errors

If your R code throws, you want Dagster to know about it — otherwise the
subprocess exits non-zero but Dagster just sees “the process failed”
with no structured error.

[`with_dagster_pipes()`](https://joekirincic.github.io/dagsterpipes/reference/with_dagster_pipes.md)
handles this automatically. If the function you pass throws an error,
the exception is forwarded to Dagster via the `closed` message
(including the error message, class, and formatted stack), and then the
error is re-raised so the R process still exits non-zero:

``` r
with_dagster_pipes(function(ctx) {
  threshold <- ctx$get_extra("threshold")
  # ... do work that may fail ...
  ctx$report_asset_materialization(metadata = list())
})
# If the function errors, Dagster sees the structured exception automatically.
```

If you need more control over the session lifecycle, you can use
[`open_dagster_pipes()`](https://joekirincic.github.io/dagsterpipes/reference/open_dagster_pipes.md)
directly and manage the error handling yourself:

``` r
ctx <- open_dagster_pipes()

tryCatch({
  threshold <- ctx$get_extra("threshold")
  # ... do work that may fail ...
  ctx$report_asset_materialization(metadata = list())
  ctx$close()
}, error = function(e) {
  ctx$close(exception = e)
  stop(e)
})
```

## Metadata types

Metadata values attached to materializations and checks are typed. Use
`pipes_metadata_value(raw_value, type)` to tag a value with a specific
type, or let Dagster infer it by omitting the `type` argument (the
default is `"__infer__"`).

| Type                     | When to use it                                          |
|--------------------------|---------------------------------------------------------|
| `"int"`                  | Integer counts (row counts, record counts).             |
| `"float"`                | Numeric measurements (thresholds, metrics, scores).     |
| `"bool"`                 | Booleans.                                               |
| `"text"`                 | Short strings.                                          |
| `"md"`                   | Markdown — renders as formatted text in the Dagster UI. |
| `"json"`                 | Arbitrary JSON blobs.                                   |
| `"path"`                 | Filesystem paths (rendered with file-path styling).     |
| `"url"`                  | URLs (rendered as clickable links).                     |
| `"notebook"`             | Path to a notebook file.                                |
| `"dagster_run"`          | A Dagster run ID.                                       |
| `"asset"`                | A Dagster asset key.                                    |
| `"timestamp"`            | Unix timestamp (float seconds since epoch).             |
| `"table"`                | A tabular value (rows + schema).                        |
| `"table_schema"`         | Just a table schema.                                    |
| `"table_column_lineage"` | Column-level lineage info.                              |
| `"null"`                 | Explicit null.                                          |
| `"__infer__"`            | Let Dagster pick the type from the R value (default).   |

Some examples you can evaluate directly:

``` r
library(dagsterpipes)

pipes_metadata_value(1000L, "int")
#> $raw_value
#> [1] 1000
#> 
#> $type
#> [1] "int"
pipes_metadata_value("/tmp/out.csv", "path")
#> $raw_value
#> [1] "/tmp/out.csv"
#> 
#> $type
#> [1] "path"
pipes_metadata_value("https://example.com/run/42", "url")
#> $raw_value
#> [1] "https://example.com/run/42"
#> 
#> $type
#> [1] "url"
pipes_metadata_value(0.97, "float")
#> $raw_value
#> [1] 0.97
#> 
#> $type
#> [1] "float"

# Default: let Dagster infer
pipes_metadata_value("hello world")
#> $raw_value
#> [1] "hello world"
#> 
#> $type
#> [1] "__infer__"
```

### Raw-value shorthand

`ctx$report_asset_materialization()` and `ctx$report_asset_check()` both
normalize their `metadata` argument: if a value is *not* already a
[`pipes_metadata_value()`](https://joekirincic.github.io/dagsterpipes/reference/pipes_metadata_value.md)
result (a list with exactly `raw_value` and `type`), it’s auto-wrapped
with `type = "__infer__"`. So these two forms are equivalent:

``` r
# Explicit
ctx$report_asset_materialization(
  metadata = list(
    row_count = pipes_metadata_value(1000L, "int"),
    note      = pipes_metadata_value("ok", "text")
  )
)

# Shorthand (types inferred by Dagster)
ctx$report_asset_materialization(
  metadata = list(
    row_count = 1000L,
    note      = "ok"
  )
)
```

Use the explicit form when you want a specific rendering in the UI (e.g.
`"md"`, `"path"`, `"url"`) or when the inferred type would be wrong.

## Running scripts standalone

A common pain point with frameworks like this is that you can’t easily
run the script on your laptop for development — it expects env vars from
an orchestrator that isn’t running.

[dagsterpipes](https://github.com/joekirincic/dagsterpipes) handles this
by returning a **`NullPipesContext`** when `DAGSTER_PIPES_CONTEXT` and
`DAGSTER_PIPES_MESSAGES` aren’t set. The NullPipesContext has the same
interface as `PipesContext`, but:

- [`log()`](https://rdrr.io/r/base/Log.html) calls go to
  [`message()`](https://rdrr.io/r/base/message.html) (i.e., the R
  console / stderr).
- `report_asset_materialization()`, `report_asset_check()`, and
  `report_custom_message()` are silent no-ops.
- `get_extra()` returns `NULL` (and prints a notice).
- Context fields like `asset_keys`, `run_id`, `partition_key` return
  sensible empty values.

This means the same script works both inside Dagster and from a plain
`Rscript my_script.R` or interactive session. You can try it right now:

``` r
library(dagsterpipes)

with_dagster_pipes(function(ctx) {
  ctx$log("running standalone", level = "INFO")
  ctx$report_asset_materialization(
    metadata = list(row_count = pipes_metadata_value(42L, "int"))
  )
})
#> Not running under Dagster Pipes. Returning no-op context.
#> [INFO] running standalone
```

The log line shows up in your console, the materialization is ignored,
and you can iterate on the script without Dagster at all. Once you’re
happy with it, hand the same file to `PipesSubprocessClient` and it will
“light up” with full orchestration.

## Further reading

- Dagster Pipes protocol docs:
  <https://docs.dagster.io/guides/build/external-pipelines/dagster-pipes-details-and-customization>
- Python reference implementation:
  <https://github.com/dagster-io/dagster/blob/master/python_modules/dagster-pipes/dagster_pipes/__init__.py>
