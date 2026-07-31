# ============================================================
# Deploy-EBPBaseline.ps1
# Despliegue de toolkit corporativo + wallpaper/lockscreen
# Ejecutar como SYSTEM desde Intune (Scripts de plataforma)
# VERSION: 1  <-- subir este numero para forzar re-ejecucion en toda la flota
# ============================================================
# Espeja TODO el arbol del repo en C:\ProgramData\EBP, respetando las
# subcarpetas que tenga el repo (recursivo). Hace MIRROR: lo que ya no
# existe en el repo se elimina del cliente. Asi el despliegue es
# reproducible y no quedan archivos viejos sueltos.
#
# Para agregar/quitar/mover un script: hacelo en el repo y suma la VERSION.
# El deploy es AGNOSTICO a la estructura: no hace falta tocarlo al reordenar.
# ============================================================
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Version = 6

# --- Configuracion ---
$Owner         = "fabrate-ebuy"
$Repo          = "intune-ebp"
$Branch        = "main"
$RepoBase      = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch"
$TreeUrl       = "https://api.github.com/repos/$Owner/$Repo/git/trees/${Branch}?recursive=1"
$ToolkitFolder = "C:\ProgramData\EBP"
$WallFolder    = "C:\Windows\Web\Wallpaper\Corporate"
$WallpaperName = "wallpaper_EBP_25.jpg"
$WallpaperPath = "$WallFolder\$WallpaperName"
$LogFile       = "$ToolkitFolder\deploy.log"

# Archivos que NO se copian al toolkit (por nombre de archivo, en cualquier carpeta)
$Excluir = @(
    "Deploy-EBPBaseline.ps1",   # el propio script (corre desde Intune)
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
Write-Log "=== Deploy v$Version iniciado ==="

# ============================================================
# 1. Listar arbol completo del repo (recursivo) y espejar
# ============================================================
$syncOk = $false
try {
    $headers = @{ "User-Agent" = "EBP-Deploy" }
    $tree = Invoke-RestMethod -Uri $TreeUrl -Headers $headers -UseBasicParsing

    if ($tree.truncated) {
        Write-Log "ADVERTENCIA: el arbol vino truncado por la API (repo muy grande)."
    }

    # Rutas relativas de archivos (blobs), aplicando exclusiones por nombre de hoja
    $wanted = @()
    foreach ($node in $tree.tree) {
        if ($node.type -ne "blob") { continue }
        $leaf = Split-Path $node.path -Leaf
        if ($Excluir -contains $leaf) {
            Write-Log "Omitido (exclusion): $($node.path)"
            continue
        }
        $wanted += $node.path
    }

    # --- Descargar cada archivo recreando subcarpetas ---
    foreach ($rel in $wanted) {
        $localRel = $rel -replace '/', '\'
        $dest     = Join-Path $ToolkitFolder $localRel
        $destDir  = Split-Path $dest -Parent
        if (!(Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }

        # URL-encode por segmento (maneja espacios, ej. el MSI de ABR)
        $encoded = ($rel -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
        $url = "$RepoBase/$encoded"
        try {
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
            Write-Log "Toolkit OK: $rel"
        } catch {
            Write-Log "Toolkit ERROR: $rel -> $($_.Exception.Message)"
        }
    }

    # --- MIRROR: eliminar del cliente lo que ya no esta en el repo ---
    # Set de rutas esperadas (en minuscula para comparar sin importar mayus/minus)
    $expected = New-Object System.Collections.Generic.HashSet[string]
    foreach ($rel in $wanted) {
        $full = (Join-Path $ToolkitFolder ($rel -replace '/', '\')).ToLower()
        [void]$expected.Add($full)
    }
    [void]$expected.Add($LogFile.ToLower())   # nunca borrar el log

    Get-ChildItem -Path $ToolkitFolder -Recurse -File -Force | ForEach-Object {
        if (-not $expected.Contains($_.FullName.ToLower())) {
            try {
                Remove-Item -Path $_.FullName -Force
                Write-Log "Mirror: eliminado $($_.FullName)"
            } catch {
                Write-Log "Mirror ERROR al eliminar $($_.FullName): $($_.Exception.Message)"
            }
        }
    }

    # --- Limpiar directorios vacios (de mas profundo a mas superficial) ---
    Get-ChildItem -Path $ToolkitFolder -Recurse -Directory -Force |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            if (-not (Get-ChildItem -Path $_.FullName -Force)) {
                Remove-Item -Path $_.FullName -Force
                Write-Log "Mirror: carpeta vacia eliminada $($_.FullName)"
            }
        }

    $syncOk = $true
} catch {
    Write-Log "ERROR listando/espejando repo: $($_.Exception.Message)"
    Write-Log "Se conserva el contenido actual de $ToolkitFolder (no se toca en fallo)."
}

# ============================================================
# 2. Descargar imagen y validar que sea JPG real
# ============================================================
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

# ============================================================
# 4. Bloquear consumer features / placeholders promocionales
# ============================================================
try {
    $ccPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    if (!(Test-Path $ccPath)) { New-Item -Path $ccPath -Force | Out-Null }

    Set-ItemProperty -Path $ccPath -Name "DisableWindowsConsumerFeatures"     -Value 1 -Type DWord
    Set-ItemProperty -Path $ccPath -Name "DisableConsumerAccountStateContent" -Value 1 -Type DWord
    Set-ItemProperty -Path $ccPath -Name "DisableCloudOptimizedContent"       -Value 1 -Type DWord

    Write-Log "Consumer features / placeholders bloqueados"
} catch {
    Write-Log "Consumer features ERROR: $($_.Exception.Message)"
}

Write-Log "=== Deploy v$Version finalizado (sync toolkit: $syncOk) ==="
exit 0
