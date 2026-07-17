# Zonasteam - Instalador
# iex (iwr "https://raw.githubusercontent.com/SteamAGS/zonasteam/master/install.ps1" -UseBasicParsing)
$Host.UI.RawUI.WindowTitle = "Zonasteam Installer"

$rel = Invoke-RestMethod "https://api.github.com/repos/SteamAGS/zonasteam/releases/latest"
$asset = $rel.assets | Where-Object { $_.name -like "*App.zip" } | Select-Object -First 1
$zip = "$env:TEMP\zonasteam.zip"
Write-Host "Descargando Zonasteam..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -TimeoutSec 60
$dir = "$env:LOCALAPPDATA\Zonasteam"
Expand-Archive -Path $zip -DestinationPath $dir -Force
Remove-Item $zip -Force
Write-Host "Instalado en $dir"
Start-Process "$dir\ZonasteamApp.exe"
