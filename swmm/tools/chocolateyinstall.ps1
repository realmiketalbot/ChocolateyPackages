$ErrorActionPreference = 'Stop';
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url        = 'https://epa.gov/system/files/other-files/2023-08/swmm524%28x86%29_setup.exe'
$url64bit      = 'https://epa.gov/system/files/other-files/2023-08/swmm524%28x64%29_setup.exe'

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  fileType      = 'exe'
  softwareName  = 'EPA SWMM*'

  url           = $url
  checksum      = '621620044346DEA2EAB6B583B951FAF1AB5476F8F868FD648ED45E912B2AD1DA'
  checksumType  = 'sha256'

  url64bit      = $url64bit
  checksum64    = 'C32B4FAAD3F8F0E510D3C96B2490A4F0837654BAC5939B3FB6D631D1411FC5CA'
  checksumType64= 'sha256'

  silentArgs   = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
