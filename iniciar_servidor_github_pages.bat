@echo off
title GeoVisor PDU Anta - GitHub Pages y tunel HTTPS
cd /d "%~dp0"

echo ============================================================================
echo  GEOVISOR PDU ANTA - GITHUB PAGES + TUNEL HTTPS
echo  Las capas permanecen en el computador servidor; no se copian a GitHub.
echo ============================================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0iniciar_servidor_github_pages.ps1"
if errorlevel 1 (
  echo.
  echo El inicio del servidor o la publicacion del endpoint fallo.
  echo Revise outputs\shiny_server.log y outputs\cloudflared_live.log.
)

echo.
pause
