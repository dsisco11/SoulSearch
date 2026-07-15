[CmdletBinding()]
param(
    [string]$SourceDir = "src",
    [Parameter(Mandatory=$true)]
    [string]$ZipPath,
    [string]$ExpandedPath = "",
    [Parameter(Mandatory=$true)]
    [string]$PackageRoot,
    [switch]$NoRootFolder
)

$ErrorActionPreference = "Stop"

function Get-NormalizedRelativePath {
    param(
        [Parameter(Mandatory=$true)][string]$BasePath,
        [Parameter(Mandatory=$true)][string]$Path
    )

    return [IO.Path]::GetRelativePath($BasePath, $Path).Replace('\', '/')
}

function Compare-PackageFileSet {
    param(
        [Parameter(Mandatory=$true)][string[]]$Expected,
        [Parameter(Mandatory=$true)][string[]]$Actual,
        [Parameter(Mandatory=$true)][string]$Label
    )

    $missing = @($Expected | Where-Object { $_ -notin $Actual })
    $unexpected = @($Actual | Where-Object { $_ -notin $Expected })
    if ($missing.Count -gt 0 -or $unexpected.Count -gt 0) {
        $parts = @()
        if ($missing.Count -gt 0) { $parts += "missing: $($missing -join ', ')" }
        if ($unexpected.Count -gt 0) { $parts += "unexpected: $($unexpected -join ', ')" }
        throw "$Label package payload differs from src ($($parts -join '; '))."
    }
}

function Assert-SoulSearchBootstrapPayload {
    param(
        [Parameter(Mandatory=$true)][string]$ScriptText,
        [Parameter(Mandatory=$true)][string]$Label
    )

    foreach ($annotation in @('--@module=true', '--@enable=true')) {
        if (-not $ScriptText.Contains($annotation)) {
            throw "$Label soulsearch.lua is missing required $annotation annotation."
        }
    }
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$sourceCandidate = if ([IO.Path]::IsPathFullyQualified($SourceDir)) {
    $SourceDir
} else {
    Join-Path $repoRoot $SourceDir
}
$sourcePath = (Resolve-Path -LiteralPath $sourceCandidate).Path
$resolvedZipPath = (Resolve-Path -LiteralPath $ZipPath).Path

$sourceFiles = @(Get-ChildItem -LiteralPath $sourcePath -Recurse -File |
    ForEach-Object { Get-NormalizedRelativePath -BasePath $sourcePath -Path $_.FullName } |
    Sort-Object)
if ($sourceFiles -notcontains 'info.txt' -or
        $sourceFiles -notcontains 'scripts_modinstalled/soulsearch.lua') {
    throw "Source payload must contain info.txt and scripts_modinstalled/soulsearch.lua."
}
if ($sourceFiles -notcontains 'scripts_modinstalled/internal/soulsearch/keybindings.lua') {
    throw "Source payload must contain the SoulSearch keybinding bootstrap dependency."
}
Assert-SoulSearchBootstrapPayload -ScriptText (
    Get-Content -LiteralPath (Join-Path $sourcePath 'scripts_modinstalled/soulsearch.lua') -Raw
) -Label 'Source'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($resolvedZipPath)
$zipPrefix = if ($NoRootFolder) { '' } else { "$PackageRoot/" }
try {
    $zipFiles = @($archive.Entries |
        Where-Object { -not $_.FullName.EndsWith('/') } |
        ForEach-Object { $_.FullName } |
        Sort-Object)
    $scriptEntry = $archive.GetEntry("${zipPrefix}scripts_modinstalled/soulsearch.lua")
    if (-not $scriptEntry) {
        throw 'Zip package is missing scripts_modinstalled/soulsearch.lua.'
    }
    $reader = [IO.StreamReader]::new($scriptEntry.Open())
    try {
        Assert-SoulSearchBootstrapPayload -ScriptText $reader.ReadToEnd() -Label 'Zip'
    }
    finally {
        $reader.Dispose()
    }
}
finally {
    $archive.Dispose()
}

$expectedZipFiles = @($sourceFiles | ForEach-Object { "$zipPrefix$_" })
Compare-PackageFileSet -Expected $expectedZipFiles -Actual $zipFiles -Label 'Zip'

if ($ExpandedPath) {
    $resolvedExpandedPath = (Resolve-Path -LiteralPath $ExpandedPath).Path
    $expandedFiles = @(Get-ChildItem -LiteralPath $resolvedExpandedPath -Recurse -File |
        ForEach-Object {
            Get-NormalizedRelativePath -BasePath $resolvedExpandedPath -Path $_.FullName
        } |
        Sort-Object)
    Compare-PackageFileSet -Expected $sourceFiles -Actual $expandedFiles -Label 'Expanded'
    Assert-SoulSearchBootstrapPayload -ScriptText (
        Get-Content -LiteralPath (Join-Path $resolvedExpandedPath 'scripts_modinstalled/soulsearch.lua') -Raw
    ) -Label 'Expanded'
}

$expandedLabel = if ($ExpandedPath) { ' and expanded folder' } else { '' }
Write-Host "Package verification passed for zip$expandedLabel."
