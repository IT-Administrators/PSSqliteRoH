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
}
