[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $SourceDir,
    [Parameter(Mandatory)]
    [string] $ZipPath,
    [Parameter(Mandatory)]
    [string] $ExpandedPath,
    [string] $PackageRoot = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Manifest {
    param([Parameter(Mandatory)][string] $Root)

    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
    return @(
        Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File | ForEach-Object {
            [pscustomobject]@{
                RelativePath = [IO.Path]::GetRelativePath($resolvedRoot, $_.FullName).Replace('\', '/')
                Hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            }
        } | Sort-Object RelativePath
    )
}

function Assert-MatchesSource {
    param(
        [Parameter(Mandatory)][object[]] $Expected,
        [Parameter(Mandatory)][object[]] $Actual,
        [Parameter(Mandatory)][string] $Label
    )

    $expectedMap = @{}
    $actualMap = @{}
    foreach ($entry in $Expected) { $expectedMap[$entry.RelativePath] = $entry.Hash }
    foreach ($entry in $Actual) { $actualMap[$entry.RelativePath] = $entry.Hash }

    if (($expectedMap.Keys | Sort-Object) -join "`n" -ne ($actualMap.Keys | Sort-Object) -join "`n") {
        throw "$Label file manifest does not match src."
    }
    foreach ($path in $expectedMap.Keys) {
        if ($expectedMap[$path] -ne $actualMap[$path]) {
            throw "$Label file differs from src: $path"
        }
    }
}

$sourceManifest = Get-Manifest -Root $SourceDir
if (-not ($sourceManifest.RelativePath -contains 'info.txt')) {
    throw 'src must contain info.txt at its root.'
}
if (-not ($sourceManifest.RelativePath | Where-Object { $_ -like 'scripts_modinstalled/*' })) {
    throw 'src must contain at least one file under scripts_modinstalled/.'
}
if ($sourceManifest.RelativePath | Where-Object { $_ -match '^(tests|tools)/' }) {
    throw 'src must not package tests or tools.'
}

Assert-MatchesSource -Expected $sourceManifest -Actual (Get-Manifest -Root $ExpandedPath) -Label 'Expanded package'

$extractRoot = Join-Path ([IO.Path]::GetTempPath()) "DFHackModVerify-$([guid]::NewGuid())"
try {
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $extractRoot -Force
    $zipContentRoot = if ($PackageRoot) { Join-Path $extractRoot $PackageRoot } else { $extractRoot }
    if (-not (Test-Path -LiteralPath $zipContentRoot -PathType Container)) {
        throw "Zip package root was not found: $PackageRoot"
    }
    Assert-MatchesSource -Expected $sourceManifest -Actual (Get-Manifest -Root $zipContentRoot) -Label 'Zip package'
}
finally {
    if (Test-Path -LiteralPath $extractRoot) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }
}

Write-Host 'Package verification passed.'
