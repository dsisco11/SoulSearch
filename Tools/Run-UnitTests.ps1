[CmdletBinding(PositionalBinding = $false)]
param(
    [string] $TestRoot = 'Tests',
    [string] $SourceRoot = 'src\scripts_modinstalled',
    [string] $DependencyRoot = '.luarocks',

    [Parameter(ValueFromRemainingArguments)]
    [string[]] $TestRunnerArgs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$luaSystemVersion = '0.3.0-2'
$testFrameworkVersion = '2.3.0-1'

# @brief Resolves a configurable path relative to the repository root.
# @param PathValue Absolute path or repository-relative path to resolve.
# @return Normalized absolute filesystem path.
function Resolve-ConfiguredPath {
    param(
        [Parameter(Mandatory)]
        [string] $PathValue
    )

    $candidate = if ([IO.Path]::IsPathRooted($PathValue)) {
        $PathValue
    } else {
        Join-Path $projectRoot $PathValue
    }
    return [IO.Path]::GetFullPath($candidate)
}

# @brief Tests whether an exact rock version is installed in a dependency tree.
# @param Name Rock name.
# @param Version Exact rock version.
# @param Tree Absolute repository-local dependency tree.
# @param LuaRocksPath Absolute LuaRocks executable path.
# @param LuaRoot Absolute root of the selected Lua installation.
# @param LuaVersion Selected Lua major/minor version.
# @return True when the exact version is installed; otherwise false.
function Test-ExactRock {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Version,

        [Parameter(Mandatory)]
        [string] $Tree,

        [Parameter(Mandatory)]
        [string] $LuaRocksPath,

        [Parameter(Mandatory)]
        [string] $LuaRoot,

        [Parameter(Mandatory)]
        [string] $LuaVersion
    )

    & $LuaRocksPath --lua-dir $LuaRoot --lua-version $LuaVersion `
        show $Name $Version --tree $Tree *> $null
    return $LASTEXITCODE -eq 0
}

# @brief Installs an exact rock version into a dependency tree when absent.
# @param Name Rock name.
# @param Version Exact rock version.
# @param Tree Absolute repository-local dependency tree.
# @param LuaRocksPath Absolute LuaRocks executable path.
# @param LuaRoot Absolute root of the selected Lua installation.
# @param LuaVersion Selected Lua major/minor version.
function Install-ExactRock {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Version,

        [Parameter(Mandatory)]
        [string] $Tree,

        [Parameter(Mandatory)]
        [string] $LuaRocksPath,

        [Parameter(Mandatory)]
        [string] $LuaRoot,

        [Parameter(Mandatory)]
        [string] $LuaVersion
    )

    if (Test-ExactRock -Name $Name -Version $Version -Tree $Tree `
            -LuaRocksPath $LuaRocksPath -LuaRoot $LuaRoot `
            -LuaVersion $LuaVersion) {
        return
    }

    Write-Host "Installing $Name $Version into $Tree..."
    & $LuaRocksPath --lua-dir $LuaRoot --lua-version $LuaVersion `
        install $Name $Version --tree $Tree
    if ($LASTEXITCODE -ne 0) {
        throw "LuaRocks failed to install $Name $Version."
    }
}

# @brief Restores a process environment variable to its exact prior state.
# @param Name Environment variable name.
# @param Value Prior value, or null when the variable was absent.
function Restore-ProcessEnvironmentVariable {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [AllowNull()]
        [string] $Value
    )

    if ($null -eq $Value) {
        Remove-Item -LiteralPath "Env:$Name" -ErrorAction SilentlyContinue
    } else {
        Set-Item -LiteralPath "Env:$Name" -Value $Value
    }
}

$luaCommand = Get-Command lua -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $luaCommand) {
    throw 'Lua was not found on PATH.'
}
$luaPath = $luaCommand.Source

