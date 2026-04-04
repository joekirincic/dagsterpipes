make_test_context <- function() {
  tmp <- tempfile()
  context_data <- list(
    asset_keys = list("test_asset"),
    code_version_by_asset_key = list(test_asset = NULL),
    provenance_by_asset_key = list(test_asset = NULL),
    partition_key = NULL,
    partition_key_range = NULL,
    partition_time_window = NULL,
    run_id = "aaaa-bbbb-cccc",
    job_name = "test_job",
    retry_number = 0,
    extras = list(threshold = 0.5, output_path = "/tmp/out.csv")
  )
  channel <- PipesFileMessageWriterChannel$new(tmp)
  ctx <- PipesContext$new(context_data, channel)
  list(ctx = ctx, path = tmp)
}

test_that("PipesContext sends 'opened' on init", {
  res <- make_test_context()
  lines <- readLines(res$path)
  expect_length(lines, 1)
  parsed <- jsonlite::fromJSON(lines[[1]], simplifyVector = FALSE)
  expect_equal(parsed$method, "opened")
  expect_equal(parsed$`__dagster_pipes_version`, "0.1")
  expect_equal(parsed$params, list(extras = list()))
})

test_that("active bindings return correct values", {
  res <- make_test_context()
  ctx <- res$ctx

  expect_equal(ctx$asset_keys, list("test_asset"))
  expect_equal(ctx$asset_key, "test_asset")
  expect_equal(ctx$run_id, "aaaa-bbbb-cccc")
  expect_equal(ctx$job_name, "test_job")
  expect_equal(ctx$retry_number, 0)
  expect_true(ctx$is_asset_step)
  expect_false(ctx$is_partition_step)
  expect_null(ctx$partition_key)
})

test_that("get_extra returns values", {
  res <- make_test_context()
  ctx <- res$ctx

  expect_equal(ctx$get_extra("threshold"), 0.5)
  expect_equal(ctx$get_extra("output_path"), "/tmp/out.csv")
})

test_that("get_extra errors on missing key", {
  res <- make_test_context()
  expect_error(res$ctx$get_extra("nonexistent"), "not found")
})

test_that("asset_key errors with multiple keys", {
  tmp <- tempfile()
  context_data <- list(
    asset_keys = list("asset_a", "asset_b"),
    run_id = "x", job_name = "j", retry_number = 0, extras = list()
  )
  channel <- PipesFileMessageWriterChannel$new(tmp)
  ctx <- PipesContext$new(context_data, channel)
  expect_error(ctx$asset_key, "Expected exactly 1")
})

test_that("log writes correct message", {
  res <- make_test_context()
  res$ctx$log("hello world", level = "WARNING")

  lines <- readLines(res$path)
  # Line 1 = opened, Line 2 = log
  expect_length(lines, 2)
  parsed <- jsonlite::fromJSON(lines[[2]], simplifyVector = FALSE)
  expect_equal(parsed$method, "log")
  expect_equal(parsed$params$message, "hello world")
  expect_equal(parsed$params$level, "WARNING")
})

test_that("log rejects invalid levels", {
  res <- make_test_context()
  expect_error(res$ctx$log("msg", level = "TRACE"), "Invalid log level")
})

test_that("report_asset_materialization writes correct message", {
  res <- make_test_context()
  res$ctx$report_asset_materialization(
    metadata = list(
      row_count = pipes_metadata_value(500L, "int")
    ),
    data_version = "v1"
  )

  lines <- readLines(res$path)
  parsed <- jsonlite::fromJSON(lines[[2]], simplifyVector = FALSE)
  expect_equal(parsed$method, "report_asset_materialization")
  expect_equal(parsed$params$asset_key, "test_asset")
  expect_equal(parsed$params$data_version, "v1")
  expect_equal(parsed$params$metadata$row_count$raw_value, 500)
  expect_equal(parsed$params$metadata$row_count$type, "int")
})

test_that("report_asset_check writes correct message", {
  res <- make_test_context()
  res$ctx$report_asset_check("row_check", passed = TRUE, severity = "ERROR")

  lines <- readLines(res$path)
  parsed <- jsonlite::fromJSON(lines[[2]], simplifyVector = FALSE)
  expect_equal(parsed$method, "report_asset_check")
  expect_equal(parsed$params$check_name, "row_check")
  expect_true(parsed$params$passed)
  expect_equal(parsed$params$severity, "ERROR")
})

test_that("report_custom_message writes correct message", {
  res <- make_test_context()
  res$ctx$report_custom_message(list(key = "value"))

  lines <- readLines(res$path)
  parsed <- jsonlite::fromJSON(lines[[2]], simplifyVector = FALSE)
  expect_equal(parsed$method, "report_custom_message")
  expect_equal(parsed$params$payload$key, "value")
})

