# PowerShell module entrypoint for PSSqliteRoH.
# This file loads the .NET helper library and exports the first cmdlet.

$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:DistFolder = Join-Path $script:ModuleRoot 'dist'
$script:LibFolder = Join-Path $script:ModuleRoot 'lib/netstandard2.0'

# Prefer published dist output, but fall back to the legacy lib folder if necessary.
$assemblyFolder = $null
if (Test-Path -Path $script:DistFolder) {
    $assemblyFolder = Get-ChildItem -Path $script:DistFolder -Recurse -Filter 'PSSqliteRoH.Sqlite.dll' -File | Select-Object -First 1 | ForEach-Object { $_.DirectoryName }
}

function Invoke-SqliteQuery {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        # The SQL query to execute (no validation performed).
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Query,

        # Open or create a database by file path.
        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [string]$Path,

        # Use an explicit SQLite connection string instead of a file path.
        [Parameter(Mandatory = $true, ParameterSetName = 'ConnectionString')]
        [string]$ConnectionString,

        # Supply an existing open connection object.
        [Parameter(Mandatory = $true, ParameterSetName = 'Connection')]
        [System.Data.Common.DbConnection]$Connection,

        # Create the database file if it does not already exist (only when using -Path).
        [switch]$Create,

        # Open the database in read-only mode (only when using -Path).
        [switch]$ReadOnly
    )

    begin {
        if (-not ([Type]::GetType('PSSqliteRoH.Sqlite.SqliteDatabaseManager, PSSqliteRoH.Sqlite'))) {
            throw 'The PSSqliteRoH.Sqlite helper assembly is not loaded. Ensure the module was imported from a folder that contains lib/netstandard2.0/PSSqliteRoH.Sqlite.dll.'
        }
    }

    process {
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
        } elseif ($PSCmdlet.ParameterSetName -eq 'ConnectionString') {
            $connection = [PSSqliteRoH.Sqlite.SqliteDatabaseManager]::CreateConnection($ConnectionString)
            $connection.Open()
            $createdConnection = $true
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

        if ($createdConnection -and $connection) {
            $connection.Close()
            $connection.Dispose()
        }
    }
}
if (-not $assemblyFolder -and (Test-Path -Path $script:LibFolder)) {
    $assemblyFolder = $script:LibFolder
}

if ($assemblyFolder) {
    Get-ChildItem -Path $assemblyFolder -Filter '*.dll' | Sort-Object Name | ForEach-Object {
        try {
            [Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null
        } catch {
            Write-Verbose "Unable to load assembly '$($_.FullName)': $_"
        }
    }
} else {
    Write-Verbose "No assembly folder found in dist or lib/netstandard2.0."
}

function New-SqliteDatabase {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        # Open or create a database by file path.
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Path', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Path,

        # Use an explicit SQLite connection string instead of a file path.
        [Parameter(Mandatory = $true, ParameterSetName = 'ConnectionString')]
        [string]$ConnectionString,

        # Create the database file if it does not already exist.
        [switch]$Create,

        # Open the database in read-only mode.
        [switch]$ReadOnly,

        # Return the raw SqliteConnection object instead of a PSCustomObject.
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

            if ($Create -and -not (Test-Path -Path (Split-Path -Parent $databasePath))) {
                New-Item -ItemType Directory -Path (Split-Path -Parent $databasePath) -Force | Out-Null
            }

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
