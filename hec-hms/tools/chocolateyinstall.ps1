$ErrorActionPreference = 'Stop';
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  fileType      = 'exe'
  url           = 'https://github.com/HydrologicEngineeringCenter/hec-downloads/releases/download/1.0.47/HEC-HMS_414_Setup.exe'

  softwareName  = 'hec-hms*'

  checksum      = 'ED76C8C4F20D709EB4EE8D45F72E3896E9ECCB9095C8E831AE8DD706A8DDD645'
  checksumType  = 'sha256'

  silentArgs   = '/s /v"/qn"' 
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
