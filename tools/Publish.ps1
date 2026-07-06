[CmdletBinding()]
param(
    [string]$SourceDir = "src",
    [string]$OutputDir = "dist",
    [string]$PackageName = "",
    [switch]$NoRootFolder,
    [switch]$NoExpandedFolder
)

$ErrorActionPreference = "Stop"

function Get-ModInfoValue {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InfoText,

        [Parameter(Mandatory=$true)]
        [string]$Key
    )

    $pattern = "\[$([regex]::Escape($Key)):(.*?)\]"
    $match = [regex]::Match($InfoText, $pattern)
    if (-not $match.Success) {
        return $null
    }
    return $match.Groups[1].Value.Trim()
}

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

if (-not (Test-Path -LiteralPath $infoPath -PathType Leaf)) {
    throw "Could not find required mod metadata file: $infoPath"
}

$infoText = Get-Content -LiteralPath $infoPath -Raw
$metadataName = Get-ModInfoValue -InfoText $infoText -Key "NAME"
$version = Get-ModInfoValue -InfoText $infoText -Key "DISPLAYED_VERSION"

if (-not $PackageName) {
    $PackageName = if ($metadataName) { $metadataName } else { "SoulSearch" }
}
if (-not $version) {
    $version = "0.0.0"
}

$safePackageName = ConvertTo-SafeFileName -Name $PackageName
$safeVersion = ConvertTo-SafeFileName -Name $version
$zipPath = Join-Path $outputPath "$safePackageName-$safeVersion.zip"
$expandedPath = Join-Path $outputPath $safePackageName
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "SoulSearchPublish-$([guid]::NewGuid())"
$stagingRoot = if ($NoRootFolder) { $tempRoot } else { Join-Path $tempRoot $safePackageName }

New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null

try {
    Get-ChildItem -LiteralPath $sourcePath -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $stagingRoot -Recurse -Force
    }

    if (-not $NoExpandedFolder) {
        if (Test-Path -LiteralPath $expandedPath) {
            Remove-Item -LiteralPath $expandedPath -Recurse -Force
        }
        Copy-Item -LiteralPath $stagingRoot -Destination $expandedPath -Recurse -Force
    }

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $tempRoot "*") -DestinationPath $zipPath
    Write-Host "Created $zipPath"
    if (-not $NoExpandedFolder) {
        Write-Host "Created $expandedPath"
        Write-Host "For manual installation, copy '$expandedPath' to the Dwarf Fortress 'mods' folder so the final path is 'mods\$safePackageName\info.txt'."
    } else {
        Write-Host "For manual installation, extract the archive so the final path is 'mods\$safePackageName\info.txt'."
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
