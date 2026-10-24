# Builds bin\caffeinate.exe using the C# compiler that ships with Windows
# (.NET Framework 4.x), so no SDK install is needed.

$ErrorActionPreference = 'Stop'

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "C# compiler not found at $csc" }

$bin = Join-Path $PSScriptRoot 'bin'
New-Item -ItemType Directory -Force $bin | Out-Null

# x64 so the PE header matches the winget manifest's Architecture: x64
# (ARM64 Windows 11 runs it under x64 emulation).
& $csc /nologo /optimize+ /target:exe /platform:x64 `
    /out:"$bin\caffeinate.exe" "$PSScriptRoot\src\caffeinate.cs"
if ($LASTEXITCODE -ne 0) { throw "build failed" }

Write-Host "Built $bin\caffeinate.exe"
