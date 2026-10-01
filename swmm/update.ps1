[CmdletBinding()]
param(
  [switch]$UpdateChangelog
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$PackageName  = 'swmm'
$PackageRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path

$InstallScript = Join-Path $PackageRoot 'tools\chocolateyinstall.ps1'
$NuspecPath    = Join-Path $PackageRoot "$PackageName.nuspec"
$ChangelogPath = Join-Path $PackageRoot 'CHANGELOG.md'

$DownloadPage = 'https://www.epa.gov/water-research/storm-water-management-model-swmm'

function Get-LatestSwmm {
  <#
    EPA links the installers from the SWMM page under dated paths, e.g.
    /system/files/other-files/2023-08/swmm524%28x64%29_setup.exe. Older releases
    use swmm522x64_setup.exe, so the parentheses are optional. The highest
    3-digit version token with both x86 and x64 installers wins.
  #>

  Write-Host "Fetching SWMM download page: $DownloadPage"
  # EPA rejects requests without a browser-like user agent
  $html = (Invoke-WebRequest -Uri $DownloadPage -UseBasicParsing -TimeoutSec 60 -UserAgent 'Mozilla/5.0').Content

  $pattern = '(?i)href\s*=\s*"(?<url>[^"]*/swmm(?<token>\d{3})(?:%28|\()?(?<arch>x86|x64)(?:%29|\))?_setup\.exe)"'
  $links = foreach ($m in [regex]::Matches($html, $pattern)) {
    $href = $m.Groups['url'].Value
    if ($href -notmatch '^https?://') { $href = (New-Object System.Uri((New-Object System.Uri($DownloadPage)), $href)).AbsoluteUri }
    [pscustomobject]@{ Token = $m.Groups['token'].Value; Arch = $m.Groups['arch'].Value.ToLower(); Url = $href }
  }

  if (-not $links) { throw "No SWMM installer links found on $DownloadPage" }

  foreach ($group in ($links | Group-Object Token | Sort-Object { [int]$_.Name } -Descending)) {
    $x86 = $group.Group | Where-Object Arch -eq 'x86' | Select-Object -First 1
    $x64 = $group.Group | Where-Object Arch -eq 'x64' | Select-Object -First 1
    if ($x86 -and $x64) {
      $t = $group.Name
      return [pscustomobject]@{
        Version = "{0}.{1}.{2}" -f $t[0], $t[1], $t[2]
        URL32   = $x86.Url
        URL64   = $x64.Url
      }
    }
  }

  throw "No SWMM version on $DownloadPage has both x86 and x64 installers."
}

function Get-Sha256FromUrl {
  param([Parameter(Mandatory)][string]$Url)

  $tmp = Join-Path $env:TEMP ("{0}.exe" -f ([guid]::NewGuid()))
  try {
    Write-Host "Downloading for checksum: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing -UserAgent 'Mozilla/5.0'
    (Get-FileHash -Path $tmp -Algorithm SHA256).Hash
  }
  finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  }
}

Import-Module au -ErrorAction Stop

function global:au_GetLatest {
  $latest = Get-LatestSwmm
  Write-Host "Parsed version:  $($latest.Version)"

  return @{
    Version    = $latest.Version
    URL32      = $latest.URL32
    URL64      = $latest.URL64
    Checksum32 = Get-Sha256FromUrl -Url $latest.URL32
    Checksum64 = Get-Sha256FromUrl -Url $latest.URL64
  }
}

function global:au_SearchReplace {
  @{
    $InstallScript = @{
      '(?m)^\$url\s*=\s*''[^'']*'''      = "`$url        = '$($Latest.URL32)'"
      '(?m)^\$url64bit\s*=\s*''[^'']*''' = "`$url64bit      = '$($Latest.URL64)'"
      "(?m)^\s*checksum\s*=\s*'[^']*'"   = "  checksum      = '$($Latest.Checksum32)'"
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

- Version $($Latest.Version) installer
"@
}

$global:au_NoCheckUrl = $true
update -NoCheckUrl -ChecksumFor none -NoReadme
