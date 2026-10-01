$ErrorActionPreference = 'Stop';
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url        = 'https://github.com/USEPA/EPANET2.2/releases/download/2.2.0/epanet2.2_setup.exe'

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  fileType      = 'exe'
  url           = $url

  softwareName  = 'EPANET*'

  checksum      = '79D9A585A557D13D8471D713D0AE093D9CCA67C14B8E573223D71EEE8B89F671'
  checksumType  = 'sha256'

  silentArgs    = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-' # Inno Setup
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
