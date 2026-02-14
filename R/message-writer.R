#' Pipes File Message Writer Channel
#'
#' Writes newline-delimited JSON messages to a temporary file for the Dagster
#' Pipes protocol.
#'
#' @keywords internal
PipesFileMessageWriterChannel <- R6::R6Class(
  "PipesFileMessageWriterChannel",
  public = list(
    #' @description Create a new message writer channel.
    #' @param path Path to the messages file.
    initialize = function(path) {
      private$.path <- path
    },

    #' @description Write a message to the file.
    #' @param message A list representing a Dagster Pipes message.
    write_message = function(message) {
      json_line <- json_serialize(message)
      cat(json_line, "\n", file = private$.path, append = TRUE, sep = "")
    }
  ),
  private = list(
    .path = NULL
  )
)
