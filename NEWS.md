# dagsterpipes 0.1.0

* Initial release.
* Implements the Dagster Pipes protocol for R, enabling R scripts to run as external processes orchestrated by Dagster.
* Provides `open_dagster_pipes()`, `PipesContext`, `NullPipesContext`, and `pipes_metadata_value()` as the public API.
* File-based message transport compatible with Dagster's default `PipesSubprocessClient` / `PipesTempFileMessageReader`.
* Minimal dependency footprint (R6, jsonlite).
