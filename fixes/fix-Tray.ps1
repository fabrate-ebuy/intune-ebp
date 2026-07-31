schtasks /delete /tn "ShowAllTrayIcons" /f
Set-ItemProperty -Path 'Registry::HKCU\Control Panel\NotifyIconSettings\*' -Name 'IsPromoted' -Value 0 -Type DWord
