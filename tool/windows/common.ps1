Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-BusyDataStoreConfig {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Windows Store configuration does not exist: $Path"
  }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-BusyDataWindowsSdkDirectory {
  param(
    [Parameter(Mandatory)][string]$KitsBin,
    [version]$MinimumVersion = [version]'10.0.26100.0'
  )
  return Get-ChildItem -LiteralPath $KitsBin -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
    Where-Object { [version]$_.Name -ge $MinimumVersion } |
    Sort-Object { [version]$_.Name } -Descending |
    Select-Object -First 1
}

function Test-BusyDataWindows11ValidationHost {
  param(
    [Parameter(Mandatory)][int]$Build,
    [Parameter(Mandatory)][uint32]$ProductType
  )
  return $ProductType -eq 1 -and $Build -ge 26100
}

function Assert-BusyDataWindows11ValidationHost {
  param(
    [Parameter(Mandatory)][int]$Build,
    [Parameter(Mandatory)][uint32]$ProductType
  )
  if ($ProductType -ne 1) {
    throw "Installed-package and WACK validation require a Windows 11 workstation (Win32_OperatingSystem.ProductType 1); found ProductType $ProductType."
  }
  if ($Build -lt 26100) {
    throw "Installed-package and WACK validation require Windows 11 24H2/build 26100 or newer; found build $Build."
  }
}

function Get-BusyDataPackageFiles {
  param([Parameter(Mandatory)][string]$PackageRoot)
  if (-not (Test-Path -LiteralPath $PackageRoot -PathType Container)) {
    throw "Package root does not exist: $PackageRoot"
  }
  return @(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File -Force)
}

function Get-BusyDataPackageRelativePath {
  param(
    [Parameter(Mandatory)][string]$PackageRoot,
    [Parameter(Mandatory)][string]$Path
  )
  return [IO.Path]::GetRelativePath($PackageRoot, $Path).Replace('\', '/')
}

function Test-BusyDataProhibitedPackageFile {
  param(
    [Parameter(Mandatory)][string]$PackageRoot,
    [Parameter(Mandatory)][IO.FileInfo]$File
  )
  $relative = Get-BusyDataPackageRelativePath -PackageRoot $PackageRoot `
    -Path $File.FullName
  if ($relative -match '^(backend/(runtime/legal|notices)/|third_party/|LICENSE)') { return $false }
  return $File.Extension -in @(
    '.pfx', '.cer', '.log', '.db', '.sqlite', '.dart', '.cc', '.h', '.pdb',
    '.cpp', '.c', '.hpp', '.cmake', '.ps1', '.jsonl', '.yaml', '.yml',
    '.md', '.p12', '.pem', '.key', '.crt', '.p7x', '.snap', '.AppImage'
  ) -or
    ($File.Extension -eq '.so' -and $relative -cne 'data/app.so') -or
    $File.Name -match '(?i)(^|[._-])(test|fake|credential|secret|token|development)([._-]|$)|flutter_logo' -or
    $relative -match '(?i)(^|/)(linux|snap|snapcraft)(/|$)'
}

function Assert-BusyDataPackageHasNoProhibitedFiles {
  param([Parameter(Mandatory)][string]$PackageRoot)
  $prohibited = @(Get-BusyDataPackageFiles -PackageRoot $PackageRoot |
    Where-Object {
      Test-BusyDataProhibitedPackageFile -PackageRoot $PackageRoot -File $_
    })
  if ($prohibited.Count -gt 0) {
    throw "Prohibited package content: $($prohibited.FullName -join ', ')"
  }
}

function Assert-BusyDataFinalMsixMetadata {
  param([Parameter(Mandatory)][string]$PackageRoot)
  foreach ($metadataFile in @('AppxBlockMap.xml', '[Content_Types].xml')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PackageRoot $metadataFile) `
        -PathType Leaf)) {
      throw "Final MSIX metadata is missing: $metadataFile"
    }
  }
}

