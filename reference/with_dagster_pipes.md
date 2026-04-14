# Run code within a Dagster Pipes session

Opens a Dagster Pipes session, passes the context to a user-supplied
function, and guarantees the session is closed afterwards. If the
function raises an error, the exception is forwarded to Dagster before
re-raising.

## Usage

``` r
with_dagster_pipes(code)
```

## Arguments

- code:

  A function that takes a single argument (the
  [PipesContext](https://joekirincic.github.io/dagsterpipes/reference/PipesContext.md)
  or
  [NullPipesContext](https://joekirincic.github.io/dagsterpipes/reference/NullPipesContext.md))
  and performs the pipeline work.

## Value

The return value of `code`, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
with_dagster_pipes(function(ctx) {
  threshold <- ctx$get_extra("threshold")
  ctx$log(sprintf("Using threshold = %s", threshold))

  # ... do work ...

  ctx$report_asset_materialization(
    metadata = list(
      row_count = pipes_metadata_value(1000L, "int")
    )
  )
})
} # }
```
