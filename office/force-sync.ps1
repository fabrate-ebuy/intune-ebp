# force-sync.ps1 - Fuerza la sincronizacion de Intune (politicas MDM + apps/scripts IME)
# Correr como ADMINISTRADOR.

Write-Host "== Force Sync Intune ==" -ForegroundColor Cyan

# 1) Disparar el sync MDM via la tarea programada PushLaunch
Write-Host "Disparando sync MDM (PushLaunch)..."
Get-ScheduledTask -TaskPath "\Microsoft\Windows\EnterpriseMgmt\*" -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskName -eq "PushLaunch" } |
    Start-ScheduledTask -ErrorAction SilentlyContinue

# 2) Reiniciar el servicio IME para forzar re-evaluacion de scripts/apps Win32
Write-Host "Reiniciando IME para re-evaluar apps y scripts..."
Restart-Service -Name IntuneManagementExtension -Force -ErrorAction SilentlyContinue

# 3) Mostrar estado del registro del dispositivo
Write-Host "`nEstado del dispositivo (dsregcmd):" -ForegroundColor Cyan
dsregcmd /status | Select-String "AzureAdJoined","AzureAdPrt ","TenantName"

Write-Host "`nSync disparado. Puede tardar unos minutos en reflejar cambios." -ForegroundColor Green
