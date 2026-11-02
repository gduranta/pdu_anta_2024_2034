param(
    [int]$Puerto = 3838,
    [switch]$SinGitPush
)

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $raiz

Write-Host "==============================================================================" -ForegroundColor DarkGreen
Write-Host " GEOVISOR PDU ANTA - GITHUB PAGES + TUNEL HTTPS" -ForegroundColor Green
Write-Host " Municipalidad Provincial de Anta" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor DarkGreen

$cloudflared = Join-Path $raiz "tools\cloudflared.exe"
$rscriptCmd = (Get-Command "Rscript.exe" -ErrorAction SilentlyContinue).Source
if (-not $rscriptCmd) {
    $rscriptCmd = Get-ChildItem "C:\Program Files\R" -Filter "Rscript.exe" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $rscriptCmd) { throw "No se encontró Rscript.exe. Instale R y agréguelo al PATH." }

if (-not (Test-Path $cloudflared)) {
    New-Item -ItemType Directory -Path (Split-Path $cloudflared) -Force | Out-Null
    Write-Host "Descargando Cloudflare Tunnel..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile $cloudflared
}

$outputs = Join-Path $raiz "outputs"
if (-not (Test-Path $outputs)) { New-Item -ItemType Directory -Path $outputs -Force | Out-Null }
$cfLog = Join-Path $outputs "cloudflared_live.log"
$cfOut = Join-Path $outputs "cloudflared_stdout.log"
$rLog = Join-Path $outputs "shiny_server.log"
$rOut = Join-Path $outputs "shiny_stdout.log"
$endpointFile = Join-Path $raiz "docs\server_endpoint.json"
$rProcess = $null
$cfProcess = $null

try {
    $env:PDU_SHINY_HOST = "127.0.0.1"
    $env:PDU_SHINY_PORT = "$Puerto"
    if (Test-Path $rLog) { Remove-Item -LiteralPath $rLog -Force }
    if (Test-Path $rOut) { Remove-Item -LiteralPath $rOut -Force }
    Write-Host "Iniciando Shiny solo en loopback, puerto $Puerto..." -ForegroundColor Cyan
    $rProcess = Start-Process -FilePath $rscriptCmd -ArgumentList @("run_server.R") -WorkingDirectory $raiz -RedirectStandardError $rLog -RedirectStandardOutput $rOut -PassThru -WindowStyle Hidden

    $listo = $false
    for ($i = 0; $i -lt 45; $i++) {
        if ($rProcess.HasExited) { throw "Shiny terminó antes de iniciar. Revise outputs\shiny_server.log y shiny_stdout.log." }
        try {
            $null = Invoke-WebRequest -Uri "http://127.0.0.1:$Puerto/" -TimeoutSec 2
            $listo = $true
            break
        } catch { Start-Sleep -Seconds 1 }
    }
    if (-not $listo) { throw "Shiny no respondió en http://127.0.0.1:$Puerto después de 45 segundos." }

    if (Test-Path $cfLog) { Remove-Item -LiteralPath $cfLog -Force }
    if (Test-Path $cfOut) { Remove-Item -LiteralPath $cfOut -Force }
    Write-Host "Iniciando Cloudflare Quick Tunnel..." -ForegroundColor Cyan
    $cfProcess = Start-Process -FilePath $cloudflared -ArgumentList @("tunnel", "--url", "http://127.0.0.1:$Puerto") -WorkingDirectory $raiz -RedirectStandardError $cfLog -RedirectStandardOutput $cfOut -PassThru -WindowStyle Hidden

    $urlPublica = ""
    for ($i = 0; $i -lt 60 -and -not $urlPublica; $i++) {
        if ($cfProcess.HasExited) { throw "Cloudflare Tunnel terminó. Revise outputs\cloudflared_live.log." }
        foreach ($archivoLog in @($cfLog, $cfOut)) {
            if (Test-Path $archivoLog) {
                $contenidoLog = Get-Content -LiteralPath $archivoLog -Raw -ErrorAction SilentlyContinue
                if ($contenidoLog -match "https://[a-zA-Z0-9-]+\.trycloudflare\.com") { $urlPublica = $Matches[0]; break }
            }
        }
        if (-not $urlPublica) { Start-Sleep -Seconds 1 }
    }
    if (-not $urlPublica) { throw "No se detectó la URL pública. Revise outputs\cloudflared_live.log." }

    $endpointData = [ordered]@{
        url = $urlPublica
        status = "online"
        updated_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        institucion = "Municipalidad Provincial de Anta"
        gerencia = "Gerencia de Desarrollo Urbano y Rural (GDUR)"
        proyecto = "Plan de Desarrollo Urbano de Anta (2024 - 2034)"
        ordenanza = "Ordenanza Municipal No 04-2025-A-MPA/C"
        mesa_de_partes = "mesadepartesvirtual@munianta.gob.pe"
    }
    $json = $endpointData | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($endpointFile, $json, [System.Text.UTF8Encoding]::new($false))

    Write-Host "`nTúnel activo: $urlPublica" -ForegroundColor Green
    Write-Host "GitHub Pages: https://antapat.github.io/pdu_anta_2024_2034/" -ForegroundColor Green
    if (-not $SinGitPush) {
        $branch = (& git -C $raiz branch --show-current).Trim()
        if (-not $branch) { throw "No se pudo determinar la rama Git para publicar el endpoint." }
        & git -C $raiz add -f -- docs/server_endpoint.json
        if ($LASTEXITCODE -ne 0) { throw "No se pudo preparar docs/server_endpoint.json." }
        & git -C $raiz commit --only -m "chore(pages): actualizar endpoint del visor" -- docs/server_endpoint.json
        if ($LASTEXITCODE -ne 0) { throw "No se pudo crear el commit del endpoint. Publique docs/server_endpoint.json manualmente." }
        & git -C $raiz push origin $branch
        if ($LASTEXITCODE -ne 0) { throw "No se pudo publicar el endpoint en GitHub Pages. Revise acceso Git y vuelva a ejecutar." }
        Write-Host "Endpoint publicado. Pages puede tardar unos minutos en actualizarse." -ForegroundColor Green
    } else {
        Write-Host "SinGitPush activado: publique docs/server_endpoint.json en GitHub para actualizar Pages." -ForegroundColor Yellow
    }

    Write-Host "`nMantenga esta ventana abierta mientras el visor esté en línea. Ctrl+C para detener." -ForegroundColor Magenta
    while (-not $rProcess.HasExited -and -not $cfProcess.HasExited) { Start-Sleep -Seconds 2 }
    if ($rProcess.HasExited) { Write-Warning "El proceso Shiny se detuvo." }
    if ($cfProcess.HasExited) { Write-Warning "Cloudflare Tunnel se detuvo." }
} finally {
    foreach ($proc in @($cfProcess, $rProcess)) {
        if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    }
    Remove-Item Env:PDU_SHINY_HOST -ErrorAction SilentlyContinue
    Remove-Item Env:PDU_SHINY_PORT -ErrorAction SilentlyContinue
    Write-Host "Servidor y túnel detenidos." -ForegroundColor Yellow
}
