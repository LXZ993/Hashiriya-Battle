@echo off
rem Hashiriya Battle: Datei-Links im Handbuch im Explorer/Editor öffnen (Doppelklick = einrichten)
rem Entfernen: in der Eingabeaufforderung  Handbuch-Links-einrichten.bat entfernen
chcp 65001 >nul
if /i "%~1"=="entfernen" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0handbuch-links.ps1" -Remove
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0handbuch-links.ps1" -Setup
)
echo.
pause
