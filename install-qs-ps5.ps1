# Title: Qlik Sense 3.1 Automated Installer
# Author: Clint Carr
# Date: 24 October 2016
# Note: Requires .NET Framework 4.5.2 or higher to use

# usage install-qs.ps1 serial '' control '' name '' organization '' serviceAccount '' serviceAccount2 '' serviceAccountPass '' PostgresAccountPass '' hostname ''


Param(
    [string]$serial,
    [string]$control,
    [string]$name,
    [string]$organization,
    [string]$serviceAccount,
    [string]$serviceAccount2,
    [string]$serviceAccountPass,
    [string]$PostgresAccountPass,
    [string]$hostname
)

#$Password = Read-Host -AsSecureString
#New-LocalUser "Qservice" -Password $Password -FullName "Qlik Service Account"


[Environment]::SetEnvironmentVariable("PGPASSWORD", "$PostgresAccountPass", "Machine")
$compname=(Get-WmiObject win32_computersystem).DNSHostName
$date = Get-Date -format "yyyyMMddHHmm"

New-Item -ItemType directory -Path C:\installation\qlik-cli -force
"$date Created path: c:\installation\qlik-cli" | Out-File -filepath C:\installation\qsInstallLog.txt -append

$source = "https://da3hntz84uekx.cloudfront.net/QlikSense/3.1.1/1/_MSI/Qlik_Sense_setup.exe"
$destination = "c:\installation\Qlik_Sense_setup.exe"
Invoke-WebRequest $source -OutFile $destination
"$date Downloaded Qlik_Sense_setup.exe" | Out-File -filepath C:\installation\qsInstallLog.txt -append

$source = "https://github.com/ahaydon/Qlik-Cli/archive/master.zip"
$destination = "c:\installation\qlik-cli\qlik-cli.zip"
Invoke-WebRequest $source -OutFile $destination
"$date Downloaded qlik-cli.zip" | Out-File -filepath C:\installation\qsInstallLog.txt -append


#$shell = New-Object -ComObject shell.application
#$zip = $shell.NameSpace("C:\installation\qlik-cli\qlik-cli.zip")
#foreach ($item in $zip.items()) {
#  $shell.Namespace("c:\installation\qlik-cli").CopyHere($item)
#}
# PowerShell5.0
Expand-Archive C:\installation\qlik-cli\qlik-cli.zip -dest C:\installation\qlik-cli
"$date Unzipped qlik-cli" | Out-File -filepath C:\installation\qsInstallLog.txt -append

New-Item -ItemType directory -Path C:\Windows\System32\WindowsPowerShell\v1.0\Modules\Qlik-Cli -force
Copy-Item C:\Installation\qlik-cli\Qlik-Cli-master\Qlik-Cli.psm1 C:\Windows\System32\WindowsPowerShell\v1.0\Modules\Qlik-Cli\
Import-Module Qlik-Cli.psm1
"$date Imported qlik-cli to PowerShell Modules" | Out-File -filepath C:\installation\qsInstallLog.txt -append

Write-Host "Adding service account user to local administrators group"
([ADSI]"WinNT://$hostname/administrators,group").psbase.Invoke("Add",([ADSI]"WinNT://$serviceAccount2").path)
"$date Added $serviceAccount2 to local administrators group" | Out-File -filepath C:\installation\qsInstallLog.txt -append

Write-Host "Installing Qlik Sense Enterprise"
Invoke-Command -ScriptBlock {Start-Process -FilePath "c:\installation\Qlik_Sense_setup.exe" -ArgumentList "-s dbpassword=$PostgresAccountPass hostname=$hostname userwithdomain=$serviceAccount password=$serviceAccountPass" -Wait -PassThru}
"$date Installed Qlik Sense 3.1.1" | Out-File -filepath C:\installation\qsInstallLog.txt -append

Write-Host "Opening TCP: 443, 4244"
New-NetFirewallRule -DisplayName "Qlik Sense" -Direction Inbound -LocalPort 443, 4244 -Protocol TCP -Action Allow
"$date Opened TCP 443, 4244" | Out-File -filepath C:\installation\qsInstallLog.txt -append


write-host "Connecting to Qlik Sense Proxy"
$statusCode = 0
while ($StatusCode -ne 200) {
  write-host "StatusCode is " $StatusCode
  start-Sleep -s 5
  try { $statusCode = (invoke-webrequest  https://$hostname/qps/user).statusCode }
Catch { 
    write-host "Server down, waiting 5 seconds"
    start-Sleep -s 5
    }
}

Write-Host "Connecting to Qlik Sense Repository Service"
Connect-Qlik $hostname -UseDefaultCredentials
"$date Connected to $hostname" | Out-File -filepath C:\installation\qsInstallLog.txt -append

Write-Host "Setting license"
Set-QlikLicense -serial $serial -control $control -name $name -organization $organization
"$date Written license: $serial" | Out-File -filepath C:\installation\qsInstallLog.txt -append

[Environment]::SetEnvironmentVariable("PGPASSWORD", "$null", "Machine")