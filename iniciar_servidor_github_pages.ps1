param(
    [int]$Puerto = 3838,
    [switch]$SinGitPush
)

$raiz = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $raiz

Write-Host "==============================================================================" -ForegroundColor DarkGreen
Write-Host " GEOVISOR PDU ANTA (2024 - 2034) - SERVIDOR CONEXION GITHUB PAGES" -ForegroundColor Green
Write-Host " Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor DarkGreen
Write-Host ""

# 1. Verificar herramienta Cloudflare Tunnel
$cloudflared = Join-Path $raiz "tools\cloudflared.exe"
if (-not (Test-Path $cloudflared)) {
    Write-Host "[*] Descargando herramienta Cloudflare Tunnel en tools\..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path (Join-Path $raiz "tools") -Force | Out-Null
    curl.exe -L -o $cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
}

# 2. Localizar Rscript
$rscriptCmd = "Rscript.exe"
$candidatos = @(
    "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe",
    "C:\Program Files\R\R-4.6.1\bin\Rscript.exe"
)
foreach ($c in $candidatos) {
    if (Test-Path $c) {
        $rscriptCmd = $c
        break
    }
}
if ($rscriptCmd -eq "Rscript.exe") {
    $rFound = Get-ChildItem "C:\Program Files\R" -Filter "Rscript.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if ($rFound) { $rscriptCmd = $rFound }
}

# 3. Iniciar R Shiny en segundo plano (host 0.0.0.0 para red local y tunel)
Write-Host "[1/3] Iniciando motor del GeoVisor en puerto $Puerto..." -ForegroundColor Cyan
$runServerScript = Join-Path $raiz "run_server.R"
$rProcess = Start-Process -FilePath $rscriptCmd -ArgumentList $runServerScript -PassThru -NoNewWindow

Start-Sleep -Seconds 3

# 4. Iniciar Cloudflare Tunnel y capturar URL publica
Write-Host "[2/3] Estableciendo tunel seguro HTTPS con Cloudflare..." -ForegroundColor Cyan
$cfLog = Join-Path $raiz "outputs\cloudflared_live.log"
if (-not (Test-Path (Join-Path $raiz "outputs"))) { New-Item -ItemType Directory -Path (Join-Path $raiz "outputs") -Force | Out-Null }
if (Test-Path $cfLog) { Remove-Item $cfLog -Force }

$cfArgs = @("tunnel", "--url", "http://127.0.0.1:$Puerto")
$cfProcess = Start-Process -FilePath $cloudflared -ArgumentList $cfArgs -RedirectStandardError $cfLog -PassThru -NoNewWindow

# Esperar a que cloudflared genere la URL publica
$urlPublica = ""
$intentos = 0
while ($intentos -lt 25 -and [string]::IsNullOrEmpty($urlPublica)) {
    Start-Sleep -Seconds 1
    $intentos++
    if (Test-Path $cfLog) {
        $lineas = Get-Content $cfLog -ErrorAction SilentlyContinue
        foreach ($linea in $lineas) {
            if ($linea -match 'https://[a-zA-Z0-9-]+\.trycloudflare\.com') {
                $candidata = $matches[0]
                if ($candidata -notmatch 'api\.trycloudflare\.com') {
                    $urlPublica = $candidata
                    break
                }
            }
        }
    }
}

$endpointFile = Join-Path $raiz "docs\server_endpoint.json"
$ahora = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

