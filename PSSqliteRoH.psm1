# PowerShell module entrypoint for PSSqliteRoH.
# This file loads the .NET helper library and exports functions.

$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:LibFolder = Join-Path $script:ModuleRoot 'lib/netstandard2.0'

$assemblyFolder = $script:LibFolder

if (-not (Test-Path -Path $assemblyFolder)) {
    throw "Unable to locate PSSqliteRoH helper assemblies. Ensure the module folder contains 'lib/netstandard2.0'."
}
# Import every dll in the lib folder.
Get-ChildItem -Path $assemblyFolder -Filter '*.dll' | Sort-Object Name | ForEach-Object {
    try {
        [Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null
    } catch {
        Write-Verbose "Unable to load assembly '$($_.FullName)': $_"
    }
}

function New-SqliteDatabase {
    <#
    .SYNOPSIS
        Create aand open new database file

    .DESCRIPTION
        This function creates and opens a new or existing database file without writing data to it. 
        The file can be opened normally until data is written.

    .PARAMETER Path
        Filepath of the database.

    .PARAMETER ConnectionString
        Connectionstring containing database specifications e.g. 'Data Source=./data/example.db;Mode=ReadWriteCreate'.

    .PARAMETER Create
        Create the database file if it does not already exist.

    .PARAMETER ReadOnly
        Open connection in readonly mode. No changes can be made to the database.

    .PARAMETER PassThru
        Return raw sqlite connection object.

    .EXAMPLE
        Create and open a SQLite database:

        $database = New-SqliteDatabase -Path './data/example.db' -Create -PassThru

    .NOTES
        Written and testet in PowerShell Core, compatible with Windows Powershell.

    .LINK
        https://github.com/IT-Administrators/PSSqliteRoH
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        # Open or create a database by file path.
        [Parameter(
        Mandatory = $true, 
        Position = 0, 
        ParameterSetName = 'Path', 
        ValueFromPipeline = $true, 
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = "Filepath of the new database.")]
        [string]$Path,

        # Use an explicit SQLite connection string instead of a file path.
        [Parameter(
        Mandatory = $true, 
        ParameterSetName = 'ConnectionString',
        HelpMessage = "Explicit SQLite connection string instead of a file path e.g. 'Data Source=./data/example.db;Mode=ReadWriteCreate'.")]
        [string]$ConnectionString,

        # Create the database file if it does not already exist.
        [Parameter(
        HelpMessage = "Create the database file if it does not already exist.")]
        [switch]$Create,

        # Open the database in read-only mode.
        [Parameter(
        HelpMessage = "Open the database in read-only mode. This prevents write operations.")]
        [switch]$ReadOnly,

        # Return the raw SqliteConnection object instead of a PSCustomObject.
        [Parameter(
        HelpMessage = "Return raw SqliteConnection object instead of a PSCustomObject.")]
        [switch]$PassThru
    )

    begin {
        # Verify the helper assembly is loaded before using its static methods.
        if (-not ([Type]::GetType('PSSqliteRoH.Sqlite.SqliteDatabaseManager, PSSqliteRoH.Sqlite'))) {
            throw 'The PSSqliteRoH.Sqlite helper assembly is not loaded. Ensure the module was imported from a folder that contains lib/netstandard2.0/PSSqliteRoH.Sqlite.dll.'
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $resolvedPath = $null
            try {
                $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop
                $databasePath = $resolvedPath.ProviderPath
            } catch {
                $databasePath = [System.IO.Path]::GetFullPath($Path)
            }
            # Create the database file if not exists. 
            # The created file is an empty file which can be opened in any editor.
            # It will be an sqlite file on first write operation.
            if ($Create -and -not (Test-Path -Path (Split-Path -Parent $databasePath))) {
                New-Item -ItemType Directory -Path (Split-Path -Parent $databasePath) -Force | Out-Null
            }
            # Catch database not exists and Create parameter not specified.
            if (-not $Create -and -not (Test-Path -Path $databasePath)) {
                throw "Database file '$databasePath' does not exist. Use -Create to create it." 
            }

            $connectionString = [PSSqliteRoH.Sqlite.SqliteDatabaseManager]::BuildConnectionString($databasePath, $Create.IsPresent, $ReadOnly.IsPresent)
        } else {
            $connectionString = $ConnectionString
        }

        # Create and open the database connection.
        $connection = [PSSqliteRoH.Sqlite.SqliteDatabaseManager]::CreateConnection($connectionString)
        $connection.Open()

        # If read-only mode requested, enforce query-only mode at the SQLite level.
        if ($ReadOnly.IsPresent) {
            try {
                $pr = $connection.CreateCommand()
                $pr.CommandText = 'PRAGMA query_only = TRUE;'
                $pr.ExecuteNonQuery() | Out-Null
            } catch {
                # If the PRAGMA is not supported, continue without failing here; reads should still work.
                Write-Verbose "Unable to set PRAGMA query_only: $_"
            }
        }

        if ($PassThru) {
            Write-Output $connection
        } else {
            [PSCustomObject]@{
                DatabasePath     = if ($PSCmdlet.ParameterSetName -eq 'Path') { $databasePath } else { $null }
                ConnectionString = $connectionString
                Connection       = $connection
            }
        }
    }
}

