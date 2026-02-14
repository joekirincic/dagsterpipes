test_that("open_dagster_pipes returns NullPipesContext when env vars absent", {
  # Save and clear env vars
  old_ctx <- Sys.getenv("DAGSTER_PIPES_CONTEXT", unset = NA)
  old_msg <- Sys.getenv("DAGSTER_PIPES_MESSAGES", unset = NA)
  Sys.unsetenv("DAGSTER_PIPES_CONTEXT")
  Sys.unsetenv("DAGSTER_PIPES_MESSAGES")
  on.exit({
    if (!is.na(old_ctx)) Sys.setenv(DAGSTER_PIPES_CONTEXT = old_ctx)
    if (!is.na(old_msg)) Sys.setenv(DAGSTER_PIPES_MESSAGES = old_msg)
  })

  ctx <- suppressMessages(open_dagster_pipes())
  expect_s3_class(ctx, "NullPipesContext")
  expect_false(ctx$is_asset_step)
  expect_false(ctx$is_partition_step)
  expect_null(ctx$run_id)
})

test_that("NullPipesContext log produces console message", {
  ctx <- NullPipesContext$new()
  expect_message(ctx$log("test message", level = "INFO"), "\\[INFO\\] test message")
})

test_that("NullPipesContext get_extra returns NULL with message", {
  ctx <- NullPipesContext$new()
  expect_message(result <- ctx$get_extra("foo"), "get_extra")
  expect_null(result)
})

test_that("NullPipesContext report methods are silent no-ops", {
  ctx <- NullPipesContext$new()
  expect_silent(ctx$report_asset_materialization())
  expect_silent(ctx$report_asset_check("check", TRUE))
  expect_silent(ctx$report_custom_message(list()))
  expect_silent(ctx$close())
})

test_that("full integration: open, report, close", {
  # Create context and messages temp files
  ctx_file <- tempfile(fileext = ".json")
  msg_file <- tempfile(fileext = ".json")
  on.exit(unlink(c(ctx_file, msg_file)), add = TRUE)

  # Write context data
  context_data <- list(
    asset_keys = list("integration_asset"),
    code_version_by_asset_key = list(integration_asset = NULL),
    provenance_by_asset_key = list(integration_asset = NULL),
    partition_key = NULL,
    partition_key_range = NULL,
    partition_time_window = NULL,
    run_id = "run-123",
    job_name = "integration_job",
    retry_number = 0,
    extras = list(param1 = "value1")
  )
  writeLines(
    jsonlite::toJSON(context_data, auto_unbox = TRUE, null = "null"),
    ctx_file
  )

  # Encode bootstrap params
  encode_param <- function(obj) {
    json_str <- jsonlite::toJSON(obj, auto_unbox = TRUE)
    compressed <- memCompress(charToRaw(json_str), type = "gzip")
    jsonlite::base64_enc(compressed)
  }

  ctx_env <- encode_param(list(path = ctx_file))
  msg_env <- encode_param(list(path = msg_file))

  # Save and set env vars
  old_ctx <- Sys.getenv("DAGSTER_PIPES_CONTEXT", unset = NA)
  old_msg <- Sys.getenv("DAGSTER_PIPES_MESSAGES", unset = NA)
  Sys.setenv(DAGSTER_PIPES_CONTEXT = ctx_env, DAGSTER_PIPES_MESSAGES = msg_env)
  on.exit({
    if (is.na(old_ctx)) Sys.unsetenv("DAGSTER_PIPES_CONTEXT") else Sys.setenv(DAGSTER_PIPES_CONTEXT = old_ctx)
    if (is.na(old_msg)) Sys.unsetenv("DAGSTER_PIPES_MESSAGES") else Sys.setenv(DAGSTER_PIPES_MESSAGES = old_msg)
  }, add = TRUE)

  ctx <- open_dagster_pipes()
  expect_s3_class(ctx, "PipesContext")
  expect_equal(ctx$asset_key, "integration_asset")
  expect_equal(ctx$run_id, "run-123")
  expect_equal(ctx$get_extra("param1"), "value1")

  ctx$log("Starting work", level = "INFO")
  ctx$report_asset_materialization(
    metadata = list(rows = pipes_metadata_value(42L, "int"))
  )
  ctx$report_asset_check("quality_check", passed = TRUE)
  ctx$close()

  # Verify messages file
  lines <- readLines(msg_file)
  expect_length(lines, 5)  # opened, log, materialization, check, closed

  methods <- vapply(lines, function(l) {
    jsonlite::fromJSON(l, simplifyVector = FALSE)$method
  }, character(1))
  expect_equal(
    unname(methods),
    c("opened", "log", "report_asset_materialization",
      "report_asset_check", "closed")
  )

  # Verify each message has the version field
  for (line in lines) {
    parsed <- jsonlite::fromJSON(line, simplifyVector = FALSE)
    expect_equal(parsed$`__dagster_pipes_version`, "0.1")
  }
})
