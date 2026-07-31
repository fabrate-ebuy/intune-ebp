<#
reset-teams-EBP.ps1
Limpia la cache de Teams (classic y nuevo) para equipos migrados con ProfWiz que
arrastran identidad vieja. Sintomas que evita/resuelve: Teams pide login en loop,
toma la cuenta equivocada, o no arranca despues de la migracion.

Correr en CONTEXTO DE USUARIO (PowerShell NORMAL en la sesion del usuario, NO admin
con otras credenciales), porque limpia el perfil del usuario.

Despues, el usuario abre Teams e inicia sesion con su cuenta. No borra chats ni
archivos (eso vive en la nube); solo borra la cache local.
#>

Write-Host "== Reset de cache de Teams ==" -ForegroundColor Cyan
Write-Host "Usuario: $(whoami)" -ForegroundColor Gray

# 1. Cerrar Teams (classic y nuevo)
Write-Host "Cerrando Teams..."
Get-Process Teams,ms-teams -EA SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# 2. Limpiar cache de Teams CLASSIC (si existe)
$teamsClassic = "$env:APPDATA\Microsoft\Teams"
if (Test-Path $teamsClassic) {
    Write-Host "Limpiando cache de Teams classic..."
    # Borrar solo las carpetas de cache, no la config critica
    $cachesClassic = @("Cache","blob_storage","databases","GPUCache","IndexedDB","Local Storage","tmp","Application Cache","Code Cache")
    foreach ($c in $cachesClassic) {
        Remove-Item "$teamsClassic\$c" -Recurse -Force -EA SilentlyContinue
    }
}

# 3. Limpiar cache de Teams NUEVO (MSIX/appx)
$teamsNew = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache"
if (Test-Path $teamsNew) {
    Write-Host "Limpiando cache de Teams nuevo..."
    Remove-Item "$teamsNew\*" -Recurse -Force -EA SilentlyContinue
}

Write-Host ""
Write-Host "Listo. El usuario debe abrir Teams e iniciar sesion con su cuenta." -ForegroundColor Green
Write-Host "Los chats y archivos estan en la nube; solo se limpio la cache local." -ForegroundColor Green
