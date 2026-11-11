<powershell>
# Packer build-time only: open WinRM over HTTPS with a self-signed cert so the
# provisioner can connect. The baked AMI's runtime userdata does not re-run this.
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My
New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * `
         -CertificateThumbPrint $cert.Thumbprint -Force
netsh advfirewall firewall add rule name="WinRM HTTPS" dir=in action=allow protocol=TCP localport=5986
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
Restart-Service WinRM
</powershell>
