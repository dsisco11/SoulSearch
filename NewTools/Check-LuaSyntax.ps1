[CmdletBinding()]
param(
    [string] $LuaCompiler = $env:DFHACK_LUAC,
    [string] $RequiredLuaVersion = $env:DFHACK_LUA_VERSION,
    [switch] $IncludeTests
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $LuaCompiler) {
    $LuaCompiler = 'luac.exe'
}

$compiler = Get-Command $LuaCompiler -ErrorAction SilentlyContinue
if (-not $compiler) {
    throw "Lua compiler was not found: $LuaCompiler. Install luac.exe on PATH, set DFHACK_LUAC, or pass -LuaCompiler."
}

$version = (& $compiler.Source -v 2>&1 | Out-String)
if ($RequiredLuaVersion -and $version -notmatch "Lua $([regex]::Escape($RequiredLuaVersion))") {
    throw "Expected a Lua $RequiredLuaVersion compiler; got: $version"
}
$versionMatch = [regex]::Match($version, 'Lua ([0-9]+(?:\.[0-9]+)+)')
$compilerVersion = if ($versionMatch.Success) {
    $versionMatch.Groups[1].Value
} else {
    'unknown version'
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$searchRoots = @((Join-Path $projectRoot 'src'))
if ($IncludeTests) {
    $searchRoots += Join-Path $projectRoot 'tests'
}

$luaFiles = $searchRoots |
    Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
    ForEach-Object { Get-ChildItem -LiteralPath $_ -Recurse -File -Filter '*.lua' } |
    Sort-Object FullName

foreach ($luaFile in $luaFiles) {
    & $compiler.Source -p $luaFile.FullName
    if ($LASTEXITCODE -ne 0) {
        throw "Lua syntax check failed: $($luaFile.FullName)"
    }
}

Write-Host "Lua $compilerVersion syntax check passed for $($luaFiles.Count) production file(s)."
