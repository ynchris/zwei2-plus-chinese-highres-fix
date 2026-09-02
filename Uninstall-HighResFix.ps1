param([string]$GamePath)

# Author: ynchris（汉化老兵）

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$OriginalHash = 'F132FE28EC24393C5FD885BEA593F481B8F5D502C3D68ECAEF9C3A1F3ABFB6B2'
$PatchedHash = 'C2668F2B546B8491C4AC32A5D2839CE2AD52F1506BB60A34F7BF8D982BA0C882'
$WrapperHash = 'AB6BF7A9A9F4B3E66A75CA038D8D10289C88ACBFE8D52C3B5A8A9A259CB26CD5'
$Targets = @('ZWEI2P.exe', 'ZWEI2PDX9.exe')
$MarkerName = '.zwei2-highres-fix.json'

function Get-Hash([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Resolve-GamePath([string]$RequestedPath) {
    if ($RequestedPath) { return (Resolve-Path -LiteralPath $RequestedPath).Path }
    if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'ZWEI2PDX9.exe')) { return $PSScriptRoot }
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select the Zwei II game directory containing ZWEI2PDX9.exe'
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { throw 'Uninstall cancelled.' }
    return (Resolve-Path -LiteralPath $dialog.SelectedPath).Path
}

try {
    $GamePath = Resolve-GamePath $GamePath
    $markerPath = Join-Path $GamePath $MarkerName
    $marker = $null
    if (Test-Path -LiteralPath $markerPath) {
        $marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
    }

    foreach ($name in $Targets) {
        $path = Join-Path $GamePath $name
        $backup = "$path.highres-fix.backup"
        if (-not (Test-Path -LiteralPath $backup)) {
            Write-Host "${name}: no installer backup found; skipped."
            continue
        }
        if ((Get-Hash $backup) -ne $OriginalHash) {
            throw "Backup integrity check failed: $backup"
        }
        $currentHash = Get-Hash $path
        if ($currentHash -ne $PatchedHash) {
            throw "Current $name is not the known patched file; refusing to overwrite it."
        }
        Copy-Item -LiteralPath $backup -Destination $path -Force
        if ((Get-Hash $path) -ne $OriginalHash) { throw "$name restore verification failed." }
        Write-Host "${name}: original restored."
    }

    if ($null -ne $marker -and $marker.installedD3d8) {
        $wrapper = Join-Path $GamePath 'd3d8.dll'
        if ((Test-Path -LiteralPath $wrapper) -and (Get-Hash $wrapper) -eq $WrapperHash) {
            Remove-Item -LiteralPath $wrapper
            Write-Host 'Removed d3d8to9 installed by this package.'
        }
    }
    if (Test-Path -LiteralPath $markerPath) { Remove-Item -LiteralPath $markerPath }
    Write-Host 'Uninstall completed successfully.' -ForegroundColor Green
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
