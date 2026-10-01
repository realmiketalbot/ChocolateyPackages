$ErrorActionPreference = 'Stop'; # stop on all errors
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# downloads available on this page: https://www.sonicwall.com/products/remote-access/vpn-clients/
$url        = 'https://software.sonicwall.com/NetExtender/NetExtender-x86-10.3.5.msi'
$url64bit      = 'https://software.sonicwall.com/NetExtender/NetExtender-x64-10.3.5.msi'

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  fileType      = 'msi'
  softwareName  = 'SonicWall NetExtender*'

  url           = $url
  checksum      = 'F4A99CDC1D3DC2FB3C40CB1760F78379B9ED5C3ABD9626A47F74F037960F495C'
  checksumType  = 'sha256'

  url64bit      = $url64bit
  checksum64    = '7E2B35ED2629FEBFC76ACD747793CC712B5A2F4FECBFA69C914FC25ED28713A3'
  checksumType64= 'sha256'


  silentArgs   = '/norestart /qn' 
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
