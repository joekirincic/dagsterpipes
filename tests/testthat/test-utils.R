test_that("decode_param round-trips correctly", {
  # Build a valid encoded param: JSON -> zlib compress -> base64 encode
  original <- list(path = "/tmp/test_file.json")
  json_str <- jsonlite::toJSON(original, auto_unbox = TRUE)
  compressed <- memCompress(charToRaw(json_str), type = "gzip")
  encoded <- jsonlite::base64_enc(compressed)

  result <- decode_param(encoded)
  expect_type(result, "list")
  expect_equal(result$path, "/tmp/test_file.json")
})

test_that("decode_param handles complex data", {
  original <- list(path = "/tmp/ctx", extra = "value")
  json_str <- jsonlite::toJSON(original, auto_unbox = TRUE)
  compressed <- memCompress(charToRaw(json_str), type = "gzip")
  encoded <- jsonlite::base64_enc(compressed)

  result <- decode_param(encoded)
  expect_equal(result$path, "/tmp/ctx")
  expect_equal(result$extra, "value")
})

test_that("json_serialize produces Dagster-compatible JSON", {
  msg <- list(
    `__dagster_pipes_version` = "0.1",
    method = "opened",
    params = list()
  )
  json_str <- as.character(json_serialize(msg))
  parsed <- jsonlite::fromJSON(json_str, simplifyVector = FALSE)

  expect_equal(parsed$`__dagster_pipes_version`, "0.1")
  expect_equal(parsed$method, "opened")
  expect_type(parsed$params, "list")
})

test_that("json_serialize auto-unboxes scalars", {
  msg <- list(value = 42)
  json_str <- as.character(json_serialize(msg))
  # Should produce {"value":42} not {"value":[42]}
  expect_false(grepl("\\[", json_str))
})

test_that("json_serialize handles NULL as JSON null", {
  msg <- list(key = NULL)
  json_str <- as.character(json_serialize(msg))
  expect_true(grepl("null", json_str))
})

test_that("%||% returns left when non-NULL", {
  expect_equal(1 %||% 2, 1)
  expect_equal("a" %||% "b", "a")
})

test_that("%||% returns right when left is NULL", {
  expect_equal(NULL %||% 2, 2)
  expect_equal(NULL %||% list(), list())
})
