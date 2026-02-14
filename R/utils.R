#' Null-coalescing operator (internal, no roxygen)
#' @keywords internal
#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Decode a Dagster Pipes bootstrap parameter
#'
#' Decodes a base64-encoded, zlib-compressed JSON string from a Dagster Pipes
#' environment variable.
#'
#' @param encoded A base64-encoded, zlib-compressed JSON string.
#' @return A list parsed from the decoded JSON.
#' @keywords internal
decode_param <- function(encoded) {
  raw_bytes <- jsonlite::base64_dec(encoded)
  decompressed <- memDecompress(raw_bytes, type = "gzip")
  jsonlite::fromJSON(rawToChar(decompressed), simplifyVector = FALSE)
}

#' Serialize an R object to Dagster-compatible JSON
#'
#' @param obj An R object to serialize.
#' @return A JSON string.
#' @keywords internal
json_serialize <- function(obj) {
  jsonlite::toJSON(obj, auto_unbox = TRUE, null = "null", digits = NA)
}
