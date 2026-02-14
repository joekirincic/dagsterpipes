#' Create a typed metadata value for Dagster Pipes
#'
#' Wraps a raw value with a type annotation for the Dagster Pipes protocol.
#'
#' @param raw_value The value to report.
#' @param type The metadata type. One of `"text"`, `"url"`, `"path"`,
#'   `"notebook"`, `"json"`, `"md"`, `"float"`, `"int"`, `"bool"`,
#'   `"dagster_run"`, `"asset"`, `"null"`, `"table"`, `"table_schema"`,
#'   `"table_column_lineage"`, `"timestamp"`, or `"__infer__"` (default).
#' @return A list with `raw_value` and `type` elements.
#' @export
pipes_metadata_value <- function(raw_value, type = "__infer__") {
  list(raw_value = raw_value, type = type)
}
