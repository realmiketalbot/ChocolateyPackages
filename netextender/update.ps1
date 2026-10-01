[CmdletBinding()]
param(
  [switch]$UpdateChangelog
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$PackageName  = 'netextender'
$PackageRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path

$InstallScript = Join-Path $PackageRoot 'tools\chocolateyinstall.ps1'
$NuspecPath    = Join-Path $PackageRoot "$PackageName.nuspec"
$ChangelogPath = Join-Path $PackageRoot 'CHANGELOG.md'

function Get-NetExtenderMeta {
  <#
    Uses SonicWall Free Downloads API (per community gist) to locate the latest version
    for Windows x86/x64. We still compute SHA256 ourselves for Chocolatey.
  #>

  [CmdletBinding()]
  param(
    [ValidateSet('Windows-x64','Windows-x86')]
    [string]$Platform = 'Windows-x64'
  )

  # Ensure TLS 1.2+ (older hosts)
  if (-not ([System.Net.ServicePointManager]::SecurityProtocol -band [System.Net.SecurityProtocolType]::Tls12)) {
    [System.Net.ServicePointManager]::SecurityProtocol =
      [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
  }

  $uri = 'https://api.mysonicwall.com/api/downloads/get-freedownloads'

  # This payload is taken from / consistent with the gist (productType 17491 = NetExtender)
  $body = @{
    category         = 'LATEST'
    productType      = '17491'          # NetExtender
    swLangCode       = 'EN'
    fileType         = @('Firmware')
    releaseTypeList  = @(@{ releaseType = 'ALL' })
    keyWord          = ''
    previousVersions = $false
    isFileTypeChange = $false
    username         = 'ANONYMOUS'
  } | ConvertTo-Json

  $headers = @{
    'Accept'     = 'application/json'
    'User-Agent' = 'Chocolatey AU updater (netextender)'
  }

  $resp = Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Headers $headers -Body $body -TimeoutSec 60

  # Gather all "applicableDownloads" and locate the NetExtender block (same approach as gist)
  $blocks = @()
  if ($resp.content -and $resp.content.UserDownloads) {
    foreach ($ud in $resp.content.UserDownloads) {
      if ($ud.applicableDownloads) { $blocks += $ud.applicableDownloads }
    }
  }

  $nx = $blocks | Where-Object { $_.Name -eq 'NetExtender' } | Select-Object -First 1
  if (-not $nx -or -not $nx.softwareList) {
    throw "NetExtender not found in API response."
  }

  $label = if ($Platform -eq 'Windows-x64') { 'Windows 64 bit' } else { 'Windows 32 bit' }

  $candidates = $nx.softwareList | Where-Object { $_.name -like "*$label*" }
  if (-not $candidates) {
    throw "No packages found for platform '$Platform'."
  }

  # Latest by Version descending (same idea as gist)
  $pkg = $candidates | Sort-Object -Property @{Expression='Version';Descending=$true} | Select-Object -First 1
  if (-not $pkg -or -not $pkg.Version) {
    throw "Could not determine latest version for $Platform."
  }

  $fileName = if ($Platform -eq 'Windows-x64') { "NetExtender-x64-$($pkg.Version).msi" } else { "NetExtender-x86-$($pkg.Version).msi" }
  $url      = "https://software.sonicwall.com/NetExtender/$fileName"

  # API provides MD5 (pkg.md5HashValue), but Chocolatey package uses SHA256 today.
  return [pscustomobject]@{
    Platform = $Platform
    Version  = $pkg.Version
    Url      = $url
    Md5      = $pkg.md5HashValue
  }
}

function Get-Sha256FromUrl {
  param([Parameter(Mandatory=$true)][string]$Url)

  $tmp = Join-Path $env:TEMP ("{0}.msi" -f ([guid]::NewGuid().ToString()))
  try {
    Write-Host "Downloading for checksum: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing
    return (Get-FileHash -Path $tmp -Algorithm SHA256).Hash
  }
  finally {
    Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue
  }
}

function Test-UrlExists {
  param([Parameter(Mandatory=$true)][string]$Url)

  try {
    $r = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 30
    return ($r.StatusCode -eq 200)
  }
  catch {
    return $false
  }
}

function Find-NetExtenderByProbe {
  <#
    Fallback for when the SonicWall API is unavailable (it began returning
    "MSWAPP:RUNTIMEERR" in March 2026). Starting from the version in the nuspec,
    HEAD-checks the predictable software.sonicwall.com MSI URLs for the next few
    patch, minor and major versions, and returns the highest one published for
    both x86 and x64. Returns $null if nothing newer than the current version exists.
  #>

  [xml]$nuspec = Get-Content -Path $NuspecPath
  $current = [version]$nuspec.package.metadata.version
  Write-Host "Probing software.sonicwall.com for versions newer than $current"

  $candidates = @()
  foreach ($patch in ($current.Build + 1)..($current.Build + 10)) { $candidates += "$($current.Major).$($current.Minor).$patch" }
  foreach ($patch in 0..5) { $candidates += "$($current.Major).$($current.Minor + 1).$patch" }
  foreach ($patch in 0..2) { $candidates += "$($current.Major + 1).0.$patch" }

  $found = $null
  foreach ($v in $candidates) {
    $x64Url = "https://software.sonicwall.com/NetExtender/NetExtender-x64-$v.msi"
    $x86Url = "https://software.sonicwall.com/NetExtender/NetExtender-x86-$v.msi"
    if ((Test-UrlExists $x64Url) -and (Test-UrlExists $x86Url)) {
      Write-Host "Found published version: $v"
      if (-not $found -or [version]$v -gt [version]$found.Version) {
        $found = [pscustomobject]@{ Version = $v; URL32 = $x86Url; URL64 = $x64Url }
      }
    }
  }

  return $found
}

Import-Module au -ErrorAction Stop

function global:au_GetLatest {
  try {
    $x64 = Get-NetExtenderMeta -Platform 'Windows-x64'
    $x86 = Get-NetExtenderMeta -Platform 'Windows-x86'

    # Sanity: versions should match; if not, prefer x64 but warn loudly.
    $version = $x64.Version
    if ($x86.Version -ne $x64.Version) {
      Write-Warning "x86 version ($($x86.Version)) != x64 version ($($x64.Version)); using x64 as package version."
    }
    $url32 = $x86.Url
    $url64 = $x64.Url
  }
  catch {
    Write-Warning "SonicWall API lookup failed: $($_.Exception.Message). Falling back to URL probing."
    $probe = Find-NetExtenderByProbe
    if (-not $probe) {
      Write-Host "No newer NetExtender version found by probing."
      return 'ignore'
    }
    $version = $probe.Version
    $url32   = $probe.URL32
    $url64   = $probe.URL64
  }

  $checksum32 = Get-Sha256FromUrl -Url $url32
  $checksum64 = Get-Sha256FromUrl -Url $url64

  return @{
    Version    = $version
    URL32      = $url32
    URL64      = $url64
    Checksum32 = $checksum32
    Checksum64 = $checksum64
  }
}

function global:au_SearchReplace {
  @{
    $InstallScript = @{
      '(?m)^\$url\s*=\s*''[^'']*'''        = "`$url        = '$($Latest.URL32)'"
      '(?m)^\$url64bit\s*=\s*''[^'']*'''   = "`$url64bit      = '$($Latest.URL64)'"
      "(?m)^\s*checksum\s*=\s*'[^']*'"     = "  checksum      = '$($Latest.Checksum32)'"
      "(?m)^\s*checksum64\s*=\s*'[^']*'"   = "  checksum64    = '$($Latest.Checksum64)'"
    }

    $NuspecPath = @{
      '(?m)^\s*<version>[^<]+</version>\s*$' = "    <version>$($Latest.Version)</version>"
    }
  }
}

function global:au_AfterUpdate {
  param($Package)

  if (-not $UpdateChangelog) { return }
  if (-not (Test-Path $ChangelogPath)) { return }

  $content = Get-Content -Path $ChangelogPath -Raw
  if ($content -match [regex]::Escape("## [$($Latest.Version)]")) { return }

  $date = Get-Date -Format 'yyyy-MM-dd'
  $entry = @"

## [$($Latest.Version)] - $date

### Added

- Version $($Latest.Version) installer
"@
  Add-Content -Path $ChangelogPath -Value $entry
}

# Critical: prevent AU URL check logic from “helpfully” altering the SonicWall URL
$global:au_NoCheckUrl = $true

# We compute checksums ourselves.
update -NoCheckUrl -ChecksumFor none -NoReadme
