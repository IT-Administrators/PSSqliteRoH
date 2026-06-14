<#
.SYNOPSIS
    PowerShell module to manage Sqlite databases.

.DESCRIPTION
    This module import functions to manage sqlite databases with powershell.
    It is a wrapper for the C# netstandard 2.0 library to make it cross platform compatible.

.NOTES
    Written and testet in PowerShell Core, compatible with Windows Powershell.

.LINK
    https://github.com/IT-Administrators/PSSqliteRoH
#>

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
        Create and open new database file

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
        $connectionParams = @{
            Create   = $Create.IsPresent
            ReadOnly = $ReadOnly.IsPresent
        }

        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $connectionParams.Path = $Path
            try {
                $databasePath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
            } catch {
                $databasePath = [System.IO.Path]::GetFullPath($Path)
            }
            $connectionString = [PSSqliteRoH.Sqlite.SqliteDatabaseManager]::BuildConnectionString($databasePath, $Create.IsPresent, $ReadOnly.IsPresent)
        } else {
            $connectionParams.ConnectionString = $ConnectionString
            $connectionString = $ConnectionString
        }

        $connectionContext = Get-SqliteConnection @connectionParams
        $connection = $connectionContext.Connection

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

function Get-SqliteConnection {
    <#
    .SYNOPSIS
        Open or reuse a SQLite database connection.

    .DESCRIPTION
        Returns a consistent connection context object for SQLite operations.
        This helper resolves the connection from one of three input modes:
        - a database file path
        - an explicit SQLite connection string
        - an existing open or closed DbConnection object

        When using a file path, the function can optionally create the database file
        and open it in read-only mode. When given an existing connection, it ensures
        the connection is opened before returning it.

        This function is primarily used internally by other module commands and
        is exported only when the module is imported from the `.psm1` file.

    .PARAMETER Path
        File path of the SQLite database file.

    .PARAMETER ConnectionString
        Explicit SQLite connection string such as 'Data Source=./data/example.db;Mode=ReadWriteCreate'.

    .PARAMETER Connection
        Existing DbConnection object to use. If the connection is not open, the function opens it.

    .PARAMETER Create
        Create the database file if it does not already exist (only valid when using -Path).

    .PARAMETER ReadOnly
        Open the database in read-only mode (only valid when using -Path).

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Returns an object with the following properties:
        - Connection: The opened DbConnection instance.
        - Created: Boolean indicating whether the function opened the connection.

    .EXAMPLE
        $connectionContext = Get-SqliteConnection -Path './data/example.db' -Create

        Returns a connection context for a file-based SQLite database and creates the file if needed.

    .EXAMPLE
        $connectionContext = Get-SqliteConnection -ConnectionString 'Data Source=./data/example.db;Mode=ReadWrite'

        Opens a new SQLite connection using an explicit connection string.

    .EXAMPLE
        $connectionContext = Get-SqliteConnection -Connection $existingConnection

        Reuses an existing connection object and ensures it is open.

    .NOTES
        Written and tested in PowerShell Core, compatible with Windows PowerShell.

    .LINK
        https://github.com/IT-Administrators/PSSqliteRoH
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        [Parameter(
        Mandatory = $true,
        Position = 0,
        ParameterSetName = 'Path',
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = 'Filepath of the database.')]
        [string]$Path,

        [Parameter(
        Mandatory = $true,
        ParameterSetName = 'ConnectionString',
        HelpMessage = 'Explicit SQLite connection string instead of a file path e.g. "Data Source=./data/example.db;Mode=ReadWriteCreate".')]
        [string]$ConnectionString,

        [Parameter(
        Mandatory = $true,
        ParameterSetName = 'Connection',
        HelpMessage = 'Existing connection object.')]
        [System.Data.Common.DbConnection]$Connection,

        [Parameter(
        HelpMessage = 'Create the database file if it does not already exist (only when using -Path).')]
        [switch]$Create,

        [Parameter(
        HelpMessage = 'Open the database in read-only mode (only when using -Path).')]
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

            $connectionString = [PSSqliteRoH.Sqlite.SqliteDatabaseManager]::BuildConnectionString($databasePath, $Create.IsPresent, $ReadOnly.IsPresent)
            $connection = [PSSqliteRoH.Sqlite.SqliteDatabaseManager]::CreateConnection($connectionString)
            $connection.Open()
            $createdConnection = $true

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
            if (-not $Connection) {
                throw 'A valid connection object must be provided when using the Connection parameter set.'
            }

            $connection = $Connection
            if ($connection.State -ne 'Open') {
                $connection.Open()
                $createdConnection = $true
            }
        }

        [PSCustomObject]@{
            Connection      = $connection
            Created         = $createdConnection
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
        $connectionParams = @{
            Create   = $Create.IsPresent
            ReadOnly = $ReadOnly.IsPresent
        }

        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $connectionParams.Path = $Path
        } elseif ($PSCmdlet.ParameterSetName -eq 'ConnectionString') {
            $connectionParams.ConnectionString = $ConnectionString
        } else {
            $connectionParams.Connection = $Connection
        }

        $connectionContext = Get-SqliteConnection @connectionParams
        $connection = $connectionContext.Connection
        $createdConnection = $connectionContext.Created

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

