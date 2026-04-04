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
  url_mv <- pipes_metadata_value("http://example.com", "url")
  expect_equal(url_mv$raw_value, "http://example.com")
  expect_equal(url_mv$type, "url")

  float_mv <- pipes_metadata_value(3.14, "float")
  expect_equal(float_mv$raw_value, 3.14)
  expect_equal(float_mv$type, "float")

  json_mv <- pipes_metadata_value(list(a = 1, b = 2), "json")
  expect_equal(json_mv$raw_value, list(a = 1, b = 2))
  expect_equal(json_mv$type, "json")

  bool_mv <- pipes_metadata_value(TRUE, "bool")
  expect_equal(bool_mv$raw_value, TRUE)
  expect_equal(bool_mv$type, "bool")

  path_mv <- pipes_metadata_value("/data/out.csv", "path")
  expect_equal(path_mv$raw_value, "/data/out.csv")
  expect_equal(path_mv$type, "path")
})
