# reset-ime-cache.ps1 - Reset AGRESIVO de la cache de Intune Management Extension.
# Correr como ADMINISTRADOR.
#
# CUANDO USAR ESTE (y no force-sync):
# - Una app Win32 NO se reinstala aunque borraste lo que instalaba (la IME "cree"
#   que sigue instalada por su estado cacheado).
# - Apps atascadas en "Error" o que no re-evaluan la deteccion.
# - Corrupcion de GRS (Global Retry Schedule).
#
# Para un sync normal (refrescar politicas/apps) usar force-sync.ps1, que es mas suave.
# Este BORRA el estado cacheado -> la IME re-evalua y re-descarga todo desde cero.

Write-Host "== Reset de cache de IME (agresivo) ==" -ForegroundColor Cyan
Write-Host "Usar solo si una app no reinstala o quedo atascada. Para sync normal, force-sync." -ForegroundColor Yellow

# 1) Parar el servicio IME
Write-Host "`nDeteniendo IntuneManagementExtension..."
Stop-Service -Name IntuneManagementExtension -Force -ErrorAction SilentlyContinue

# 2) Borrar el contenido descargado (paquetes .intunewin cacheados)
Write-Host "Borrando Content cacheado..."
Remove-Item "C:\Program Files (x86)\Microsoft Intune Management Extension\Content\*" -Recurse -Force -ErrorAction SilentlyContinue

# 3) Borrar el estado de apps Win32 en el registro (fuerza re-evaluacion de deteccion)
Write-Host "Borrando estado de Win32Apps en el registro..."
Remove-Item "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps\*" -Recurse -Force -ErrorAction SilentlyContinue

# 4) Reiniciar el servicio -> re-evalua y re-descarga todo
Write-Host "Reiniciando IntuneManagementExtension..."
Start-Service -Name IntuneManagementExtension -ErrorAction SilentlyContinue

# 5) Disparar tambien el sync MDM por las dudas
Get-ScheduledTask -TaskPath "\Microsoft\Windows\EnterpriseMgmt\*" -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskName -eq "PushLaunch" } |
    Start-ScheduledTask -ErrorAction SilentlyContinue

Write-Host "`nCache reseteada. La IME va a re-evaluar y re-descargar apps/scripts." -ForegroundColor Green
Write-Host "Puede tardar varios minutos. Verificar luego que la app haya reinstalado." -ForegroundColor Green