test_that("report_asset_materialization errors on duplicate asset key", {
  res <- make_test_context()
  res$ctx$report_asset_materialization(metadata = list())
  expect_error(
    res$ctx$report_asset_materialization(metadata = list()),
    "already been materialized"
  )
})

test_that("report methods error on asset_key not in asset_keys", {
  res <- make_test_context()
  expect_error(
    res$ctx$report_asset_materialization(asset_key = "not_a_real_asset"),
    "not one of the valid asset keys"
  )
  expect_error(
    res$ctx$report_asset_check(
      "c", passed = TRUE, asset_key = "not_a_real_asset", severity = "ERROR"
    ),
    "not one of the valid asset keys"
  )
})

test_that("report_asset_check validates severity", {
  res <- make_test_context()
  expect_error(
    res$ctx$report_asset_check("c", passed = TRUE, severity = "WARNING"),
    "Invalid severity"
  )
  expect_error(
    res$ctx$report_asset_check("c", passed = TRUE, severity = "FOO"),
    "Invalid severity"
  )
  # Both WARN and ERROR accepted
  expect_silent(res$ctx$report_asset_check("c1", passed = TRUE, severity = "WARN"))
  expect_silent(res$ctx$report_asset_check("c2", passed = TRUE, severity = "ERROR"))
})

test_that("close with exception reports exception params", {
  res <- make_test_context()
  err <- simpleError("boom")
  res$ctx$close(exception = err)

  lines <- readLines(res$path)
  closed_line <- lines[[length(lines)]]
  parsed <- jsonlite::fromJSON(closed_line, simplifyVector = FALSE)
  expect_equal(parsed$method, "closed")
  expect_equal(parsed$params$exception$message, "boom")
  expect_equal(parsed$params$exception$name, "simpleError")
  expect_true(is.list(parsed$params$exception$stack))
  expect_true(length(parsed$params$exception$stack) >= 1)
  expect_null(parsed$params$exception$cause)
  expect_null(parsed$params$exception$context)
})

test_that("close without exception sends empty params", {
  res <- make_test_context()
  res$ctx$close()

  lines <- readLines(res$path)
  closed_line <- lines[[length(lines)]]
  parsed <- jsonlite::fromJSON(closed_line, simplifyVector = FALSE)
  expect_equal(parsed$method, "closed")
  expect_equal(parsed$params, list())
})

test_that("log_external_stream writes correct message", {
  res <- make_test_context()
  res$ctx$log_external_stream("stdout", "hello")

  lines <- readLines(res$path)
  parsed <- jsonlite::fromJSON(lines[[2]], simplifyVector = FALSE)
  expect_equal(parsed$method, "log_external_stream")
  expect_equal(parsed$params$stream, "stdout")
  expect_equal(parsed$params$text, "hello")
  expect_equal(parsed$params$extras, list())
})

test_that("report_asset_materialization auto-wraps raw metadata values", {
  res <- make_test_context()
  res$ctx$report_asset_materialization(
    metadata = list(count = 42L, path = "/tmp/out.csv")
  )

  lines <- readLines(res$path)
  parsed <- jsonlite::fromJSON(lines[[2]], simplifyVector = FALSE)
  expect_equal(parsed$params$metadata$count,
               list(raw_value = 42L, type = "__infer__"))
  expect_equal(parsed$params$metadata$path,
               list(raw_value = "/tmp/out.csv", type = "__infer__"))
})

test_that("report_asset_materialization preserves explicit pipes_metadata_value", {
  res <- make_test_context()
  res$ctx$report_asset_materialization(
    metadata = list(
      count = 42L,
      url = pipes_metadata_value("http://x", "url")
    )
  )

  lines <- readLines(res$path)
  parsed <- jsonlite::fromJSON(lines[[2]], simplifyVector = FALSE)
  expect_equal(parsed$params$metadata$count,
               list(raw_value = 42L, type = "__infer__"))
  expect_equal(parsed$params$metadata$url$raw_value, "http://x")
  expect_equal(parsed$params$metadata$url$type, "url")
})

test_that("close sends closed message only once", {
  res <- make_test_context()
  res$ctx$close()
  res$ctx$close()  # second call should be no-op

  lines <- readLines(res$path)
  methods <- vapply(lines, function(l) {
    jsonlite::fromJSON(l, simplifyVector = FALSE)$method
  }, character(1))
  expect_equal(sum(methods == "closed"), 1)
})
