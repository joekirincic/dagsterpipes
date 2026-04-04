# Decode a Dagster Pipes bootstrap parameter

Decodes a base64-encoded, zlib-compressed JSON string from a Dagster
Pipes environment variable.

## Usage

``` r
decode_param(encoded)
```

## Arguments

- encoded:

  A base64-encoded, zlib-compressed JSON string.

## Value

A list parsed from the decoded JSON.
