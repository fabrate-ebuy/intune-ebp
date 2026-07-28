<#
Clean-OldWallpaperGPO.ps1
Limpia el resto de la GPO de wallpaper de Samba que ProfWiz arrastra al migrar el
perfil. Esa GPO vieja deja en el HKCU del usuario:
    HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System
        Wallpaper      = C:\wallpaper_EBP.jpg   (archivo viejo, ya no existe)
        WallpaperStyle = 4
Como es una POLITICA (Policies\System), tiene prioridad sobre PersonalizationCSP
(el wallpaper corporativo nuevo), y al apuntar a un archivo borrado deja el fondo
en negro y no deja cambiarlo. Al quitarlo, PersonalizationCSP (ebp_25) toma efecto.

IMPORTANTE: este script debe correr EN CONTEXTO DE USUARIO (no SYSTEM), porque
limpia HKCU. En Intune: Scripts de plataforma -> "Ejecutar con credenciales de
inicio de sesion del usuario: SI".

Es idempotente: si no hay nada que limpiar, no hace daño.
#>

$ErrorActionPreference = "SilentlyContinue"

$ruta = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
$limpiado = $false

if (Test-Path $ruta) {
    $props = Get-ItemProperty -Path $ruta

    if ($null -ne $props.Wallpaper) {
        Write-Host "Encontrado Wallpaper de GPO vieja: $($props.Wallpaper)"
        Remove-ItemProperty -Path $ruta -Name "Wallpaper" -Force
        $limpiado = $true
    }
    if ($null -ne $props.WallpaperStyle) {
        Remove-ItemProperty -Path $ruta -Name "WallpaperStyle" -Force
        $limpiado = $true
    }
}

# Tambien limpiar ActiveDesktop por las dudas (algunas GPOs de wallpaper usan esto)
$rutaAD = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop"
if (Test-Path $rutaAD) {
    $propsAD = Get-ItemProperty -Path $rutaAD
    if ($null -ne $propsAD.NoChangingWallPaper) {
        Remove-ItemProperty -Path $rutaAD -Name "NoChangingWallPaper" -Force
        $limpiado = $true
    }
    if ($null -ne $propsAD.Wallpaper) {
        Remove-ItemProperty -Path $rutaAD -Name "Wallpaper" -Force
        $limpiado = $true
    }
}

if ($limpiado) {
    Write-Host "Resto de GPO de wallpaper limpiado. Refrescando..."
    # Refrescar el escritorio para que PersonalizationCSP tome efecto
    RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters
    Write-Host "Listo. El wallpaper corporativo (PersonalizationCSP) deberia aplicar."
    Write-Host "Si no se ve al instante, se aplica en el proximo inicio de sesion."
} else {
    Write-Host "No habia resto de GPO de wallpaper. Nada que limpiar."
}

exit 0
