# renovar-Cert.ps1 - lo ejecuta el usuario desde el acceso directo
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

# Entrada SSH: reemplaza cualquier bloque 'Host 214' previo (Kerberos) por el de certificado
$cfg = "$env:USERPROFILE\.ssh\config"
New-Item -ItemType Directory "$env:USERPROFILE\.ssh" -Force | Out-Null
$lines = @(); if (Test-Path $cfg) { $lines = Get-Content $cfg }
if (-not ($lines -match '^\s*HostName\s+10\.30\.20\.214\s*$')) {
    $out = @(); $skip = $false
    foreach ($l in $lines) {
        if ($l -match '^\s*Host\s+214\s*$') { $skip = $true; continue }
        if ($skip -and $l -match '^\s*Host\s+') { $skip = $false }
        if (-not $skip) { $out += $l }
    }
    $out += '', 'Host 214', '    HostName 10.30.20.214', "    User $u"
    [System.IO.File]::WriteAllText($cfg, ($out -join "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
}

# WinSCP: sitio '214' (solo si no existe)
$ws = 'HKCU:\Software\Martin Prikryl\WinSCP 2\Sessions\214'
if (-not (Test-Path $ws)) {
    New-Item $ws -Force | Out-Null
    New-ItemProperty $ws -Name HostName -Value '10.30.20.214' -PropertyType String -Force | Out-Null
    New-ItemProperty $ws -Name UserName -Value $u -PropertyType String -Force | Out-Null
}

# WinSCP: acceso directo 'WinSCP 214' en el escritorio del usuario
$scp = @("$env:LOCALAPPDATA\Programs\WinSCP\WinSCP.exe",'C:\Program Files (x86)\WinSCP\WinSCP.exe','C:\Program Files\WinSCP\WinSCP.exe') | Where-Object { Test-Path $_ } | Select-Object -First 1
$lnk = "$([Environment]::GetFolderPath('Desktop'))\WinSCP 214.lnk"
if ($scp -and -not (Test-Path $lnk)) {
    $w  = New-Object -ComObject WScript.Shell
    $sc = $w.CreateShortcut($lnk)
    $sc.TargetPath = $scp
    $sc.Arguments  = '"214" /Desktop'
    $sc.Save()
}

# Certificado
if (-not (ssh-add -L 2>$null | Select-String $upn)) {
    Write-Host 'Autenticate en Office 365 en el navegador...' -ForegroundColor Yellow
    & $s ssh login $upn --provisioner Entra
}

if (ssh-add -L 2>$null | Select-String $upn) {
    Write-Host 'Certificado vigente. Ya podes usar VSCode (host 214), ssh 214 o WinSCP 214.' -ForegroundColor Green
} else {
    Write-Host 'No se obtuvo certificado. Si la CA se reinicio hace poco, espera 5-10 min y reintenta.' -ForegroundColor Red
}
Read-Host 'Enter para cerrar'
