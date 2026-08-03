<#
Reinstall-Office-EBP.ps1
Reinstala Microsoft 365 Apps LIMPIO usando el Office Deployment Tool (ODT).
Para equipos donde Office quedo en estado corrupto (grace, no activa, o Intune da
"error de instalacion del agente" al reinstalar).

Hace todo automatico:
  1. Descarga el ODT oficial de Microsoft.
  2. Desinstala TODAS las versiones de Office (limpia restos).
  3. Instala M365 Apps con la config de E-BUYPLACE (canal empresa, es-es + en-us, 64 bits).

Correr como ADMINISTRADOR. NO necesita al usuario presente (la instalacion es a nivel
maquina). La ACTIVACION la hace el usuario despues: abre Word -> Cuenta -> Iniciar
sesion con su cuenta + MFA.

Requiere los XML remove-office.xml e install-office.xml en la misma carpeta que este script.
#>

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$work = "C:\ODT-EBP"

Write-Host "== Reinstalacion limpia de Office (ODT) ==" -ForegroundColor Cyan

# ---- 0. Preparar carpeta de trabajo ----
New-Item -ItemType Directory -Path $work -Force | Out-Null
Copy-Item "$scriptDir\remove-office.xml"  "$work\remove-office.xml"  -Force
Copy-Item "$scriptDir\install-office.xml" "$work\install-office.xml" -Force

# ---- 1. Descargar el ODT ----
# El ODT se distribuye como un .exe autoextraible. La URL cambia con las versiones;
# usamos el enlace estable del Download Center. Si falla, descargarlo manual de:
# https://www.microsoft.com/download/details.aspx?id=49117
$odtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_18730-20142.exe"
$odtExe = "$work\odt-setup.exe"

# Si el ODT ya esta descargado (manual), usarlo y saltar la descarga
if (Test-Path $odtExe) {
    Write-Host "`nODT ya presente en $odtExe -> se salta la descarga." -ForegroundColor Green
} else {
    Write-Host "`nDescargando el Office Deployment Tool..."
    try {
        Invoke-WebRequest -Uri $odtUrl -OutFile $odtExe -UseBasicParsing
    } catch {
        Write-Host "No se pudo descargar el ODT automaticamente." -ForegroundColor Red
        Write-Host "Descargalo manual de: https://www.microsoft.com/download/details.aspx?id=49117" -ForegroundColor Yellow
        Write-Host "Guardalo como $odtExe y volve a correr el script." -ForegroundColor Yellow
        exit 1
    }
}
# Desbloquear el ODT por si tiene marca de web (SmartScreen)
Unblock-File $odtExe -ErrorAction SilentlyContinue

# ---- 2. Extraer el setup.exe del ODT ----
Write-Host "Extrayendo el ODT..."
Start-Process -FilePath $odtExe -ArgumentList "/quiet /extract:$work" -Wait
$setup = "$work\setup.exe"
if (-not (Test-Path $setup)) {
    Write-Host "No se encontro setup.exe tras extraer el ODT." -ForegroundColor Red
    exit 1
}

# ---- 3. Desinstalar TODO Office ----
Write-Host "`nDesinstalando Office (todas las versiones)... (puede tardar varios minutos)"
Start-Process -FilePath $setup -ArgumentList "/configure `"$work\remove-office.xml`"" -Wait
Write-Host "Desinstalacion terminada." -ForegroundColor Green

# ---- 4. Instalar M365 Apps limpio ----
Write-Host "`nInstalando Microsoft 365 Apps... (descarga ~2-3 GB, tarda bastante)"
Start-Process -FilePath $setup -ArgumentList "/configure `"$work\install-office.xml`"" -Wait

# ---- 5. Verificar ----
Write-Host "`nVerificando instalacion..."
$cfg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -EA SilentlyContinue
if ($cfg.ProductReleaseIds) {
    Write-Host "Office instalado: $($cfg.ProductReleaseIds)" -ForegroundColor Green
    Write-Host "Canal: $($cfg.UpdateChannel)" -ForegroundColor Green
    Write-Host ""
    Write-Host "LISTO. Ahora el usuario debe:" -ForegroundColor Cyan
    Write-Host "  1. Abrir Word o Excel" -ForegroundColor Cyan
    Write-Host "  2. Archivo -> Cuenta -> Iniciar sesion con su cuenta @e-buyplace.com + MFA" -ForegroundColor Cyan
    Write-Host "  3. Verificar activacion:" -ForegroundColor Cyan
    Write-Host '     cscript "C:\Program Files\Microsoft Office\root\Office16\OSPP.VBS" /dstatus' -ForegroundColor Cyan
    Write-Host "     Debe decir LICENSED (no OOB_GRACE)" -ForegroundColor Cyan
} else {
    Write-Host "La instalacion no se completo. Revisar C:\ODT-EBP y los logs de %temp%." -ForegroundColor Red
}
