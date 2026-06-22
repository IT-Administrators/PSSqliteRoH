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

# Import native/runtime-specific assemblies for the current platform.
if ($PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion.Major -eq 5) {
    $assemblyFolder = Join-Path -Path $assemblyFolder -ChildPath 'win-x64'
}
elseif ($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion.Major -ge 7) {
    if ($IsWindows) {
        $assemblyFolder = Join-Path -Path $assemblyFolder -ChildPath 'win-x64'
    }
    elseif ($IsLinux) {
        $assemblyFolder = Join-Path -Path $assemblyFolder -ChildPath 'linux-x64'
    }
    elseif ($IsMacOS) {
        $assemblyFolder = Join-Path -Path $assemblyFolder -ChildPath 'osx-x64'
    }
}

# Load every DLL from the resolved runtime folder so the helper assembly can be resolved.
if (Test-Path -Path $assemblyFolder) {
    foreach ($dll in Get-ChildItem -Path $assemblyFolder -Filter '*.dll' | Sort-Object FullName) {
        try {
            $assemblyName = [System.IO.Path]::GetFileNameWithoutExtension($dll.FullName)
            if (-not ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq $assemblyName })) {
                [Reflection.Assembly]::LoadFrom($dll.FullName) | Out-Null
            }
        } catch {
            Write-Verbose "Unable to load assembly '$($dll.FullName)': $($_.Exception.Message)"
        }
    }
}

