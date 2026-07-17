# ============================================================
# debloat-EBP.ps1 - Quita bloatware de consumo de Windows 11
# Ejecutar como SYSTEM desde Intune (Script de plataforma) o Win32.
# Quita para el usuario actual Y del provisioning (usuarios nuevos).
# ============================================================

$log = "C:\ProgramData\EBP\debloat.log"
if (!(Test-Path "C:\ProgramData\EBP")) { New-Item -ItemType Directory -Path "C:\ProgramData\EBP" -Force | Out-Null }
function Log($m){ "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" | Out-File $log -Append }

Log "=== Debloat iniciado ==="

# Lista de apps a quitar (nombre del paquete Appx, admite comodines)
$quitar = @(
    # Juegos y Xbox
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxGameOverlay"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.GamingApp"
    "Microsoft.549981C3F5F10"          # Cortana
    "king.com.CandyCrush*"
    "Microsoft.MicrosoftSolitaireCollection"
    # Phone Link
    "Microsoft.YourPhone"
    # Teams personal (consumer)
    "MicrosoftTeams"                   # el consumer/chat (NO es el Teams corporativo de Office)
    "MSTeams"                          # variante nueva del consumer
    # Bing
    "Microsoft.BingNews"
    "Microsoft.BingWeather"
    "Microsoft.BingSearch"
    # Otros de consumo
    "Microsoft.MixedReality.Portal"
    "Microsoft.People"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.ZuneMusic"              # Groove Music
    "Microsoft.ZuneVideo"             # Movies & TV
    "Microsoft.Getstarted"            # Tips / Get Started
    "Microsoft.MicrosoftOfficeHub"    # "Office" hub promocional (no es Office real)
)

# NOTA: se CONSERVAN (no se tocan): Clipchamp, Outlook, Calculator, SnippingTool,
#       Paint, Photos, Terminal, Notepad, Store, WindowsSecurity, StickyNotes, Camera

foreach ($app in $quitar) {
    try {
        # Quitar para usuarios actuales
        Get-AppxPackage -AllUsers -Name $app -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        # Quitar del provisioning (para que no se reinstale en perfiles nuevos)
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $app } |
            ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue }
        Log "Quitado: $app"
    } catch {
        Log "ERROR quitando $app : $($_.Exception.Message)"
    }
}

Log "=== Debloat finalizado ==="
exit 0
