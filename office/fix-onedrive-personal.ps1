<#
fix-onedrive-personal.ps1
Detecta cuentas PERSONALES de OneDrive (@hotmail, @gmail, @outlook, etc.) que quedaron
configuradas en un equipo migrado, y ofrece desvincularlas para dejar solo la corporativa.

Comun en la migracion: usuarios que usaban su OneDrive personal en la PC de trabajo.
Al migrar, OneDrive intenta sincronizar con la cuenta personal (no la corporativa).

Correr en CONTEXTO DE USUARIO (PowerShell NORMAL en la sesion del usuario).

Por defecto es INTERACTIVO: muestra cada cuenta personal y pregunta si desvincularla.
Con -Auto desvincula todas las personales sin preguntar (para rollout masivo).
Con -SoloListar solo muestra, no toca nada.

NO borra archivos de la nube personal ni de la corporativa: solo saca la configuracion
de la cuenta personal de OneDrive en este equipo. Los archivos en C:\Users\<u>\OneDrive
quedan en disco (se pueden mover/borrar aparte si se quiere).
#>

param(
    [switch]$Auto,        # desvincular todas las personales sin preguntar
    [switch]$SoloListar   # solo mostrar, no tocar
)

Write-Host "== OneDrive: cuentas personales ==" -ForegroundColor Cyan
Write-Host "Usuario: $(whoami)" -ForegroundColor Gray

$accountsKey = "HKCU:\Software\Microsoft\OneDrive\Accounts"
if (-not (Test-Path $accountsKey)) {
    Write-Host "No hay cuentas de OneDrive configuradas." -ForegroundColor Yellow
    exit 0
}

# Listar todas las cuentas y clasificar
$cuentas = Get-ChildItem $accountsKey -EA SilentlyContinue | ForEach-Object {
    $email = (Get-ItemProperty $_.PSPath -Name UserEmail -EA SilentlyContinue).UserEmail
    [PSCustomObject]@{
        Clave    = $_.PSChildName
        Email    = $email
        Path     = $_.PSPath
        # "Business*" = corporativa; "Personal" = cuenta Microsoft personal
        EsPersonal = ($_.PSChildName -like "Personal*")
    }
}

Write-Host "`n=== Cuentas encontradas ===" -ForegroundColor Cyan
foreach ($c in $cuentas) {
    $tipo = if ($c.EsPersonal) { "PERSONAL" } else { "corporativa" }
    Write-Host "  [$tipo] $($c.Clave) -> $($c.Email)"
}

$personales = $cuentas | Where-Object { $_.EsPersonal }
if (-not $personales) {
    Write-Host "`nNo hay cuentas personales. Nada que hacer." -ForegroundColor Green
    exit 0
}

if ($SoloListar) {
    Write-Host "`n(SoloListar: no se desvincula nada)" -ForegroundColor Yellow
    exit 0
}

# Cerrar OneDrive antes de tocar el registro
Write-Host "`nCerrando OneDrive..."
Get-Process OneDrive -EA SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

foreach ($p in $personales) {
    $quitar = $false
    if ($Auto) {
        $quitar = $true
    } else {
        $resp = Read-Host "`nDesvincular la cuenta personal $($p.Email)? (s/n)"
        if ($resp -match '^[sS]') { $quitar = $true }
    }
    if ($quitar) {
        Remove-Item $p.Path -Recurse -Force -EA SilentlyContinue
        Write-Host "  Desvinculada: $($p.Email)" -ForegroundColor Green
    } else {
        Write-Host "  Se deja: $($p.Email)" -ForegroundColor Gray
    }
}

# Reiniciar OneDrive (para que quede con la corporativa, si esta configurada)
Write-Host "`nReiniciando OneDrive..."
$od = "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
if (Test-Path $od) { Start-Process $od }

Write-Host "`nListo." -ForegroundColor Green
Write-Host "Si NO hay cuenta corporativa configurada, abrir OneDrive e iniciar sesion" -ForegroundColor Cyan
Write-Host "con la cuenta @e-buyplace.com. Los archivos personales en" -ForegroundColor Cyan
Write-Host "C:\Users\<usuario>\OneDrive quedan en disco (mover/borrar aparte si se quiere)." -ForegroundColor Cyan
