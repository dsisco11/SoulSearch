[CmdletBinding()]
param(
    [string]$SourceDir = "src",
    [string]$OutputDir = "dist",
    [string]$PackageName = ""
)

$ErrorActionPreference = "Stop"

function ConvertTo-SafeFileName {
    param([Parameter(Mandatory=$true)][string]$Name)

    $invalid = [IO.Path]::GetInvalidFileNameChars()
    $chars = $Name.ToCharArray() | ForEach-Object {
        if ($invalid -contains $_) { "-" } else { $_ }
    }
    return (-join $chars).Trim()
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
$sourcePath = Resolve-Path (Join-Path $repoRoot $SourceDir)
$outputPath = Join-Path $repoRoot $OutputDir
$infoPath = Join-Path $sourcePath "info.txt"
$buildScript = Join-Path $scriptRoot 'Build.ps1'
$commonTools = Join-Path $scriptRoot 'Common.ps1'

if (-not (Test-Path -LiteralPath $commonTools -PathType Leaf)) {
    throw "Missing required common tools: $commonTools"
}
. $commonTools

if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
    throw "Missing required build script: $buildScript"
}

& $buildScript -LiveReload:$false
if ($LASTEXITCODE -ne 0) {
    throw 'Package build failed.'
}

$modInfo = Get-ModInfo -InfoPath $infoPath
$metadataName = $modInfo.Name
$version = $modInfo.DisplayedVersion

if (-not $PackageName) {
    $PackageName = $metadataName
}
if (-not $version) {
    throw "Missing required [DISPLAYED_VERSION] in $infoPath"
}
if (-not $PackageName) {
    throw "Missing required [NAME] in $infoPath"
}

$safePackageName = ConvertTo-SafeFileName -Name $PackageName
$safeVersion = ConvertTo-SafeFileName -Name $version
$zipPath = Join-Path $outputPath "$safePackageName-$safeVersion.zip"
$expandedPath = Join-Path $outputPath $safePackageName
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "DFHackModPublish-$([guid]::NewGuid())"
$stagingRoot = $tempRoot

New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null

try {
    Get-ChildItem -LiteralPath $sourcePath -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $stagingRoot -Recurse -Force
    }

    if (Test-Path -LiteralPath $expandedPath) {
        Remove-Item -LiteralPath $expandedPath -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $expandedPath | Out-Null
    Get-ChildItem -LiteralPath $stagingRoot -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $expandedPath -Recurse -Force
    }

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $stagingRoot "*") -DestinationPath $zipPath
    $verifyScript = Join-Path $scriptRoot "VerifyPackage.ps1"
    $verifyArgs = @{
        SourceDir = $sourcePath
        ZipPath = $zipPath
        PackageRoot = ''
        ExpandedPath = $expandedPath
    }
    & $verifyScript @verifyArgs
    if ($LASTEXITCODE -ne 0) {
        throw 'Package verification failed.'
    }
    Write-Host "Created $zipPath"
    Write-Host "Created $expandedPath"
    Write-Host "For manual installation, copy '$expandedPath' to the Dwarf Fortress 'mods' folder so the final path is 'mods\$safePackageName\info.txt'."
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
