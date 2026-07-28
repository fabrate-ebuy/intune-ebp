<#
reset-office-identity.ps1
Resuelve el error de activacion de Office:
"Otra cuenta de su organizacion ya ha iniciado sesion en este dispositivo"
(a veces con codigo [48v35]), y Office que no activa pese a que el usuario TIENE
licencia (verificado en Entra: SPB con OFFICE_BUSINESS = Success).

VALIDADO en TEST04 / cyalovyy (28/07/2026). Lo que NO alcanzaba:
  - Limpiar solo HKCU\...\Identity\Identities\*  (el CONTENIDO de la clave)
  - Limpiar solo las credenciales (SSO_POP_Device, virtualapp/didlogical)
  - Vaciar solo el Token Broker (WAM)
  - Reinstalar Office (el instalador NO borra los tokens de Entra del sistema)
  - Resetear password y MFA del usuario en Entra
  - Nada de esto servia: el error volvia siempre.

LO QUE SI FUNCIONO (esta secuencia completa + REINICIO):
  1. Cerrar TODO lo de Microsoft (Office, Teams, Outlook, navegadores, OneDrive)
  2. Vaciar  %LOCALAPPDATA%\Microsoft\OneAuth        <- tokens de Entra que sobreviven a todo
  3. Vaciar  %LOCALAPPDATA%\Microsoft\IdentityCache  <- idem
  4. Borrar la CLAVE Identities COMPLETA (no su contenido): Office la recrea limpia
  5. Vaciar el Token Broker (WAM)
  6. REINICIAR el equipo  <- imprescindible
  Post-reinicio Office tomo la cuenta solo, sin pedir login.

IMPORTANTE: correr en CONTEXTO DE USUARIO (PowerShell NORMAL en la sesion del usuario,
NO como admin con otras credenciales) porque limpia el HKCU y el LOCALAPPDATA del usuario.
Si alguna carpeta no se deja borrar (archivo en uso), reiniciar y correr el script de
nuevo ANTES de abrir cualquier app de Microsoft.

NOTA sobre la verificacion: OSPP.VBS /dstatus NO sirve para licencias de suscripcion
(reporta licencias de dispositivo: retail/KMS/MAK) y va a seguir mostrando OOB_GRACE
aunque Office este activado. Verificar en Word -> Archivo -> Cuenta ("Producto activado",
sin el cartel amarillo) o mirando %LOCALAPPDATA%\Microsoft\Office\Licenses.

Es idempotente y seguro: no borra datos, documentos ni perfiles.
#>

Write-Host "== Reset de identidad de Office (OneAuth + IdentityCache + Identities + WAM) ==" -ForegroundColor Cyan
Write-Host "Usuario actual: $(whoami)" -ForegroundColor Gray
Write-Host ""

# --- 1. Cerrar TODO lo de Microsoft ---
Write-Host "1. Cerrando Office, Teams, Outlook, navegadores, OneDrive..."
Get-Process WINWORD,EXCEL,OUTLOOK,POWERPNT,ONENOTE,MSACCESS,MSPUB,Teams,ms-teams,msedge,chrome,firefox,OneDrive `
    -EA SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

# --- 2. OneAuth (tokens de Entra) ---
Write-Host "2. Vaciando OneAuth..."
Remove-Item "$env:LOCALAPPDATA\Microsoft\OneAuth\*" -Recurse -Force -EA SilentlyContinue

# --- 3. IdentityCache ---
Write-Host "3. Vaciando IdentityCache..."
Remove-Item "$env:LOCALAPPDATA\Microsoft\IdentityCache\*" -Recurse -Force -EA SilentlyContinue

# --- 4. Borrar la CLAVE Identities completa (Office la recrea) ---
Write-Host "4. Borrando la clave Identities completa..."
Remove-Item "HKCU:\Software\Microsoft\Office\16.0\Common\Identity\Identities" -Recurse -Force -EA SilentlyContinue
Remove-Item "HKCU:\Software\Microsoft\Office\16.0\Common\Identity\Profiles\*"  -Recurse -Force -EA SilentlyContinue

# --- 5. Token Broker (WAM) ---
Write-Host "5. Vaciando el Token Broker (WAM)..."
$broker = "$env:LOCALAPPDATA\Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy\AC\TokenBroker\Accounts"
if (Test-Path $broker) {
    Remove-Item "$broker\*" -Recurse -Force -EA SilentlyContinue
}

# --- 6. Credenciales de Office/SSO (por prolijidad) ---
Write-Host "6. Limpiando credenciales de Office/SSO..."
cmdkey /delete:MicrosoftAccount:target=SSO_POP_Device   2>$null | Out-Null
cmdkey /delete:WindowsLive:target=virtualapp/didlogical 2>$null | Out-Null

# --- Verificacion ---
Write-Host ""
Write-Host "=== VERIFICACION (todo debe estar vacio / False) ===" -ForegroundColor Cyan
Write-Host "OneAuth:"       -NoNewline; $a = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\OneAuth" -EA SilentlyContinue
Write-Host " $($a.Count) items"
Write-Host "IdentityCache:" -NoNewline; $b = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\IdentityCache" -EA SilentlyContinue
Write-Host " $($b.Count) items"
Write-Host "Identities existe: " -NoNewline
Write-Host (Test-Path "HKCU:\Software\Microsoft\Office\16.0\Common\Identity\Identities")
Write-Host "TokenBroker:"    -NoNewline; $c = Get-ChildItem $broker -EA SilentlyContinue
Write-Host " $($c.Count) items"

Write-Host ""
Write-Host "=== PASO OBLIGATORIO: REINICIAR EL EQUIPO ===" -ForegroundColor Yellow
Write-Host "Sin reinicio NO funciona. Despues del reinicio:" -ForegroundColor Yellow
Write-Host "  - Abrir Word (nada mas antes: ni Teams, ni Edge, ni Outlook)" -ForegroundColor Yellow
Write-Host "  - Deberia tomar la cuenta solo. Si pide login: Archivo -> Cuenta ->" -ForegroundColor Yellow
Write-Host "    Iniciar sesion con la cuenta del usuario + MFA" -ForegroundColor Yellow
Write-Host "  - Si aparece 'Permitir que mi organizacion administre el dispositivo':" -ForegroundColor Yellow
Write-Host "    elegir el link chico 'No, iniciar sesion solo en esta aplicacion'" -ForegroundColor Yellow
Write-Host "  - Verificar en Word -> Archivo -> Cuenta: 'Producto activado'" -ForegroundColor Yellow
Write-Host "    (NO usar OSPP.VBS /dstatus: no sirve para licencias de suscripcion)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Si algo no se dejo borrar (items > 0 arriba), reiniciar y correr este" -ForegroundColor Yellow
Write-Host "script de nuevo ANTES de abrir apps de Microsoft." -ForegroundColor Yellow
