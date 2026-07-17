# reset-ime.ps1 - Resetea la cache de la Intune Management Extension
# Correr como ADMINISTRADOR. Fuerza re-descarga y re-evaluacion de apps Win32.
# NOTA: no se puede correr desde Intune (detiene el servicio que ejecuta Intune).

Write-Host "== Reset IME ==" -ForegroundColor Cyan

Write-Host "Deteniendo servicio IME..."
Stop-Service -Name IntuneManagementExtension -Force -ErrorAction SilentlyContinue

Write-Host "Limpiando cache de contenido Win32..."
Remove-Item -Path "C:\Program Files (x86)\Microsoft Intune Management Extension\Content\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Limpiando estado Win32Apps (GRS)..."
Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Reiniciando servicio IME..."
Start-Service -Name IntuneManagementExtension

Write-Host "Listo. Forza un sync desde Configuracion > Acceso a trabajo, y espera unos minutos." -ForegroundColor Green
