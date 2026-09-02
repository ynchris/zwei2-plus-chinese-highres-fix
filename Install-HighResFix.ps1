param([string]$GamePath)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$OriginalHash = 'F132FE28EC24393C5FD885BEA593F481B8F5D502C3D68ECAEF9C3A1F3ABFB6B2'
$PatchedHash = 'C2668F2B546B8491C4AC32A5D2839CE2AD52F1506BB60A34F7BF8D982BA0C882'
$WrapperHash = 'AB6BF7A9A9F4B3E66A75CA038D8D10289C88ACBFE8D52C3B5A8A9A259CB26CD5'
$Targets = @('ZWEI2P.exe', 'ZWEI2PDX9.exe')
$PatchOffsets = @(0x68E78, 0x68E86)
$ExpectedBytes = [byte[]](0x00, 0x08, 0x00, 0x00)
$ReplacementBytes = [byte[]](0x00, 0x10, 0x00, 0x00)
$MarkerName = '.zwei2-highres-fix.json'

function Get-Hash([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Resolve-GamePath([string]$RequestedPath) {
    if ($RequestedPath) {
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }
    if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'ZWEI2PDX9.exe')) {
        return $PSScriptRoot
    }
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select the Zwei II game directory containing ZWEI2PDX9.exe'
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw 'Installation cancelled.'
    }
    return (Resolve-Path -LiteralPath $dialog.SelectedPath).Path
}

try {
    $GamePath = Resolve-GamePath $GamePath
    Write-Host "Game directory: $GamePath"

    $states = @()
    foreach ($name in $Targets) {
        $path = Join-Path $GamePath $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Missing required file: $path"
        }
        $hash = Get-Hash $path
        if ($hash -notin @($OriginalHash, $PatchedHash)) {
            throw "Unsupported $name (SHA-256 $hash). Apply the known Chinese patch first, or restore its original 2010 executable. No files were changed."
        }
        $states += [pscustomobject]@{ Name = $name; Path = $path; Hash = $hash }
    }

    $sourceWrapper = Join-Path $PSScriptRoot 'd3d8.dll'
    if ((Get-Hash $sourceWrapper) -ne $WrapperHash) {
        throw 'Bundled d3d8.dll failed integrity verification.'
    }
    $targetWrapper = Join-Path $GamePath 'd3d8.dll'
    $installWrapper = $false
    $wrapperWasInstalledByPackage = $false
    $existingMarkerPath = Join-Path $GamePath $MarkerName
    if (Test-Path -LiteralPath $existingMarkerPath) {
        $existingMarker = Get-Content -LiteralPath $existingMarkerPath -Raw | ConvertFrom-Json
        $wrapperWasInstalledByPackage = [bool]$existingMarker.installedD3d8
    }
    if (Test-Path -LiteralPath $targetWrapper) {
        $existingWrapperHash = Get-Hash $targetWrapper
        if ($existingWrapperHash -ne $WrapperHash) {
            throw "Another d3d8.dll already exists (SHA-256 $existingWrapperHash). Remove or configure that wrapper manually before installing. No files were changed."
        }
    } else {
        $installWrapper = $true
    }

    $patchedFiles = @()
    foreach ($state in $states) {
        if ($state.Hash -eq $PatchedHash) {
            Write-Host "$($state.Name): already patched."
            continue
        }
        $backup = "$($state.Path).highres-fix.backup"
        if (-not (Test-Path -LiteralPath $backup)) {
            Copy-Item -LiteralPath $state.Path -Destination $backup
        } elseif ((Get-Hash $backup) -ne $OriginalHash) {
            throw "Unsafe backup already exists: $backup"
        }

        $bytes = [IO.File]::ReadAllBytes($state.Path)
        foreach ($offset in $PatchOffsets) {
            for ($i = 0; $i -lt $ExpectedBytes.Length; $i++) {
                if ($bytes[$offset + $i] -ne $ExpectedBytes[$i]) {
                    throw ('Unexpected byte at file offset 0x{0:X}. Backup was preserved; target was not written.' -f ($offset + $i))
                }
            }
            [Array]::Copy($ReplacementBytes, 0, $bytes, $offset, $ReplacementBytes.Length)
        }
        [IO.File]::WriteAllBytes($state.Path, $bytes)
        if ((Get-Hash $state.Path) -ne $PatchedHash) {
            Copy-Item -LiteralPath $backup -Destination $state.Path -Force
            throw "$($state.Name) verification failed; the original was restored."
        }
        $patchedFiles += $state.Name
        Write-Host "$($state.Name): texture limit raised from 2048 to 4096."
    }

    if ($installWrapper) {
        Copy-Item -LiteralPath $sourceWrapper -Destination $targetWrapper
        if ((Get-Hash $targetWrapper) -ne $WrapperHash) {
            throw 'd3d8.dll verification failed after copying.'
        }
        Write-Host 'Installed d3d8to9 v1.15.1.'
        $wrapperWasInstalledByPackage = $true
    } else {
        Write-Host 'd3d8to9 v1.15.1 is already present.'
    }

    $marker = [ordered]@{
        version = 1
        installedUtc = [DateTime]::UtcNow.ToString('o')
        originalExeSha256 = $OriginalHash
        patchedExeSha256 = $PatchedHash
        installedD3d8 = $wrapperWasInstalledByPackage
        d3d8Sha256 = $WrapperHash
        patchedFiles = $patchedFiles
    }
    $marker | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $GamePath $MarkerName) -Encoding UTF8
    Write-Host 'Installation completed successfully.' -ForegroundColor Green
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
