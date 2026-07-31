# diag.ps1 - Diagnostico rapido del estado del equipo (Entra, Hello, servicios, apps)
# Correr como ADMINISTRADOR para ver todo.

Write-Host "===== DIAGNOSTICO EBP - $env:COMPUTERNAME - $(Get-Date) =====" -ForegroundColor Cyan

Write-Host "`n--- Registro Entra / PRT / Hello ---" -ForegroundColor Yellow
dsregcmd /status | Select-String "AzureAdJoined","DomainJoined","AzureAdPrt ","AzureAdPrtExpiryTime","TenantName","NgcSet","WamDefaultSet"

Write-Host "`n--- Servicios clave ---" -ForegroundColor Yellow
Get-Service -Name "IntuneManagementExtension","glpi-agent","WinDefend","OneDrive Updater Service" -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize

Write-Host "`n--- Defender (estado) ---" -ForegroundColor Yellow
try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
    "AntivirusEnabled : $($mp.AntivirusEnabled)"
    "RealTimeProtection: $($mp.RealTimeProtectionEnabled)"
    "TamperProtection : $($mp.IsTamperProtected)"
} catch { Write-Host "No se pudo leer Defender" -ForegroundColor Red }

Write-Host "`n--- BitLocker ---" -ForegroundColor Yellow
Get-BitLockerVolume -ErrorAction SilentlyContinue | Select-Object MountPoint, VolumeStatus, ProtectionStatus | Format-Table -AutoSize

Write-Host "`n--- Ultimos errores de apps Win32 (AppWorkload) ---" -ForegroundColor Yellow
$awl = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AppWorkload.log"
if (Test-Path $awl) {
    Get-Content $awl -Tail 300 | Select-String "error","fail","0x8" | Select-Object -Last 10
} else { Write-Host "No se encontro AppWorkload.log" }

Write-Host "`n===== FIN DIAGNOSTICO =====" -ForegroundColor Cyan
