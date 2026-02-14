test_that("pipes_metadata_value creates correct structure", {
  mv <- pipes_metadata_value(1000L, "int")
  expect_type(mv, "list")
  expect_equal(mv$raw_value, 1000L)
  expect_equal(mv$type, "int")
})

test_that("pipes_metadata_value defaults to __infer__", {
  mv <- pipes_metadata_value("hello")
  expect_equal(mv$type, "__infer__")
  expect_equal(mv$raw_value, "hello")
})

test_that("pipes_metadata_value handles various types", {
  expect_equal(pipes_metadata_value(3.14, "float")$type, "float")
  expect_equal(pipes_metadata_value(TRUE, "bool")$type, "bool")
  expect_equal(pipes_metadata_value("/data/out.csv", "path")$type, "path")
  expect_equal(pipes_metadata_value(NULL, "null")$type, "null")
})
