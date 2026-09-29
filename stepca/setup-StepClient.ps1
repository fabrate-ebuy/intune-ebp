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

# WinSSH-Pageant
$wg = (Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1).FullName
if ($wg) { & $wg install --id NathanBeals.WinSSH-Pageant --silent --accept-package-agreements --accept-source-agreements --disable-interactivity }

# ssh-agent
Set-Service ssh-agent -StartupType Automatic
Start-Service ssh-agent

# Acceso directo en el escritorio publico -> script del toolkit
$target = 'C:\ProgramData\EBP\stepca\Renovar-Cert.ps1'
$pub = [Environment]::GetFolderPath('CommonDesktopDirectory')
$w = New-Object -ComObject WScript.Shell
$sc = $w.CreateShortcut("$pub\Renovar certificado.lnk")
$sc.TargetPath   = 'powershell.exe'
$sc.Arguments    = "-ExecutionPolicy Bypass -File `"$target`""
$sc.IconLocation = '%SystemRoot%\System32\imageres.dll,25'
$sc.Save()

if (-not (Test-Path "$bin\step.exe")) { Write-Output 'step no instalado'; exit 1 }
Write-Output 'OK'
