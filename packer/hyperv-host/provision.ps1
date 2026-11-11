# Bake the Hyper-V host AMI: role + management tools + AWS PowerShell module.
$ErrorActionPreference = "Stop"

Install-WindowsFeature -Name Hyper-V -IncludeManagementTools

# AWS.Tools for Read-S3Object used by runtime userdata.
Install-PackageProvider -Name NuGet -Force
Install-Module -Name AWS.Tools.S3 -Force -AllowClobber

Write-Host "hyperv-host provisioning complete (reboot pending for role activation)"
