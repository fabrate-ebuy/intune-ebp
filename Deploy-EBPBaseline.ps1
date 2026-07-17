# ============================================================
# Deploy-EBPBaseline.ps1
# Despliegue de toolkit corporativo + wallpaper/lockscreen
# Ejecutar como SYSTEM desde Intune (Scripts de plataforma)
# VERSION: 2  <-- subir este numero para forzar re-ejecucion en toda la flota
# ============================================================
# v2: descarga automaticamente TODO el contenido del repo a C:\ProgramData\EBP
#     (excepto el propio Deploy y el wallpaper, que se manejan aparte).
#     Para agregar un script/txt a la flota: subilo al repo y suma la VERSION.
# ============================================================
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Configuracion ---
$Owner         = "fabrate-ebuy"
$Repo          = "intune-ebp"
$Branch        = "main"
$RepoBase      = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch"
$ApiUrl        = "https://api.github.com/repos/$Owner/$Repo/contents?ref=$Branch"
$ToolkitFolder = "C:\ProgramData\EBP"
$WallFolder    = "C:\Windows\Web\Wallpaper\Corporate"
$WallpaperName = "wallpaper_EBP_25.jpg"
$WallpaperPath = "$WallFolder\$WallpaperName"
$LogFile       = "$ToolkitFolder\deploy.log"

# Archivos que NO se copian al toolkit (se manejan aparte o no corresponden)
$Excluir = @(
    "Deploy-EBPBaseline.ps1",   # el propio script
    "wallpaper_EBP_25.jpg",     # el wallpaper (se maneja en su bloque)
    "README.md",
    ".gitignore"
)

function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$ts  $msg"
}

# --- Preparar carpetas ---
foreach ($f in @($ToolkitFolder, $WallFolder)) {
    if (!(Test-Path $f)) { New-Item -ItemType Directory -Force -Path $f | Out-Null }
}
Write-Log "=== Deploy v2 iniciado ==="

# --- 1. Listar y descargar TODO el contenido del repo (excepto exclusiones) ---
try {
    # GitHub API requiere un User-Agent
    $headers = @{ "User-Agent" = "EBP-Deploy" }
    $items = Invoke-RestMethod -Uri $ApiUrl -Headers $headers -UseBasicParsing

    foreach ($item in $items) {
        # Solo archivos (type=file), no carpetas
        if ($item.type -ne "file") { continue }
        if ($Excluir -contains $item.name) {
            Write-Log "Omitido (exclusion): $($item.name)"
            continue
        }
        try {
            $dest = Join-Path $ToolkitFolder $item.name
            Invoke-WebRequest -Uri $item.download_url -OutFile $dest -UseBasicParsing
            Write-Log "Toolkit OK: $($item.name)"
        } catch {
            Write-Log "Toolkit ERROR: $($item.name) -> $($_.Exception.Message)"
        }
    }
} catch {
    Write-Log "ERROR listando repo via API: $($_.Exception.Message)"
    # Fallback: si la API falla (ej. rate limit), al menos bajar lo critico
    try {
        Invoke-WebRequest -Uri "$RepoBase/BitlockerPIN.ps1" -OutFile "$ToolkitFolder\BitlockerPIN.ps1" -UseBasicParsing
        Write-Log "Fallback: BitlockerPIN.ps1 descargado"
    } catch {
        Write-Log "Fallback ERROR: $($_.Exception.Message)"
    }
}

# --- 2. Descargar imagen y validar que sea JPG real ---
try {
    Invoke-WebRequest -Uri "$RepoBase/$WallpaperName" -OutFile $WallpaperPath -UseBasicParsing
    $b = [System.IO.File]::ReadAllBytes($WallpaperPath) | Select-Object -First 2
    if ($b[0] -ne 0xFF -or $b[1] -ne 0xD8) {
        Write-Log "Imagen ERROR: el archivo descargado no es un JPG valido"
        throw "No es JPG"
    }
    Write-Log "Imagen descargada OK"

    # --- 3. Aplicar fondo + lockscreen a nivel maquina (PersonalizationCSP) ---
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
    if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
    Set-ItemProperty -Path $RegPath -Name DesktopImagePath      -Value $WallpaperPath -Type String
    Set-ItemProperty -Path $RegPath -Name DesktopImageStatus    -Value 1 -Type DWord
    Set-ItemProperty -Path $RegPath -Name DesktopImageUrl       -Value $WallpaperPath -Type String
    Set-ItemProperty -Path $RegPath -Name LockScreenImagePath   -Value $WallpaperPath -Type String
    Set-ItemProperty -Path $RegPath -Name LockScreenImageStatus -Value 1 -Type DWord
    Set-ItemProperty -Path $RegPath -Name LockScreenUrl         -Value $WallpaperPath -Type String
    Write-Log "Fondo + LockScreen aplicados"
} catch {
    Write-Log "Imagen ERROR: $($_.Exception.Message)"
}

Write-Log "=== Deploy v2 finalizado ==="
exit 0
