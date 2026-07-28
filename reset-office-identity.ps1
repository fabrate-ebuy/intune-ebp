<#
reset-office-identity.ps1
Limpia el cache de identidad de Office cuando da el error de activacion
"Otra cuenta de su organizacion ya ha iniciado sesion en este dispositivo"
o cuando Office no activa pese a que el usuario TIENE licencia (verificado que
la licencia esta OK en Entra, ej. SPB con OFFICE_BUSINESS = Success).

Causa tipica: perfiles migrados con ProfWiz arrastran el cache de identidad viejo
de Office, o quedo una identidad de una instalacion previa (Office LTSC, otra cuenta).

IMPORTANTE: correr EN CONTEXTO DE USUARIO (no admin con otras credenciales), porque
limpia el HKCU del usuario. En la sesion del usuario, PowerShell NORMAL.

Despues de correrlo, el usuario debe abrir Word/Excel -> Archivo -> Cuenta ->
Iniciar sesion, con SU cuenta (+ MFA). Eso reactiva Office. El login es manual,
no se puede automatizar.

Es idempotente y seguro (solo borra cache de identidad, no datos ni documentos).
#>

Write-Host "== Reset de identidad de Office ==" -ForegroundColor Cyan
Write-Host "Usuario actual: $(whoami)" -ForegroundColor Gray

# 1. Cerrar todas las apps de Office
Write-Host "Cerrando apps de Office..."
Get-Process WINWORD,EXCEL,OUTLOOK,POWERPNT,ONENOTE,MSACCESS,MSPUB,lync -EA SilentlyContinue | Stop-Process -Force

# 2. Limpiar el cache de identidades de Office (16.0 = Office 2016/2019/2021/365)
Write-Host "Limpiando cache de identidad de Office..."
Remove-Item "HKCU:\Software\Microsoft\Office\16.0\Common\Identity\Identities\*" -Recurse -Force -EA SilentlyContinue
Remove-Item "HKCU:\Software\Microsoft\Office\16.0\Common\Identity\Profiles\*"   -Recurse -Force -EA SilentlyContinue

# 3. Limpiar credenciales genericas de Office/SSO en el Administrador de credenciales
Write-Host "Limpiando credenciales de Office/SSO..."
$targets = cmdkey /list | Select-String "Destino:" | ForEach-Object { ($_ -split "Destino:")[1].Trim() }
foreach ($t in $targets) {
    if ($t -match "MicrosoftOffice16|SSO_POP_Device|virtualapp/didlogical|MSOnline|office365") {
        cmdkey /delete:$t | Out-Null
        Write-Host "  Quitada credencial: $t" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Listo. Ahora el usuario debe:" -ForegroundColor Green
Write-Host "  1. Abrir Word o Excel" -ForegroundColor Green
Write-Host "  2. Archivo -> Cuenta -> Iniciar sesion" -ForegroundColor Green
Write-Host "  3. Ingresar SU cuenta @e-buyplace.com + MFA" -ForegroundColor Green
Write-Host "Office deberia activar con la licencia del usuario." -ForegroundColor Green
