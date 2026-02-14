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
