<!-- toc:insertAfterHeading=PSSqliteRoH — API and Code Overview-->
<!-- toc:insertAfterHeadingOffset=3 -->

# PSSqliteRoH — API and Code Overview

This document summarizes the main classes, functions, and methods used by the project, what they do, and where they are defined.

## Table of Contents

1. [High-level counts](#high-level-counts)
1. [C# — src/PSSqliteRoH.Sqlite/SqliteDatabase.cs](#c-srcpssqliterohsqlitesqlitedatabasecs)
1. [PowerShell — PSSqliteRoH.psm1](#powershell-pssqliterohpsm1)
1. [Tests](#tests)
1. [Notes and recommendations](#notes-and-recommendations)
1. [File references](#file-references)

## High-level counts

- C# classes: 2 (public or internal helper classes)
- C# methods (public/overrides/static): 4
- PowerShell functions: 4 (3 exported public functions + 1 internal helper)


## C# — src/PSSqliteRoH.Sqlite/SqliteDatabase.cs

- `SqliteDatabaseManager` (public static class)
  - Purpose: Central helper for building connection strings and creating SQLite connections from those strings. Used by PowerShell cmdlets to open or create databases in a cross-platform way.
  - Members:
    - static constructor (static SqliteDatabaseManager())
      - Purpose: Initializes the native SQLite provider by calling `Batteries_V2.Init()`.
      - File reference: [src/PSSqliteRoH.Sqlite/SqliteDatabase.cs](src/PSSqliteRoH.Sqlite/SqliteDatabase.cs)
    - `BuildConnectionString(string databasePath, bool createIfNotExists, bool readOnly)`
      - Purpose: Validates path, creates directories (if allowed), and returns a `SqliteConnectionStringBuilder`-based connection string. Chooses the appropriate `Mode` (ReadOnly/ReadWriteCreate/ReadWrite) and sets `Cache=Shared`.
      - Returns: `string` (formatted connection string).
      - File reference: [src/PSSqliteRoH.Sqlite/SqliteDatabase.cs](src/PSSqliteRoH.Sqlite/SqliteDatabase.cs)
    - `CreateConnection(string connectionString)`
      - Purpose: Creates a `SqliteConnection`. If the connection string indicates `Mode=ReadOnly`, returns a `ReadOnlySqliteConnection` that enforces `PRAGMA query_only = TRUE` when opened.
      - Returns: `SqliteConnection` or `ReadOnlySqliteConnection`.
      - File reference: [src/PSSqliteRoH.Sqlite/SqliteDatabase.cs](src/PSSqliteRoH.Sqlite/SqliteDatabase.cs)

- `ReadOnlySqliteConnection` (internal class, extends `SqliteConnection`)
  - Purpose: Wrapper connection that overrides `Open()` to set `PRAGMA query_only = TRUE` after opening, enforcing SQLite-level read-only behavior that prevents writes and DDL when applied.
  - Members:
    - `ReadOnlySqliteConnection(string connectionString)` — constructor
    - `Open()` — override that sets the read-only PRAGMA and throws a descriptive error if it cannot be applied.
  - File reference: [src/PSSqliteRoH.Sqlite/SqliteDatabase.cs][sqlitedatabase]


## PowerShell — PSSqliteRoH.psm1

- `New-SqliteDatabase` (function)
  - Purpose: PowerShell cmdlet that opens or creates a SQLite database. Accepts either a file `-Path` or an explicit `-ConnectionString`. Parameters: `-Create`, `-ReadOnly`, `-PassThru`.
  - Behavior: Builds a connection string via `SqliteDatabaseManager.BuildConnectionString`, creates the connection via `SqliteDatabaseManager.CreateConnection`, opens the connection, optionally sets `PRAGMA query_only = TRUE` for read-only mode, and returns either the raw connection (when `-PassThru`) or a PSCustomObject with `DatabasePath`, `ConnectionString`, and `Connection`.
  - File reference: [PSSqliteRoH.psm1][pssqliteroh]

- `Get-SqliteConnection` (function)
  - Purpose: Resolves or opens a SQLite connection from one of three input sources: a database file path, an explicit connection string, or an existing `DbConnection` object.
  - Behavior: When given `-Path`, it builds a connection string and opens a new connection; when given `-ConnectionString`, it opens a new connection directly; when given `-Connection`, it ensures the provided connection is open. Returns a PSCustomObject with `Connection` and `Created` properties.
  - Notes: This helper function is not part of the normal exported public API when importing the module via `PSSqliteRoH.psd1`; it is only available when importing the `.psm1` file directly.
  - File reference: [PSSqliteRoH.psm1][pssqliteroh]

- `Invoke-SqliteQuery` (function)
  - Purpose: Runs SQL statements against a SQLite database using a single connection context object returned by `Get-SqliteConnection`.
  - Behavior: For SELECT queries returns rows as `PSCustomObject` instances; for non-query statements returns a small PSCustomObject with `Query` and `RowsAffected`. It uses the provided connection and does not close or dispose it.
  - File reference: [PSSqliteRoH.psm1][pssqliteroh]

- `Get-SqliteVersion` (function)
  - Purpose: Returns the SQLite engine version for a current database using `SELECT sqlite_version()`.
  - Behavior: Accepts a connection context object returned by `Get-SqliteConnection` and leaves the connection open.
  - File reference: [PSSqliteRoH.psm1][pssqliteroh]

- `Get-SqliteDatabaseManagerType` (function helper)
  - Purpose: Check if the dlls are correctly imported.
  - Behavior: Checks if the dlls are correctly imported by check the name of all assemblies in the current runspace. If it contains this modules name it is correctly imported.

- `Get-SqliteTableNames` (function)
  - Purpose: Return all user created table names to check if a table exists.
  - Behavior: Checks the sqlite_master table for all user created table names.

## Tests

- C# unit tests (xUnit): [src/PSSqliteRoH.Sqlite.Tests/][pssqliteroh.sqlite.tests]
  - `SqliteDatabaseManagerTests` — tests for `BuildConnectionString` and `CreateConnection` behaviors.
  - `SqliteCrudTests` — integration-style tests that create a temporary database and verify CREATE/INSERT/SELECT/UPDATE/DELETE operations and read-only enforcement.

- PowerShell tests (Pester): [tests/PSSqliteRoH.Tests.ps1][pssqliteroh.tests.ps1]
  - Tests import the module and verify `New-SqliteDatabase` and `Invoke-SqliteQuery` behaviors.


## Notes and recommendations

- The project uses the `Microsoft.Data.Sqlite` provider and includes a netstandard2.0 helper assembly in `lib/netstandard2.0/` so the module can be imported cross-platform without rebuilding.
- Read-only enforcement for SQLite is implemented using `PRAGMA query_only = TRUE` in `ReadOnlySqliteConnection.Open()` — this is reliable across platforms and triggers `SqliteException` when write operations are attempted.


## File references

- [PSSqliteRoH.psm1][pssqliteroh]
- [src/PSSqliteRoH.Sqlite/SqliteDatabase.cs][sqlitedatabase]
- [src/PSSqliteRoH.Sqlite.Tests/SqliteCrudTests.cs][sqlitecrudtests]
- [src/PSSqliteRoH.Sqlite.Tests/SqliteDatabaseManagerTests.cs][sqlitedatabasemanagertests]
- [tests/PSSqliteRoH.Tests.ps1][pssqliteroh.tests.ps1]


[sqlitedatabase]: src/PSSqliteRoH.Sqlite/SqliteDatabase.cs
[pssqliteroh]: PSSqliteRoH.psm1
[pssqliteroh.sqlite.tests]: src/PSSqliteRoH.Sqlite.Tests/
[pssqliteroh.tests.ps1]: tests/PSSqliteRoH.Tests.ps1
[sqlitecrudtests]: src/PSSqliteRoH.Sqlite.Tests/SqliteCrudTests.cs
[sqlitedatabasemanagertests]: src/PSSqliteRoH.Sqlite.Tests/SqliteDatabaseManagerTests.cs