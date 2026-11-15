$ErrorActionPreference = 'Stop';
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  fileType      = 'exe'
  url           = 'https://github.com/HydrologicEngineeringCenter/hec-downloads/releases/download/1.0.48/HEC-RAS_702_Setup.exe'

  softwareName  = 'hec-ras*'

  checksum      = '49E2634C7B6552CE78DCB79D741F7ABDAA93020D67C2D8790A677867A0841E6C'
  checksumType  = 'sha256'

  silentArgs   = '/s /v"/qn"' 
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
