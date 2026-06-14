<!-- toc:insertAfterHeading= PSSqliteRoH-->
<!-- toc:insertAfterHeadingOffset=3 -->

# PSSqliteRoH

A powershell cross platform module to manage sqlite databases.

## Table of Contents

1. [Introduction](#introduction)
1. [Install](#install)
    1. [Prerequisites](#prerequisites)
        1. [Step 1: Clone or Download the Repository](#step-1-clone-or-download-the-repository)
        1. [Step 2: Import the Module](#step-2-import-the-module)
        1. [Step 3: Verify Installation](#step-3-verify-installation)
1. [Build](#build)
1. [How to use](#how-to-use)
1. [Documentation](#documentation)
1. [License](#license)

## Introduction

PSSqliteRoH is a cross-platform PowerShell module that wraps a .NET (netstandard2.0) helper library to manage SQLite databases. It provides simple PowerShell functions for creating/opening databases and running SQL queries while reusing a small C# helper library for connection management.

## Install


### Prerequisites

- **PowerShell**: Windows PowerShell 5.1+ or PowerShell Core 7.0+
- **Operating Systems**: Windows, Linux

#### Step 1: Clone or Download the Repository

Using Git:
```powershell
git clone "https://github.com/IT-Administrators/PSSqliteRoH.git"
cd PSSqliteRoH
```

Or download the ZIP archive:
```powershell
Invoke-WebRequest -Uri "https://github.com/IT-Administrators/PSSqliteRoH/archive/refs/heads/main.zip" -OutFile "PSSqliteRoH.zip"
Expand-Archive -Path ".\PSSqliteRoH.zip"
cd PSSqliteRoH-main
```

#### Step 2: Import the Module

**Import from current directory**
```powershell
Import-Module -Path ".\PSSqliteRoH.psm1" -Force -Verbose
```

#### Step 3: Verify Installation

```powershell
# Check if the module is loaded
Get-Module PSSqliteRoH

# View available commands
Get-Command -Module PSSqliteRoH

# Get detailed help
Get-Help <FunctionName> -Full
```

## Build

If you want to rebuild the helper library yourself:

```powershell
# PowerShell
dotnet build src/PSSqliteRoH.Sqlite/PSSqliteRoH.Sqlite.csproj

# Bash
dotnet build src/PSSqliteRoH.Sqlite/PSSqliteRoH.Sqlite.csproj
```

## How to use

Import the module and create/open a database:

```powershell
Import-Module .\PSSqliteRoH.psd1
$database = New-SqliteDatabase -Path './data/example.db' -Create -PassThru
```

Open an existing database:

```powershell
$database = New-SqliteDatabase -Path './data/example.db' -PassThru
```

Open with a custom connection string:

```powershell
$database = New-SqliteDatabase -ConnectionString 'Data Source=./data/example.db;Mode=ReadWriteCreate' -PassThru
```

Run SQL using `Invoke-SqliteQuery` (examples):

```powershell
# Create table
Invoke-SqliteQuery -Query 'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);' -Path ./data/example.db -Create | Out-Null

# Insert
Invoke-SqliteQuery -Query "INSERT INTO users (name) VALUES ('Alice');" -Path ./data/example.db | Out-Null

# Select
Invoke-SqliteQuery -Query 'SELECT id, name FROM users ORDER BY id;' -Path ./data/example.db

# Read-only mode (prevents writes where supported)
Invoke-SqliteQuery -Query 'SELECT id, name FROM users;' -Path ./data/example.db -ReadOnly
```

## Documentation

- Module entry: [PSSqliteRoH.psm1][pssqliteroh]
- C# helper library: [src/PSSqliteRoH.Sqlite/SqliteDatabase.cs][sqlitedatabase]
- Tests: [src/PSSqliteRoH.Sqlite.Tests/][pssqliteroh.sqlite.tests]
- PowerShell tests: [tests/PSSqliteRoH.Tests.ps1][pssqliteroh.tests.ps1]

For detailed technical documentation including:
- Complete class and method reference
- Architecture overview
- Development guide

See the [docs][Docs] folder.

## License

[MIT][License]

[pssqliteroh]: ./PSSqliteRoH.psm1
[sqlitedatabase]: ./src/PSSqliteRoH.Sqlite/SqliteDatabase.cs
[pssqliteroh.sqlite.tests]: ./src/PSSqliteRoH.Sqlite.Tests/
[pssqliteroh.tests.ps1]: ./tests/PSSqliteRoH.Tests.ps1
[License]: ./LICENSE
[Docs]: ./docs