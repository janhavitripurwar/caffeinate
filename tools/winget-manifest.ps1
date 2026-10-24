# Generates the winget manifest for a published release and validates it.
#
#   .\tools\winget-manifest.ps1 -Owner <github-user> -Publisher "<Your Name>"
#
# Run it after the GitHub Release for the current version exists: it downloads
# caffeinate.exe from that release to compute the SHA256 winget requires.
# Output goes to winget\manifests\..., ready to submit to microsoft/winget-pkgs.
# -ExePath hashes a local file instead (for a dry run before releasing).

param(
    [Parameter(Mandatory)] [string] $Owner,
    [Parameter(Mandatory)] [string] $Publisher,
    [string] $Version,
    [string] $License = 'MIT',
    [string] $ExePath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

# winget-pkgs manifests are UTF-8 without a BOM; Windows PowerShell's
# Set-Content -Encoding utf8 would add one.
function Write-Utf8([string] $Path, [string] $Text) {
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding $false))
}

if (-not $Version) {
    $src = Get-Content (Join-Path $root 'src\caffeinate.cs') -Raw
    if ($src -notmatch 'const string Version = "([^"]+)"') { throw "Version not found in src\caffeinate.cs" }
    $Version = $Matches[1]
}

$id   = "$Owner.caffeinate"
$repo = "https://github.com/$Owner/caffeinate"
$url  = "$repo/releases/download/v$Version/caffeinate.exe"

if ($ExePath) {
    $exe = $ExePath
} else {
    $exe = Join-Path ([IO.Path]::GetTempPath()) "caffeinate-$Version.exe"
    Invoke-WebRequest $url -OutFile $exe -UseBasicParsing
}
$sha = (Get-FileHash $exe -Algorithm SHA256).Hash

$dir = Join-Path $root "winget\manifests\$($Owner.Substring(0,1).ToLower())\$Owner\caffeinate\$Version"
New-Item -ItemType Directory -Force $dir | Out-Null
$schema = '1.10.0'

Write-Utf8 "$dir\$id.yaml" @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.version.$schema.schema.json

PackageIdentifier: $id
PackageVersion: $Version
DefaultLocale: en-US
ManifestType: version
ManifestVersion: $schema
"@

Write-Utf8 "$dir\$id.installer.yaml" @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.installer.$schema.schema.json

PackageIdentifier: $id
PackageVersion: $Version
InstallerType: portable
Commands:
- caffeinate
Installers:
- Architecture: x64
  InstallerUrl: $url
  InstallerSha256: $sha
ManifestType: installer
ManifestVersion: $schema
"@

Write-Utf8 "$dir\$id.locale.en-US.yaml" @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.defaultLocale.$schema.schema.json

PackageIdentifier: $id
PackageVersion: $Version
PackageLocale: en-US
Publisher: $Publisher
PublisherUrl: https://github.com/$Owner
PublisherSupportUrl: $repo/issues
Author: $Publisher
PackageName: caffeinate
PackageUrl: $repo
License: $License
LicenseUrl: $repo/blob/main/LICENSE
ShortDescription: Keep Windows awake from the terminal, like macOS caffeinate.
Description: A tiny command-line tool that keeps your display on for as long as it runs, using the Windows power request API. Run 'caffeinate -d' and press Ctrl+C to restore your normal sleep settings. Nothing is changed permanently.
Moniker: caffeinate
Tags:
- awake
- caffeinate
- cli
- display
- power
- sleep
ReleaseNotesUrl: $repo/releases/tag/v$Version
ManifestType: defaultLocale
ManifestVersion: $schema
"@

Write-Host "Wrote manifest to $dir (SHA256 $sha)"
winget validate --manifest $dir
