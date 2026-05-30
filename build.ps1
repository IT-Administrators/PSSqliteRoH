param(
    [string]$Configuration = 'Release',
    [string]$RuntimeIdentifier = ''
)

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectPath = Join-Path $projectRoot 'src/PSSqliteRoH.Sqlite/PSSqliteRoH.Sqlite.csproj'

if (-not (Test-Path -Path $projectPath)) {
    throw "Project file not found: $projectPath"
}

if (-not $RuntimeIdentifier) {
    if ($IsWindows) {
        $RuntimeIdentifier = 'win-x64'
    } elseif ($IsLinux) {
        $RuntimeIdentifier = 'linux-x64'
    } elseif ($IsMacOS) {
        $RuntimeIdentifier = 'osx-x64'
    } else {
        throw 'Unable to determine a default runtime identifier. Provide -RuntimeIdentifier explicitly.'
    }
}

$distRoot = Join-Path $projectRoot 'dist'
$distFolder = Join-Path $distRoot $RuntimeIdentifier

Write-Host "Building PSSqliteRoH.Sqlite for '$RuntimeIdentifier' into '$distFolder'..."

Remove-Item -LiteralPath $distFolder -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $distFolder | Out-Null

$publishArgs = @(
    'publish',
    $projectPath,
    '-c', $Configuration,
    '-r', $RuntimeIdentifier,
    '-p:SelfContained=false',
    '-o', $distFolder
)

dotnet @publishArgs

Write-Host "Build complete. Output available in '$distFolder'."
Write-Host 'Note: This publishes the helper assembly and its runtime dependencies into dist/.'
