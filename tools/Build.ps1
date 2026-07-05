[CmdletBinding()]
param(
    [string]$SourceDir = "src/scripts_modinstalled",
    [string]$LuaPath = "",
    [ValidateSet("Auto", "Luac", "Lua")]
    [string]$LuaMode = "Auto"
)

$ErrorActionPreference = "Stop"

function Resolve-ToolPath {
    param(
        [string]$ExplicitPath,
        [string[]]$CandidateNames
    )

    if ($ExplicitPath) {
        $resolved = Resolve-Path -LiteralPath $ExplicitPath -ErrorAction Stop
        return $resolved.Path
    }

    foreach ($candidate in $CandidateNames) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    return $null
}

function Test-LuaFileWithLuac {
    param(
        [string]$ToolPath,
        [string]$FilePath
    )

    & $ToolPath -p $FilePath
    return $LASTEXITCODE
}

function Test-LuaFileWithLua {
    param(
        [string]$ToolPath,
        [string]$FilePath
    )

    & $ToolPath -e "assert(loadfile(arg[1]))" $FilePath
    return $LASTEXITCODE
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
$sourcePath = Resolve-Path (Join-Path $repoRoot $SourceDir)

$luacPath = Resolve-ToolPath -ExplicitPath $LuaPath -CandidateNames @("luac", "luac5.4", "luac54", "luac5.3", "luac53", "luac5.2", "luac52", "luac5.1", "luac51")
$useLuaFallback = $false

if ($LuaMode -eq "Lua") {
    $useLuaFallback = $true
} elseif ($LuaMode -eq "Luac") {
    $useLuaFallback = $false
} elseif ($LuaPath) {
    $toolFileName = [IO.Path]::GetFileNameWithoutExtension($luacPath)
    $useLuaFallback = $toolFileName -notmatch '^luac'
}

if (-not $luacPath -and $LuaMode -ne "Luac") {
    $luacPath = Resolve-ToolPath -ExplicitPath "" -CandidateNames @("lua", "lua5.4", "lua54", "lua5.3", "lua53", "lua5.2", "lua52", "lua5.1", "lua51")
    $useLuaFallback = $true
}

if (-not $luacPath) {
    throw @"
No Lua compiler/interpreter was found.

Install Lua and make either 'luac' or 'lua' available on PATH, or pass an explicit tool path:

    .\tools\Build.ps1 -LuaPath "C:\path\to\luac.exe"
    .\tools\Build.ps1 -LuaPath "C:\path\to\lua.exe" -LuaMode Lua

This build only syntax-checks Lua files; DFHack runtime behavior still needs in-game validation.
"@
}

$luaFiles = Get-ChildItem -LiteralPath $sourcePath -Recurse -Filter "*.lua" -File | Sort-Object FullName
if (-not $luaFiles) {
    throw "No Lua files found under $sourcePath"
}

$failed = @()
$toolName = if ($useLuaFallback) { "lua" } else { "luac" }
Write-Host "Checking $($luaFiles.Count) Lua file(s) with $toolName at '$luacPath'..."

foreach ($file in $luaFiles) {
    $relativePath = [IO.Path]::GetRelativePath($repoRoot.Path, $file.FullName)
    Write-Host "  $relativePath"

    $exitCode = if ($useLuaFallback) {
        Test-LuaFileWithLua -ToolPath $luacPath -FilePath $file.FullName
    } else {
        Test-LuaFileWithLuac -ToolPath $luacPath -FilePath $file.FullName
    }

    if ($exitCode -ne 0) {
        $failed += $relativePath
    }
}

if ($failed.Count -gt 0) {
    throw "Lua build check failed for $($failed.Count) file(s): $($failed -join ', ')"
}

Write-Host "Lua build check passed."
