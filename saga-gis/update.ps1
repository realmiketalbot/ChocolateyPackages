[CmdletBinding()]
param(
  [switch]$UpdateChangelog
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$PackageName  = 'saga-gis'
$PackageRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path

$InstallScript = Join-Path $PackageRoot 'tools\chocolateyinstall.ps1'
$NuspecPath    = Join-Path $PackageRoot "$PackageName.nuspec"
$ChangelogPath = Join-Path $PackageRoot 'CHANGELOG.md'

$BestReleaseApi = 'https://sourceforge.net/projects/saga-gis/best_release.json'

function Get-LatestSagaGis {
  <#
    SourceForge's "best release" for Windows is the portable zip, e.g.
    /SAGA - 9/SAGA - 9.13.0/saga-9.13.0_msw.zip. The installer is published
    alongside it as saga-<version>_msw_setup.exe.
  #>

  Write-Host "Querying SourceForge best release: $BestReleaseApi"
  $best = Invoke-RestMethod -Uri $BestReleaseApi -TimeoutSec 60

  $filename = $best.platform_releases.windows.filename
  if (-not $filename) { throw "No Windows release found in $BestReleaseApi" }

  $m = [regex]::Match($filename, '^(?<folder>/.+)/saga-(?<version>\d+\.\d+\.\d+)_msw\.zip$')
  if (-not $m.Success) { throw "Unrecognized SAGA release file name: $filename" }

  $version = $m.Groups['version'].Value
  $folder  = ($m.Groups['folder'].Value.TrimStart('/') -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
  $url     = "https://downloads.sourceforge.net/project/saga-gis/$folder/saga-${version}_msw_setup.exe"

  return [pscustomobject]@{
    Version = $version
    Url     = $url
  }
}

function Get-Sha256FromUrl {
  param([Parameter(Mandatory)][string]$Url)

  $tmp = Join-Path $env:TEMP ("{0}.exe" -f ([guid]::NewGuid()))
  try {
    Write-Host "Downloading for checksum: $Url"
    # A non-browser user agent makes SourceForge redirect straight to a mirror
    Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing -UserAgent 'Wget'

    # Guard against hashing an HTML download page instead of the installer
    $header = [System.IO.File]::ReadAllBytes($tmp)[0..1]
    if ($header[0] -ne 0x4D -or $header[1] -ne 0x5A) { throw "Downloaded file is not a Windows executable: $Url" }

    (Get-FileHash -Path $tmp -Algorithm SHA256).Hash
  }
  finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  }
}

Import-Module au -ErrorAction Stop

function global:au_GetLatest {
  $latest = Get-LatestSagaGis
  Write-Host "Parsed version:  $($latest.Version)"
  Write-Host "Installer URL:   $($latest.Url)"
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
      '(?m)^\$url\s*=\s*''[^'']*''' =
        "`$url        = '$($Latest.URL32)'"

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

- Version $($Latest.Version) installer
"@
}

$global:au_NoCheckUrl = $true
update -NoCheckUrl -ChecksumFor none -NoReadme
