@echo off
rem Hashiriya Battle: Release-Test an/aus und Release-ZIP bauen (Doppelklick)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0release-werkzeug.ps1" %*
