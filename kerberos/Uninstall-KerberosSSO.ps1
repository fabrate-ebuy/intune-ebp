<#
Uninstall-KerberosSSO.ps1
Revierte TODO lo que hace Install-KerberosSSO.ps1, para dejar el equipo limpio.
Sirve para: (a) probar el deploy desde cero, y (b) como uninstall command del
paquete Win32 en Intune.

Correr como ADMINISTRADOR / SYSTEM.
#>

Write-Host "== Rollback Kerberos SSO ==" -ForegroundColor Cyan

# 1. Borrar la tarea programada
$taskName = "EBP-KerberosTicket"
if (Get-ScheduledTask -TaskName $taskName -EA SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Tarea '$taskName' eliminada." -ForegroundColor Green
}

# 2. Destruir cualquier ticket en cache MSLSA (opcional, limpieza)
$kdestroy = "C:\Program Files\MIT\Kerberos\bin\kdestroy.exe"
if (Test-Path $kdestroy) {
    $env:KRB5CCNAME = "MSLSA:"
    & $kdestroy 2>$null
    Write-Host "Ticket MSLSA destruido." -ForegroundColor Green
}

# 3. Quitar la variable de entorno KRB5CCNAME (maquina)
[Environment]::SetEnvironmentVariable("KRB5CCNAME", $null, "Machine")
Write-Host "Variable KRB5CCNAME (maquina) eliminada." -ForegroundColor Green

# 4. Borrar krb5.ini
$krb5 = "C:\ProgramData\MIT\Kerberos5\krb5.ini"
if (Test-Path $krb5) { Remove-Item $krb5 -Force; Write-Host "krb5.ini borrado." -ForegroundColor Green }

# 4b. Quitar entradas de hosts (DC + 214)
$hostsFile = "C:\Windows\System32\drivers\etc\hosts"
$nombres = @("dc1.infra.ebuyplace.com","dc2.infra.ebuyplace.com","win2019test.infra.ebuyplace.com")
if (Test-Path $hostsFile) {
    $lineas = Get-Content $hostsFile
    $filtradas = $lineas | Where-Object {
        $linea = $_
        -not ($nombres | Where-Object { $linea -match [regex]::Escape($_) })
    }
    Set-Content -Path $hostsFile -Value $filtradas -Encoding ascii
    Write-Host "Entradas de hosts (DC + 214) removidas." -ForegroundColor Green
}

# 5. Borrar el script de ProgramData
$ebp = "C:\ProgramData\EBP\Get-Ticket-EBP.ps1"
if (Test-Path $ebp) { Remove-Item $ebp -Force; Write-Host "Get-Ticket-EBP.ps1 borrado." -ForegroundColor Green }

# 5b. Borrar el acceso directo del escritorio
$lnk = "C:\Users\Public\Desktop\Acceso SSH (214).lnk"
if (Test-Path $lnk) { Remove-Item $lnk -Force; Write-Host "Acceso directo borrado." -ForegroundColor Green }

# 6. Quitar el bloque "Host 214" del ssh config de cada usuario
$profiles = Get-ChildItem "C:\Users" -Directory -EA SilentlyContinue |
    Where-Object { $_.Name -notin @("Public","Default","Default User","All Users") }
foreach ($p in $profiles) {
    $cfg = Join-Path $p.FullName ".ssh\config"
    if (Test-Path $cfg) {
        $content = Get-Content $cfg -Raw
        # remover el bloque Host 214 ... hasta el proximo Host o fin
        $nuevo = ($content -replace "(?ms)Host\s+214.*?(?=(^Host\s)|\Z)", "").Trim()
        Set-Content -Path $cfg -Value $nuevo -Encoding ascii
        Write-Host "  Bloque Host 214 removido de $($p.Name)" -ForegroundColor Gray
    }
}

# 7. Desinstalar MIT Kerberos
$abr = Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
    -EA SilentlyContinue | Where-Object { $_.DisplayName -like "*Kerberos*" }
foreach ($item in $abr) {
    Write-Host "Desinstalando MIT Kerberos ($($item.PSChildName))..." -ForegroundColor Yellow
    Start-Process msiexec.exe -ArgumentList "/x $($item.PSChildName) /qn /norestart" -Wait
}

Write-Host "`nRollback completo. Equipo limpio para probar el deploy desde cero." -ForegroundColor Cyan
Write-Host "NOTA: reiniciar para que la variable de entorno se limpie del todo." -ForegroundColor Yellow
