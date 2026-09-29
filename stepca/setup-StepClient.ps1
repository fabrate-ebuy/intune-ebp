$bin = 'C:\Program Files\Smallstep\bin'
New-Item -ItemType Directory $bin -Force | Out-Null

# step (binario directo, ruta fija)
if (-not (Test-Path "$bin\step.exe")) {
    Invoke-WebRequest 'https://github.com/smallstep/cli/releases/latest/download/step_windows_amd64.zip' -OutFile "$env:TEMP\step.zip" -UseBasicParsing
    Expand-Archive "$env:TEMP\step.zip" "$env:TEMP\step-x" -Force
    Copy-Item (Get-ChildItem "$env:TEMP\step-x" -Recurse -Filter step.exe | Select-Object -First 1).FullName "$bin\step.exe" -Force
}
$mp = [Environment]::GetEnvironmentVariable('Path','Machine')
if ($mp -notlike "*$bin*") { [Environment]::SetEnvironmentVariable('Path', "$mp;$bin", 'Machine') }

# WinSSH-Pageant (extraccion del MSI, version fija, hash verificado)
$pgDir = 'C:\Program Files\WinSSH-Pageant'
$pgExe = "$pgDir\winssh-pageant.exe"
if (-not (Test-Path $pgExe)) {
    $msi = "$env:TEMP\winssh-pageant.msi"
    Invoke-WebRequest 'https://github.com/ndbeals/winssh-pageant/releases/download/v2.3.1/winssh-pageant-v2.3.1_amd64.msi' -OutFile $msi -UseBasicParsing
    if ((Get-FileHash $msi -Algorithm SHA256).Hash -ne 'D2E857B2BBD12ABAE9D7B7E3D54B284F9AD901C5E8AF38CDCC6DEB5556D95093') { Write-Output 'Hash de WinSSH-Pageant invalido'; exit 1 }
    Start-Process msiexec.exe -ArgumentList "/a `"$msi`" /qn TARGETDIR=`"$env:TEMP\pg-x`"" -Wait
    New-Item -ItemType Directory $pgDir -Force | Out-Null
    Copy-Item (Get-ChildItem "$env:TEMP\pg-x" -Recurse -Filter winssh-pageant.exe | Select-Object -First 1).FullName $pgExe -Force
}
# Arranque automatico en cada inicio de sesion (todos los usuarios)
New-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'WinSSH-Pageant' -Value "`"$pgExe`"" -PropertyType String -Force | Out-Null

# ssh-agent
Set-Service ssh-agent -StartupType Automatic
Start-Service ssh-agent

# Acceso directo en el escritorio publico -> script del toolkit
$target = 'C:\ProgramData\EBP\stepca\renovar-Cert.ps1'
$pub = [Environment]::GetFolderPath('CommonDesktopDirectory')
$w = New-Object -ComObject WScript.Shell
$sc = $w.CreateShortcut("$pub\Renovar certificado.lnk")
$sc.TargetPath   = 'powershell.exe'
$sc.Arguments    = "-ExecutionPolicy Bypass -File `"$target`""
$sc.IconLocation = '%SystemRoot%\System32\imageres.dll,25'
$sc.Save()

if (-not (Test-Path "$bin\step.exe")) { Write-Output 'step no instalado'; exit 1 }
Write-Output 'OK'
