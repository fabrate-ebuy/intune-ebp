<#
Install-SAP-EBP.ps1
Instala SAP GUI for Windows 8.0 sin que tengas que recordar comandos.
Hace TODO:
  1. Desbloquea el instalador (quita la marca de web que SmartScreen usa para bloquear).
  2. Instala SAP GUI en silencio.
  3. Desbloquea el SAP ya instalado (para que saplogon.exe abra sin bloqueo).

Correr como ADMINISTRADOR.

USO:
  .\Install-SAP-EBP.ps1
  .\Install-SAP-EBP.ps1 -InstallerRoot "D:\otra\ruta\SapGui 8"   (si el instalador esta en otro lado)

Ajustar $InstallerRoot al default de donde tenes el instalador si siempre es el mismo.
#>

param(
    # Carpeta raiz donde esta el instalador de SAP (se busca SapGui64Setup.exe adentro)
    [string]$InstallerRoot = "C:\SapGui 8"
)

$ErrorActionPreference = "Stop"
Write-Host "== Instalacion de SAP GUI 8 - E-BUYPLACE ==" -ForegroundColor Cyan

# --- 1. Encontrar el instalador ---
Write-Host "`n1. Buscando el instalador en $InstallerRoot ..."
$setup = Get-ChildItem $InstallerRoot -Recurse -Filter "SapGui64Setup.exe" -EA SilentlyContinue | Select-Object -First 1
if (-not $setup) {
    Write-Host "ERROR: no se encontro SapGui64Setup.exe dentro de $InstallerRoot" -ForegroundColor Red
    Write-Host "Pasa la ruta correcta:  .\Install-SAP-EBP.ps1 -InstallerRoot 'RUTA'" -ForegroundColor Yellow
    exit 1
}
Write-Host "   Encontrado: $($setup.FullName)" -ForegroundColor Green

# --- 2. Desbloquear TODA la carpeta del instalador (quita marca de web) ---
Write-Host "`n2. Desbloqueando el instalador (marca de web)..."
Get-ChildItem $InstallerRoot -Recurse -File | Unblock-File
Write-Host "   Instalador desbloqueado." -ForegroundColor Green

# --- 3. Instalar SAP GUI en silencio ---
# NWSAPSetup soporta /Silent para instalacion desatendida con la config por defecto.
# Si necesitas un package especifico de componentes, se agrega con /Package="..."
Write-Host "`n3. Instalando SAP GUI (silencioso)... puede tardar varios minutos."
$proc = Start-Process -FilePath $setup.FullName -ArgumentList "/Silent" -Wait -PassThru
Write-Host "   Instalador termino con codigo: $($proc.ExitCode)" -ForegroundColor Gray

# --- 4. Desbloquear el SAP ya instalado (para que saplogon.exe abra) ---
Write-Host "`n4. Desbloqueando el SAP instalado..."
$rutasSAP = @(
    "C:\Program Files\SAP\FrontEnd",
    "C:\Program Files (x86)\SAP\FrontEnd"
)
foreach ($r in $rutasSAP) {
    if (Test-Path $r) {
        Get-ChildItem $r -Recurse -File -EA SilentlyContinue | Unblock-File
        Write-Host "   Desbloqueado: $r" -ForegroundColor Green
    }
}

# --- 5. Verificar ---
Write-Host "`n== Verificacion ==" -ForegroundColor Cyan
$sapLogon = Get-ChildItem "C:\Program Files*\SAP\FrontEnd" -Recurse -Filter "saplogon.exe" -EA SilentlyContinue | Select-Object -First 1
if ($sapLogon) {
    Write-Host "SAP instalado OK: $($sapLogon.FullName)" -ForegroundColor Green
    $marca = Get-Item $sapLogon.FullName -Stream Zone.Identifier -EA SilentlyContinue
    if ($marca) {
        Write-Host "ADVERTENCIA: saplogon.exe todavia tiene marca de web." -ForegroundColor Yellow
    } else {
        Write-Host "saplogon.exe sin marca de web -> deberia abrir bien." -ForegroundColor Green
    }
} else {
    Write-Host "No se encontro saplogon.exe. Revisar si la instalacion se completo." -ForegroundColor Yellow
    Write-Host "Si el /Silent no funciono, correr el instalador a mano (ya esta desbloqueado):" -ForegroundColor Yellow
    Write-Host "   $($setup.FullName)" -ForegroundColor Yellow
}
