$ErrorActionPreference = 'Stop';
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url        = 'https://downloads.sourceforge.net/project/saga-gis/SAGA%20-%209/SAGA%20-%209.14.2/saga-9.14.2_msw_setup.exe'

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  fileType      = 'exe'
  url           = $url

  softwareName  = 'saga-gis*'

  checksum      = 'E0DD957A57873F810CACC99F3832DD12D365199DA9F96B5D69BE5C4EF0DBF1A9'
  checksumType  = 'sha256'

  silentArgs    = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
