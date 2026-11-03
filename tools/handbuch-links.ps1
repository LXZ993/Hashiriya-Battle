# Hashiriya Battle: Datei-Links im Handbuch im Explorer oder Editor öffnen.
# Einrichten/Entfernen über tools\Handbuch-Links-einrichten.bat (Doppelklick).
# Danach öffnet ein Klick auf einen Datei-Link im Handbuch den Windows-Explorer
# mit der Datei markiert (oder die Datei im Editor, je nach Auswahl im Handbuch).
# Es wird nie eine Datei ausgeführt, nur Explorer bzw. Editor geöffnet,
# und nur für Pfade im BeamNG-Userordner und in %LOCALAPPDATA%\BeamNG.
param([switch]$Setup, [switch]$Remove, [string]$Open)

$modRoot = Split-Path -Parent $PSScriptRoot
$userDir = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $modRoot))
$key = 'HKCU:\Software\Classes\hashiriya-open'

function Open-Link([string]$url) {
    $raw = $url -replace '^hashiriya-open:(//)?', ''
    $mode = 'zeigen'
    if ($raw -match '^(zeigen|editor)/(.*)$') { $mode = $Matches[1]; $raw = $Matches[2] }
    $p = [Uri]::UnescapeDataString($raw) -replace '/', '\'
    if (-not $p -or $p.Contains('"') -or $p -notmatch '^[A-Za-z]:\\') { return }
    try { $full = [IO.Path]::GetFullPath($p) } catch { return }
    $ok = $false
    foreach ($a in @($userDir, $modRoot, (Join-Path $env:LOCALAPPDATA 'BeamNG'))) {
        $base = [IO.Path]::GetFullPath($a).TrimEnd('\') + '\'
        if (($full.TrimEnd('\') + '\').StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) { $ok = $true }
    }
    if (-not $ok) { return }
    $full = $full.TrimEnd('\')
    if ($full -match '^[A-Za-z]:$') { $full += '\' }
    if (Test-Path -LiteralPath $full -PathType Container) {
        Start-Process explorer.exe -ArgumentList "`"$full`""
        return
    }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        # Datei gibt es (noch) nicht, z. B. Spielstand vor dem ersten Speichern: nächsten vorhandenen Ordner zeigen
        $d = Split-Path -Parent $full
        while ($d -and -not (Test-Path -LiteralPath $d -PathType Container)) { $d = Split-Path -Parent $d }
        if ($d) { Start-Process explorer.exe -ArgumentList "`"$d`"" }
        return
    }
    if ($mode -eq 'editor') {
        $code = @(
            (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\Code.exe'),
            (Join-Path $env:ProgramFiles 'Microsoft VS Code\Code.exe')
        ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if ($code) { Start-Process $code -ArgumentList "`"$full`"" }
        else { Start-Process notepad.exe -ArgumentList "`"$full`"" }
        return
    }
    Start-Process explorer.exe -ArgumentList "/select,`"$full`""
}

if ($Open) { Open-Link $Open; exit 0 }

if ($Remove) {
    Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ''
    Write-Host '  Handbuch-Links entfernt. Links im Handbuch öffnen jetzt wieder nur im Browser.' -ForegroundColor Yellow
    Write-Host '  Stell im Handbuch links unten "Datei-Links" wieder auf "im Browser".'
    exit 0
}

$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$cmd = "`"$ps`" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Open `"%1`""
New-Item -Path $key -Force | Out-Null
Set-ItemProperty -Path $key -Name '(default)' -Value 'URL:Hashiriya Handbuch-Links'
New-ItemProperty -Path $key -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null
New-Item -Path "$key\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "$key\shell\open\command" -Name '(default)' -Value $cmd
Write-Host ''
Write-Host '  Handbuch-Links eingerichtet.' -ForegroundColor Green
Write-Host "  Mod-Ordner:  $modRoot"
Write-Host "  Userordner:  $userDir"
Write-Host ''
Write-Host '  So gehts weiter:'
Write-Host '  1. Handbuch im Browser neu laden (F5).'
Write-Host '  2. Links unten "Datei-Links" auf "im Explorer" oder "im Editor" stellen.'
Write-Host '  3. Beim ersten Klick fragt der Browser, ob er die App öffnen darf: erlauben'
Write-Host '     (und "immer erlauben" anhaken, wenn der Browser das anbietet).'
Write-Host ''
Write-Host '  Verschiebst du den Mod-Ordner, diese Datei einfach nochmal starten.'
