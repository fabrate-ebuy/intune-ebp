$krbDir = "C:\ProgramData\MIT\Kerberos5"
New-Item -ItemType Directory -Force -Path $krbDir | Out-Null

@"
[libdefaults]
    default_realm = INFRA.EBUYPLACE.COM
    dns_lookup_kdc = true
    dns_lookup_realm = false

[realms]
    INFRA.EBUYPLACE.COM = {
        kdc = dc1.infra.ebuyplace.com
        kdc = dc2.infra.ebuyplace.com
        admin_server = dc1.infra.ebuyplace.com
    }

[domain_realm]
    .infra.ebuyplace.com = INFRA.EBUYPLACE.COM
    infra.ebuyplace.com = INFRA.EBUYPLACE.COM
"@ | Set-Content -Path "$krbDir\krb5.ini" -Encoding ascii
