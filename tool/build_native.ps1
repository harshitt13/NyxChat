#!/usr/bin/env pwsh
# Builds build/native/nyxpq.dll (x64) from native/mlkem so that `flutter test`
# can load the ML-KEM-768 (FIPS 203) binding on Windows. Works from any
# directory:   pwsh tool/build_native.ps1   (or powershell -File ...)
#
# Compiler selection, in order:
#   1. $env:NYXPQ_CC            gcc/clang-compatible driver that emits x64 code
#   2. an x86_64 gcc on PATH or in the usual MinGW-w64 / MSYS2 locations
#   3. MSVC (cl.exe) located through vswhere (Build Tools are enough)
# The 32-bit-only MinGW.org gcc (C:\MinGW) is skipped on purpose: the Dart VM
# is a 64-bit process and cannot load a 32-bit DLL.
$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $PSScriptRoot
$src    = Join-Path $root 'native\mlkem'
$clean  = Join-Path $src 'pqclean\crypto_kem\ml-kem-768\clean'
$common = Join-Path $src 'pqclean\common'
$outDir = Join-Path $root 'build\native'
$objDir = Join-Path $outDir 'obj'
$dll    = Join-Path $outDir 'nyxpq.dll'
New-Item -ItemType Directory -Force $objDir | Out-Null

$sources  = @((Join-Path $src 'nyxpq.c'), (Join-Path $common 'fips202.c'), (Join-Path $common 'randombytes.c'))
$sources += Get-ChildItem -Path $clean -Filter '*.c' | ForEach-Object { $_.FullName }
$includes = @($src, $common, $clean)

function Test-Gcc64([string]$exe) {
  if (-not $exe) { return $false }
  $cmd = Get-Command $exe -ErrorAction SilentlyContinue
  if (-not $cmd) { return $false }
  try { $m = & $cmd.Source -dumpmachine 2>$null } catch { return $false }
  return [bool]($m -match 'x86_64|amd64')
}

function Build-WithGcc([string]$gcc) {
  Write-Host "nyxpq: building with $gcc"
  $gccArgs = @('-std=c99', '-O2', '-Wall', '-Wextra', '-shared', '-static-libgcc', '-DNYXPQ_BUILD=1')
  foreach ($i in $includes) { $gccArgs += "-I$i" }
  $gccArgs += $sources
  $gccArgs += @('-o', $dll, '-ladvapi32')
  & $gcc @gccArgs
  if ($LASTEXITCODE -ne 0) { throw "nyxpq: $gcc failed with exit code $LASTEXITCODE" }
}

function Find-VcVars {
  $pf86 = ${env:ProgramFiles(x86)}
  if (-not $pf86) { $pf86 = $env:ProgramFiles }
  $vswhere = Join-Path $pf86 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (-not (Test-Path $vswhere)) { return $null }
  $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
  if (-not $vs) { return $null }
  $bat = Join-Path ($vs | Select-Object -First 1) 'VC\Auxiliary\Build\vcvarsall.bat'
  if (Test-Path $bat) { return $bat }
  return $null
}

function Build-WithMsvc([string]$vcvars) {
  Write-Host "nyxpq: building with MSVC via $vcvars"
  $inc  = ($includes | ForEach-Object { '/I"' + $_ + '"' }) -join ' '
  $srcs = ($sources  | ForEach-Object { '"' + $_ + '"' }) -join ' '
  $script = Join-Path $objDir 'build_msvc.cmd'
  $lines = @(
    '@echo off',
    ('call "' + $vcvars + '" x64 >nul 2>nul'),
    'if errorlevel 1 exit /b 1',
    ('cl /nologo /O2 /W3 /MT /std:c11 /DNYXPQ_BUILD=1 ' + $inc + ' ' + $srcs + ' /LD /Fe"' + $dll + '" /link advapi32.lib'),
    'exit /b %errorlevel%'
  )
  Set-Content -Path $script -Value $lines -Encoding oem
  Push-Location $objDir   # cl drops .obj files into the working directory
  try {
    & cmd.exe /c $script
    if ($LASTEXITCODE -ne 0) { throw "nyxpq: cl.exe failed with exit code $LASTEXITCODE" }
  } finally { Pop-Location }
}

$gcc = $null
if ($env:NYXPQ_CC) {
  $gcc = $env:NYXPQ_CC
} elseif (Test-Gcc64 'x86_64-w64-mingw32-gcc') {
  $gcc = 'x86_64-w64-mingw32-gcc'
} elseif (Test-Gcc64 'gcc') {
  $gcc = 'gcc'
} else {
  foreach ($c in @('C:\msys64\ucrt64\bin\gcc.exe', 'C:\msys64\mingw64\bin\gcc.exe',
                   'C:\mingw64\bin\gcc.exe', 'C:\TDM-GCC-64\bin\gcc.exe',
                   'C:\Strawberry\c\bin\gcc.exe')) {
    if (Test-Gcc64 $c) { $gcc = $c; break }
  }
}

if ($gcc) {
  Build-WithGcc $gcc
} else {
  $vc = Find-VcVars
  if ($vc) {
    Build-WithMsvc $vc
  } else {
    throw ("nyxpq: no 64-bit C compiler found. Install MinGW-w64 (e.g. MSYS2 ucrt64 gcc) " +
           "or the Visual Studio Build Tools (C++ workload), or set NYXPQ_CC. " +
           "C:\MinGW\bin\gcc is 32-bit only and cannot build a DLL for the 64-bit Dart VM.")
  }
}

# Sanity check: the PE header must say x64 (IMAGE_FILE_MACHINE_AMD64).
$bytes   = [System.IO.File]::ReadAllBytes($dll)
$pe      = [BitConverter]::ToInt32($bytes, 0x3C)
$machine = [BitConverter]::ToUInt16($bytes, $pe + 4)
if ($machine -ne 0x8664) {
  throw ("nyxpq: $dll is not an x64 DLL (machine 0x{0:X4}); the Dart VM cannot load it." -f $machine)
}
Write-Host "nyxpq: built $dll (x64, $($bytes.Length) bytes)"
