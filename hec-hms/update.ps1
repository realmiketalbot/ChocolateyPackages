[CmdletBinding()]
param(
  [switch]$UpdateChangelog
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$PackageName  = 'hec-hms'
$PackageRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path

$InstallScript = Join-Path $PackageRoot 'tools\chocolateyinstall.ps1'
$NuspecPath    = Join-Path $PackageRoot "$PackageName.nuspec"
$ChangelogPath = Join-Path $PackageRoot 'CHANGELOG.md'

$ReleasesApi = 'https://api.github.com/repos/HydrologicEngineeringCenter/hec-downloads/releases'

function Convert-HecHmsTokenToVersion {
  param([Parameter(Mandatory)][string]$Token)

  # Token examples:
  # 412  -> 4.12
  # 413  -> 4.13
  # 4100 -> 4.10.0 (rare, but handle)
  # 500  -> 5.0.0 (future-proof)
  if ($Token.Length -eq 3) {
    return "{0}.{1}" -f $Token.Substring(0,1), $Token.Substring(1,2)
  }
  elseif ($Token.Length -eq 4) {
    return "{0}.{1}.{2}" -f $Token.Substring(0,1), $Token.Substring(1,2), $Token.Substring(3,1)
  }
  elseif ($Token.Length -ge 5) {
    # Fallback: 1 digit major, 2 digit minor, rest patch
    $major = $Token.Substring(0,1)
    $minor = $Token.Substring(1,2)
    $patch = $Token.Substring(3)
    return "$major.$minor.$patch"
  }

  throw "Unrecognized HEC-HMS version token: $Token"
}

function Get-LatestHecHmsFromHecDownloads {
  $headers = @{
    'User-Agent' = 'Chocolatey-AU'
    'Accept'     = 'application/vnd.github+json'
  }
  # In GitHub Actions, authenticate so requests count against this repository's limit
  # rather than the anonymous 60/hour limit shared by everyone on the runner's IP
  if ($env:GITHUB_TOKEN) { $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN" }

  Write-Host "Querying GitHub releases: $ReleasesApi"
  $releases = Invoke-RestMethod -Uri $ReleasesApi -Headers $headers -TimeoutSec 60

  if (-not $releases) { throw "No releases returned from $ReleasesApi" }

  foreach ($rel in $releases) {
    if ($rel.draft -or $rel.prerelease) { continue }
    if (-not $rel.assets) { continue }

    # Find the first HEC-HMS Setup asset in this release
    $asset = $rel.assets |
      Where-Object { $_.name -match '^HEC-HMS_(\d+)_Setup\.exe$' } |
      Select-Object -First 1

    if ($asset) {
      $m = [regex]::Match($asset.name, '^HEC-HMS_(\d+)_Setup\.exe$')
      $token = $m.Groups[1].Value
      $version = Convert-HecHmsTokenToVersion -Token $token

      return [pscustomobject]@{
        Version = $version
        Url     = $asset.browser_download_url
        Asset   = $asset.name
        Release = $rel.tag_name
      }
    }
  }

  throw "Could not find any asset matching HEC-HMS_(digits)_Setup.exe in recent releases."
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
  $latest = Get-LatestHecHmsFromHecDownloads
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
      "(?m)^\s*url\s*=\s*'[^']*'\s*$" =
        "  url           = '$($Latest.URL32)'"

      "(?m)^\s*checksum\s*=\s*'[^']*'\s*$" =
        "  checksum      = '$($Latest.Checksum32)'"
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

- Updated to HEC-HMS $($Latest.Version)
"@
}

$global:au_NoCheckUrl = $true
update -NoCheckUrl -ChecksumFor none -NoReadme
