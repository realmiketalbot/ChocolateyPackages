$ErrorActionPreference = 'Stop'; # stop on all errors
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
# Community Repo: Use official urls for non-redist binaries or redist where total package size is over 200MB
# Internal/Organization: Download from internal location (internet sources are unreliable)
$url        = 'https://software.sonicwall.com/GlobalVPNClient/184-011921-00_REV_A_GVCSetup64.exe' # download url, HTTPS preferred

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  fileType      = 'exe'
  url           = $url

  softwareName  = 'Global VPN Client*'

  checksum      = '2663dee4be9d346751d42bb1465b5d0138bcc99805790be0cb6f8f01574c1309'
  checksumType  = 'sha256'

  # silentArgs = '/s' # from ussf, but did not work
  # silentArgs = '/S' # did not work
  # silentArgs = '/q' # did not work
  # silentArgs = '/qn' # did not work
  # silentArgs = '/Q' # did not work
  # silentArgs = '/quiet' # did not work
  # silentArgs = '/silent' # did not work
  # silentArgs   = '/SILENT' # did not work
  # silentArgs = '/verysilent'
  # silentArgs = '/VERYSILENT' # did not work
  # silentArgs   = '/s /v"/qn"' # did not work 
  # silentArgs = '/S /V" /qn' # did not work
  # silentArgs   = '/norestart /qn' # did not work 
  # silentArgs = '/verysilent /norestart '
  # silentArgs   = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-' # did not work
  # The installer is a WinRAR self-extractor that runs GVCInstall64.msi; -s keeps the extraction
  # silent and -sp passes the quiet switches through to the MSI.
  silentArgs    = '-s "-sp/qn /norestart"'
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
