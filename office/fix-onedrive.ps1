# fix-onedrive.ps1 - Reinicia OneDrive para forzar sync y auto-mount de bibliotecas
# Correr en la sesion del USUARIO afectado (no como SYSTEM).

Write-Host "== Fix OneDrive ==" -ForegroundColor Cyan

$od = "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
if (!(Test-Path $od)) { $od = "$env:PROGRAMFILES\Microsoft OneDrive\OneDrive.exe" }
if (!(Test-Path $od)) { $od = "${env:PROGRAMFILES(x86)}\Microsoft OneDrive\OneDrive.exe" }

Write-Host "Cerrando OneDrive..."
taskkill /f /im OneDrive.exe 2>$null
Start-Sleep -Seconds 3

Write-Host "Reiniciando OneDrive ($od)..."
if (Test-Path $od) {
    Start-Process $od
    Write-Host "OneDrive reiniciado. El auto-mount de bibliotecas puede tardar unos minutos." -ForegroundColor Green
} else {
    Write-Host "No se encontro OneDrive.exe" -ForegroundColor Red
}

# Mostrar cuenta y carpetas montadas
Write-Host "`nCuenta configurada:" -ForegroundColor Cyan
Get-ItemProperty "HKCU:\Software\Microsoft\OneDrive\Accounts\Business1" -ErrorAction SilentlyContinue | Select-Object UserEmail, ConfiguredTenantId

Write-Host "`nCarpetas de e-BuyPlace en el perfil:" -ForegroundColor Cyan
Get-ChildItem "$env:USERPROFILE" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*e-BuyPlace*" } | Select-Object Name
