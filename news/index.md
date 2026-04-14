# Changelog

## dagsterpipes 0.1.0

- Initial release.
- Implements the Dagster Pipes protocol for R, enabling R scripts to run
  as external processes orchestrated by Dagster.
- Provides
  [`with_dagster_pipes()`](https://joekirincic.github.io/dagsterpipes/reference/with_dagster_pipes.md),
  [`open_dagster_pipes()`](https://joekirincic.github.io/dagsterpipes/reference/open_dagster_pipes.md),
  `PipesContext`, `NullPipesContext`, and
  [`pipes_metadata_value()`](https://joekirincic.github.io/dagsterpipes/reference/pipes_metadata_value.md)
  as the public API.
- File-based message transport compatible with Dagster’s default
  `PipesSubprocessClient` / `PipesTempFileMessageReader`.
- Minimal dependency footprint (R6, jsonlite).
