# Zonasteam - Instalador unico
# Uso: iex (iwr "https://bit.ly/zonasteam" -UseBasicParsing)
$Host.UI.RawUI.WindowTitle = "Zonasteam Installer"

function Log { param($Msg) Write-Host "[$(Get-Date -Format HH:mm:ss)] $Msg" }

# --- Detectar Steam ---
$steam = $null
$paths = @(
    (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath,
    (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath,
    "C:\Program Files (x86)\Steam"
)
foreach ($p in $paths) {
    if ($p -and (Test-Path "$p\steam.exe")) { $steam = $p; break }
}
if (-not $steam) { Log "ERROR: Steam no encontrado"; Read-Host "Presiona Enter"; exit 1 }

Log "Cerrando Steam..."
Get-Process steam -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 2

# --- Descargar e instalar Millennium ---
$millDir = "$steam\millennium"
if (-not (Test-Path $millDir)) {
    Log "Descargando Millennium..."
    $rel = (Invoke-RestMethod "https://api.github.com/repos/SteamClientHomebrew/Millennium/releases/latest")
    $url = $rel.assets | Where-Object { $_.name -like "*windows-x86_64.zip" } | Select-Object -First 1 -ExpandProperty browser_download_url
    $zip = "$env:TEMP\millennium.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip -TimeoutSec 60
    Expand-Archive -Path $zip -DestinationPath $steam -Force
    Remove-Item $zip -Force
    Log "Millennium $($rel.tag_name) instalado"
}

# --- Descargar e instalar plugin ---
$pluginDir = "$steam\millennium\plugins\zonasteam-plugin"
Log "Descargando Zonasteam plugin..."
if (Test-Path $pluginDir) { Remove-Item -Recurse -Force $pluginDir }

# Descargar desde GitHub Releases
$rel = (Invoke-RestMethod "https://api.github.com/repos/SteamAGS/zonasteam/releases/latest" -ErrorAction SilentlyContinue)
if ($rel) {
    $url = $rel.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1 -ExpandProperty browser_download_url
    $zip = "$env:TEMP\zonasteam.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip -TimeoutSec 30
    Expand-Archive -Path $zip -DestinationPath "$steam\millennium\plugins" -Force
    Remove-Item $zip -Force
} else {
    # Fallback: raw de GitHub
    $raw = "https://raw.githubusercontent.com/SteamAGS/zonasteam/master"
    $files = @(
        "plugin.json",
        "backend/main.lua",
        "backend/zonasteam.exe",
        "backend/data/hubcap-cache.json",
        "public/zonasteam.js",
        "public/zonasteam.css",
        "webkit/Zonasteam/zonasteam.js",
        "webkit/Zonasteam/zonasteam.css"
    )
    New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
    foreach ($f in $files) {
        $path = "$pluginDir\$f"
        $dir = Split-Path $path -Parent
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try { Invoke-WebRequest -Uri "$raw/$f" -OutFile $path -TimeoutSec 15 } catch {}
    }
    # Shared redists
    $redists = @("228983_8124929965194586177","228984_2547553897526095397","228988_6645201662696499616","228990_1829726630299308803")
    $rdir = "$pluginDir\backend\data\shared-redists"
    New-Item -ItemType Directory -Path $rdir -Force | Out-Null
    foreach ($r in $redists) {
        try { Invoke-WebRequest -Uri "$raw/backend/data/shared-redists/$r.manifest" -OutFile "$rdir\$r.manifest" -TimeoutSec 15 } catch {}
    }
}
Log "Plugin instalado"

# --- Habilitar plugin ---
$cfg = "$steam\millennium\config\config.json"
if (Test-Path $cfg) {
    $c = Get-Content $cfg -Raw | ConvertFrom-Json
    if (-not $c.plugins) { $c | Add-Member plugins @{} }
    if (-not $c.plugins.enabledPlugins) { $c.plugins | Add-Member enabledPlugins @() }
    if ($c.plugins.enabledPlugins -notcontains "zonasteam-plugin") { $c.plugins.enabledPlugins += "zonasteam-plugin" }
    $c | ConvertTo-Json -Depth 10 | Set-Content $cfg -Encoding UTF8
} else {
    $d = Split-Path $cfg -Parent; New-Item -ItemType Directory -Path $d -Force | Out-Null
    @{plugins=@{enabledPlugins=@("zonasteam-plugin")}} | ConvertTo-Json | Set-Content $cfg -Encoding UTF8
}

Log "Iniciando Steam..."
Start-Process "$steam\steam.exe" -ArgumentList "-clearbeta"
Log "Instalacion completada! Abri la tienda Steam y busca un juego para ver el boton Zonasteam."
Read-Host "Presiona Enter para salir"
