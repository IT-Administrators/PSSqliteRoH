Describe 'PSSqliteRoH PowerShell module' {
    Context 'New-SqliteDatabase command' {
        It 'imports the module successfully' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            Get-Command New-SqliteDatabase | Should -Not -BeNullOrEmpty
        }

        It 'creates a SQLite database and returns a SqliteConnection object' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $connection = New-SqliteDatabase -Path $testDbPath -Create -PassThru

            $connection | Should -Not -BeNullOrEmpty
            $connection.GetType().FullName | Should -Be 'Microsoft.Data.Sqlite.SqliteConnection'
            $connection.State | Should -Be 'Open'

            $connection.Close()
            Test-Path $testDbPath | Should -BeTrue
        }

        It 'returns a PSCustomObject when PassThru is not specified' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $result = New-SqliteDatabase -Path $testDbPath -Create

            $result | Should -BeOfType 'System.Management.Automation.PSCustomObject'
            $result.DatabasePath | Should -Be (Resolve-Path -LiteralPath $testDbPath).ProviderPath
            $result.Connection | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Invoke-SqliteQuery command' {
        It 'imports the module successfully' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            Get-Command Invoke-SqliteQuery | Should -Not -BeNullOrEmpty
        }

        It 'executes non-query SQL and returns rows affected' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_InvokeQuery_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            $createResult = Invoke-SqliteQuery -Query 'CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);' -Database $db

            $createResult | Should -BeOfType 'System.Management.Automation.PSCustomObject'
            $createResult.Query | Should -Be 'CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);'
            $createResult.RowsAffected | Should -Be 0
            $db.Connection.Close()
        }

        It 'executes SELECT SQL and returns query rows' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_InvokeQuery_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            Invoke-SqliteQuery -Query 'CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);' -Database $db | Out-Null
            Invoke-SqliteQuery -Query "INSERT INTO test_table (name) VALUES ('Alice');" -Database $db | Out-Null
            Invoke-SqliteQuery -Query "INSERT INTO test_table (name) VALUES ('Bob');" -Database $db | Out-Null

            $rows = Invoke-SqliteQuery -Query 'SELECT id, name FROM test_table ORDER BY id;' -Database $db
            $db.Connection.Close()

            $rows | Should -HaveCount 2
            $rows[0].id | Should -Be 1
            $rows[0].name | Should -Be 'Alice'
            $rows[1].id | Should -Be 2
            $rows[1].name | Should -Be 'Bob'
        }

        It 'performs full CRUD operations via Invoke-SqliteQuery' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_CRUD_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create

            # Create table
            Invoke-SqliteQuery -Query 'CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);' -Database $db | Out-Null

            # Insert rows
            Invoke-SqliteQuery -Query "INSERT INTO test_table (name) VALUES ('Alice');" -Database $db | Out-Null
            Invoke-SqliteQuery -Query "INSERT INTO test_table (name) VALUES ('Bob');" -Database $db | Out-Null

            # Read and verify
            $rows = Invoke-SqliteQuery -Query 'SELECT id, name FROM test_table ORDER BY id;' -Database $db
            $rows | Should -HaveCount 2

            # Update and verify
            Invoke-SqliteQuery -Query "UPDATE test_table SET name = 'Alicia' WHERE name = 'Alice';" -Database $db | Out-Null
            $row = Invoke-SqliteQuery -Query 'SELECT id, name FROM test_table WHERE id = 1;' -Database $db
            $row.name | Should -Be 'Alicia'

            # Delete and verify
            Invoke-SqliteQuery -Query "DELETE FROM test_table WHERE name = 'Bob';" -Database $db | Out-Null
            $rows = Invoke-SqliteQuery -Query 'SELECT id, name FROM test_table ORDER BY id;' -Database $db
            $rows | Should -HaveCount 1
            $rows[0].name | Should -Be 'Alicia'
            $db.Connection.Close()
        }

        It 'prevents modifications when opened ReadOnly but allows reads' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_ReadOnly_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            # Prepare DB with one row
            $prepDb = Get-SqliteConnection -Path $testDbPath -Create
            Invoke-SqliteQuery -Query 'CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);' -Database $prepDb | Out-Null
            Invoke-SqliteQuery -Query "INSERT INTO test_table (name) VALUES ('Alice');" -Database $prepDb | Out-Null
            $prepDb.Connection.Close()

            # Read-only should allow SELECT
            $roDb = Get-SqliteConnection -Path $testDbPath -ReadOnly
            $rows = Invoke-SqliteQuery -Query 'SELECT id, name FROM test_table;' -Database $roDb
            $rows | Should -HaveCount 1

            # Read-only should prevent INSERT (PRAGMA query_only enforced)
            { Invoke-SqliteQuery -Query "INSERT INTO test_table (name) VALUES ('Charlie');" -Database $roDb } | Should -Throw
            $roDb.Connection.Close()
        }
    }

    Context 'Get-SqliteVersion command' {
        It 'imports the module successfully' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            Get-Command Get-SqliteVersion | Should -Not -BeNullOrEmpty
        }

        It 'returns the sqlite engine version for a database path' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetVersion_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            $version = Get-SqliteVersion -Database $db
            $db.Connection.Close()

            $version | Should -Not -BeNullOrEmpty
            $version | Should -BeOfType 'System.String'
        }

        It 'returns the sqlite engine version for an open connection' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetVersion_Conn_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            $version = Get-SqliteVersion -Database $db
            $db.Connection.Close()

            $version | Should -Not -BeNullOrEmpty
            $version | Should -BeOfType 'System.String'
        }
    }

    Context 'Get-SqliteTableNames command' {
        It 'imports the module successfully' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            Get-Command Get-SqliteTableNames | Should -Not -BeNullOrEmpty
        }

        It 'returns all table names when database contains multiple tables' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetTables_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            
            # Create multiple tables
            Invoke-SqliteQuery -Query 'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);' -Database $db | Out-Null
            Invoke-SqliteQuery -Query 'CREATE TABLE products (id INTEGER PRIMARY KEY, title TEXT);' -Database $db | Out-Null
            Invoke-SqliteQuery -Query 'CREATE TABLE orders (id INTEGER PRIMARY KEY, user_id INTEGER);' -Database $db | Out-Null

            $tableNames = Get-SqliteTableNames -Database $db
            $db.Connection.Close()

            $tableNames | Should -HaveCount 3
            $tableNames | Should -Contain 'users'
            $tableNames | Should -Contain 'products'
            $tableNames | Should -Contain 'orders'
        }

        It 'returns table names as an array when multiple tables exist' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetTables_Array_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            
            Invoke-SqliteQuery -Query 'CREATE TABLE table1 (id INTEGER PRIMARY KEY);' -Database $db | Out-Null
            Invoke-SqliteQuery -Query 'CREATE TABLE table2 (id INTEGER PRIMARY KEY);' -Database $db | Out-Null

            $tableNames = Get-SqliteTableNames -Database $db
            $db.Connection.Close()

            # When there are multiple results, PowerShell should return an array
            @($tableNames).Count | Should -Be 2
        }

        It 'returns a single table name when only one table exists' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetTables_Single_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            
            Invoke-SqliteQuery -Query 'CREATE TABLE single_table (id INTEGER PRIMARY KEY);' -Database $db | Out-Null

            $tableNames = Get-SqliteTableNames -Database $db
            $db.Connection.Close()

            $tableNames | Should -Be 'single_table'
        }

        It 'returns empty array when database contains no user tables' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetTables_Empty_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            
            $tableNames = Get-SqliteTableNames -Database $db
            $db.Connection.Close()

            $tableNames | Should -HaveCount 0
        }

        It 'excludes system tables (sqlite_*) from results' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetTables_NoSys_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            
            # Create a user table and create an index (which creates a system table)
            Invoke-SqliteQuery -Query 'CREATE TABLE my_table (id INTEGER PRIMARY KEY, value TEXT);' -Database $db | Out-Null
            Invoke-SqliteQuery -Query 'CREATE INDEX idx_value ON my_table(value);' -Database $db | Out-Null

            $tableNames = Get-SqliteTableNames -Database $db
            $db.Connection.Close()

            # Should only return the user table, not sqlite_autoindex_* tables
            $tableNames | Should -Contain 'my_table'
            $tableNames | ForEach-Object { $_ | Should -Not -Match '^sqlite_' }
        }

        It 'works with a connection context object' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetTables_ConnCtx_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            
            Invoke-SqliteQuery -Query 'CREATE TABLE ctx_table (id INTEGER PRIMARY KEY);' -Database $db | Out-Null

            $tableNames = Get-SqliteTableNames -Database $db
            $db.Connection.Close()

            $tableNames | Should -Contain 'ctx_table'
        }

        It 'works with a raw DbConnection object' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetTables_RawConn_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            $connection = $db.Connection
            
            Invoke-SqliteQuery -Query 'CREATE TABLE raw_table (id INTEGER PRIMARY KEY);' -Database $db | Out-Null

            $tableNames = Get-SqliteTableNames -Database $connection
            $connection.Close()

            $tableNames | Should -Contain 'raw_table'
        }

        It 'throws error when database parameter is invalid' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            { Get-SqliteTableNames -Database 'invalid' } | Should -Throw 'The -Database parameter must be a connection context returned by Get-SqliteConnection or a DbConnection object.'
        }
    }

    Context 'Get-SqliteTableColumnNames command' {
        It 'imports the module successfully' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            Get-Command Get-SqliteTableColumnNames | Should -Not -BeNullOrEmpty
        }

        It 'returns column names for the specified table' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetTableColumns_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            Invoke-SqliteQuery -Query 'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT);' -Database $db | Out-Null

            $columns = Get-SqliteTableColumnNames -Database $db -TableName 'users'
            $db.Connection.Close()

            $columns | Should -HaveCount 3
            $columns | Should -Contain 'id'
            $columns | Should -Contain 'name'
            $columns | Should -Contain 'email'
        }

        It 'returns empty array for a table with no columns' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetTableColumns_Empty_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            Invoke-SqliteQuery -Query 'CREATE TABLE empty_columns (id INTEGER PRIMARY KEY);' -Database $db | Out-Null

            $columns = Get-SqliteTableColumnNames -Database $db -TableName 'empty_columns'
            $db.Connection.Close()

            $columns | Should -HaveCount 1
            $columns | Should -Contain 'id'
        }

        It 'throws error when table does not exist' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetTableColumns_Invalid_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            
            { Get-SqliteTableColumnNames -Database $db -TableName 'missing' } | Should -Throw
            $db.Connection.Close()
        }
    }

    Context 'Get-SqliteColumnsNamesAll command' {
        It 'imports the module successfully' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            Get-Command Get-SqliteColumnsNamesAll | Should -Not -BeNullOrEmpty
        }

        It 'returns all column names for all tables in the database' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetAllColumns_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            Invoke-SqliteQuery -Query 'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);' -Database $db | Out-Null
            Invoke-SqliteQuery -Query 'CREATE TABLE products (id INTEGER PRIMARY KEY, price REAL);' -Database $db | Out-Null

            $columns = Get-SqliteColumnsNamesAll -Database $db
            $db.Connection.Close()

            $columns | Should -HaveCount 4
            $columns | Where-Object TableName -Eq 'users' | Should -HaveCount 2
            $columns | Where-Object TableName -Eq 'products' | Should -HaveCount 2
            $columns | Where-Object ColumnName -Eq 'name' | Should -HaveCount 1
            $columns | Where-Object ColumnName -Eq 'price' | Should -HaveCount 1
        }

        It 'returns no rows when database contains no tables' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetAllColumns_Empty_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $db = Get-SqliteConnection -Path $testDbPath -Create
            $columns = Get-SqliteColumnsNamesAll -Database $db
            $db.Connection.Close()

            $columns | Should -HaveCount 0
        }
    }
}
