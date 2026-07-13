# ============================================================
# Deploy-EBPBaseline.ps1
# Despliegue de toolkit corporativo + wallpaper/lockscreen
# Ejecutar como SYSTEM desde Intune (Scripts de plataforma)
# VERSION: 1  <-- subir este numero para forzar re-ejecucion en toda la flota
# ============================================================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Configuracion ---
$RepoBase      = "https://raw.githubusercontent.com/fabrate-ebuy/wallpaper-ebp/main"
$ToolkitFolder = "C:\ProgramData\EBP"
$WallFolder    = "C:\Windows\Web\Wallpaper\Corporate"
$WallpaperPath = "$WallFolder\wallpaper_EBP_25.jpg"
$LogFile       = "$ToolkitFolder\deploy.log"

function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$ts  $msg"
}

# --- Preparar carpetas ---
foreach ($f in @($ToolkitFolder, $WallFolder)) {
    if (!(Test-Path $f)) { New-Item -ItemType Directory -Force -Path $f | Out-Null }
}
Write-Log "=== Deploy v1 iniciado ==="

# --- 1. Descargar toolkit (scripts que quedan disponibles en el equipo) ---
$Toolkit = @(
    "BitlockerPIN.ps1"
    # agregar aca futuros scripts: "OtroScript.ps1", etc.
)

foreach ($script in $Toolkit) {
    try {
        Invoke-WebRequest -Uri "$RepoBase/$script" -OutFile "$ToolkitFolder\$script" -UseBasicParsing
        Write-Log "Toolkit OK: $script"
    } catch {
        Write-Log "Toolkit ERROR: $script -> $($_.Exception.Message)"
    }
}

# --- 2. Descargar wallpaper y validar que sea JPG real ---
try {
    Invoke-WebRequest -Uri "$RepoBase/wallpaper_EBP_25.jpg" -OutFile $WallpaperPath -UseBasicParsing
    $b = [System.IO.File]::ReadAllBytes($WallpaperPath) | Select-Object -First 2
    if ($b[0] -ne 0xFF -or $b[1] -ne 0xD8) {
        Write-Log "Wallpaper ERROR: el archivo descargado no es un JPG valido"
        throw "No es JPG"
    }
    Write-Log "Wallpaper descargado OK"

    # --- 3. Aplicar fondo + lockscreen a nivel maquina (PersonalizationCSP, funciona en Pro como SYSTEM) ---
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
    if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }

    Set-ItemProperty -Path $RegPath -Name DesktopImagePath      -Value $WallpaperPath -Type String
    Set-ItemProperty -Path $RegPath -Name DesktopImageStatus    -Value 1 -Type DWord
    Set-ItemProperty -Path $RegPath -Name DesktopImageUrl       -Value $WallpaperPath -Type String
    Set-ItemProperty -Path $RegPath -Name LockScreenImagePath   -Value $WallpaperPath -Type String
    Set-ItemProperty -Path $RegPath -Name LockScreenImageStatus -Value 1 -Type DWord
    Set-ItemProperty -Path $RegPath -Name LockScreenUrl         -Value $WallpaperPath -Type String
    Write-Log "Wallpaper + LockScreen aplicados"
} catch {
    Write-Log "Wallpaper ERROR: $($_.Exception.Message)"
}

Write-Log "=== Deploy v1 finalizado ==="
exit 0