function Invoke-SqliteQuery {
    <#
    .SYNOPSIS
        Invoke the specified SQL command

    .DESCRIPTION
        Run the specified command against the database. This function does not contain
        any command verification, so SQL injections might be possible using this command.

    .PARAMETER Query
        Command to run against the database.

    .PARAMETER Path
        Filepath of the database.

    .PARAMETER ConnectionString
        Connectionstring containing database specifications e.g. 'Data Source=./data/example.db;Mode=ReadWriteCreate'.

    .PARAMETER Connection
        Existing connection object.

    .PARAMETER Create
        Create database of not exist.

    .PARAMETER ReadOnly
        Open database in readonly mode. No changes to database possible.

    .EXAMPLE
        Create table in a new DB
        Invoke-SqliteQuery -Query 'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);' -Path $dbPath -Create | Out-Null

        Insert rows
        Invoke-SqliteQuery -Query "INSERT INTO users (name) VALUES ('Alice');" -Path $dbPath | Out-Null

        Select rows
        Invoke-SqliteQuery -Query 'SELECT id, name FROM users ORDER BY id;' -Path $dbPath

        Output:

        name  id
        ----  --
        Alice  1

    .NOTES
        Written and testet in PowerShell Core, compatible with Windows Powershell.

    .LINK
        https://github.com/IT-Administrators/PSSqliteRoH
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        # The SQL query to execute (no validation performed).
        [Parameter(
        Mandatory = $true, 
        Position = 0,
        HelpMessage = "Command to run against the database.")]
        [string]$Query,

        # Open or create a database by file path.
        [Parameter(
        Mandatory = $true, 
        ParameterSetName = 'Path',
        HelpMessage = "Filepath of the new database.")]
        [string]$Path,

        # Use an explicit SQLite connection string instead of a file path.
        [Parameter(
        Mandatory = $true, 
        ParameterSetName = 'ConnectionString',
        HelpMessage = "Explicit SQLite connection string instead of a file path e.g. 'Data Source=./data/example.db;Mode=ReadWriteCreate'.")]
        [string]$ConnectionString,

        # Supply an existing open connection object.
        [Parameter(
        Mandatory = $true, 
        ParameterSetName = 'Connection',
        HelpMessage = "Existing connection object.")]
        [System.Data.Common.DbConnection]$Connection,

        # Create the database file if it does not already exist (only when using -Path).
        [Parameter(
        HelpMessage = "Create database if not exists.")]
        [switch]$Create,

        # Open the database in read-only mode (only when using -Path).
        [Parameter(
        HelpMessage = "Open database in read-only mode. No changes possible.")]
        [switch]$ReadOnly
    )

    begin {
        # Check if module is losded.
        if (-not ([Type]::GetType('PSSqliteRoH.Sqlite.SqliteDatabaseManager, PSSqliteRoH.Sqlite'))) {
            throw 'The PSSqliteRoH.Sqlite helper assembly is not loaded. Ensure the module was imported from a folder that contains lib/netstandard2.0/PSSqliteRoH.Sqlite.dll.'
        }
    }

    process {
        # Save connection status.
        $createdConnection = $false

        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $resolvedPath = $null
            try {
                $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop
                $databasePath = $resolvedPath.ProviderPath
            } catch {
                $databasePath = [System.IO.Path]::GetFullPath($Path)
            }

            if ($Create -and -not (Test-Path -Path (Split-Path -Parent $databasePath))) {
                New-Item -ItemType Directory -Path (Split-Path -Parent $databasePath) -Force | Out-Null
            }

            if (-not $Create -and -not (Test-Path -Path $databasePath)) {
                throw "Database file '$databasePath' does not exist. Use -Create to create it."
            }

            $cs = [PSSqliteRoH.Sqlite.SqliteDatabaseManager]::BuildConnectionString($databasePath, $Create.IsPresent, $ReadOnly.IsPresent)
            $connection = [PSSqliteRoH.Sqlite.SqliteDatabaseManager]::CreateConnection($cs)
            $connection.Open()
            $createdConnection = $true
            # Check if readonly was specified.
            if ($ReadOnly.IsPresent) {
                try {
                    $pr = $connection.CreateCommand()
                    $pr.CommandText = 'PRAGMA query_only = TRUE;'
                    $pr.ExecuteNonQuery() | Out-Null
                } catch {
                    Write-Verbose "Unable to set PRAGMA query_only: $_"
                }
            }
        } elseif ($PSCmdlet.ParameterSetName -eq 'ConnectionString') {
            $connection = [PSSqliteRoH.Sqlite.SqliteDatabaseManager]::CreateConnection($ConnectionString)
            $connection.Open()
            $createdConnection = $true
            # No explicit ReadOnly parameter for ConnectionString parameter set.
            # If the connection string itself requests ReadOnly, attempt to enforce query-only.
            try {
                $csb = New-Object Microsoft.Data.Sqlite.SqliteConnectionStringBuilder($ConnectionString)
                if ($csb.Mode -eq [Microsoft.Data.Sqlite.SqliteOpenMode]::ReadOnly) {
                    $pr = $connection.CreateCommand()
                    $pr.CommandText = 'PRAGMA query_only = TRUE;'
                    $pr.ExecuteNonQuery() | Out-Null
                }
            } catch {
                Write-Verbose "Unable to inspect/enforce read-only for ConnectionString: $_"
            }
        } else {
            # ParameterSet 'Connection' - use provided connection
            if (-not $Connection) {
                throw 'A valid connection object must be provided when using the Connection parameter set.'
            }
            $connection = $Connection
            if ($connection.State -ne 'Open') {
                $connection.Open()
                $createdConnection = $true
            }
        }

        $command = $connection.CreateCommand()
        $command.CommandText = $Query

        # If the query looks like a SELECT, return rows. Otherwise execute non-query.
        if ($Query -match '^[\s\(]*SELECT\b') {
            $reader = $command.ExecuteReader()
            try {
                while ($reader.Read()) {
                    $row = @{}
                    for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                        $name = $reader.GetName($i)
                        $value = $reader.GetValue($i)
                        $row[$name] = $value
                    }
                    [PSCustomObject]$row
                }
            } finally {
                $reader.Close()
            }
        } else {
            $affected = $command.ExecuteNonQuery()
            [PSCustomObject]@{
                Query         = $Query
                RowsAffected  = $affected
            }
        }
        # Remove connection and close db.
        if ($createdConnection -and $connection) {
            $connection.Close()
            $connection.Dispose()
        }
    }
}
