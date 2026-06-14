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

            $createResult = Invoke-SqliteQuery -Query 'CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);' -Path $testDbPath -Create

            $createResult | Should -BeOfType 'System.Management.Automation.PSCustomObject'
            $createResult.Query | Should -Be 'CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);'
            $createResult.RowsAffected | Should -Be 0
        }

        It 'executes SELECT SQL and returns query rows' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_InvokeQuery_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            Invoke-SqliteQuery -Query 'CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);' -Path $testDbPath -Create | Out-Null
            Invoke-SqliteQuery -Query "INSERT INTO test_table (name) VALUES ('Alice');" -Path $testDbPath | Out-Null
            Invoke-SqliteQuery -Query "INSERT INTO test_table (name) VALUES ('Bob');" -Path $testDbPath | Out-Null

            $rows = Invoke-SqliteQuery -Query 'SELECT id, name FROM test_table ORDER BY id;' -Path $testDbPath

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

            # Create table
            Invoke-SqliteQuery -Query 'CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);' -Path $testDbPath -Create | Out-Null

            # Insert rows
            Invoke-SqliteQuery -Query "INSERT INTO test_table (name) VALUES ('Alice');" -Path $testDbPath | Out-Null
            Invoke-SqliteQuery -Query "INSERT INTO test_table (name) VALUES ('Bob');" -Path $testDbPath | Out-Null

            # Read and verify
            $rows = Invoke-SqliteQuery -Query 'SELECT id, name FROM test_table ORDER BY id;' -Path $testDbPath
            $rows | Should -HaveCount 2

            # Update and verify
            Invoke-SqliteQuery -Query "UPDATE test_table SET name = 'Alicia' WHERE name = 'Alice';" -Path $testDbPath | Out-Null
            $row = Invoke-SqliteQuery -Query 'SELECT id, name FROM test_table WHERE id = 1;' -Path $testDbPath
            $row.name | Should -Be 'Alicia'

            # Delete and verify
            Invoke-SqliteQuery -Query "DELETE FROM test_table WHERE name = 'Bob';" -Path $testDbPath | Out-Null
            $rows = Invoke-SqliteQuery -Query 'SELECT id, name FROM test_table ORDER BY id;' -Path $testDbPath
            $rows | Should -HaveCount 1
            $rows[0].name | Should -Be 'Alicia'
        }

        It 'prevents modifications when opened ReadOnly but allows reads' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_ReadOnly_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            # Prepare DB with one row
            Invoke-SqliteQuery -Query 'CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);' -Path $testDbPath -Create | Out-Null
            Invoke-SqliteQuery -Query "INSERT INTO test_table (name) VALUES ('Alice');" -Path $testDbPath | Out-Null

            # Read-only should allow SELECT
            $rows = Invoke-SqliteQuery -Query 'SELECT id, name FROM test_table;' -Path $testDbPath -ReadOnly
            $rows | Should -HaveCount 1

            # Read-only should prevent INSERT (PRAGMA query_only enforced)
            { Invoke-SqliteQuery -Query "INSERT INTO test_table (name) VALUES ('Charlie');" -Path $testDbPath -ReadOnly } | Should -Throw
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

            New-SqliteDatabase -Path $testDbPath -Create -PassThru | Out-Null
            $version = Get-SqliteVersion -Path $testDbPath

            $version | Should -Not -BeNullOrEmpty
            $version | Should -BeOfType 'System.String'
        }

        It 'returns the sqlite engine version for an open connection' {
            $modulePath = Join-Path (Get-Location) 'PSSqliteRoH.psd1'
            Import-Module $modulePath -Force

            $testDbPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqliteRoH_GetVersion_Conn_Test_$(New-Guid).db"
            Remove-Item -Path $testDbPath -ErrorAction SilentlyContinue

            $connection = New-SqliteDatabase -Path $testDbPath -Create -PassThru
            $version = Get-SqliteVersion -Connection $connection
            $connection.Close()

            $version | Should -Not -BeNullOrEmpty
            $version | Should -BeOfType 'System.String'
        }
    }
}
