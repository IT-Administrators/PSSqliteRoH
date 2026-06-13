# PSSqliteRoH

A cross-platform .NET PowerShell module for managing SQLite databases.

## Build

The module already ships with the cross-platform helper library in `lib/netstandard2.0`, including native SQLite binaries for Windows, Linux, and macOS. No runtime-specific compilation is required.

If you want to rebuild the helper library, use `dotnet build`:

```powershell
dotnet build src/PSSqliteRoH.Sqlite/PSSqliteRoH.Sqlite.csproj
```

```bash
dotnet build src/PSSqliteRoH.Sqlite/PSSqliteRoH.Sqlite.csproj
```

When the module is imported, `PSSqliteRoH.psm1` loads the helper assembly directly from `lib/netstandard2.0`.

## Tests

Run the .NET unit tests with xUnit:

```powershell
dotnet test src/PSSqliteRoH.Sqlite.Tests/PSSqliteRoH.Sqlite.Tests.csproj
```

Run the PowerShell module tests with Pester:

```powershell
Invoke-Pester -Path .\tests\PSSqliteRoH.Tests.ps1
```

## Getting started

Import the module from the repository root:

```powershell
Import-Module .\PSSqliteRoH.psd1
```

Create and open a SQLite database:

```powershell
$database = New-SqliteDatabase -Path './data/example.db' -Create -PassThru
```

Open an existing database:

```powershell
$database = New-SqliteDatabase -Path './data/example.db' -PassThru
```

Open using a custom connection string:

```powershell
$database = New-SqliteDatabase -ConnectionString 'Data Source=./data/example.db;Mode=ReadWriteCreate' -PassThru
```

The returned object is a `Microsoft.Data.Sqlite.SqliteConnection` instance that can be used to execute SQL commands.

## Examples: Invoke-SqliteQuery

Below are common ways to call `Invoke-SqliteQuery` using each parameter set. Import the module first:

```powershell
Import-Module .\PSSqliteRoH.psd1
```

- Using `-Path` to create a new database and run DDL/DML:

```powershell
$dbPath = Join-Path $env:TEMP "example_create.db"
Remove-Item -Path $dbPath -ErrorAction SilentlyContinue

# Create table in a new DB
Invoke-SqliteQuery -Query 'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);' -Path $dbPath -Create | Out-Null

# Insert rows
Invoke-SqliteQuery -Query "INSERT INTO users (name) VALUES ('Alice');" -Path $dbPath | Out-Null
Invoke-SqliteQuery -Query "INSERT INTO users (name) VALUES ('Bob');" -Path $dbPath | Out-Null

# Select rows
Invoke-SqliteQuery -Query 'SELECT id, name FROM users ORDER BY id;' -Path $dbPath
```

- Using `-Path` with an existing database (no `-Create`):

```powershell
$existing = 'C:\path\to\existing.db'
Invoke-SqliteQuery -Query 'SELECT name FROM users;' -Path $existing
```

- Using an open `-Connection` object (reuse an open `SqliteConnection`):

```powershell
$conn = New-SqliteDatabase -Path $dbPath -PassThru
Invoke-SqliteQuery -Query "INSERT INTO users (name) VALUES ('Charlie');" -Connection $conn | Out-Null
Invoke-SqliteQuery -Query 'SELECT id, name FROM users;' -Connection $conn
$conn.Close()
```

- Using a `-ConnectionString` directly:

```powershell
$cs = 'Data Source=./data/example.db;Mode=ReadWriteCreate'
Invoke-SqliteQuery -Query 'SELECT sqlite_version();' -ConnectionString $cs
```

- Read-only mode: open with `-ReadOnly` or a connection string with `Mode=ReadOnly` to prevent modifications.

```powershell
# Open read-only by Path
Invoke-SqliteQuery -Query 'SELECT id, name FROM users;' -Path $dbPath -ReadOnly

# Attempts to write will be prevented (PRAGMA query_only is set when possible)
{ Invoke-SqliteQuery -Query "INSERT INTO users (name) VALUES ('Eve');" -Path $dbPath -ReadOnly } | Should -Throw
```

These examples show how to create a database, run queries, reuse connections, and enforce read-only behavior.
