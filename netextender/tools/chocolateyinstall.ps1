$ErrorActionPreference = 'Stop'; # stop on all errors
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# downloads available on this page: https://www.sonicwall.com/products/remote-access/vpn-clients/
$url        = 'https://software.sonicwall.com/NetExtender/NetExtender-x86-10.3.6.msi'
$url64bit      = 'https://software.sonicwall.com/NetExtender/NetExtender-x64-10.3.6.msi'

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  fileType      = 'msi'
  softwareName  = 'SonicWall NetExtender*'

  url           = $url
  checksum      = '62CDCE4FFC839C93BBF1B2EFB09C32A7B08A158F44698BF5A4E9D39D5BC275BA'
  checksumType  = 'sha256'

  url64bit      = $url64bit
  checksum64    = 'D6809EF5A5AF5CBB47BF469E9199E54666EECCE5C44D5B5D58E2F8D6128AC7DF'
  checksumType64= 'sha256'


  silentArgs   = '/norestart /qn' 
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
