@echo off
rem Hashiriya Battle: PSD (oder PNG) auf diese Datei ziehen -> Livery im Mod wird aktualisiert.
rem Braucht Python 3 mit: pip install numpy pillow psd-tools
cd /d "%~dp0"
if "%~1"=="" (
  echo PSD-Datei auf diese .bat ziehen ^(Dateiname z. B. pessima_hb_kaido.psd^).
  pause
  exit /b
)
for %%F in (%*) do python psd_zu_skin.py "%%~fF"
pause
