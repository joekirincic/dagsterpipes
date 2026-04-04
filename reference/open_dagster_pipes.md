# Open a Dagster Pipes session

Reads bootstrap parameters from environment variables, initializes the
message channel, and returns a
[PipesContext](https://joekirincic.github.io/dagsterpipes/reference/PipesContext.md)
ready to use. When not running under Dagster (environment variables
absent), returns a no-op
[NullPipesContext](https://joekirincic.github.io/dagsterpipes/reference/NullPipesContext.md)
that logs to the console and silently ignores reports.

## Usage

``` r
open_dagster_pipes()
```

## Value

A
[PipesContext](https://joekirincic.github.io/dagsterpipes/reference/PipesContext.md)
or
[NullPipesContext](https://joekirincic.github.io/dagsterpipes/reference/NullPipesContext.md)
object.

## Examples

``` r
if (FALSE) { # \dontrun{
ctx <- open_dagster_pipes()

threshold <- ctx$get_extra("threshold")
ctx$log(sprintf("Using threshold = %s", threshold), level = "INFO")

# ... do work ...

ctx$report_asset_materialization(
  metadata = list(
    row_count = pipes_metadata_value(1000L, "int")
  )
)
ctx$close()
} # }
```
