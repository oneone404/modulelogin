$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $root '.tools\android-ndk-r30\toolchains\llvm\prebuilt\windows-x86_64\bin\x86_64-linux-android28-clang++.cmd'
$output = Join-Path $root 'magisk_module\system\bin\oneone_finder_v2'

if (-not (Test-Path $compiler)) { throw "Android NDK compiler not found: $compiler" }

& $compiler @(
    '-O3', '-DNDEBUG', '-std=c++17', '-static-libstdc++',
    '-fno-exceptions', '-fno-rtti', '-ffunction-sections', '-fdata-sections',
    '-Wl,--gc-sections', '-s',
    (Join-Path $PSScriptRoot 'oneone_finder_v2.cpp'),
    '-o', $output
)
if ($LASTEXITCODE -ne 0) { throw "NDK build failed with exit code $LASTEXITCODE" }
Get-Item $output
