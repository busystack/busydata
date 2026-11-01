$ErrorActionPreference='Stop'
function Invoke-VerificationStage {
  param([string]$Name, [string[]]$Command, [string[]]$Reports=@(), [string[]]$Artifacts=@())
  $evidenceArguments=@('tool/verification_evidence.py','run','--stage',$Name)
  foreach ($report in $Reports) { $evidenceArguments+=@('--reports',$report) }
  foreach ($artifact in $Artifacts) { $evidenceArguments+=@('--artifact',$artifact) }
  $evidenceArguments+=@('--')+$Command
  & python @evidenceArguments
  if ($LASTEXITCODE -ne 0) { throw "Verification failed: $Name; current-run evidence retained" }
}
$previousPubCache=$env:PUB_CACHE
$previousTemporaryDirectory=$env:TMPDIR
$sourceRoot=Split-Path (Split-Path $PSScriptRoot)
$env:PUB_CACHE=Join-Path $sourceRoot 'build/official-dependencies/pub-cache'
$env:TMPDIR=Join-Path $sourceRoot 'build/t'
New-Item -ItemType Directory -Force -Path $env:PUB_CACHE,$env:TMPDIR | Out-Null
try {
  & python tool/verification_evidence.py start
  if ($LASTEXITCODE -ne 0) { throw 'Evidence initialization failed' }
  Invoke-VerificationStage 'windows-prerequisites' @('pwsh','-NoProfile','-File',"$PSScriptRoot/check_prerequisites.ps1")
  $flutterPath=(Get-Command flutter).Source
  $dartPath=Join-Path (Split-Path $flutterPath) 'cache/dart-sdk/bin/dart.exe'
  Invoke-VerificationStage 'configuration' @('python','tool/check_toolchain.py')
  Invoke-VerificationStage 'toolchain' @($dartPath,'tool/verify_flutter_sdk.dart','--flutter',$flutterPath,'--dart',$dartPath,'--toolchain','config/toolchain.json')
  Invoke-VerificationStage 'flutter-dependencies' @('flutter','pub','get','--enforce-lockfile')
  Invoke-VerificationStage 'official-dependencies' @('python','tool/verify_official_dependencies.py') @() @('build/official-dependencies/verification.json')
  Invoke-VerificationStage 'localizations' @('flutter','gen-l10n')
  Invoke-VerificationStage 'java' @('backend/mvnw.cmd','-f','backend/pom.xml','verify') @('backend/target/surefire-reports') @('backend/target/bom.json')
  Invoke-VerificationStage 'protocol' @('python','tool/generate_protocol.py')
  Invoke-VerificationStage 'format' @('dart','format','--output=none','--set-exit-if-changed','lib','test','tool','integration_test')
  Invoke-VerificationStage 'analyze' @('flutter','analyze')
  Invoke-VerificationStage 'boundaries' @('dart','run','tool/check_platform_boundaries.dart')
  Invoke-VerificationStage 'flutter-tests' @('flutter','test','--machine')
  Invoke-VerificationStage 'runtime' @('python','tool/bundle_backend.py') @() @('backend/target/bundle/runtime-check.json')
  Invoke-VerificationStage 'sources' @('python','tool/prepare_sources.py')
  Invoke-VerificationStage 'inventory' @('python','tool/dependency_inventory.py')
  $backendBundle=(Resolve-Path 'backend/target/bundle').Path
  Invoke-VerificationStage 'lifecycle' @('dart',"--define=BUSYDATA_BACKEND_DIR=$backendBundle",'run','tool/verify_backend_lifecycle.dart')
  Invoke-VerificationStage 'windows-release' @('python','tool/build_windows_release.py') @() @('build/windows-release-build.json')
  Invoke-VerificationStage 'windows-native-build' @('cmake','--build','build/windows/x64','--config','Release','--target','busydata_runner_native_test')
  Invoke-VerificationStage 'windows-native' @('ctest','--test-dir','build/windows/x64/runner','-C','Release','--output-on-failure')
  & python tool/record_verification.py --required windows-prerequisites configuration toolchain flutter-dependencies official-dependencies localizations java protocol format analyze boundaries flutter-tests runtime sources inventory lifecycle windows-release windows-native-build windows-native
  if ($LASTEXITCODE -ne 0) { throw 'Windows verification evidence is incomplete or invalid' }
} finally {
  $env:PUB_CACHE=$previousPubCache
  $env:TMPDIR=$previousTemporaryDirectory
}
