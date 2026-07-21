# fix-glpi.ps1 - Configura el servidor/tag del agente GLPI y lo rearranca
# Correr como ADMINISTRADOR (escribe en Program Files y reinicia servicio).
# Ajustar $server a la URL real del GLPI.

$server = "http://10.20.20.234/glpi"   # <-- AJUSTAR
$tag    = "migracion2026"

$base = "C:\Program Files\GLPI-Agent"
$bat  = Join-Path $base "glpi-agent.bat"
$cfg  = Join-Path $base "etc\agent.cfg"

Write-Host "== Fix GLPI Agent ==" -ForegroundColor Cyan

# 1. Verificar instalacion (por el .bat, que es lo que realmente usamos)
if (!(Test-Path $bat)) {
    Write-Host "GLPI Agent no esta instalado (no se encontro glpi-agent.bat)." -ForegroundColor Red
    return
}
if (!(Test-Path $cfg)) {
    Write-Host "No se encontro agent.cfg en $cfg" -ForegroundColor Red
    return
}

Write-Host "Estado actual del servicio:"
Get-Service glpi-agent -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType

# 2. Escribir server + tag en agent.cfg de forma idempotente
#    (borra TODAS las lineas server=/tag= existentes -incluidos ejemplos- y agrega una de cada)
Write-Host "`nConfigurando agent.cfg (server=$server, tag=$tag) ..."
$lines = Get-Content $cfg | Where-Object { $_ -notmatch '^\s*server\s*=' -and $_ -notmatch '^\s*tag\s*=' }
$lines += "server = $server"
$lines += "tag = $tag"
$lines | Set-Content $cfg -Encoding ascii

# Verificar que quedo UNA sola linea de cada
$srvCount = (Get-Content $cfg | Select-String '^\s*server\s*=').Count
$tagCount = (Get-Content $cfg | Select-String '^\s*tag\s*=').Count
Write-Host ("  lineas server: {0} | tag: {1}" -f $srvCount, $tagCount)
if ($srvCount -ne 1) { Write-Host "  ADVERTENCIA: se esperaba 1 linea server" -ForegroundColor Yellow }

# 3. Asegurar servicio Automatico y arrancado, y reiniciar para tomar el cfg
Write-Host "`nAsegurando servicio Automatico y reiniciando..."
Set-Service   glpi-agent -StartupType Automatic -ErrorAction SilentlyContinue
Restart-Service glpi-agent -ErrorAction SilentlyContinue

# 4. Forzar inventario ahora (via .bat; el .exe pelado NO acepta estos flags)
#    Con el server ya en el cfg, --force alcanza. Se pasa --server por robustez.
Write-Host "`nForzando inventario contra $server ..."
& $bat --force --server=$server 2>&1 |
    Where-Object { $_ -notmatch 'uninitialized value' -and $_ -notmatch 'Firewall\.pm' }
    # los warnings de Firewall.pm son cosmeticos (bug conocido del agente en Windows)

Write-Host "`nEstado final del servicio:"
Get-Service glpi-agent -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType
Write-Host "Listo. Verificar que el activo aparezca en GLPI." -ForegroundColor Green
