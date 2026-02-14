#' Pipes Context
#'
#' Holds the execution context received from Dagster and provides methods to
#' report materializations, asset checks, logs, and custom messages back to the
#' orchestrator.
#'
#' @export
PipesContext <- R6::R6Class(
  "PipesContext",
  public = list(
    #' @description Create a new PipesContext.
    #' @param context_data A list of context data from Dagster.
    #' @param message_channel A `PipesFileMessageWriterChannel` instance.
    initialize = function(context_data, message_channel) {
      private$.context_data <- context_data
      private$.message_channel <- message_channel
      private$write_message("opened")
    },

    #' @description Get an extra value by key.
    #' @param key The extra key to look up.
    #' @return The value associated with the key, or an error if not found.
    get_extra = function(key) {
      extras <- private$.context_data$extras
      if (!key %in% names(extras)) {
        stop(sprintf("Extra key '%s' not found. Available keys: %s",
                      key, paste(names(extras), collapse = ", ")))
      }
      extras[[key]]
    },

    #' @description Send a log message to Dagster.
    #' @param message The log message text.
    #' @param level The log level. One of `"DEBUG"`, `"INFO"`, `"WARNING"`,
    #'   `"ERROR"`, `"CRITICAL"`.
    log = function(message, level = "INFO") {
      valid_levels <- c("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")
      level <- toupper(level)
      if (!level %in% valid_levels) {
        stop(sprintf("Invalid log level '%s'. Must be one of: %s",
                      level, paste(valid_levels, collapse = ", ")))
      }
      private$write_message("log", list(message = message, level = level))
    },

    #' @description Report an asset materialization to Dagster.
    #' @param metadata A named list of metadata values (use [pipes_metadata_value()]).
    #' @param asset_key The asset key. If `NULL`, uses the single asset key from context.
    #' @param data_version Optional data version string.
    report_asset_materialization = function(metadata = NULL, asset_key = NULL,
                                            data_version = NULL) {
      if (is.null(asset_key)) {
        asset_key <- self$asset_key
      }
      params <- list(
        asset_key = asset_key,
        data_version = data_version,
        metadata = metadata %||% list()
      )
      private$write_message("report_asset_materialization", params)
    },

    #' @description Report an asset check result to Dagster.
    #' @param check_name The name of the check.
    #' @param passed Whether the check passed.
    #' @param asset_key The asset key. If `NULL`, uses the single asset key from context.
    #' @param severity The severity level (`"ERROR"` or `"WARN"`).
    #' @param metadata A named list of metadata values.
    report_asset_check = function(check_name, passed, asset_key = NULL,
                                   severity = "ERROR", metadata = NULL) {
      if (is.null(asset_key)) {
        asset_key <- self$asset_key
      }
      params <- list(
        asset_key = asset_key,
        check_name = check_name,
        passed = passed,
        severity = severity,
        metadata = metadata %||% list()
      )
      private$write_message("report_asset_check", params)
    },

    #' @description Report a custom message to Dagster.
    #' @param payload An arbitrary R object to send as the message payload.
    report_custom_message = function(payload) {
      private$write_message("report_custom_message", list(payload = payload))
    },

    #' @description Close the Pipes session.
    close = function() {
      if (!private$.closed) {
        private$write_message("closed")
        private$.closed <- TRUE
      }
    }
  ),
  active = list(
    #' @field asset_keys The list of asset keys from the context.
    asset_keys = function() private$.context_data$asset_keys,

    #' @field asset_key The single asset key. Errors if there is not exactly one.
    asset_key = function() {
      keys <- private$.context_data$asset_keys
      if (length(keys) != 1) {
        stop(sprintf(
          "Expected exactly 1 asset key, got %d. Use `asset_keys` instead.",
          length(keys)
        ))
      }
      keys[[1]]
    },

    #' @field run_id The Dagster run ID.
    run_id = function() private$.context_data$run_id,

    #' @field job_name The Dagster job name.
    job_name = function() private$.context_data$job_name,

    #' @field retry_number The current retry number.
    retry_number = function() private$.context_data$retry_number,

    #' @field extras The extras dictionary passed from Dagster.
    extras = function() private$.context_data$extras,

    #' @field partition_key The partition key, or `NULL`.
    partition_key = function() private$.context_data$partition_key,

    #' @field partition_key_range The partition key range, or `NULL`.
    partition_key_range = function() private$.context_data$partition_key_range,

    #' @field partition_time_window The partition time window, or `NULL`.
    partition_time_window = function() private$.context_data$partition_time_window,

    #' @field is_asset_step Whether this step involves assets.
    is_asset_step = function() length(private$.context_data$asset_keys) > 0,

    #' @field is_partition_step Whether this step involves partitions.
    is_partition_step = function() !is.null(private$.context_data$partition_key),

    #' @field provenance The provenance info by asset key.
    provenance = function() private$.context_data$provenance_by_asset_key,

    #' @field code_version The code version info by asset key.
    code_version = function() private$.context_data$code_version_by_asset_key
  ),
  private = list(
    .context_data = NULL,
    .message_channel = NULL,
    .closed = FALSE,
    write_message = function(method, params = NULL) {
      msg <- list(
        `__dagster_pipes_version` = "0.1",
        method = method,
        params = params %||% list()
      )
      private$.message_channel$write_message(msg)
    }
  )
)
