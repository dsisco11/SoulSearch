[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$publishScript = Join-Path $projectRoot 'tools\Publish.ps1'
$verifyScript = Join-Path $projectRoot 'tools\VerifyPackage.ps1'
$fixtureRoot = Join-Path $projectRoot ".package-tools-test-$([guid]::NewGuid())"
$sourceRoot = Join-Path $fixtureRoot 'source'
$outputRoot = Join-Path $fixtureRoot 'output'
$packageName = 'FixtureMod'
$zipPath = Join-Path $outputRoot "$packageName-1.2.3.zip"
$expandedPath = Join-Path $outputRoot $packageName

function Assert-Condition {
    param(
        [Parameter(Mandatory)][bool] $Condition,
        [Parameter(Mandatory)][string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Invoke-ExpectedFailure {
    param(
        [Parameter(Mandatory)][scriptblock] $Action,
        [Parameter(Mandatory)][string] $MessagePattern
    )

    $failure = $null
    try {
        & $Action
    }
    catch {
        $failure = $_
    }
    if (-not $failure) {
        throw "Expected failure matching '$MessagePattern', but the command passed."
    }
    if ($failure.Exception.Message -notlike "*$MessagePattern*") {
        throw "Expected failure matching '$MessagePattern'; got: $($failure.Exception.Message)"
    }
}

function Get-TemporaryDirectories {
    param([Parameter(Mandatory)][string] $Prefix)

    return @(
        Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Directory `
            -Filter "$Prefix*" -ErrorAction SilentlyContinue |
            ForEach-Object FullName |
            Sort-Object
    )
}

function Assert-NoNewTemporaryDirectories {
    param(
        [AllowEmptyCollection()][string[]] $Before = @(),
        [Parameter(Mandatory)][string] $Prefix
    )

    $after = Get-TemporaryDirectories -Prefix $Prefix
    $newDirectories = @($after | Where-Object { $_ -notin $Before })
    Assert-Condition ($newDirectories.Count -eq 0) `
        "Temporary directories were not cleaned: $($newDirectories -join ', ')"
}

function Copy-DirectoryContents {
    param(
        [Parameter(Mandatory)][string] $Source,
        [Parameter(Mandatory)][string] $Destination
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination `
            -Recurse -Force
    }
}

function New-FlatZip {
    param(
        [Parameter(Mandatory)][string] $Source,
        [Parameter(Mandatory)][string] $Destination
    )

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Force
    }
    [IO.Compression.ZipFile]::CreateFromDirectory(
        $Source,
        $Destination,
        [IO.Compression.CompressionLevel]::Optimal,
        $false)
}

$oldRunner = [Environment]::GetEnvironmentVariable('DFHACK_RUNNER', 'Process')
$oldDwarfFortressRoot = [Environment]::GetEnvironmentVariable(
    'DFHACK_DWARF_FORTRESS_ROOT', 'Process')

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Path (
        Join-Path $sourceRoot 'scripts_modinstalled') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $sourceRoot 'info.txt') -Encoding utf8 `
        -Value @'
[ID:fixture_mod]
[NUMERIC_VERSION:1]
[DISPLAYED_VERSION:1.2.3]
[NAME:FixtureMod]
[DESCRIPTION:Generic package tooling fixture.]
'@
    Set-Content -LiteralPath (
        Join-Path $sourceRoot 'scripts_modinstalled\fixture.lua') `
        -Encoding utf8 -Value 'return {value=42}'
    [IO.File]::WriteAllBytes((Join-Path $sourceRoot 'payload.bin'),
        [byte[]](0, 1, 2, 255))

    # Invalid runner settings prove publishing does not attempt live reload.
    [Environment]::SetEnvironmentVariable(
        'DFHACK_RUNNER', (Join-Path $fixtureRoot 'missing-runner.exe'), 'Process')
    [Environment]::SetEnvironmentVariable(
        'DFHACK_DWARF_FORTRESS_ROOT',
        (Join-Path $fixtureRoot 'missing-df-root'),
        'Process')

    $publishTemps = Get-TemporaryDirectories -Prefix 'DFHackModPublish-'
    $verifyTemps = Get-TemporaryDirectories -Prefix 'DFHackModVerify-'
    & $publishScript -SourceDir $sourceRoot -OutputDir $outputRoot
    Assert-NoNewTemporaryDirectories -Before $publishTemps `
        -Prefix 'DFHackModPublish-'
    Assert-NoNewTemporaryDirectories -Before $verifyTemps `
        -Prefix 'DFHackModVerify-'

    Assert-Condition (Test-Path -LiteralPath $zipPath -PathType Leaf) `
        'Fixture zip was not created.'
    Assert-Condition (Test-Path -LiteralPath $expandedPath -PathType Container) `
        'Fixture expanded package was not created.'

    $explicitOutput = Join-Path $fixtureRoot 'explicit-output'
    & $publishScript -SourceDir $sourceRoot -OutputDir $explicitOutput `
        -PackageName 'ExplicitPackage'
    Assert-Condition (Test-Path -LiteralPath (
        Join-Path $explicitOutput 'ExplicitPackage-1.2.3.zip') -PathType Leaf) `
        'Explicit package identity was not used for the zip.'
    Assert-Condition (Test-Path -LiteralPath (
        Join-Path $explicitOutput 'ExplicitPackage') -PathType Container) `
        'Explicit package identity was not used for the expanded folder.'

    $archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $entries = @($archive.Entries | Where-Object {
            -not $_.FullName.EndsWith('/')
        } | ForEach-Object FullName | Sort-Object)
    }
    finally {
        $archive.Dispose()
    }
    $expectedEntries = @(
        'info.txt',
        'payload.bin',
        'scripts_modinstalled/fixture.lua'
    )
    Assert-Condition (($entries -join "`n") -eq
        ($expectedEntries -join "`n")) `
        "Flat zip entries were unexpected: $($entries -join ', ')"

    # Absolute paths and repo-relative paths must both work, even from another cwd.
    & $verifyScript -SourceDir $sourceRoot -ZipPath $zipPath `
        -ExpandedPath $expandedPath
    $relativeSource = [IO.Path]::GetRelativePath($projectRoot, $sourceRoot)
    $relativeZip = [IO.Path]::GetRelativePath($projectRoot, $zipPath)
    $relativeExpanded = [IO.Path]::GetRelativePath($projectRoot, $expandedPath)
    Push-Location $fixtureRoot
    try {
        & $verifyScript -SourceDir $relativeSource -ZipPath $relativeZip `
            -ExpandedPath $relativeExpanded
    }
    finally {
        Pop-Location
    }

    foreach ($probe in @(
        @{Name='missing'; Pattern='missing: payload.bin'},
        @{Name='unexpected'; Pattern='unexpected: unexpected.txt'},
        @{Name='differing'; Pattern='differing: payload.bin'}
    )) {
        $probeRoot = Join-Path $fixtureRoot $probe.Name
        Copy-DirectoryContents -Source $expandedPath -Destination $probeRoot
        if ($probe.Name -eq 'missing') {
            Remove-Item -LiteralPath (Join-Path $probeRoot 'payload.bin') -Force
        } elseif ($probe.Name -eq 'unexpected') {
            Set-Content -LiteralPath (Join-Path $probeRoot 'unexpected.txt') `
                -Value 'unexpected' -Encoding utf8
        } else {
            [IO.File]::WriteAllBytes((Join-Path $probeRoot 'payload.bin'),
                [byte[]](9, 9, 9))
        }
        Invoke-ExpectedFailure -MessagePattern $probe.Pattern -Action {
            & $verifyScript -SourceDir $sourceRoot -ZipPath $zipPath `
                -ExpandedPath $probeRoot
        }
    }

    $badZipRoot = Join-Path $fixtureRoot 'bad-zip-root'
    Copy-DirectoryContents -Source $expandedPath -Destination $badZipRoot
    Set-Content -LiteralPath (Join-Path $badZipRoot 'unexpected.txt') `
        -Value 'unexpected' -Encoding utf8
    $badZipPath = Join-Path $fixtureRoot 'bad.zip'
    New-FlatZip -Source $badZipRoot -Destination $badZipPath
    $verifyTemps = Get-TemporaryDirectories -Prefix 'DFHackModVerify-'
    Invoke-ExpectedFailure -MessagePattern 'unexpected: unexpected.txt' -Action {
        & $verifyScript -SourceDir $sourceRoot -ZipPath $badZipPath `
            -ExpandedPath $expandedPath
    }
    Assert-NoNewTemporaryDirectories -Before $verifyTemps `
        -Prefix 'DFHackModVerify-'

    $wrapperRoot = Join-Path $fixtureRoot 'wrapper-root'
    $wrapperPackage = Join-Path $wrapperRoot $packageName
    Copy-DirectoryContents -Source $expandedPath -Destination $wrapperPackage
    $wrapperZipPath = Join-Path $fixtureRoot 'wrapper.zip'
    New-FlatZip -Source $wrapperRoot -Destination $wrapperZipPath
    Invoke-ExpectedFailure -MessagePattern 'missing: info.txt' -Action {
        & $verifyScript -SourceDir $sourceRoot -ZipPath $wrapperZipPath `
            -ExpandedPath $expandedPath
    }

    # A custom source with bad Lua proves Publish forwards SourceDir to Build.
    $brokenLua = Join-Path $sourceRoot 'scripts_modinstalled\broken.lua'
    Set-Content -LiteralPath $brokenLua -Value 'this is not lua !!!' -Encoding utf8
    Invoke-ExpectedFailure -MessagePattern 'Lua syntax check failed' -Action {
        & $publishScript -SourceDir $sourceRoot `
            -OutputDir (Join-Path $fixtureRoot 'broken-output')
    }
    Remove-Item -LiteralPath $brokenLua -Force

    # A verifier stub proves Publish removes staging after verification fails.
    $toolCopy = Join-Path $fixtureRoot 'tool-copy'
    Copy-DirectoryContents -Source (Join-Path $projectRoot 'tools') `
        -Destination $toolCopy
    Set-Content -LiteralPath (Join-Path $toolCopy 'VerifyPackage.ps1') `
        -Encoding utf8 -Value "throw 'forced verification failure'"
    $publishTemps = Get-TemporaryDirectories -Prefix 'DFHackModPublish-'
    Invoke-ExpectedFailure -MessagePattern 'forced verification failure' -Action {
        & (Join-Path $toolCopy 'Publish.ps1') -SourceDir $sourceRoot `
            -OutputDir (Join-Path $fixtureRoot 'verification-failure-output')
    }
    Assert-NoNewTemporaryDirectories -Before $publishTemps `
        -Prefix 'DFHackModPublish-'

    # An exclusively locked payload forces failure after staging is created.
    $lockedPath = Join-Path $sourceRoot 'locked.bin'
    [IO.File]::WriteAllBytes($lockedPath, [byte[]](1, 2, 3))
    $lock = [IO.File]::Open(
        $lockedPath,
        [IO.FileMode]::Open,
        [IO.FileAccess]::Read,
        [IO.FileShare]::None)
    $publishTemps = Get-TemporaryDirectories -Prefix 'DFHackModPublish-'
    try {
        Invoke-ExpectedFailure -MessagePattern 'used by another process' -Action {
            & $publishScript -SourceDir $sourceRoot `
                -OutputDir (Join-Path $fixtureRoot 'locked-output')
        }
    }
    finally {
        $lock.Dispose()
    }
    Assert-NoNewTemporaryDirectories -Before $publishTemps `
        -Prefix 'DFHackModPublish-'

    Write-Host 'Package tooling contract tests passed.'
}
finally {
    [Environment]::SetEnvironmentVariable(
        'DFHACK_RUNNER', $oldRunner, 'Process')
    [Environment]::SetEnvironmentVariable(
        'DFHACK_DWARF_FORTRESS_ROOT', $oldDwarfFortressRoot, 'Process')
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}
