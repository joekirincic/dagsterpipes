# Create a typed metadata value for Dagster Pipes

Wraps a raw value with a type annotation for the Dagster Pipes protocol.

## Usage

``` r
pipes_metadata_value(raw_value, type = "__infer__")
```

## Arguments

- raw_value:

  The value to report.

- type:

  The metadata type. One of `"text"`, `"url"`, `"path"`, `"notebook"`,
  `"json"`, `"md"`, `"float"`, `"int"`, `"bool"`, `"dagster_run"`,
  `"asset"`, `"null"`, `"table"`, `"table_schema"`,
  `"table_column_lineage"`, `"timestamp"`, or `"__infer__"` (default).

## Value

A list with `raw_value` and `type` elements.

## Examples

``` r
pipes_metadata_value(1000L, "int")
#> $raw_value
#> [1] 1000
#> 
#> $type
#> [1] "int"
#> 
pipes_metadata_value("/data/output.csv", "path")
#> $raw_value
#> [1] "/data/output.csv"
#> 
#> $type
#> [1] "path"
#> 
pipes_metadata_value(0.97, "float")
#> $raw_value
#> [1] 0.97
#> 
#> $type
#> [1] "float"
#> 
# Let Dagster infer the type from the raw value:
pipes_metadata_value("hello world")
#> $raw_value
#> [1] "hello world"
#> 
#> $type
#> [1] "__infer__"
#> 
```
