<#
Fix-SSHConfigPerms.ps1
Corrige el dueño y los permisos de ~/.ssh y ~/.ssh/config cuando SSH tira:
  "bad owner or permissions on C:\Users\...\.ssh\config"
Pasa cuando el config lo creo un contexto elevado o quedo con permisos heredados;
SSH exige que .ssh y config sean SOLO del usuario, sin herencia ni otros usuarios.

Detecta solo el perfil y la cuenta:
  - Sin argumentos: usa el usuario y el perfil de la SESION ACTUAL (correr como el usuario).
  - Con -Perfil y -Usuario: para corregir el de otro (correr como ADMIN).

OJO: el nombre de la CARPETA de perfil puede diferir del nombre de la CUENTA
(ej. carpeta C:\Users\nbonet pero cuenta AzureAD\nahuelbonet). El script maneja eso.

Ejemplos:
  # En la sesion del propio usuario (PowerShell NORMAL):
  .\Fix-SSHConfigPerms.ps1

  # Como ADMIN, corrigiendo el de otro perfil:
  .\Fix-SSHConfigPerms.ps1 -Perfil "C:\Users\nbonet" -Usuario "AzureAD\nahuelbonet"
#>

param(
    [string]$Perfil  = "",   # ruta del perfil, ej. C:\Users\nbonet. Vacio = perfil actual
    [string]$Usuario = ""    # cuenta, ej. AzureAD\nahuelbonet. Vacio = usuario actual
)

# Resolver perfil
if (-not $Perfil) { $Perfil = $env:USERPROFILE }
# Resolver usuario (whoami devuelve dominio\usuario, ej. azuread\nahuelbonet)
if (-not $Usuario) { $Usuario = whoami }

$sshDir    = Join-Path $Perfil ".ssh"
$sshConfig = Join-Path $sshDir "config"

Write-Host "== Fix permisos SSH ==" -ForegroundColor Cyan
Write-Host "Perfil : $Perfil"
Write-Host "Usuario: $Usuario"
Write-Host "Carpeta: $sshDir"

if (-not (Test-Path $sshDir)) {
    Write-Host "ERROR: no existe $sshDir" -ForegroundColor Red
    exit 1
}

# 1. Tomar posesion (por si el dueno es otro contexto y da 'acceso denegado')
Write-Host "`n1. Tomando posesion..."
takeown /f $sshDir /r /d s 2>$null | Out-Null
if (Test-Path $sshConfig) { takeown /f $sshConfig 2>$null | Out-Null }

# 2. Resetear herencia y dejar SOLO al usuario
Write-Host "2. Ajustando permisos (solo el usuario, sin herencia)..."
icacls $sshDir /reset 2>$null | Out-Null
icacls $sshDir /inheritance:r 2>$null | Out-Null
icacls $sshDir /grant:r "${Usuario}:(OI)(CI)F" 2>$null | Out-Null

if (Test-Path $sshConfig) {
    icacls $sshConfig /reset 2>$null | Out-Null
    icacls $sshConfig /inheritance:r 2>$null | Out-Null
    icacls $sshConfig /grant:r "${Usuario}:F" 2>$null | Out-Null
}

# 3. Verificar
Write-Host "`n=== Permisos de .ssh ===" -ForegroundColor Green
icacls $sshDir
if (Test-Path $sshConfig) {
    Write-Host "`n=== Permisos de config ===" -ForegroundColor Green
    icacls $sshConfig
    Write-Host "`n=== Contenido del config ===" -ForegroundColor Green
    Get-Content $sshConfig
} else {
    Write-Host "`n(No existe el archivo config todavia)" -ForegroundColor Yellow
}

Write-Host "`nListo. Probar: ssh 214" -ForegroundColor Cyan
