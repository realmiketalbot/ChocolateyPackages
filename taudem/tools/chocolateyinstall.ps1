$ErrorActionPreference = 'Stop';
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$unzipDir   = Join-Path $toolsDir 'bin'

# TauDEM 5.4+ is published as 64-bit only
$packageArgs = @{
  packageName   = $Env:ChocolateyPackageName
  url64bit      = 'https://github.com/dtarb/TauDEM/releases/download/v5.5.0/TauDEM550exeWin64.zip'
  UnzipLocation = $unzipDir
  checksum64    = '7C16312F86ADF96CE1C35786A0664A1A5FFA0E0B9A873E1C71167A2C27B7A126'
  checksumType64= 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

# The upstream zip contains macOS metadata (__MACOSX\._*.exe) that Chocolatey would otherwise shim
Remove-Item -Path (Join-Path $unzipDir '__MACOSX') -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path $unzipDir -Recurse -Force -Filter '.DS_Store' | Remove-Item -Force -ErrorAction SilentlyContinue

Write-Warning 'TauDEM requires the Microsoft MPI runtime (msmpi.dll). If it is not already installed, download it from https://learn.microsoft.com/en-us/message-passing-interface/microsoft-mpi'
