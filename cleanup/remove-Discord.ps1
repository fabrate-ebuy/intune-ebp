<#
Remove-Discord.ps1
Barre Discord por completo (winget + cliente per-user + TODOS los perfiles) y limpia
las entradas de registro que GLPI inventaria, para no dejar rastro antes del inventario.

Correr como ADMINISTRADOR / SYSTEM (para agarrar todos los perfiles).
Pensado como paso de PRE-MIGRACION, antes de que GLPI Agent reporte.
#>

Write-Host "== Barrido total de Discord ==" -ForegroundColor Cyan

# 1. Matar procesos
Get-Process -Name "Discord*" -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
Get-Process -EA SilentlyContinue | Where-Object { $_.Path -like "*Discord*" } |
    Stop-Process -Force -EA SilentlyContinue
Start-Sleep -Seconds 2

# 2. winget uninstall (por si fue instalado asi)
$winget = Get-Command winget -EA SilentlyContinue
if ($winget) {
    Write-Host "winget uninstall Discord..." -ForegroundColor Yellow
    winget uninstall --id Discord.Discord --silent --accept-source-agreements 2>$null
}

# 3. Uninstaller nativo del cliente en cada perfil
$userProfiles = Get-ChildItem "C:\Users" -Directory -EA SilentlyContinue
foreach ($p in $userProfiles) {
    $discordPath = Join-Path $p.FullName "AppData\Local\Discord"
    if (Test-Path $discordPath) {
        Write-Host "Discord en perfil: $($p.Name)" -ForegroundColor Yellow
        $updateExe = Get-ChildItem $discordPath -Filter "Update.exe" -Recurse -EA SilentlyContinue | Select-Object -First 1
        if ($updateExe) {
            try { Start-Process -FilePath $updateExe.FullName -ArgumentList "--uninstall -s" -Wait -EA SilentlyContinue } catch {}
        }
    }
}
Start-Sleep -Seconds 2

# 4. Borrar carpetas residuales en TODOS los perfiles
$folders = @("AppData\Local\Discord", "AppData\Roaming\discord", "AppData\Local\SquirrelTemp")
foreach ($p in $userProfiles) {
    foreach ($f in $folders) {
        $path = Join-Path $p.FullName $f
        if (Test-Path $path) {
            Write-Host "Borrando carpeta: $path" -ForegroundColor Gray
            Remove-Item -Path $path -Recurse -Force -EA SilentlyContinue
        }
    }
}

# 5. Accesos directos
$shortcuts = @(
    "C:\Users\*\Desktop\Discord.lnk",
    "C:\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Discord Inc*"
)
foreach ($s in $shortcuts) {
    Get-Item $s -EA SilentlyContinue | Remove-Item -Recurse -Force -EA SilentlyContinue
}

# 6. LIMPIAR REGISTRO - esto es lo que GLPI lee para el inventario de software
#    Discord se registra en el Uninstall PER-USER de cada hive (HKU), no en HKLM.
Write-Host "`nLimpiando entradas de registro (lo que inventaria GLPI)..." -ForegroundColor Cyan

# 6a. Cargar cada hive de usuario y limpiar su clave Uninstall de Discord
foreach ($p in $userProfiles) {
    $ntuser = Join-Path $p.FullName "NTUSER.DAT"
    if (-not (Test-Path $ntuser)) { continue }

    $sid = "TempHive_$($p.Name)"
    $loaded = $false
    # Si el hive no esta ya cargado (usuario no logueado), cargarlo temporalmente
    try {
        reg load "HKU\$sid" "$ntuser" 2>$null | Out-Null
        $loaded = $true
    } catch {}

    $hiveRoot = if ($loaded) { "Registry::HKEY_USERS\$sid" } else { $null }

    if ($hiveRoot) {
        $uninstallKey = "$hiveRoot\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Discord"
        if (Test-Path $uninstallKey) {
            Write-Host "  Borrando registro Discord de perfil $($p.Name)" -ForegroundColor Gray
            Remove-Item $uninstallKey -Recurse -Force -EA SilentlyContinue
        }
        # descargar el hive
        [gc]::Collect()
        reg unload "HKU\$sid" 2>$null | Out-Null
    }
}

# 6b. Para usuarios ACTUALMENTE logueados (hive ya montado en HKU por su SID real)
Get-ChildItem "Registry::HKEY_USERS" -EA SilentlyContinue | ForEach-Object {
    $k = "Registry::$($_.Name)\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Discord"
    if (Test-Path $k) {
        Write-Host "  Borrando registro Discord (usuario activo)" -ForegroundColor Gray
        Remove-Item $k -Recurse -Force -EA SilentlyContinue
    }
}

# 6c. Por si acaso, HKLM (instalaciones a nivel maquina, raras pero posibles)
$hklmKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Discord",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Discord"
)
foreach ($k in $hklmKeys) {
    if (Test-Path $k) { Remove-Item $k -Recurse -Force -EA SilentlyContinue }
}

# 7. Verificacion final
Write-Host "`nVerificando restos..." -ForegroundColor Cyan
$restosCarpeta = $userProfiles | ForEach-Object {
    $p = Join-Path $_.FullName "AppData\Local\Discord"
    if (Test-Path $p) { $_.Name }
}
if ($restosCarpeta) {
    Write-Host "AUN quedan carpetas en: $($restosCarpeta -join ', ')" -ForegroundColor Red
    Write-Host "(usuario con Discord abierto o archivos bloqueados; reintentar tras logoff)" -ForegroundColor Yellow
} else {
    Write-Host "Sin rastros de Discord (carpetas + registro). Listo para inventario GLPI." -ForegroundColor Green
}