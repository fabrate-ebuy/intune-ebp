<#
Get-Ticket-EBP.ps1
Obtiene el ticket Kerberos para SSO por SSH al 214.
Corre en la sesion del USUARIO (NO elevada), donde VS Code / ssh leen el cache MSLSA.

- Pide usuario de dominio + password (NO guarda el password).
- Escribe/actualiza el "User <usuario>" en el ~/.ssh/config del Host 214,
  asi 'ssh 214' funciona directo con el usuario correcto.
- Si ya hay ticket valido, no molesta.

Lo dispara la tarea programada al login. Tambien se puede correr a mano.
El ticket dura ~24h (segun krb5.ini). Al expirar, correr de nuevo.
#>

$kinit = "C:\Program Files\MIT\Kerberos\bin\kinit.exe"
$klist = "C:\Program Files\MIT\Kerberos\bin\klist.exe"
$realm = "INFRA.EBUYPLACE.COM"

# Cache MSLSA en esta sesion (por si la variable de maquina no llego)
$env:KRB5CCNAME = "MSLSA:"

# Si ya hay ticket valido, no pedir de nuevo
$tiene = $false
try {
    $out = & $klist 2>&1
    if ($out -match "krbtgt/$realm") { $tiene = $true }
} catch {}

if ($tiene) {
    Write-Host "Ya existe un ticket Kerberos valido. SSO activo." -ForegroundColor Green
    & $klist
    Start-Sleep -Seconds 2
    exit 0
}

Write-Host "=== Acceso SSH al servidor de desarrollo (214) ===" -ForegroundColor Cyan
Write-Host "Ingresar usuario de dominio (SIN INFRA) y password." -ForegroundColor Yellow

$user = Read-Host "Usuario de dominio"
if ([string]::IsNullOrWhiteSpace($user)) {
    Write-Host "No se ingreso usuario. Cancelado." -ForegroundColor Red
    exit 1
}

$principal = "$user@$realm"
Write-Host "Solicitando ticket para $principal ..." -ForegroundColor Cyan
& $kinit $principal

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nTicket obtenido." -ForegroundColor Green

    # --- Escribir/actualizar el User en el ~/.ssh/config para el Host 214 ---
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
    $cfg = Join-Path $sshDir "config"

    $bloque = @"
Host 214
    HostName win2019test.infra.ebuyplace.com
    User INFRA\$user
    GSSAPIAuthentication yes
    GSSAPIDelegateCredentials yes
"@

    if (Test-Path $cfg) {
        $content = Get-Content $cfg -Raw
        if ($content -match "(?ms)Host\s+214\b.*?(?=(^Host\s)|\Z)") {
            # reemplazar el bloque 214 existente (para actualizar el User)
            $content = [regex]::Replace($content, "(?ms)Host\s+214\b.*?(?=(^Host\s)|\Z)", ($bloque + "`n"))
            Set-Content -Path $cfg -Value $content.TrimEnd() -Encoding ascii
        } else {
            Add-Content -Path $cfg -Value "`n$bloque" -Encoding ascii
        }
    } else {
        Set-Content -Path $cfg -Value $bloque -Encoding ascii
    }
    Write-Host "Config SSH actualizado con User=$user." -ForegroundColor Green
} else {
    Write-Host "`nNo se pudo obtener el ticket. Revisar usuario/password/conexion." -ForegroundColor Red
}
Start-Sleep -Seconds 3
