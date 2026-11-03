# Packaging flow adapted from BusyMax bf986002; Apache-2.0.
param([Parameter(Mandatory)][string]$ConfigPath,
  [string]$ReleasePath='build/windows/x64/runner/Release')
. "$PSScriptRoot/common.ps1"
$environment = & "$PSScriptRoot/check_prerequisites.ps1"
$config = Get-BusyDataStoreConfig -Path $ConfigPath
foreach ($field in @('identityName','publisher','publisherDisplayName','assetsDirectory')) {
  if (Test-BusyDataPlaceholder ([string]$config.$field)) { throw "Supply approved $field; no production identity or artwork is generated." }
}
Assert-BusyDataMsixVersion -Version $config.msixVersion -PreviousVersion $config.previousMsixVersion
foreach ($file in @('busydata.exe','flutter_windows.dll','backend/runtime/bin/java.exe','backend/native/busydata_windows_files.dll','backend/lib/busydata-backend-0.1.0.jar','backend/runtime-check.json','backend/bom.json')) {
  if (-not (Test-Path -LiteralPath (Join-Path $ReleasePath $file))) { throw "Missing bundled component: $file" }
}
$output='build/windows/store'
New-Item -ItemType Directory -Force $output | Out-Null
$staging=Join-Path $output ('staging-'+[guid]::NewGuid())
New-Item -ItemType Directory $staging | Out-Null
Copy-Item "$ReleasePath/*" $staging -Recurse
Get-ChildItem $staging -Filter '*.pdb' -Recurse | Remove-Item
Copy-BusyDataVCRuntime -VisualStudioPath $environment.VisualStudio -Destination $staging
New-Item -ItemType Directory (Join-Path $staging 'Assets') | Out-Null
foreach ($asset in @('StoreLogo.png','Square44x44Logo.png','Square150x150Logo.png')) {
  $source=Join-Path $config.assetsDirectory $asset
  if (-not (Test-Path $source -PathType Leaf)) { throw "Approved package visual asset is missing: $asset" }
  Copy-Item $source (Join-Path $staging 'Assets')
}
$manifest=Get-Content "$PSScriptRoot/AppxManifest.xml.template" -Raw
$values=@{IDENTITY_NAME=$config.identityName;PUBLISHER=$config.publisher;PACKAGE_VERSION=$config.msixVersion;PUBLISHER_DISPLAY_NAME=$config.publisherDisplayName;MAX_TESTED_VERSION=$environment.WindowsSdk;RESOURCE_LANGUAGES='    <Resource Language="en-US" />'}
foreach ($key in $values.Keys) {
  $value=if ($key -eq 'RESOURCE_LANGUAGES') { $values[$key] } else { [Security.SecurityElement]::Escape([string]$values[$key]) }
  $manifest=$manifest.Replace("@@${key}@@",$value)
}
$manifest | Set-Content (Join-Path $staging 'AppxManifest.xml') -Encoding utf8NoBOM
Assert-BusyDataPackageHasNoProhibitedFiles -PackageRoot $staging
$inventory=Get-BusyDataPackageInventory $staging
$inventory | ConvertTo-Json -Depth 4 | Set-Content "$output/staging-inventory.json" -Encoding utf8NoBOM
$package=Join-Path $output "BusyData-$($config.msixVersion)-x64.msix"
$makeAppx=Join-Path $environment.WindowsSdkBin 'makeappx.exe'
& $makeAppx pack /v /d $staging /p $package /o
if ($LASTEXITCODE -ne 0) { throw 'MakeAppx validation/packing failed' }
$unpacked=Join-Path $output ('unpacked-'+[guid]::NewGuid())
& $makeAppx unpack /p $package /d $unpacked
if ($LASTEXITCODE -ne 0) { throw 'MakeAppx unpack failed' }
Expand-BusyDataMsixMetadata -PackagePath $package -PackageRoot $unpacked
Assert-BusyDataFinalMsixMetadata -PackageRoot $unpacked
$actual=Get-BusyDataPackageInventory $unpacked | Where-Object Path -notin @('AppxBlockMap.xml','[Content_Types].xml')
$difference=Compare-Object ($inventory | ForEach-Object { "$($_.Path)|$($_.Length)|$($_.SHA256)" }) ($actual | ForEach-Object { "$($_.Path)|$($_.Length)|$($_.SHA256)" })
if ($difference) { throw 'Exact MSIX differs from staging inventory' }
Get-FileHash $package -Algorithm SHA256
