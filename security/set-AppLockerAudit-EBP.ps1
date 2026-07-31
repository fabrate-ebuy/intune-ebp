<#
Set-AppLockerAudit-EBP.ps1
Aplica las reglas base de AppLocker en modo AUDITORIA usando Set-AppLockerPolicy
(cmdlet nativo), en vez del CSP por OMA-URI (que no aplicaba en el build 26200:
Intune reportaba "Correcto" pero las reglas nunca llegaban al equipo).

Reglas base: permitir Program Files + Windows + Administradores locales, para EXE,
MSI y Script. Modo AuditOnly (no bloquea, solo registra en el log de AppLocker).
Los DESA (admin local) quedan sin restriccion por la regla de Administradores.

Desplegar por Intune: Dispositivos > Scripts y correcciones > Scripts de plataforma
> Windows 10 y posteriores. "Ejecutar con credenciales de usuario: NO" (corre como
SYSTEM). "Host de 64 bits: Si". Asignar al grupo de prueba primero.

Idempotente: usa IDs fijos, correrlo varias veces no duplica reglas.
#>

$ErrorActionPreference = "Stop"

$AppLockerXML = @'
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="AuditOnly">
    <FilePathRule Id="921cc481-6e17-4653-8f75-050b80acca20" Name="(Default) Program Files" Description="Permitir Program Files" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%PROGRAMFILES%\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="a61c8b2c-a319-4cd0-9690-d2177cad7b51" Name="(Default) Windows" Description="Permitir Windows" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%WINDIR%\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="fd686d83-a829-4351-8ff4-27c7de5755d2" Name="(Default) Administradores - todo" Description="Permitir todo a Administradores locales" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions><FilePathCondition Path="*" /></Conditions>
    </FilePathRule>
  </RuleCollection>
  <RuleCollection Type="Msi" EnforcementMode="AuditOnly">
    <FilePathRule Id="5bfcc334-2e10-4840-ae59-d8975ab4efab" Name="(Default) MSI Program Files" Description="Permitir MSI Program Files" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%PROGRAMFILES%\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="14a1dbb1-3ef5-46aa-bf7d-2b475960eb53" Name="(Default) Windows Installer" Description="Permitir Windows Installer" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%WINDIR%\Installer\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="3a241d7a-1153-48b4-938b-bfa0e52b2707" Name="(Default) MSI Administradores" Description="Permitir MSI a Administradores" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions><FilePathCondition Path="*" /></Conditions>
    </FilePathRule>
  </RuleCollection>
  <RuleCollection Type="Script" EnforcementMode="AuditOnly">
    <FilePathRule Id="0670c87a-64da-44fe-93ef-95bda6ed7811" Name="(Default) Script Program Files" Description="Permitir Script Program Files" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%PROGRAMFILES%\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="aa746a50-250c-4fa2-bfbb-1a55677054f1" Name="(Default) Script Windows" Description="Permitir Script Windows" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%WINDIR%\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="92f9b819-21c8-47a3-8321-7d12f9f1f0a1" Name="(Default) Script Administradores" Description="Permitir Script a Administradores" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions><FilePathCondition Path="*" /></Conditions>
    </FilePathRule>
  </RuleCollection>
</AppLockerPolicy>
'@

# Guardar el XML temporal
$TempPath = "$env:TEMP\AppLockerPolicy-EBP.xml"
$AppLockerXML | Out-File -FilePath $TempPath -Encoding Unicode -Force

# Aplicar la politica (Set = reemplaza la local por esta; usar -Merge si se quiere combinar)
Set-AppLockerPolicy -XmlPolicy $TempPath

# Asegurar el servicio AppIDSvc en Automatico y corriendo
Set-Service -Name AppIDSvc -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service -Name AppIDSvc -ErrorAction SilentlyContinue

# Limpieza
Remove-Item -Path $TempPath -Force -ErrorAction SilentlyContinue

# Verificacion (queda en el log de la IME si se corre por Intune)
$eff = Get-AppLockerPolicy -Effective -Xml
if ($eff -match "FilePathRule") {
    Write-Host "OK: AppLocker aplicado en modo Auditoria. Reglas efectivas presentes."
    exit 0
} else {
    Write-Host "ADVERTENCIA: la politica no quedo efectiva. Revisar AppIDSvc y el log de AppLocker."
    exit 1
}
