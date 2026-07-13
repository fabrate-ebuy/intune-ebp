# ============================================================
# BitlockerPIN.ps1
# Agrega protector TPM+PIN a un volumen ya cifrado por politica Intune (TPM-only)
# Uso: abrir PowerShell COMO ADMINISTRADOR y ejecutar:
#      powershell.exe -ExecutionPolicy Bypass -File C:\ProgramData\EBP\BitlockerPIN.ps1
# Requiere: volumen C: en estado FullyEncrypted
# ============================================================

$vol = Get-BitLockerVolume -MountPoint "C:"

# Validacion: el disco tiene que estar completamente cifrado
if ($vol.VolumeStatus -ne 'FullyEncrypted') {
    Write-Host "El volumen no esta completamente cifrado (estado actual: $($vol.VolumeStatus))." -ForegroundColor Yellow
    Write-Host "Espera a que la politica de Intune termine de cifrar antes de agregar el PIN." -ForegroundColor Yellow
    exit 1
}

# Validacion: idempotente - si ya tiene TPM+PIN, no hace nada
if ($vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'TpmPin' }) {
    Write-Host "El volumen ya tiene protector TPM+PIN configurado. Nada que hacer." -ForegroundColor Green
    exit 0
}

# Pedir PIN al usuario (minimo 8 digitos segun politica)
Write-Host ""
Write-Host "Vas a configurar el PIN de arranque de BitLocker (minimo 8 digitos)." -ForegroundColor Cyan
$pin = Read-Host -AsSecureString "Ingresa el PIN"

# Agregar protector TPM+PIN
try {
    Add-BitLockerKeyProtector -MountPoint "C:" -TpmAndPinProtector -Pin $pin -ErrorAction Stop
    Write-Host "Protector TPM+PIN agregado correctamente." -ForegroundColor Green
} catch {
    Write-Host "ERROR al agregar TPM+PIN: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Mostrar protectores finales
Write-Host ""
Write-Host "Protectores actuales del volumen C:" -ForegroundColor Cyan
(Get-BitLockerVolume -MountPoint "C:").KeyProtector | Format-Table KeyProtectorType, KeyProtectorId -AutoSize

Write-Host ""
Write-Host "Listo. En el proximo reinicio el equipo pedira el PIN antes de arrancar Windows." -ForegroundColor Green
exit 0
