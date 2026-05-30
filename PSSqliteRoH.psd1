# Module manifest for the PSSqliteRoH PowerShell module.
# The manifest is used by PowerShell to load the module and expose the cmdlet.
@{
    RootModule = 'PSSqliteRoH.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'd69d6d3a-2b6d-4d4b-8d9b-5a8f7c7a9e12'
    Author = 'IT-Administrators'
    Copyright = '(c) 2026 PSSqliteRoH'
    Description = 'Cross-platform PowerShell module for managing SQLite databases using .NET.'
    PowerShellVersion = '3.0'
    CompatiblePSEditions = @('Desktop','Core')
    FunctionsToExport = @('New-SqliteDatabase')
    FileList = @('PSSqliteRoH.psm1')
    PrivateData = @{
        PSData = @{
            ProjectUri = ''
            LicenseUri = ''
            ReleaseNotes = 'Initial version'
            Tags = @('SQLite','Database','PowerShell','Cross-platform')
        }
    }
}
