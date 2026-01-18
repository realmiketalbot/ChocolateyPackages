$ErrorActionPreference = 'Stop'; # stop on all errors
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# downloads available on this page: https://www.sonicwall.com/products/remote-access/vpn-clients/
$url        = 'https://software.sonicwall.com/NetExtender/NetExtender-x86-10.3.3.msi'
$url64bit      = 'https://software.sonicwall.com/NetExtender/NetExtender-x64-10.3.3.msi'

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  fileType      = 'msi'
  softwareName  = 'netextender*'

  url           = $url
  checksum      = '9976F349F3B33A0DD5AFC839E9CB0C66AF09E4750773E6A00743EEDB96374505'
  checksumType  = 'sha256'

  url64bit      = $url64bit
  checksum64    = 'A349F2160C3F729DF5461BA3F3387518C98B8C455D70EF25DADAA89893923352'
  checksumType64= 'sha256'


  silentArgs   = '/norestart /qn' 
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