function Expand-BusyDataMsixMetadata {
  param(
    [Parameter(Mandatory)][string]$PackagePath,
    [Parameter(Mandatory)][string]$PackageRoot
  )
  if (-not (Test-Path -LiteralPath $PackagePath -PathType Leaf)) {
    throw "MSIX package does not exist: $PackagePath"
  }
  if (-not (Test-Path -LiteralPath $PackageRoot -PathType Container)) {
    throw "Unpacked MSIX directory does not exist: $PackageRoot"
  }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [IO.Compression.ZipFile]::OpenRead(
    (Resolve-Path -LiteralPath $PackagePath).Path)
  try {
    foreach ($metadataFile in @('AppxBlockMap.xml', '[Content_Types].xml')) {
      $entries = @($archive.Entries | Where-Object {
          $_.FullName -ceq $metadataFile
        })
      if ($entries.Count -ne 1) {
        throw "Exact MSIX archive must contain one $metadataFile entry; found $($entries.Count)."
      }
      $destination = Join-Path $PackageRoot $metadataFile
      $inputStream = $entries[0].Open()
      try {
        $outputStream = [IO.File]::Open(
          $destination, [IO.FileMode]::Create, [IO.FileAccess]::Write,
          [IO.FileShare]::None)
        try {
          $inputStream.CopyTo($outputStream)
        } finally {
          $outputStream.Dispose()
        }
      } finally {
        $inputStream.Dispose()
      }
    }
  } finally {
    $archive.Dispose()
  }
}

