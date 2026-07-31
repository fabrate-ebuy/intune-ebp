<#
Install-KerberosSSO.ps1
Deploy por Intune (SYSTEM) de SSO por SSH via GSSAPI/Kerberos contra el dominio
Samba, para clientes Windows Entra.

Hace todo lo automatico (sin password):
  1. Instala MIT Kerberos (kfw-*.msi)
  2. Coloca krb5.ini (realm, DCs, ticket_lifetime 24h)
  3. Setea KRB5CCNAME=MSLSA: a nivel maquina
  4. Coloca el script Get-Ticket-EBP.ps1 en C:\ProgramData\EBP
  5. Crea una tarea programada AL LOGON de cada usuario que dispara el kinit
     (el usuario mete su password una vez al dia; NO se guarda)

Empaquetar en el .intunewin junto con:
  - kfw-4.1-amd64.msi
  - Get-Ticket-EBP.ps1

Install command (Intune, contexto System):
  powershell.exe -ExecutionPolicy Bypass -File .\Install-KerberosSSO.ps1
Detection:
  Existe C:\Program Files\MIT\Kerberos\bin\kinit.exe
#>

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot

Write-Host "== Deploy Kerberos SSO ==" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. Instalar MIT Kerberos
# ---------------------------------------------------------------------------
$installed = Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
    -EA SilentlyContinue | Where-Object { $_.DisplayName -like "*Kerberos*" }

if (-not $installed) {
    $msi = Join-Path $here "kfw-4.1-amd64.msi"
    if (-not (Test-Path $msi)) { Write-Error "No se encontro $msi"; exit 1 }
    Write-Host "Instalando MIT Kerberos..." -ForegroundColor Yellow
    $p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait -PassThru
    # 0 = OK, 3010 = OK pero requiere reinicio (ambos son exito)
    if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
        Write-Host "MSI instalado (codigo $($p.ExitCode))." -ForegroundColor Green
    } else {
        Write-Error "MSI fallo: $($p.ExitCode)"; exit 1
    }
} else {
    Write-Host "MIT Kerberos ya instalado." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 2. krb5.ini con ticket_lifetime largo (menos prompts)
# ---------------------------------------------------------------------------
$krbDir = "C:\ProgramData\MIT\Kerberos5"
New-Item -ItemType Directory -Force -Path $krbDir | Out-Null
$krb5 = @"
[libdefaults]
    default_realm = INFRA.EBUYPLACE.COM
    dns_lookup_kdc = true
    dns_lookup_realm = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true

[realms]
    INFRA.EBUYPLACE.COM = {
        kdc = dc1.infra.ebuyplace.com
        kdc = dc2.infra.ebuyplace.com
        admin_server = dc1.infra.ebuyplace.com
    }

[domain_realm]
    .infra.ebuyplace.com = INFRA.EBUYPLACE.COM
    infra.ebuyplace.com = INFRA.EBUYPLACE.COM
"@
Set-Content -Path "$krbDir\krb5.ini" -Value $krb5 -Encoding ascii
Write-Host "krb5.ini colocado." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 2b. Entradas en hosts para resolver DC y 214 (Kerberos/SSH usan nombres)
#     Quirurgico: solo estas 3 lineas, no toca el DNS general del equipo.
#     Requiere VPN activa cuando el equipo esta fuera de la oficina.
# ---------------------------------------------------------------------------
$hostsFile = "C:\Windows\System32\drivers\etc\hosts"
$entradas = @(
    "10.20.20.30    dc1.infra.ebuyplace.com"
    "10.30.20.5     dc2.infra.ebuyplace.com"
    "10.30.20.214   win2019test.infra.ebuyplace.com"
)
$hostsContent = Get-Content $hostsFile -EA SilentlyContinue
foreach ($e in $entradas) {
    $nombre = ($e -split "\s+")[1]   # el FQDN
    # agregar solo si ese nombre no esta ya en el hosts
    if (-not ($hostsContent | Select-String -SimpleMatch $nombre)) {
        Add-Content -Path $hostsFile -Value $e -Encoding ascii
        Write-Host "  hosts += $e" -ForegroundColor Gray
    }
}
Write-Host "Entradas de hosts verificadas (DC + 214)." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 3. KRB5CCNAME=MSLSA: a nivel maquina
# ---------------------------------------------------------------------------
[Environment]::SetEnvironmentVariable("KRB5CCNAME", "MSLSA:", "Machine")
Write-Host "KRB5CCNAME=MSLSA: seteado (maquina)." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 4. Copiar Get-Ticket-EBP.ps1 a ProgramData (lo usara la tarea)
# ---------------------------------------------------------------------------
$ebpDir = "C:\ProgramData\EBP"
New-Item -ItemType Directory -Force -Path $ebpDir | Out-Null
$ticketScript = Join-Path $here "Get-Ticket-EBP.ps1"
if (Test-Path $ticketScript) {
    Copy-Item $ticketScript "$ebpDir\Get-Ticket-EBP.ps1" -Force
    Write-Host "Get-Ticket-EBP.ps1 copiado a $ebpDir." -ForegroundColor Green
} else {
    Write-Warning "No se encontro Get-Ticket-EBP.ps1 para copiar."
}

# ---------------------------------------------------------------------------
# 6. (El ~/.ssh/config lo genera Get-Ticket-EBP.ps1 con el User correcto,
#     la primera vez que el usuario obtiene su ticket. No se crea aca para no
#     dejar un config con el User equivocado.)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# 7. Tarea programada AL LOGON que dispara el kinit en la sesion del usuario
#    Corre como el usuario interactivo (NO SYSTEM), para que el ticket vaya
#    a la sesion de logon del usuario (que es donde VS Code lo lee).
# ---------------------------------------------------------------------------
$taskName = "EBP-KerberosTicket"
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-WindowStyle Normal -ExecutionPolicy Bypass -File `"$ebpDir\Get-Ticket-EBP.ps1`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
# Principal: el usuario interactivo que inicia sesion (grupo Users), nivel normal
$principal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null
Write-Host "Tarea programada '$taskName' creada (dispara kinit al logon)." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 8. Acceso directo en el escritorio (Public) para que el usuario pueda
#    re-obtener el ticket con un click (si no estaba en VPN al iniciar sesion,
#    o si el ticket expiro a mitad del dia).
# ---------------------------------------------------------------------------
$lnkPath = "C:\Users\Public\Desktop\Acceso SSH (214).lnk"
try {
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($lnkPath)
    $sc.TargetPath = "powershell.exe"
    $sc.Arguments  = "-ExecutionPolicy Bypass -File `"$ebpDir\Get-Ticket-EBP.ps1`""
    $sc.WorkingDirectory = $ebpDir
    $sc.IconLocation = "imageres.dll,77"   # icono de llave/credencial
    $sc.Description = "Obtener/renovar el acceso SSH al servidor 214 (Kerberos SSO)"
    $sc.Save()
    Write-Host "Acceso directo creado: $lnkPath" -ForegroundColor Green
} catch {
    Write-Warning "No se pudo crear el acceso directo: $_"
}

Write-Host "`nDeploy completo. Al iniciar sesion, el usuario vera el prompt de kinit" -ForegroundColor Cyan
Write-Host "una vez, y tendra SSO por VS Code/ssh todo el dia." -ForegroundColor Cyan
