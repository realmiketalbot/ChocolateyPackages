$ErrorActionPreference = 'Stop';
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  fileType      = 'exe'
  url           = 'https://github.com/HydrologicEngineeringCenter/hec-downloads/releases/download/1.0.46/HEC-RAS_701_Setup.exe'

  softwareName  = 'hec-ras*'

  checksum      = '1FE76297076AA7A13E43191ECC76C3BA152FDC4BBD606FA2C349EEC7DB3CEE73'
  checksumType  = 'sha256'

  silentArgs   = '/s /v"/qn"' 
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