$luaRocksCommand = Get-Command luarocks -CommandType Application `
    -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $luaRocksCommand) {
    throw 'LuaRocks was not found on PATH.'
}
$luaRocksPath = $luaRocksCommand.Source

$luaVersion = & $luaPath -e "io.write(_VERSION:match('(%d+%.%d+)'))"
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($luaVersion)) {
    throw 'Could not determine the Lua version.'
}
$luaRoot = Split-Path -Parent (Split-Path -Parent $luaPath)

$resolvedTestRoot = Resolve-ConfiguredPath -PathValue $TestRoot
$resolvedSourceRoot = Resolve-ConfiguredPath -PathValue $SourceRoot
$resolvedDependencyRoot = Resolve-ConfiguredPath -PathValue $DependencyRoot

if (-not (Test-Path -LiteralPath $resolvedTestRoot -PathType Container)) {
    throw "Could not find Lua test directory: $resolvedTestRoot"
}
if (-not (Test-Path -LiteralPath $resolvedSourceRoot -PathType Container)) {
    throw "Could not find Lua source directory: $resolvedSourceRoot"
}
if (-not (Test-Path -LiteralPath $resolvedDependencyRoot)) {
    New-Item -ItemType Directory -Path $resolvedDependencyRoot -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $resolvedDependencyRoot -PathType Container)) {
    throw "Dependency root is not a directory: $resolvedDependencyRoot"
}

$configurationPath = Join-Path $projectRoot '.busted'
if (-not (Test-Path -LiteralPath $configurationPath -PathType Leaf)) {
    throw "Could not find Busted configuration: $configurationPath"
}

Install-ExactRock -Name 'luasystem' -Version $luaSystemVersion `
    -Tree $resolvedDependencyRoot -LuaRocksPath $luaRocksPath `
    -LuaRoot $luaRoot -LuaVersion $luaVersion
Install-ExactRock -Name 'busted' -Version $testFrameworkVersion `
    -Tree $resolvedDependencyRoot -LuaRocksPath $luaRocksPath `
    -LuaRoot $luaRoot -LuaVersion $luaVersion

$testLauncher = Join-Path $resolvedDependencyRoot 'bin\busted'
if (-not (Test-Path -LiteralPath $testLauncher -PathType Leaf)) {
    $installedLauncher = Join-Path $resolvedDependencyRoot `
        "lib\luarocks\rocks-$luaVersion\busted\$testFrameworkVersion\bin\busted"
    if (Test-Path -LiteralPath $installedLauncher -PathType Leaf) {
        Copy-Item -LiteralPath $installedLauncher -Destination $testLauncher
    }
}
if (-not (Test-Path -LiteralPath $testLauncher -PathType Leaf)) {
    throw "Could not find the Busted launcher: $testLauncher"
}

$oldLuaPath = [Environment]::GetEnvironmentVariable('LUA_PATH', 'Process')
$oldLuaCPath = [Environment]::GetEnvironmentVariable('LUA_CPATH', 'Process')
$testExitCode = $null

try {
    $luaPathEntries = @(
        (Join-Path $resolvedDependencyRoot "share\lua\$luaVersion\?.lua"),
        (Join-Path $resolvedDependencyRoot "share\lua\$luaVersion\?\init.lua"),
        (Join-Path $resolvedTestRoot '?.lua'),
        (Join-Path $resolvedTestRoot '?\init.lua'),
        (Join-Path $resolvedSourceRoot '?.lua'),
        (Join-Path $resolvedSourceRoot '?\init.lua')
    )
    if ($null -ne $oldLuaPath) {
        $luaPathEntries += $oldLuaPath
    }
    Set-Item -LiteralPath Env:LUA_PATH -Value ($luaPathEntries -join ';')

    $luaCPathEntries = @(
        (Join-Path $resolvedDependencyRoot "lib\lua\$luaVersion\?.dll"),
        (Join-Path $resolvedDependencyRoot "lib\lua\$luaVersion\?\init.dll")
    )
    if ($null -ne $oldLuaCPath) {
        $luaCPathEntries += $oldLuaCPath
    }
    Set-Item -LiteralPath Env:LUA_CPATH -Value ($luaCPathEntries -join ';')

    & $luaPath $testLauncher "--config-file=$configurationPath" `
        $resolvedTestRoot @TestRunnerArgs
    $testExitCode = $LASTEXITCODE
}
finally {
    Restore-ProcessEnvironmentVariable -Name 'LUA_PATH' -Value $oldLuaPath
    Restore-ProcessEnvironmentVariable -Name 'LUA_CPATH' -Value $oldLuaCPath
}

if ($testExitCode -ne 0) {
    throw "Unit tests failed with exit code $testExitCode."
}
