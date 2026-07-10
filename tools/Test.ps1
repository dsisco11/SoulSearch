[CmdletBinding()]
param(
    [string]$LuaPath = ""
)

$ErrorActionPreference = "Stop"

function Resolve-LuaPath {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        return (Resolve-Path -LiteralPath $ExplicitPath -ErrorAction Stop).Path
    }

    foreach ($candidate in @("lua", "lua5.4", "lua54", "lua5.3", "lua53", "lua5.2", "lua52", "lua5.1", "lua51")) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    return $null
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$runnerPath = Join-Path $repoRoot "tests/run.lua"
$resolvedLuaPath = Resolve-LuaPath -ExplicitPath $LuaPath

if (-not $resolvedLuaPath) {
    throw @"
No Lua interpreter was found.

Install Lua and make 'lua' available on PATH, or pass an explicit interpreter:

    .\tools\Test.ps1 -LuaPath "C:\path\to\lua.exe"
"@
}

if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
    throw "Could not find the Lua test runner: $runnerPath"
}

Write-Host "Running SoulSearch pure Lua tests with '$resolvedLuaPath'..."
& $resolvedLuaPath $runnerPath $repoRoot
$testExitCode = $LASTEXITCODE

if ($testExitCode -ne 0) {
    throw "SoulSearch Lua tests failed with exit code $testExitCode."
}

Write-Host "SoulSearch Lua tests passed."
