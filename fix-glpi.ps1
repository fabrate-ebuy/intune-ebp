# fix-glpi.ps1 - Reconfigura el servidor del agente GLPI y lo rearranca
# Correr como ADMINISTRADOR. Ajustar $server a la URL real del GLPI.

$server = "http://TU-IP-GLPI/front/inventory.php"   # <-- AJUSTAR
$tag    = "migracion2026"

Write-Host "== Fix GLPI Agent ==" -ForegroundColor Cyan

$glpi = "C:\Program Files\GLPI-Agent\glpi-agent.exe"
if (!(Test-Path $glpi)) {
    Write-Host "GLPI Agent no esta instalado en la ruta esperada." -ForegroundColor Red
    return
}

Write-Host "Estado actual del servicio:"
Get-Service glpi-agent -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType

Write-Host "`nForzando inventario contra $server ..."
& $glpi --server $server --tag $tag --force --debug

Write-Host "`nAsegurando servicio en Automatico y arrancado..."
Set-Service glpi-agent -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service glpi-agent -ErrorAction SilentlyContinue

Get-Service glpi-agent -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType
Write-Host "Listo." -ForegroundColor Green