if ([string]::IsNullOrEmpty($urlPublica)) {
    Write-Host "[!] Advertencia: No se pudo capturar automaticamente la URL de Cloudflare en 25 segundos." -ForegroundColor Red
    Write-Host "    Verifique el archivo outputs\cloudflared_live.log para copiarla manualmente." -ForegroundColor Yellow
} else {
    Write-Host "    URL del tunel activo: $urlPublica" -ForegroundColor Green
    
    # 5. Actualizar docs\server_endpoint.json
    $endpointData = [ordered]@{
        url = $urlPublica
        status = "online"
        updated_at = $ahora
        institucion = "Municipalidad Provincial de Anta"
        gerencia = "Gerencia de Desarrollo Urbano y Rural (GDUR)"
        proyecto = "Plan de Desarrollo Urbano de Anta (2024 - 2034)"
        ordenanza = "Ordenanza Municipal No 04-2025-A-MPA/C"
        mesa_de_partes = "mesadepartesvirtual@munianta.gob.pe"
    }
    $jsonContent = $endpointData | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($endpointFile, $jsonContent, [System.Text.Encoding]::UTF8)
    Write-Host "[3/3] Archivo docs\server_endpoint.json actualizado." -ForegroundColor Green

    # 6. Sincronizar con GitHub si no se indico -SinGitPush
    if (-not $SinGitPush) {
        $cambios = git status --porcelain docs/server_endpoint.json
        if ($cambios) {
            Write-Host "    Sincronizando con GitHub Pages (antapat/pdu_anta_2024_2034)..." -ForegroundColor Cyan
            git add docs/server_endpoint.json
            git commit -m "chore(pages): activar servidor en vivo [skip ci]" --quiet
            git push origin main
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    Sincronizacion con GitHub completada exitosamente." -ForegroundColor Green
            } else {
                Write-Host "    Nota: No se pudo hacer push automatico a GitHub (verifique conexion o credenciales)." -ForegroundColor Yellow
            }
        }
    }
}

Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host " EL GEOVISOR ESTA EN LINEA Y DISPONIBLE PUBLICAMENTE EN:" -ForegroundColor Yellow
Write-Host ""
Write-Host "   https://antapat.github.io/pdu_anta_2024_2034/" -ForegroundColor White -BackgroundColor DarkGreen
Write-Host ""
if (-not [string]::IsNullOrEmpty($urlPublica)) {
    Write-Host " Enlace de tunel directo: $urlPublica" -ForegroundColor Cyan
}
Write-Host " Enlace de red local municipal: http://localhost:$Puerto" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host " [Presione Ctrl + C en cualquier momento para apagar el servidor]" -ForegroundColor Magenta
Write-Host ""

try {
    # Mantener el script en espera activa
    while ($true) {
        Start-Sleep -Seconds 2
        if ($rProcess.HasExited -or $cfProcess.HasExited) {
            Write-Host "[!] Uno de los procesos se detuvo inesperadamente." -ForegroundColor Red
            break
        }
    }
} finally {
    Write-Host "`nCerrando servidor y servicios en segundo plano..." -ForegroundColor Yellow
    
    if ($cfProcess -and -not $cfProcess.HasExited) {
        Stop-Process -Id $cfProcess.Id -Force -ErrorAction SilentlyContinue
    }
    if ($rProcess -and -not $rProcess.HasExited) {
        Stop-Process -Id $rProcess.Id -Force -ErrorAction SilentlyContinue
    }

    # Marcar fuera de linea en docs\server_endpoint.json
    $offlineAhora = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $offlineData = [ordered]@{
        url = ""
        status = "offline"
        updated_at = $offlineAhora
        institucion = "Municipalidad Provincial de Anta"
        gerencia = "Gerencia de Desarrollo Urbano y Rural (GDUR)"
        proyecto = "Plan de Desarrollo Urbano de Anta (2024 - 2034)"
        ordenanza = "Ordenanza Municipal No 04-2025-A-MPA/C"
        mesa_de_partes = "mesadepartesvirtual@munianta.gob.pe"
    }
    $jsonOffline = $offlineData | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($endpointFile, $jsonOffline, [System.Text.Encoding]::UTF8)
    
    if (-not $SinGitPush) {
        $cambios = git status --porcelain docs/server_endpoint.json
        if ($cambios) {
            git add docs/server_endpoint.json
            git commit -m "chore(pages): servidor fuera de linea [skip ci]" --quiet
            git push origin main
        }
    }

    Write-Host "Servidor detenido correctamente. Estado fuera de linea registrado." -ForegroundColor Green
}