function Get-SqliteVersion {
    <#
    .SYNOPSIS
        Get sqlite version of specified database

    .DESCRIPTION
        Get the sqlite version of the specified database. This might be important as not all sqlite commands
        are compatible with all versions. 

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
        Get the sqlite version of the specified database.

        Get-SqliteVersion -Path ./data/example.db

        Output:

        3.40.1

    .NOTES
        Written and testet in PowerShell Core, compatible with Windows Powershell.

    .LINK
        https://github.com/IT-Administrators/PSSqliteRoH
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        # File path of the database to inspect.
        [Parameter(
        Mandatory = $true,
        Position = 0,
        ParameterSetName = 'Path',
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = 'Filepath of the database.')]
        [string]$Path,

        # Explicit SQLite connection string.
        [Parameter(
        Mandatory = $true,
        ParameterSetName = 'ConnectionString',
        HelpMessage = 'Explicit SQLite connection string instead of a file path e.g. "Data Source=./data/example.db;Mode=ReadWriteCreate".')]
        [string]$ConnectionString,

        # Existing open connection object.
        [Parameter(
        Mandatory = $true,
        ParameterSetName = 'Connection',
        HelpMessage = 'Existing connection object.')]
        [System.Data.Common.DbConnection]$Connection,

        # Create the database file if it does not already exist (only when using -Path).
        [Parameter(
        HelpMessage = 'Create the database file if it does not already exist.')]
        [switch]$Create,

        # Open the database in read-only mode (only when using -Path).
        [Parameter(
        HelpMessage = 'Open the database in read-only mode. This prevents modifications when possible.')]
        [switch]$ReadOnly
    )

    begin {
        if (-not ([Type]::GetType('PSSqliteRoH.Sqlite.SqliteDatabaseManager, PSSqliteRoH.Sqlite'))) {
            throw 'The PSSqliteRoH.Sqlite helper assembly is not loaded. Ensure the module was imported from a folder that contains lib/netstandard2.0/PSSqliteRoH.Sqlite.dll.'
        }
    }

    process {
        $connectionParams = @{
            Create   = $Create.IsPresent
            ReadOnly = $ReadOnly.IsPresent
        }

        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $connectionParams.Path = $Path
        } elseif ($PSCmdlet.ParameterSetName -eq 'ConnectionString') {
            $connectionParams.ConnectionString = $ConnectionString
        } else {
            $connectionParams.Connection = $Connection
        }

        $connectionContext = Get-SqliteConnection @connectionParams
        $connection = $connectionContext.Connection
        $createdConnection = $connectionContext.Created

        $command = $connection.CreateCommand()
        $command.CommandText = 'SELECT sqlite_version();'
        $version = $command.ExecuteScalar()

        if ($createdConnection -and $connection) {
            $connection.Close()
            $connection.Dispose()
        }

        Write-Output $version
    }
}
