<#
unblock-software.ps1
Quita la "marca de web" (Zone.Identifier) de los ejecutables/DLLs de una carpeta,
para que SmartScreen no bloquee software instalado manualmente desde archivos bajados
de internet (SAP GUI, FileZilla, etc.).

Sintoma que resuelve: un programa "no hace nada" al abrirlo (bloqueo silencioso de
SmartScreen). Pasa con software instalado desde instaladores marcados como "de internet",
sobre todo con SmartScreen activo.

Uso:
  .\unblock-software.ps1                              -> desbloquea las rutas comunes de SAP
  .\unblock-software.ps1 "C:\ruta\a\la\carpeta"       -> desbloquea la carpeta que le pases

Correr como ADMINISTRADOR (para tocar Program Files). Es seguro e idempotente.
#>

param(
    [string]$Carpeta = ""
)

Write-Host "== Desbloquear software (quitar marca de web) ==" -ForegroundColor Cyan

# Rutas comunes a desbloquear si no se pasa una carpeta especifica
$rutasComunes = @(
    "C:\Program Files\SAP\FrontEnd",
    "C:\Program Files (x86)\SAP\FrontEnd",
    "C:\Program Files\FileZilla FTP Client",
    "C:\Program Files (x86)\FileZilla FTP Client"
)

$rutas = if ($Carpeta) { @($Carpeta) } else { $rutasComunes }

$total = 0
foreach ($r in $rutas) {
    if (Test-Path $r) {
        Write-Host "`nDesbloqueando: $r"
        $archivos = Get-ChildItem $r -Recurse -File -EA SilentlyContinue
        $conMarca = $archivos | Where-Object {
            Get-Item $_.FullName -Stream Zone.Identifier -EA SilentlyContinue
        }
        if ($conMarca) {
            $conMarca | Unblock-File
            Write-Host "  Desbloqueados: $($conMarca.Count) archivos" -ForegroundColor Green
            $total += $conMarca.Count
        } else {
            Write-Host "  Sin archivos marcados." -ForegroundColor Gray
        }
    }
}

Write-Host ""
if ($total -gt 0) {
    Write-Host "Listo. Total desbloqueado: $total archivos. El software deberia abrir." -ForegroundColor Green
} else {
    Write-Host "No se encontraron archivos con marca de web en las rutas revisadas." -ForegroundColor Yellow
    if (-not $Carpeta) {
        Write-Host "Si el software esta en otra ruta, pasala como argumento:" -ForegroundColor Yellow
        Write-Host '  .\unblock-software.ps1 "C:\ruta\del\software"' -ForegroundColor Yellow
    }
}
