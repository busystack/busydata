param(
  [switch]$RequireWindows11,
  [switch]$RequireWack
)

. "$PSScriptRoot/common.ps1"

if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem) {
  throw 'BusyData Windows builds require 64-bit Windows 11.'
}
$operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem
if ($null -eq $operatingSystem) {
  throw 'Win32_OperatingSystem could not be queried for Windows validation.'
}
try {
  $hostBuild = [int]$operatingSystem.BuildNumber
  $hostProductType = [uint32]$operatingSystem.ProductType
} catch {
  throw "Win32_OperatingSystem returned invalid validation data: $($_.Exception.Message)"
}
$windows11ValidationHost = Test-BusyDataWindows11ValidationHost `
  -Build $hostBuild -ProductType $hostProductType
if ($RequireWindows11) {
  Assert-BusyDataWindows11ValidationHost -Build $hostBuild `
    -ProductType $hostProductType
}
$flutterCommands = @(Get-Command flutter -CommandType Application -All `
  -ErrorAction Stop)
if ($flutterCommands.Count -eq 0) {
  throw 'Flutter was not found on PATH.'
}
$flutterExecutable = [IO.Path]::GetFullPath($flutterCommands[0].Source)
$flutterBin = [IO.Path]::GetFullPath((Split-Path -Parent $flutterExecutable))
$dartExecutable = [IO.Path]::GetFullPath((Join-Path $flutterBin `
  'cache\dart-sdk\bin\dart.exe'))
if (-not (Test-Path -LiteralPath $dartExecutable -PathType Leaf)) {
  throw "The selected Flutter SDK has no bundled Dart executable at $dartExecutable."
}
$toolchainVerifier = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot `
  '..\verify_flutter_sdk.dart'))
$toolchainJson = & $dartExecutable $toolchainVerifier `
  --flutter $flutterExecutable `
  --dart $dartExecutable `
  --toolchain (Join-Path $PSScriptRoot '..\..\config\toolchain.json')
if ($LASTEXITCODE -ne 0) {
  throw 'Flutter SDK verification failed.'
}
$toolchain = $toolchainJson | ConvertFrom-Json
$flutterVersion = [string]$toolchain.flutterVersion
$dartVersion = [string]$toolchain.dartVersion
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) {
  throw 'Visual Studio 2022 with Desktop development with C++ is required.'
}
$visualStudio = & $vswhere -latest -products * `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.VC.ATL `
  -property installationPath
if ([string]::IsNullOrWhiteSpace($visualStudio)) {
  throw 'Visual Studio C++ x64 desktop tools with matching ATL were not found.'
}
$visualStudioVersion = & $vswhere -latest -products * `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.VC.ATL `
  -property installationVersion
$visualStudioDisplayName = & $vswhere -latest -products * `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.VC.ATL `
  -property displayName
$kitsBin = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$sdk = Get-BusyDataWindowsSdkDirectory -KitsBin $kitsBin
if ($null -eq $sdk) { throw 'Windows SDK 10.0.26100.0 or newer is required.' }
foreach ($tool in @('makeappx.exe', 'signtool.exe')) {
  if (-not (Test-Path -LiteralPath (Join-Path $sdk.FullName "x64\$tool"))) {
    throw "$tool was not found in Windows SDK $($sdk.Name)."
  }
}
if ($RequireWack) {
  $appCert = Join-Path ${env:ProgramFiles(x86)} `
    'Windows Kits\10\App Certification Kit\appcert.exe'
  if (-not (Test-Path -LiteralPath $appCert)) {
    throw 'The Windows App Certification Kit is required.'
  }
}
$windowsVersion = Get-ItemProperty -LiteralPath `
  'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
[pscustomobject]@{
  Flutter = $flutterVersion
  FlutterExecutable = $flutterExecutable
  Dart = $dartVersion
  DartExecutable = $dartExecutable
  VisualStudio = $visualStudio
  VisualStudioDisplayName = $visualStudioDisplayName
  VisualStudioVersion = $visualStudioVersion
  WindowsSdk = $sdk.Name
  WindowsSdkBin = Join-Path $sdk.FullName 'x64'
  HostProductName = [string]$windowsVersion.ProductName
  HostEditionId = [string]$windowsVersion.EditionID
  HostDisplayVersion = [string]$windowsVersion.DisplayVersion
  HostVersion = [Environment]::OSVersion.Version.ToString()
  HostBuild = $hostBuild
  HostProductType = $hostProductType
  Windows11ValidationHost = $windows11ValidationHost
}