function Get-SqliteDatabaseManagerType {
    <#
    .SYNOPSIS
        Internal helper used to verify that the managed SQLite runtime is loaded.
    
    .DESCRIPTION
        Internal helper function that checks if the PSSqliteRoH.Sqlite assembly is loaded and returns the type of the SqliteDatabaseManager class. 
        This is used by other functions to verify that the necessary runtime is available before attempting to use it.

    .NOTES
        Written and testet in PowerShell Core, compatible with Windows Powershell.

    .LINK
        https://github.com/IT-Administrators/PSSqliteRoH
    #>
    $loadedAssembly = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'PSSqliteRoH.Sqlite' } | Select-Object -First 1

    if ($loadedAssembly) {
        return $loadedAssembly.GetType('PSSqliteRoH.Sqlite.SqliteDatabaseManager', $false, $true)
    }

    return $null
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
        if (-not (Get-SqliteDatabaseManagerType)) {
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
        if (-not (Get-SqliteDatabaseManagerType)) {
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

    .PARAMETER Database
        Connection context returned by Get-SqliteConnection. This object must contain a valid Connection property.

    .EXAMPLE
        $db = Get-SqliteConnection -Path './data/example.db' -Create
        Invoke-SqliteQuery -Query 'SELECT id, name FROM users ORDER BY id;' -Database $db

    .NOTES
        Written and testet in PowerShell Core, compatible with Windows Powershell.

    .LINK
        https://github.com/IT-Administrators/PSSqliteRoH
    #>
    [CmdletBinding()]
    param (
        # The SQL query to execute (no validation performed).
        [Parameter(
        Mandatory = $true, 
        Position = 0,
        HelpMessage = "Command to run against the database.")]
        [string]$Query,

        # Connection context returned by Get-SqliteConnection.
        [Parameter(
        Mandatory = $true,
        Position = 1,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = 'Connection context returned by Get-SqliteConnection.')]
        [object]$Database
    )

    begin {
        # Check if module is loaded.
        if (-not (Get-SqliteDatabaseManagerType)) {
            throw 'The PSSqliteRoH.Sqlite helper assembly is not loaded. Ensure the module was imported from a folder that contains lib/netstandard2.0/PSSqliteRoH.Sqlite.dll.'
        }
    }

    process {
        if (-not $Database) {
            throw 'A valid database connection context must be provided via -Database.'
        }

        if ($Database -is [System.Management.Automation.PSCustomObject] -and $Database.PSObject.Properties.Name -contains 'Connection') {
            $connection = $Database.Connection
        } elseif ($Database -is [System.Data.Common.DbConnection]) {
            $connection = $Database
        } else {
            throw 'The -Database parameter must be a connection context returned by Get-SqliteConnection or a DbConnection object.'
        }

        if (-not $connection) {
            throw 'The provided -Database object does not contain a valid Connection.'
        }

        if ($connection.State -ne 'Open') {
            $connection.Open()
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
    }
}

function Get-SqliteVersion {
    <#
    .SYNOPSIS
        Get sqlite version of specified database

    .DESCRIPTION
        Get the sqlite version of the specified database. This might be important as not all sqlite commands
        are compatible with all versions. 

    .PARAMETER Database
        Connection context returned by Get-SqliteConnection. This object must contain a valid Connection property.

    .EXAMPLE
        $db = Get-SqliteConnection -Path ./data/example.db -Create
        Get-SqliteVersion -Database $db

    .NOTES
        Written and testet in PowerShell Core, compatible with Windows Powershell.

    .LINK
        https://github.com/IT-Administrators/PSSqliteRoH
    #>
    [CmdletBinding()]
    param (
        # Connection context returned by Get-SqliteConnection.
        [Parameter(
        Mandatory = $true,
        Position = 0,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = 'Connection context returned by Get-SqliteConnection.')]
        [object]$Database
    )

    begin {
        if (-not (Get-SqliteDatabaseManagerType)) {
            throw 'The PSSqliteRoH.Sqlite helper assembly is not loaded. Ensure the module was imported from a folder that contains lib/netstandard2.0/PSSqliteRoH.Sqlite.dll.'
        }
    }

    process {
        if (-not $Database) {
            throw 'A valid database connection context must be provided via -Database.'
        }

        if ($Database -is [System.Management.Automation.PSCustomObject] -and $Database.PSObject.Properties.Name -contains 'Connection') {
            $connection = $Database.Connection
        } elseif ($Database -is [System.Data.Common.DbConnection]) {
            $connection = $Database
        } else {
            throw 'The -Database parameter must be a connection context returned by Get-SqliteConnection or a DbConnection object.'
        }

        if (-not $connection) {
            throw 'The provided -Database object does not contain a valid Connection.'
        }

        if ($connection.State -ne 'Open') {
            $connection.Open()
        }

        $command = $connection.CreateCommand()
        $command.CommandText = 'SELECT sqlite_version();'
        # ExecuteScalar only returns the first row
        $version = $command.ExecuteScalar()

        return $version
    }
}

function Get-SqliteTableNames {
    <#
    .SYNOPSIS
        Get the names of all tables in the database.

    .DESCRIPTION
        Get all table names in the specified database.
        It ony returns user created tables and no system tables.

    .PARAMETER Database
        Connection context returned by Get-SqliteConnection. This object must contain a valid Connection property.
    
    .EXAMPLE
        Get all table names of user created tables in the specified database.

        Get-SqliteTableNames -Database $Connection 

        Output:

        Printer
        Printers
        Processes

    .NOTES
        Written and testet in PowerShell Core, compatible with Windows Powershell.

    .LINK
        https://github.com/IT-Administrators/PSSqliteRoH
    #>
    [CmdletBinding()]
    param (
        # Connection context returned by Get-SqliteConnection.
        [Parameter(
        Mandatory = $true,
        Position = 0,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = 'Connection context returned by Get-SqliteConnection.')]
        [object]$Database
    )
    
    begin {
        if (-not (Get-SqliteDatabaseManagerType)) {
            throw 'The PSSqliteRoH.Sqlite helper assembly is not loaded. Ensure the module was imported from a folder that contains lib/netstandard2.0/PSSqliteRoH.Sqlite.dll.'
        }
    }
    
    process {
        if (-not $Database) {
            throw 'A valid database connection context must be provided via -Database.'
        }

        if ($Database -is [System.Management.Automation.PSCustomObject] -and $Database.PSObject.Properties.Name -contains 'Connection') {
            $connection = $Database.Connection
        } elseif ($Database -is [System.Data.Common.DbConnection]) {
            $connection = $Database
        } else {
            throw 'The -Database parameter must be a connection context returned by Get-SqliteConnection or a DbConnection object.'
        }

        if (-not $connection) {
            throw 'The provided -Database object does not contain a valid Connection.'
        }

        if ($connection.State -ne 'Open') {
            $connection.Open()
        }

        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
        # ExecuteReader returns all rows.
        $reader = $command.ExecuteReader()
        
        $tableNames = @()
        try {
            # Read all rows and append to array.
            while ($reader.Read()) {
                $tableNames += $reader.GetValue(0)
            }
        } finally {
            $reader.Close()
        }
        
        return $tableNames
    }
    
    end {
        
    }
}

function Get-SqliteTableColumnNames {
    <#
    .SYNOPSIS
        Get the column names for a specified table.

    .DESCRIPTION
        Returns the names of all columns defined in the specified table.

    .PARAMETER Database
        Connection context returned by Get-SqliteConnection or a raw DbConnection.

    .PARAMETER TableName
        Name of the table whose columns should be returned.

    .EXAMPLE
        Get all column names of the specified table.

        Get-SqliteTableColumnNames -Database $Connection -TableName Printers

        Output:

        name
        Type
        drivername
        portname
        shared
        published

    .NOTES
        Written and tested in PowerShell Core, compatible with Windows PowerShell.

    .LINK
        https://github.com/IT-Administrators/PSSqliteRoH
    #>
    [CmdletBinding()]
    param (
        [Parameter(
        Mandatory = $true,
        Position = 0,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = 'Connection context returned by Get-SqliteConnection.')]
        [object]$Database,

        [Parameter(
        Mandatory = $true,
        Position = 1,
        HelpMessage = 'Name of the table whose column names should be returned.')]
        [string]$TableName
    )

    begin {
        if (-not (Get-SqliteDatabaseManagerType)) {
            throw 'The PSSqliteRoH.Sqlite helper assembly is not loaded. Ensure the module was imported from a folder that contains lib/netstandard2.0/PSSqliteRoH.Sqlite.dll.'
        }
    }

    process {
        if (-not $Database) {
            throw 'A valid database connection context must be provided via -Database.'
        }

        if ($Database -is [System.Management.Automation.PSCustomObject] -and $Database.PSObject.Properties.Name -contains 'Connection') {
            $connection = $Database.Connection
        } elseif ($Database -is [System.Data.Common.DbConnection]) {
            $connection = $Database
        } else {
            throw 'The -Database parameter must be a connection context returned by Get-SqliteConnection or a DbConnection object.'
        }

        if (-not $connection) {
            throw 'The provided -Database object does not contain a valid Connection.'
        }

        if ($connection.State -ne 'Open') {
            $connection.Open()
        }

        $safeTableName = $TableName -replace "'", "''"

        $existsCommand = $connection.CreateCommand()
        $existsCommand.CommandText = "SELECT COUNT(1) FROM sqlite_master WHERE type='table' AND name = '$safeTableName';"
        $tableExists = [int]$existsCommand.ExecuteScalar()

        if ($tableExists -eq 0) {
            throw "Table '$TableName' does not exist in the database."
        }

        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT name FROM pragma_table_info('$safeTableName') ORDER BY cid;"

        $reader = $command.ExecuteReader()
        $columnNames = @()
        try {
            while ($reader.Read()) {
                $columnNames += $reader.GetValue(0)
            }
        } finally {
            $reader.Close()
        }

        return $columnNames
    }
}

function Get-SqliteColumnNamesAll {
    <#
    .SYNOPSIS
        Get all column names for all tables in the database.

    .DESCRIPTION
        Returns the table and column names for every user-defined table in the database.

    .PARAMETER Database
        Connection context returned by Get-SqliteConnection or a raw DbConnection.

    .EXAMPLE
        Get all column names of all tables in the specified database.

        Get-SqliteColumnNamesAll -Database $Connection

        Output:

        TableName  ColumnName
        ---------  ----------
        Printer    name
        ...
        Printers   name
        ...
        Processes  name
        ...

    .NOTES
        Written and tested in PowerShell Core, compatible with Windows PowerShell.

    .LINK
        https://github.com/IT-Administrators/PSSqliteRoH
    #>
    [CmdletBinding()]
    param (
        [Parameter(
        Mandatory = $true,
        Position = 0,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = 'Connection context returned by Get-SqliteConnection.')]
        [object]$Database
    )

    begin {
        if (-not (Get-SqliteDatabaseManagerType)) {
            throw 'The PSSqliteRoH.Sqlite helper assembly is not loaded. Ensure the module was imported from a folder that contains lib/netstandard2.0/PSSqliteRoH.Sqlite.dll.'
        }
    }

    process {
        if (-not $Database) {
            throw 'A valid database connection context must be provided via -Database.'
        }

        if ($Database -is [System.Management.Automation.PSCustomObject] -and $Database.PSObject.Properties.Name -contains 'Connection') {
            $connection = $Database.Connection
        } elseif ($Database -is [System.Data.Common.DbConnection]) {
            $connection = $Database
        } else {
            throw 'The -Database parameter must be a connection context returned by Get-SqliteConnection or a DbConnection object.'
        }

        if (-not $connection) {
            throw 'The provided -Database object does not contain a valid Connection.'
        }

        if ($connection.State -ne 'Open') {
            $connection.Open()
        }

        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
        $reader = $command.ExecuteReader()

        $tableNames = @()
        try {
            while ($reader.Read()) {
                $tableNames += $reader.GetValue(0)
            }
        } finally {
            $reader.Close()
        }

        $columns = @()
        foreach ($tableName in $tableNames) {
            $safeTableName = $tableName -replace "'", "''"
            $columnCommand = $connection.CreateCommand()
            $columnCommand.CommandText = "SELECT name FROM pragma_table_info('$safeTableName') ORDER BY cid;"

            $columnReader = $columnCommand.ExecuteReader()
            try {
                while ($columnReader.Read()) {
                    $columns += [PSCustomObject]@{
                        TableName  = $tableName
                        ColumnName = $columnReader.GetValue(0)
                    }
                }
            } finally {
                $columnReader.Close()
            }
        }

        return $columns
    }
}
