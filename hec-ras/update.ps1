[CmdletBinding()]
param(
  [switch]$UpdateChangelog
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$PackageName  = 'hec-ras'
$PackageRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path

$InstallScript = Join-Path $PackageRoot 'tools\chocolateyinstall.ps1'
$NuspecPath    = Join-Path $PackageRoot "$PackageName.nuspec"
$ChangelogPath = Join-Path $PackageRoot 'CHANGELOG.md'

$ReleasesApi = 'https://api.github.com/repos/HydrologicEngineeringCenter/hec-downloads/releases'

function Convert-RasTokenToVersion {
  param([Parameter(Mandatory)][string]$Token)

  # Common tokens:
  # 66  -> 6.6
  # 70  -> 7.0
  # 701 -> 7.0.1
  # 641 -> 6.4.1
  # 631 -> 6.3.1
  # 610 -> 6.1 (or 6.1.0; we drop trailing .0)
  if ($Token.Length -lt 2) { throw "Unrecognized HEC-RAS token: $Token" }

  $major = $Token.Substring(0,1)
  $minor = $Token.Substring(1,1)
  $patch = $null
  if ($Token.Length -ge 3) { $patch = $Token.Substring(2) }

  if ($patch -and $patch -match '^\d+$' -and [int]$patch -ne 0) {
    return "$major.$minor.$patch"
  }

  return "$major.$minor"
}

function Get-LatestHecRasFromHecDownloads {
  $headers = @{
    'User-Agent' = 'Chocolatey-AU'
    'Accept'     = 'application/vnd.github+json'
  }

  Write-Host "Querying GitHub releases: $ReleasesApi"
  $releases = Invoke-RestMethod -Uri $ReleasesApi -Headers $headers -TimeoutSec 60

  if (-not $releases) { throw "No releases returned from $ReleasesApi" }

  foreach ($rel in $releases) {
    if ($rel.draft -or $rel.prerelease) { continue }
    if (-not $rel.assets) { continue }

    # Only plain Windows installers with a 2-3 digit version token (e.g. HEC-RAS_66_Setup.exe,
    # HEC-RAS_701_Setup.exe). This skips Beta/Alpha builds, "_with_Linux_" bundles, and
    # year-named builds such as HEC-RAS_2025_*.
    $asset = $rel.assets |
      Where-Object { $_.name -match '^HEC-RAS_(\d{2,3})_Setup\.exe$' } |
      Select-Object -First 1

    if ($asset) {
      $m = [regex]::Match($asset.name, '^HEC-RAS_(\d{2,3})_Setup\.exe$')
      $version = Convert-RasTokenToVersion -Token $m.Groups[1].Value

      return [pscustomobject]@{
        Version = $version
        Url     = $asset.browser_download_url
        Asset   = $asset.name
        Release = $rel.tag_name
      }
    }
  }

  throw "Could not find any asset matching HEC-RAS_(digits)_Setup.exe in recent releases."
}

function Get-Sha256FromUrl {
  param([Parameter(Mandatory)][string]$Url)

  $tmp = Join-Path $env:TEMP ("{0}.exe" -f ([guid]::NewGuid()))
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
  $latest = Get-LatestHecRasFromHecDownloads
  Write-Host "Selected asset: $($latest.Asset) (release: $($latest.Release))"
  Write-Host "Parsed version:  $($latest.Version)"

  $sha256 = Get-Sha256FromUrl -Url $latest.Url

  return @{
    Version    = $latest.Version
    URL32      = $latest.Url
    Checksum32 = $sha256
  }
}

function global:au_SearchReplace {
  @{
    $InstallScript = @{
      # Recommended install-script style: inline url/checksum literals inside $packageArgs (no $url variable).
      "(?m)^\s*url\s*=\s*'[^']*'\s*$"      = "  url           = '$($Latest.URL32)'"
      "(?m)^\s*checksum\s*=\s*'[^']*'\s*$" = "  checksum      = '$($Latest.Checksum32)'"
    }

    $NuspecPath = @{
      '(?m)^\s*<version>[^<]+</version>\s*$' = "    <version>$($Latest.Version)</version>"
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

- Version $($Latest.Version) installer
"@
}

$global:au_NoCheckUrl = $true
update -NoCheckUrl -ChecksumFor none -NoReadme