function Get-BusyDataPackageInventory {
  param([Parameter(Mandatory)][string]$PackageRoot)
  return @(Get-BusyDataPackageFiles -PackageRoot $PackageRoot |
    Sort-Object FullName |
    ForEach-Object {
      [pscustomobject]@{
        Path = Get-BusyDataPackageRelativePath -PackageRoot $PackageRoot `
          -Path $_.FullName
        Length = $_.Length
        SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
      }
    })
}

function Test-BusyDataPlaceholder {
  param([AllowNull()][string]$Value)
  return [string]::IsNullOrWhiteSpace($Value) -or
    $Value -match '(?i)(replace_with|placeholder|your[-_]|example\.com|todo)'
}

function Assert-BusyDataMsixVersion {
  param(
    [Parameter(Mandatory)][string]$Version,
    [string]$PreviousVersion = ''
  )
  if ($Version -notmatch '^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$') {
    throw 'BUSYDATA_MSIX_VERSION must have exactly four numeric components.'
  }
  $parts = @($Matches[1], $Matches[2], $Matches[3], $Matches[4]) |
    ForEach-Object { [uint64]$_ }
  if ($parts[0] -lt 1) { throw 'The first MSIX version component must be at least 1.' }
  if ($parts[3] -ne 0) { throw 'The fourth MSIX version component is reserved and must be 0.' }
  if ($parts | Where-Object { $_ -gt 65535 }) {
    throw 'Each MSIX version component must be no greater than 65535.'
  }
  if (-not [string]::IsNullOrWhiteSpace($PreviousVersion)) {
    Assert-BusyDataMsixVersion -Version $PreviousVersion
    if ([version]$Version -le [version]$PreviousVersion) {
      throw "MSIX version $Version must be greater than $PreviousVersion."
    }
  }
}

function Assert-BusyDataHttpsUrl {
  param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Value)
  $uri = $null
  if (-not [uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -or
      $uri.Scheme -ne 'https' -or [string]::IsNullOrWhiteSpace($uri.Host)) {
    throw "$Name must be a valid HTTPS URL."
  }
}

function Assert-BusyDataCertificatePublisher {
  param(
    [Parameter(Mandatory)][string]$CertificateSubject,
    [Parameter(Mandatory)][string]$ManifestPublisher
  )
  if ($CertificateSubject -cne $ManifestPublisher) {
    throw "Certificate subject '$CertificateSubject' does not exactly match AppxManifest Publisher '$ManifestPublisher' in LocalTestSigning mode."
  }
}

function Get-BusyDataPackageFamilyName {
  param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Publisher)
  if (-not ('BusyData.PackageIdentity' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
namespace BusyData {
  public static class PackageIdentity {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct PACKAGE_ID {
      public uint reserved;
      public uint processorArchitecture;
      public ulong version;
      [MarshalAs(UnmanagedType.LPWStr)] public string name;
      [MarshalAs(UnmanagedType.LPWStr)] public string publisher;
      [MarshalAs(UnmanagedType.LPWStr)] public string resourceId;
      [MarshalAs(UnmanagedType.LPWStr)] public string publisherId;
    }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern int PackageFamilyNameFromId(
      ref PACKAGE_ID packageId, ref uint packageFamilyNameLength,
      StringBuilder packageFamilyName);
    public static string FamilyName(string name, string publisher) {
      var id = new PACKAGE_ID { name = name, publisher = publisher };
      // PACKAGE_FAMILY_NAME_MAX_LENGTH is 64 characters, excluding the
      // terminating null. A fixed buffer avoids a nullable output pointer in
      // managed interop and follows Microsoft's documented C# example.
      uint length = 65;
      var value = new StringBuilder((int)length);
      int result = PackageFamilyNameFromId(ref id, ref length, value);
      if (result != 0) throw new Win32Exception(result,
        "PackageFamilyNameFromId failed");
      var familyName = value.ToString();
      if (String.IsNullOrWhiteSpace(familyName)) throw new InvalidOperationException(
        "PackageFamilyNameFromId returned an empty package family name");
      return familyName;
    }
  }
}
'@
  }
  return [BusyData.PackageIdentity]::FamilyName($Name, $Publisher)
}

function Get-BusyDataResourceLanguages {
  $locales = Get-ChildItem -LiteralPath 'lib/l10n' -Filter 'app_*.arb' |
    ForEach-Object {
      $json = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
      $translationKeys = @($json.PSObject.Properties.Name |
        Where-Object { -not $_.StartsWith('@') })
      # Flutter requires an empty generic `pt` catalog to generate pt-PT, but
      # BusyData does not expose generic Portuguese as a supported locale.
      if ($translationKeys.Count -gt 0) {
        $locale = ([string]$json.'@@locale').Replace('_', '-')
        if ($locale -notmatch '^[A-Za-z]{2,3}(?:-[A-Za-z]{4})?(?:-[A-Za-z]{2}|-[0-9]{3})?$') {
          throw "ARB locale is not a valid BCP-47 language tag: $locale"
        }
        try {
          [Globalization.CultureInfo]::GetCultureInfo($locale) | Out-Null
        } catch {
          throw "ARB locale is not recognized as a BCP-47 language tag: $locale"
        }
        $locale
      }
    } | Sort-Object -Unique
  if (-not $locales) { throw 'No BusyData ARB locales were found.' }
  return @($locales)
}

function Get-BusyDataResourceXml {
  return (Get-BusyDataResourceLanguages | ForEach-Object {
      "    <Resource Language=`"$_`" />"
    }) -join "`r`n"
}

function Get-BusyDataVCRuntimeDirectory {
  param([Parameter(Mandatory)][string]$RedistRoot)
  $rankedDirectories = @(Get-ChildItem -LiteralPath $RedistRoot -Directory |
    ForEach-Object {
      $directory = $_
      try {
        [pscustomobject]@{
          Directory = $directory
          IsNumericVersion = 1
          Version = [version]$directory.Name
        }
      } catch {
        # Recent Visual Studio layouts can include aliases such as `v145`
        # beside numeric redistributable versions. Keep them as a fallback.
        [pscustomobject]@{
          Directory = $directory
          IsNumericVersion = 0
          Version = [version]'0.0'
        }
      }
    } | Sort-Object -Property `
      @{ Expression = 'IsNumericVersion'; Descending = $true }, `
      @{ Expression = 'Version'; Descending = $true }, `
      @{ Expression = { $_.Directory.Name }; Descending = $true })
  foreach ($entry in $rankedDirectories) {
    $candidate = Get-ChildItem -LiteralPath `
      (Join-Path $entry.Directory.FullName 'x64') -Directory `
      -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue |
      Sort-Object Name -Descending | Select-Object -First 1
    if ($null -ne $candidate) { return $candidate }
  }
  return $null
}

function Copy-BusyDataVCRuntime {
  param(
    [Parameter(Mandatory)][string]$VisualStudioPath,
    [Parameter(Mandatory)][string]$Destination
  )
  $redistRoot = Join-Path $VisualStudioPath 'VC\Redist\MSVC'
  $crt = Get-BusyDataVCRuntimeDirectory -RedistRoot $redistRoot
  if ($null -eq $crt) {
    throw 'The Visual Studio x64 VC runtime redistributable was not found.'
  }
  $runtimeNames = @(
    'concrt140.dll', 'msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll',
    'msvcp140_atomic_wait.dll', 'msvcp140_codecvt_ids.dll', 'vccorlib140.dll',
    'vcruntime140.dll', 'vcruntime140_1.dll', 'vcruntime140_threads.dll'
  )
  foreach ($name in $runtimeNames) {
    $source = Join-Path $crt.FullName $name
    if (Test-Path -LiteralPath $source) {
      Copy-Item -LiteralPath $source -Destination $Destination
    }
  }
  foreach ($required in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    if (-not (Test-Path -LiteralPath (Join-Path $Destination $required))) {
      throw "Required Visual C++ runtime file was not staged: $required"
    }
  }
}
