[CmdletBinding()]
param(
  [switch]$UpdateChangelog
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$PackageName  = 'whiteboxtools-open-core'
$PackageRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path

$InstallScript = Join-Path $PackageRoot 'tools\chocolateyinstall.ps1'
$NuspecPath    = Join-Path $PackageRoot "$PackageName.nuspec"
$ChangelogPath = Join-Path $PackageRoot 'CHANGELOG.md'

# whiteboxgeo.com serves the current build at a fixed, unversioned URL, so the
# version number comes from the open-source project's GitHub releases.
$DownloadUrl = 'https://www.whiteboxgeo.com/WBT_Windows/WhiteboxTools_win_amd64.zip'
$LatestApi   = 'https://api.github.com/repos/jblindsay/whitebox-tools/releases/latest'

function Get-LatestWhiteboxVersion {
  $headers = @{
    'User-Agent' = 'Chocolatey-AU'
    'Accept'     = 'application/vnd.github+json'
  }

  Write-Host "Querying GitHub latest release: $LatestApi"
  $rel = Invoke-RestMethod -Uri $LatestApi -Headers $headers -TimeoutSec 60

  if ($rel.tag_name -notmatch '^v?(\d+\.\d+\.\d+)$') { throw "Unrecognized WhiteboxTools release tag: $($rel.tag_name)" }
  return $Matches[1]
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
  $version = Get-LatestWhiteboxVersion
  Write-Host "Parsed version:  $version"
  $sha256 = Get-Sha256FromUrl -Url $DownloadUrl

  [xml]$nuspec = Get-Content -Path $NuspecPath
  $currentVersion = $nuspec.package.metadata.version
  $currentChecksum = [regex]::Match((Get-Content -Path $InstallScript -Raw), "(?m)^\s*checksum64\s*=\s*'(?<sum>[^']*)'").Groups['sum'].Value

  # Same version but different file: the published package would fail its checksum check.
  # Fail loudly so the maintainer can decide how to version the new build.
  if ($version -eq $currentVersion -and $sha256 -ne $currentChecksum) {
    throw "WhiteboxTools zip changed (SHA256 $sha256, package has $currentChecksum) but the latest GitHub release is still $version. Update the package manually."
  }

  # New version tagged on GitHub but whiteboxgeo.com still serves the old build: wait for it.
  if ($version -ne $currentVersion -and $sha256 -eq $currentChecksum) {
    Write-Host "GitHub release $version found, but $DownloadUrl has not changed yet; skipping."
    return 'ignore'
  }

  return @{
    Version    = $version
    URL64      = $DownloadUrl
    Checksum64 = $sha256
  }
}

function global:au_SearchReplace {
  @{
    $InstallScript = @{
      "(?m)^\s*checksum64\s*=\s*'[^']*'" = "  checksum64    = '$($Latest.Checksum64)'"
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

- Version $($Latest.Version) binaries
"@
}

$global:au_NoCheckUrl = $true
update -NoCheckUrl -ChecksumFor none -NoReadme
