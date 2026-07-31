<#
    fix-rustdesk-id.ps1
    Regenera el MachineGuid y limpia la config de RustDesk en equipos clonados
    para forzar un ID nuevo. Ejecutar como Administrador en cada equipo duplicado.
#>

# --- Verificar privilegios de administrador ---
$admin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $admin) {
    Write-Host "Este script debe ejecutarse como Administrador." -ForegroundColor Red
    exit 1
}

$regPath = "HKLM:\SOFTWARE\Microsoft\Cryptography"

# --- Mostrar MachineGuid actual ---
$oldGuid = (Get-ItemProperty -Path $regPath -Name MachineGuid).MachineGuid
Write-Host "MachineGuid actual: $oldGuid" -ForegroundColor Yellow

# --- Detener RustDesk ---
Write-Host "Deteniendo RustDesk..." -ForegroundColor Cyan
Stop-Service -Name RustDesk -ErrorAction SilentlyContinue
taskkill /IM rustdesk.exe /F 2>$null | Out-Null

# --- Regenerar MachineGuid ---
$newGuid = [guid]::NewGuid().ToString()
Set-ItemProperty -Path $regPath -Name MachineGuid -Value $newGuid
Write-Host "MachineGuid nuevo:  $newGuid" -ForegroundColor Green

# --- Borrar configuracion de RustDesk (perfil de servicio y usuario) ---
Write-Host "Borrando configuracion de RustDesk..." -ForegroundColor Cyan
Remove-Item -Recurse -Force `
    "C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk" `
    -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:AppData\RustDesk" -ErrorAction SilentlyContinue

# --- Reinicio ---
Write-Host ""
Write-Host "Listo. Se requiere reiniciar para aplicar los cambios." -ForegroundColor Green
$resp = Read-Host "Reiniciar ahora? (s/N)"
if ($resp -match '^[sS]$') {
    shutdown /r /t 0
} else {
    Write-Host "Reinicia manualmente cuando puedas. RustDesk tomara un ID nuevo al volver." -ForegroundColor Yellow
}
