<#
Clean-WallpaperGPP-AllProfiles.ps1
Limpia el wallpaper viejo que la GPP del dominio Samba dejo pegado en los perfiles
de usuario, y que ProfWiz arrastra al migrar (fondo negro que no se puede cambiar).

Recorre TODOS los perfiles de usuario del equipo (los que tienen hive cargado y los
que estan en disco) y borra:
    HKEY_USERS\<SID>\Software\Microsoft\Windows\CurrentVersion\Policies\System
        Wallpaper       (= C:\wallpaper_EBP.jpg u otra ruta vieja)
        WallpaperStyle

Correr como ADMINISTRADOR, en cada equipo durante la migracion (post-desunir del
dominio). Una sola corrida limpia a todos los usuarios del equipo.

Despues de correrlo, el wallpaper corporativo (PersonalizationCSP del baseline) toma
efecto en el proximo inicio de sesion de cada usuario.
#>

$ErrorActionPreference = "SilentlyContinue"
Write-Host "== Limpieza de wallpaper viejo (GPP Samba) en todos los perfiles ==" -ForegroundColor Cyan

$subKey = "Software\Microsoft\Windows\CurrentVersion\Policies\System"
$limpiados = 0

# ---- 1. Perfiles con hive YA cargado (usuarios con sesion o perfil montado) ----
Write-Host "`nRevisando perfiles cargados (HKEY_USERS)..."
Get-ChildItem "Registry::HKEY_USERS" |
    Where-Object { $_.Name -match "S-1-12-1-" -and $_.Name -notmatch "_Classes$" } |
    ForEach-Object {
        $sid = $_.PSChildName
        $key = "Registry::HKEY_USERS\$sid\$subKey"
        if (Test-Path $key) {
            $wp = (Get-ItemProperty $key -Name Wallpaper -EA SilentlyContinue).Wallpaper
            if ($wp) {
                Remove-ItemProperty $key -Name Wallpaper -Force -EA SilentlyContinue
                Remove-ItemProperty $key -Name WallpaperStyle -Force -EA SilentlyContinue
                Write-Host "  Limpiado (cargado): $sid  (tenia: $wp)" -ForegroundColor Green
                $limpiados++
            }
        }
    }

# ---- 2. Perfiles NO cargados (en disco): cargar el hive, limpiar, descargar ----
Write-Host "`nRevisando perfiles en disco (no cargados)..."
$profiles = Get-CimInstance Win32_UserProfile |
    Where-Object { -not $_.Special -and $_.LocalPath -like "C:\Users\*" }

foreach ($p in $profiles) {
    $sid = $p.SID
    # Saltar los que ya estan cargados (los procesamos arriba)
    if (Test-Path "Registry::HKEY_USERS\$sid") { continue }

    $ntuser = Join-Path $p.LocalPath "NTUSER.DAT"
    if (-not (Test-Path $ntuser)) { continue }

    $tmpHive = "TempHive_$($sid.Substring($sid.Length-6))"
    reg load "HKU\$tmpHive" "$ntuser" *> $null
    if ($LASTEXITCODE -eq 0) {
        $key = "Registry::HKEY_USERS\$tmpHive\$subKey"
        if (Test-Path $key) {
            $wp = (Get-ItemProperty $key -Name Wallpaper -EA SilentlyContinue).Wallpaper
            if ($wp) {
                Remove-ItemProperty $key -Name Wallpaper -Force -EA SilentlyContinue
                Remove-ItemProperty $key -Name WallpaperStyle -Force -EA SilentlyContinue
                Write-Host "  Limpiado (disco): $($p.LocalPath)  (tenia: $wp)" -ForegroundColor Green
                $limpiados++
            }
        }
        [gc]::Collect()
        reg unload "HKU\$tmpHive" *> $null
    }
}

Write-Host ""
if ($limpiados -gt 0) {
    Write-Host "Listo. Perfiles limpiados: $limpiados" -ForegroundColor Green
    Write-Host "El wallpaper corporativo aplicara en el proximo inicio de sesion de cada usuario." -ForegroundColor Green
} else {
    Write-Host "No se encontro wallpaper viejo en ningun perfil. Nada que limpiar." -ForegroundColor Yellow
}
exit 0
