# Pipes File Message Writer Channel

Pipes File Message Writer Channel

Pipes File Message Writer Channel

## Details

Writes newline-delimited JSON messages to a temporary file for the
Dagster Pipes protocol.

## Methods

### Public methods

- [`PipesFileMessageWriterChannel$new()`](#method-PipesFileMessageWriterChannel-new)

- [`PipesFileMessageWriterChannel$write_message()`](#method-PipesFileMessageWriterChannel-write_message)

- [`PipesFileMessageWriterChannel$clone()`](#method-PipesFileMessageWriterChannel-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new message writer channel.

#### Usage

    PipesFileMessageWriterChannel$new(path)

#### Arguments

- `path`:

  Path to the messages file.

------------------------------------------------------------------------

### Method `write_message()`

Write a message to the file.

#### Usage

    PipesFileMessageWriterChannel$write_message(message)

#### Arguments

- `message`:

  A list representing a Dagster Pipes message.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    PipesFileMessageWriterChannel$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
