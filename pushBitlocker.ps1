$id = (Get-BitLockerVolume -MountPoint C:).KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select -First 1 -ExpandProperty KeyProtectorId
BackupToAAD-BitLockerKeyProtector -MountPoint C: -KeyProtectorId $id
