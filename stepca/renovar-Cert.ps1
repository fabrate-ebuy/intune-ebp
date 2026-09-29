$s  = 'C:\Program Files\Smallstep\bin\step.exe'
$ca = 'https://10.30.20.5:8443'
$fp = '3d60d1682305ef6c08b6018e85a3cd6889040b754c40c8521d7d17c8c01bcc98'

$upn = (whoami /upn 2>$null)
if ([string]::IsNullOrWhiteSpace($upn)) { $upn = Read-Host 'Cuenta de Office 365 (nombre@e-buyplace.com)' }
$u = $upn.Split('@')[0]

if (-not (Test-Path $s)) { Write-Host 'Falta step: el equipo no recibio el despliegue. Avisar a IT.' -ForegroundColor Red; Read-Host 'Enter'; exit 1 }
if ((Get-Service ssh-agent).Status -ne 'Running') { Write-Host 'ssh-agent detenido. Avisar a IT.' -ForegroundColor Red; Read-Host 'Enter'; exit 1 }

# Primera vez: confiar en la CA
if (-not (Test-Path "$env:USERPROFILE\.step\certs\root_ca.crt")) {
    & $s ca bootstrap --ca-url $ca --fingerprint $fp --force
}

# Primera vez: entrada SSH
$cfg = "$env:USERPROFILE\.ssh\config"
New-Item -ItemType Directory "$env:USERPROFILE\.ssh" -Force | Out-Null
if (-not (Test-Path $cfg) -or -not (Select-String -Path $cfg -Pattern '^\s*Host\s+desarrollo\b' -Quiet)) {
    Add-Content $cfg "`nHost desarrollo`n    HostName 10.30.20.214`n    User $u"
}

# Certificado
if (-not (ssh-add -L 2>$null | Select-String $upn)) {
    Write-Host 'Autenticate en Office 365 en el navegador...' -ForegroundColor Yellow
    & $s ssh login $upn --provisioner Entra
}

if (ssh-add -L 2>$null | Select-String $upn) {
    Write-Host 'Certificado vigente. Ya podes usar VSCode (host desarrollo), ssh desarrollo o WinSCP.' -ForegroundColor Green
} else {
    Write-Host 'No se obtuvo certificado. Si la CA se reinicio hace poco, espera 5-10 min y reintenta.' -ForegroundColor Red
}
Read-Host 'Enter para cerrar'
