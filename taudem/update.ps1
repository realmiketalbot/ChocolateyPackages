[CmdletBinding()]
param(
  [switch]$UpdateChangelog
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$PackageName  = 'taudem'
$PackageRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path

$InstallScript = Join-Path $PackageRoot 'tools\chocolateyinstall.ps1'
$NuspecPath    = Join-Path $PackageRoot "$PackageName.nuspec"
$ChangelogPath = Join-Path $PackageRoot 'CHANGELOG.md'

$ReleasesApi = 'https://api.github.com/repos/dtarb/TauDEM/releases'

function Get-LatestTauDem {
  $headers = @{
    'User-Agent' = 'Chocolatey-AU'
    'Accept'     = 'application/vnd.github+json'
  }

  Write-Host "Querying GitHub releases: $ReleasesApi"
  $releases = Invoke-RestMethod -Uri $ReleasesApi -Headers $headers -TimeoutSec 60

  if (-not $releases) { throw "No releases returned from $ReleasesApi" }

  foreach ($rel in $releases) {
    if ($rel.draft -or $rel.prerelease) { continue }
    if ($rel.tag_name -notmatch '^v?(\d+\.\d+\.\d+)$') { continue }
    $version = $Matches[1]

    # 64-bit command line executables zip, e.g. TauDEM550exeWin64.zip
    $asset = $rel.assets |
      Where-Object { $_.name -match '^TauDEM\d+exeWin64\.zip$' } |
      Select-Object -First 1

    if ($asset) {
      return [pscustomobject]@{
        Version = $version
        Url     = $asset.browser_download_url
        Asset   = $asset.name
        Release = $rel.tag_name
      }
    }
  }

  throw "Could not find any asset matching TauDEM(digits)exeWin64.zip in recent releases."
}

function Get-Sha256FromUrl {
  param([Parameter(Mandatory)][string]$Url)

  $tmp = Join-Path $env:TEMP ("{0}.zip" -f ([guid]::NewGuid()))
  try {
    Write-Host "Downloading for checksum: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing
    (Get-FileHash -Path $tmp -Algorithm SHA256).Hash
  }
  finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  }
}

Import-Module au -ErrorAction Stop

function global:au_GetLatest {
  $latest = Get-LatestTauDem
  Write-Host "Selected asset: $($latest.Asset) (release: $($latest.Release))"
  Write-Host "Parsed version:  $($latest.Version)"
  $sha256 = Get-Sha256FromUrl -Url $latest.Url

  return @{
    Version    = $latest.Version
    URL64      = $latest.Url
    Checksum64 = $sha256
  }
}

function global:au_SearchReplace {
  @{
    $InstallScript = @{
      "(?m)^\s*url64bit\s*=\s*'[^']*'\s*$" =
        "  url64bit      = '$($Latest.URL64)'"

      "(?m)^\s*checksum64\s*=\s*'[^']*'\s*$" =
        "  checksum64    = '$($Latest.Checksum64)'"
    }

    $NuspecPath = @{
      '(?m)^\s*<version>[^<]+</version>\s*$' =
        "    <version>$($Latest.Version)</version>"
    }
  }
}

function global:au_AfterUpdate {
  if (-not $UpdateChangelog) { return }
  if (-not (Test-Path $ChangelogPath)) { return }

  $content = Get-Content -Path $ChangelogPath -Raw
  if ($content -match [regex]::Escape("## [$($Latest.Version)]")) { return }

  $date = Get-Date -Format 'yyyy-MM-dd'
  Add-Content -Path $ChangelogPath -Value @"

## [$($Latest.Version)] - $date

### Added

- Version $($Latest.Version) executables
"@
}

$global:au_NoCheckUrl = $true
update -NoCheckUrl -ChecksumFor none -NoReadme
