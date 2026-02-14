test_that("PipesFileMessageWriterChannel writes JSON lines", {
  tmp <- tempfile()
  on.exit(unlink(tmp))

  channel <- PipesFileMessageWriterChannel$new(tmp)

  msg1 <- list(`__dagster_pipes_version` = "0.1", method = "opened", params = list())
  msg2 <- list(`__dagster_pipes_version` = "0.1", method = "closed", params = list())

  channel$write_message(msg1)
  channel$write_message(msg2)

  lines <- readLines(tmp)
  expect_length(lines, 2)

  parsed1 <- jsonlite::fromJSON(lines[[1]], simplifyVector = FALSE)
  expect_equal(parsed1$method, "opened")

  parsed2 <- jsonlite::fromJSON(lines[[2]], simplifyVector = FALSE)
  expect_equal(parsed2$method, "closed")
})

test_that("PipesFileMessageWriterChannel appends correctly", {
  tmp <- tempfile()
  on.exit(unlink(tmp))

  channel <- PipesFileMessageWriterChannel$new(tmp)

  for (i in 1:5) {
    channel$write_message(list(
      `__dagster_pipes_version` = "0.1",
      method = "log",
      params = list(message = paste("msg", i), level = "INFO")
    ))
  }

  lines <- readLines(tmp)
  expect_length(lines, 5)
})

test_that("message writer handles metadata in messages", {
  tmp <- tempfile()
  on.exit(unlink(tmp))

  channel <- PipesFileMessageWriterChannel$new(tmp)

  msg <- list(
    `__dagster_pipes_version` = "0.1",
    method = "report_asset_materialization",
    params = list(
      asset_key = "my_asset",
      data_version = NULL,
      metadata = list(
        row_count = list(raw_value = 1000, type = "int")
      )
    )
  )
  channel$write_message(msg)

  lines <- readLines(tmp)
  parsed <- jsonlite::fromJSON(lines[[1]], simplifyVector = FALSE)
  expect_equal(parsed$params$metadata$row_count$raw_value, 1000)
  expect_equal(parsed$params$metadata$row_count$type, "int")
})
