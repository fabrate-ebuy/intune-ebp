<#
Remove-OpenOffice.ps1
Desinstala LibreOffice y/o Apache OpenOffice de un equipo, con deteccion dinamica
del product code (cubre cualquier version instalada).

Va en la PRE-MIGRACION, junto con Remove-Discord.ps1 (antes de ProfWiz).
Correr como ADMINISTRADOR / SYSTEM.

Ambas suites son MSI, se desinstalan con msiexec /x <ProductCode> /qn.
Los usuarios pasan a M365 Apps (Office). Office abre ODF (.odt/.ods) sin problema.
#>

$ErrorActionPreference = "Continue"
Write-Host "== Quitar LibreOffice / OpenOffice ==" -ForegroundColor Cyan

# Patrones de nombre a buscar en el registro de desinstalacion
$patrones = @("*LibreOffice*", "*OpenOffice*", "*Apache OpenOffice*")

# Rutas de desinstalacion (64 y 32 bits)
$rutasUninstall = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$encontrados = Get-ItemProperty $rutasUninstall -EA SilentlyContinue | Where-Object {
    $nombre = $_.DisplayName
    $nombre -and ($patrones | Where-Object { $nombre -like $_ })
}

if (-not $encontrados) {
    Write-Host "No se encontro LibreOffice ni OpenOffice. Nada que hacer." -ForegroundColor Green
    exit 0
}

foreach ($app in $encontrados) {
    $nombre = $app.DisplayName
    Write-Host "`nDesinstalando: $nombre" -ForegroundColor Yellow

    # Preferir el product code (PSChildName es el GUID en las claves MSI)
    $code = $app.PSChildName
    $uninstallString = $app.UninstallString

    if ($code -match '^\{[0-9A-Fa-f\-]+\}$') {
        # Es un MSI con GUID -> msiexec /x limpio y silencioso
        Write-Host "  MSI product code: $code" -ForegroundColor Gray
        $p = Start-Process msiexec.exe -ArgumentList "/x $code /qn /norestart" -Wait -PassThru
        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
            Write-Host "  OK (codigo $($p.ExitCode))" -ForegroundColor Green
        } else {
            Write-Host "  Fallo con codigo $($p.ExitCode)" -ForegroundColor Red
        }
    }
    elseif ($uninstallString) {
        # Fallback: usar el UninstallString, forzando modo silencioso si es msiexec
        Write-Host "  Usando UninstallString" -ForegroundColor Gray
        if ($uninstallString -match "msiexec") {
            # extraer el GUID del uninstall string
            if ($uninstallString -match '\{[0-9A-Fa-f\-]+\}') {
                $g = $matches[0]
                Start-Process msiexec.exe -ArgumentList "/x $g /qn /norestart" -Wait
                Write-Host "  OK (via UninstallString MSI)" -ForegroundColor Green
            }
        } else {
            Write-Host "  UninstallString no-MSI, revisar manual: $uninstallString" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  Sin product code ni UninstallString utilizable, revisar manual." -ForegroundColor Red
    }
}

# Limpieza de accesos directos huerfanos que a veces quedan
$lnks = @(
    "C:\Users\Public\Desktop\LibreOffice*.lnk",
    "C:\Users\Public\Desktop\OpenOffice*.lnk"
)
foreach ($l in $lnks) {
    Get-ChildItem $l -EA SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Force -EA SilentlyContinue
        Write-Host "Acceso directo removido: $($_.Name)" -ForegroundColor Gray
    }
}

Write-Host "`nListo. Verificar que ya no aparezca en Programas instalados." -ForegroundColor Cyan
