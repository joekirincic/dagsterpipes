#' Open a Dagster Pipes session
#'
#' Reads bootstrap parameters from environment variables, initializes the
#' message channel, and returns a [PipesContext] ready to use. When not running
#' under Dagster (environment variables absent), returns a no-op
#' [NullPipesContext] that logs to the console and silently ignores reports.
#'
#' @return A [PipesContext] or [NullPipesContext] object.
#' @export
open_dagster_pipes <- function() {
  context_env <- Sys.getenv("DAGSTER_PIPES_CONTEXT", unset = "")
  messages_env <- Sys.getenv("DAGSTER_PIPES_MESSAGES", unset = "")

  if (context_env == "" || messages_env == "") {
    message("Not running under Dagster Pipes. Returning no-op context.")
    return(NullPipesContext$new())
  }

  context_params <- decode_param(context_env)
  messages_params <- decode_param(messages_env)

  context_data <- jsonlite::fromJSON(context_params$path, simplifyVector = FALSE)
  message_channel <- PipesFileMessageWriterChannel$new(messages_params$path)

  PipesContext$new(context_data, message_channel)
}


#' Null Pipes Context (no-op)
#'
#' A lightweight stand-in for [PipesContext] used when running outside Dagster.
#' Log calls go to [message()]; report calls are silently ignored.
#'
#' @export
NullPipesContext <- R6::R6Class(
  "NullPipesContext",
  public = list(
    #' @description Create a new NullPipesContext.
    initialize = function() {
      invisible(self)
    },

    #' @description Get an extra value by key. Always returns `NULL`.
    #' @param key The extra key.
    get_extra = function(key) {
      message(sprintf("[NullPipesContext] get_extra('%s') -> NULL", key))
      NULL
    },

    #' @description Log a message to the R console.
    #' @param message The log message text.
    #' @param level The log level.
    log = function(message, level = "INFO") {
      base::message(sprintf("[%s] %s", level, message))
    },

    #' @description No-op materialization report.
    #' @param metadata Ignored.
    #' @param asset_key Ignored.
    #' @param data_version Ignored.
    report_asset_materialization = function(metadata = NULL, asset_key = NULL,
                                            data_version = NULL) {
      invisible(NULL)
    },

    #' @description No-op asset check report.
    #' @param check_name Ignored.
    #' @param passed Ignored.
    #' @param asset_key Ignored.
    #' @param severity Ignored.
    #' @param metadata Ignored.
    report_asset_check = function(check_name, passed, asset_key = NULL,
                                   severity = "ERROR", metadata = NULL) {
      invisible(NULL)
    },

    #' @description No-op custom message report.
    #' @param payload Ignored.
    report_custom_message = function(payload) {
      invisible(NULL)
    },

    #' @description No-op close.
    close = function() {
      invisible(NULL)
    }
  ),
  active = list(
    #' @field asset_keys Always `list()`.
    asset_keys = function() list(),

    #' @field asset_key Always errors.
    asset_key = function() {
      stop("No asset key available in NullPipesContext.")
    },

    #' @field run_id Always `NULL`.
    run_id = function() NULL,

    #' @field job_name Always `NULL`.
    job_name = function() NULL,

    #' @field retry_number Always `0`.
    retry_number = function() 0L,

    #' @field extras Always empty list.
    extras = function() list(),

    #' @field partition_key Always `NULL`.
    partition_key = function() NULL,

    #' @field partition_key_range Always `NULL`.
    partition_key_range = function() NULL,

    #' @field partition_time_window Always `NULL`.
    partition_time_window = function() NULL,

    #' @field is_asset_step Always `FALSE`.
    is_asset_step = function() FALSE,

    #' @field is_partition_step Always `FALSE`.
    is_partition_step = function() FALSE,

    #' @field provenance Always `NULL`.
    provenance = function() NULL,

    #' @field code_version Always `NULL`.
    code_version = function() NULL
  )
)
