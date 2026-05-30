# PSSqliteRoH

A cross-platform .NET PowerShell module for managing SQLite databases.

## Build

Use the included build script to publish the .NET helper library into `dist/<rid>`.

PowerShell:

```powershell
.\build.ps1 -RuntimeIdentifier linux-x64
```

Bash:

```bash
./build.sh linux-x64
```

The output will be published into `dist/<rid>` and loaded automatically by `PSSqliteRoH.psm1` when available.

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
