[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]] $LuaUnitArgs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$rockTree = Join-Path $projectRoot '.luarocks'
$luaUnitVersion = '3.5-1'

if (-not (Get-Command lua -ErrorAction SilentlyContinue)) {
    throw 'Lua was not found on PATH.'
}

if (-not (Get-Command luarocks -ErrorAction SilentlyContinue)) {
    throw 'LuaRocks was not found on PATH.'
}

& luarocks show luaunit $luaUnitVersion --tree $rockTree *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing LuaUnit $luaUnitVersion into .luarocks..."
    & luarocks install luaunit $luaUnitVersion --tree $rockTree
    if ($LASTEXITCODE -ne 0) {
        throw "LuaRocks failed to install LuaUnit $luaUnitVersion."
    }
}

$testFiles = @(
    Get-ChildItem (Join-Path $projectRoot 'tests') -Recurse -File -Filter '*.lua' |
        Where-Object {
            $_.Name -match '(^test_.*|.*_test)\.lua$'
        } |
        Sort-Object FullName |
        ForEach-Object FullName
)

if ($testFiles.Count -eq 0) {
    throw 'No Lua test files found. Name tests test_*.lua or *_test.lua.'
}

$oldLuaPath = $env:LUA_PATH
$oldTestFiles = $env:DOTHIS_TEST_FILES

try {
    $env:LUA_PATH = & luarocks path --tree $rockTree --lr-path
    if ($LASTEXITCODE -ne 0) {
        throw 'LuaRocks failed to calculate LUA_PATH.'
    }

    $env:DOTHIS_TEST_FILES = $testFiles -join "`n"
    & lua (Join-Path $projectRoot 'tests/run.lua') @LuaUnitArgs
    exit $LASTEXITCODE
}
finally {
    $env:LUA_PATH = $oldLuaPath
    $env:DOTHIS_TEST_FILES = $oldTestFiles
}
