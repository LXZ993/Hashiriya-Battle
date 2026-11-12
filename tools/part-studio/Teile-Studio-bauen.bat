@echo off
rem Baut tools\part-studio\dist\hashiriya_part_studio.zip (eigenständige Mod "Teile-Studio")
cd /d "%~dp0"
python build_part_studio.py
pause
