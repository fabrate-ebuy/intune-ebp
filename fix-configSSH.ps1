$sshDir = "C:\Users\nbonet\.ssh"
$sshConfig = "C:\Users\nbonet\.ssh\config"
$usuario = "AzureAD\nahuelbonet"

# 1. Tomar posesión (por eso daba acceso denegado)
takeown /f $sshConfig
takeown /f $sshDir /r /d y

# 2. Resetear y dejar SOLO al usuario real
icacls $sshDir /reset
icacls $sshDir /inheritance:r
icacls $sshDir /grant:r "${usuario}:(OI)(CI)F"

icacls $sshConfig /reset
icacls $sshConfig /inheritance:r
icacls $sshConfig /grant:r "${usuario}:F"

# 3. Verificar
Write-Host "=== Permisos finales ==="
icacls $sshConfig
Write-Host "=== Contenido del config ==="
Get-Content $sshConfig
