<#
Backup-BitLockerToEntra.ps1
Sube el recovery key de BitLocker a Entra ID (Azure AD), SIN descifrar el disco.

Uso principal: equipos que YA estaban cifrados con BitLocker antes de la migracion.
Al pasarlos a Entra, el disco sigue cifrado tal cual, pero hay que asegurar que el
recovery key quede respaldado en Entra (Devices -> equipo -> BitLocker keys) por si
el usuario queda bloqueado.

Tambien sirve como verificacion/refuerzo en equipos cifrados por la politica de Intune.

NO descifra nada. Solo hace backup de la recovery password existente a Entra.
Correr como ADMINISTRADOR. Requiere que el equipo este Entra-joined.
#>

$ErrorActionPreference = "Stop"
Write-Host "== Backup de recovery key de BitLocker a Entra ==" -ForegroundColor Cyan

# Recorrer todos los volumenes con BitLocker
$volumenes = Get-BitLockerVolume | Where-Object { $_.VolumeStatus -ne "FullyDecrypted" }

if (-not $volumenes) {
    Write-Host "No hay volumenes cifrados con BitLocker en este equipo." -ForegroundColor Yellow
    exit 0
}

foreach ($vol in $volumenes) {
    $punto = $vol.MountPoint
    Write-Host "`nVolumen $punto - Estado: $($vol.VolumeStatus)" -ForegroundColor Gray

    # Buscar el protector de tipo RecoveryPassword
    $recovery = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }

    if (-not $recovery) {
        Write-Host "  $punto no tiene protector RecoveryPassword. Creando uno..." -ForegroundColor Yellow
        # Si no hay recovery password, crear uno (necesario para el backup)
        try {
            Add-BitLockerKeyProtector -MountPoint $punto -RecoveryPasswordProtector | Out-Null
            $vol = Get-BitLockerVolume -MountPoint $punto
            $recovery = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }
            Write-Host "  Recovery password creado." -ForegroundColor Green
        } catch {
            Write-Host "  No se pudo crear recovery password en $punto : $_" -ForegroundColor Red
            continue
        }
    }

    # Subir cada recovery password a Entra
    foreach ($rp in $recovery) {
        try {
            BackupToAAD-BitLockerKeyProtector -MountPoint $punto -KeyProtectorId $rp.KeyProtectorId
            Write-Host "  OK: recovery key de $punto subida a Entra (ProtectorId $($rp.KeyProtectorId))" -ForegroundColor Green
        } catch {
            Write-Host "  Fallo al subir a Entra ($punto): $_" -ForegroundColor Red
            Write-Host "  Verificar que el equipo este Entra-joined y con conexion." -ForegroundColor Yellow
        }
    }
}

Write-Host "`nListo. Verificar en Entra: Devices -> el equipo -> BitLocker keys." -ForegroundColor Cyan
