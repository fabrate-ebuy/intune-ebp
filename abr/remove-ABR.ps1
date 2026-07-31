<#
Remove-AdminByRequest.ps1
Desinstala Admin By Request de forma no-interactiva, detectando el product code
sea cual sea la version (8.6.3, 8.7.1, etc.). Confirmado que en este entorno la
uninstall protection NO esta activa, asi que el msiexec /x lo saca directo.

Correr como ADMINISTRADOR / SYSTEM.
Paso de PRE-MIGRACION. Recordar desvincular el equipo del Inventory en el portal
ABR despues, para liberar la licencia (plan free = 25 devices).
#>

Write-Host "== Desinstalacion de Admin By Request ==" -ForegroundColor Cyan

# Detectar ABR (cubre 32/64 bits y cualquier version)
$abr = Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
    -EA SilentlyContinue |
    Where-Object { $_.DisplayName -like "*Admin By Request*" }

if (-not $abr) {
    Write-Host "Admin By Request no esta instalado. Nada que hacer." -ForegroundColor Green
    exit 0
}

foreach ($item in $abr) {
    Write-Host ("Desinstalando: {0} (v{1}) - {2}" -f $item.DisplayName, $item.DisplayVersion, $item.PSChildName) -ForegroundColor Yellow
    $proc = Start-Process msiexec.exe -ArgumentList "/x $($item.PSChildName) /qn /norestart" -Wait -PassThru
    if ($proc.ExitCode -eq 0) {
        Write-Host "  OK" -ForegroundColor Green
    } else {
        Write-Host ("  msiexec devolvio codigo {0}" -f $proc.ExitCode) -ForegroundColor Red
    }
}

# Verificar
$check = Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
    -EA SilentlyContinue |
    Where-Object { $_.DisplayName -like "*Admin By Request*" }

if ($check) {
    Write-Host "`nATENCION: ABR sigue presente." -ForegroundColor Red
} else {
    Write-Host "`nABR removido. Desvincular el equipo del Inventory en el portal ABR." -ForegroundColor Green
}