@echo off
title GeoVisor PDU Anta - Servidor GitHub Pages
cd /d "%~dp0"

echo ==============================================================================
echo  GEOVISOR PDU ANTA (2024 - 2034) - INICIANDO CONEXION CON GITHUB PAGES
echo  Municipalidad Provincial de Anta
echo ==============================================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0iniciar_servidor_github_pages.ps1"

pause
