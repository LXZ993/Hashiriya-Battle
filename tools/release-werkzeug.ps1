# Hashiriya Battle: Release-Werkzeug
# Start per Doppelklick auf tools\Release-Werkzeug.bat (oder: powershell -File tools\release-werkzeug.ps1)
#
#   1  Release-Test AN   -> data\build.json "release": true  (Spiel neu starten, dann gelten die Release-Sperren)
#   2  Release-Test AUS  -> data\build.json "release": false (Dev-Tools wieder da)
#   3  Release-ZIP bauen -> dist\hashiriya_battle_<version>.zip zum Verschicken
#
# Ohne Menü:  release-werkzeug.ps1 -Aktion an | aus | zip [-Version "Alpha 0.4"]
param(
  [string]$Aktion = '',
  [string]$Version = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$BuildJson = Join-Path $Root 'lua\ge\extensions\hashiriyaBattle\data\build.json'
$Utf8 = New-Object System.Text.UTF8Encoding($false)

# Ordner und Dateien, die in die ZIP kommen
$Include = @('lua', 'scripts', 'settings', 'ui', 'art', 'vehicles')
# Nur für die Entwicklung: kommt nicht in die ZIP
$ExcludeNames = @('logo-source.html', 'LIESMICH.txt', 'Thumbs.db', '.DS_Store', 'builder.lua')
$ExcludeDirs = @('ui/modules/apps/HashiriyaBuilder')
$DevBindings = @('hashiriyaCaptureCamera')
$DevApps = @('hashiriyaBuilder', 'HashiriyaBuilder')

function Read-Text($path) { [System.IO.File]::ReadAllText($path, $Utf8) }
function Write-Text($path, $text) { [System.IO.File]::WriteAllText($path, $text, $Utf8) }

function Get-ReleaseState {
  $t = Read-Text $BuildJson
  if ($t -match '"release"\s*:\s*true') { return $true }
  return $false
}

function Set-Release([bool]$on) {
  $t = Read-Text $BuildJson
  $value = 'false'
  if ($on) { $value = 'true' }
  $new = [regex]::Replace($t, '"release"\s*:\s*(true|false)', '"release": ' + $value, 1)
  Write-Text $BuildJson $new
  if ($on) {
    Write-Host ''
    Write-Host 'Release-Test ist AN.' -ForegroundColor Green
    Write-Host 'BeamNG komplett neu starten, dann Karriere laden: keine Dev-Tools, keine Fahrzeugauswahl,'
    Write-Host 'kein Fahrzeug-/Umgebungs-Tab, keine Konsole, keine Schnellreise. Nur der Node Grabber bleibt.'
  } else {
    Write-Host ''
    Write-Host 'Release-Test ist AUS (Entwicklung, alle Dev-Tools da).' -ForegroundColor Yellow
    Write-Host 'BeamNG komplett neu starten, damit es greift.'
  }
}

function Get-ModVersion {
  $t = Read-Text $BuildJson
  $m = [regex]::Match($t, '"modVersion"\s*:\s*"([^"]*)"')
  if ($m.Success) { return $m.Groups[1].Value }
  return 'Alpha'
}

# build.json für die ZIP: release an, Version setzen
function Convert-BuildJson($text, $ver) {
  $text = [regex]::Replace($text, '"release"\s*:\s*(true|false)', '"release": true', 1)
  $text = [regex]::Replace($text, '"modVersion"\s*:\s*"[^"]*"', '"modVersion": "' + $ver + '"', 1)
  return $text
}

# Tastenbelegung ohne Dev-Tasten (Titelbild-Kamera merken)
function Convert-Inputmap($text) {
  $lines = $text -split "`n"
  $keep = $lines | Where-Object {
    $line = $_
    -not ($DevBindings | Where-Object { $line -match [regex]::Escape($_) })
  }
  $out = ($keep -join "`n")
  # Komma vor schließender Klammer entfernen, falls die letzte Zeile wegfiel
  return [regex]::Replace($out, ',(\s*\])', '$1')
}

# UI-Layout ohne Dev-Apps (Builder)
function Convert-Layout($text) {
  try {
    $obj = $text | ConvertFrom-Json
  } catch { return $text }
  if ($null -eq $obj.apps) { return $text }
  $apps = @($obj.apps | Where-Object { $DevApps -notcontains $_.appName })
  if ($apps.Count -eq @($obj.apps).Count) { return $text }
  $obj.apps = $apps
  return ($obj | ConvertTo-Json -Depth 20)
}

function Build-Zip {
  $ver = $Version
  if (-not $ver) {
    $current = Get-ModVersion
    $ver = Read-Host "Versionsnummer (Enter = $current)"
    if (-not $ver) { $ver = $current }
  }
  $ver = $ver.Trim()
  $slug = ($ver.ToLower() -replace '[^a-z0-9.]+', '_').Trim('_')
  $dist = Join-Path $Root 'dist'
  if (-not (Test-Path $dist)) { New-Item -ItemType Directory -Path $dist | Out-Null }
  $zipPath = Join-Path $dist ("hashiriya_battle_" + $slug + ".zip")
  if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

  foreach ($cl in @('CHANGELOG.md', 'CHANGELOG_EN.md')) {
    $p = Join-Path $Root $cl
    if (-not (Test-Path $p)) { throw "$cl fehlt im Mod-Ordner." }
    if (-not ((Read-Text $p) -match [regex]::Escape($ver))) {
      Write-Host "Hinweis: In $cl steht noch kein Abschnitt für '$ver'." -ForegroundColor Yellow
    }
  }

  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
  $script:count = 0
  try {
    function Add-Entry($name, $bytes) {
      $entry = $zip.CreateEntry($name, [System.IO.Compression.CompressionLevel]::Optimal)
      $s = $entry.Open()
      $s.Write($bytes, 0, $bytes.Length)
      $s.Dispose()
    }
    foreach ($top in $Include) {
      $dir = Join-Path $Root $top
      if (-not (Test-Path $dir)) { continue }
      Get-ChildItem -Path $dir -Recurse -File | Sort-Object FullName | ForEach-Object {
        $rel = $_.FullName.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/'
        if ($ExcludeNames -contains $_.Name) { return }
        foreach ($d in $ExcludeDirs) { if ($rel.StartsWith($d + '/')) { return } }
        if ($rel -eq 'lua/ge/extensions/hashiriyaBattle/data/build.json') {
          Add-Entry $rel ($Utf8.GetBytes((Convert-BuildJson (Read-Text $_.FullName) $ver)))
        } elseif ($rel -like 'settings/inputmaps/*.json') {
          Add-Entry $rel ($Utf8.GetBytes((Convert-Inputmap (Read-Text $_.FullName))))
        } elseif ($rel -like '*.uilayout.json') {
          Add-Entry $rel ($Utf8.GetBytes((Convert-Layout (Read-Text $_.FullName))))
        } else {
          Add-Entry $rel ([System.IO.File]::ReadAllBytes($_.FullName))
        }
        $script:count++
      }
    }
    Add-Entry 'CHANGELOG_DE.md' ([System.IO.File]::ReadAllBytes((Join-Path $Root 'CHANGELOG.md')))
    Add-Entry 'CHANGELOG_EN.md' ([System.IO.File]::ReadAllBytes((Join-Path $Root 'CHANGELOG_EN.md')))
    $script:count += 2
  } finally {
    $zip.Dispose()
  }
  $kb = [math]::Round((Get-Item $zipPath).Length / 1024)
  Write-Host ''
  Write-Host "Fertig: $zipPath ($script:count Dateien, $kb KB)" -ForegroundColor Green
  Write-Host 'In der ZIP ist release an und die Version gesetzt. Dein Mod-Ordner bleibt, wie er ist.'
  if ($env:OS -eq 'Windows_NT') { Start-Process explorer.exe "/select,`"$zipPath`"" }
}

function Show-Menu {
  while ($true) {
    $state = 'AUS (Entwicklung)'
    if (Get-ReleaseState) { $state = 'AN' }
    Write-Host ''
    Write-Host '=== Hashiriya Battle: Release-Werkzeug ===' -ForegroundColor Cyan
    Write-Host "Mod-Ordner:   $Root"
    Write-Host "Release-Test: $state      Version: $(Get-ModVersion)"
    Write-Host ''
    Write-Host '  1  Release-Test AN   (so testen, wie es die Tester bekommen)'
    Write-Host '  2  Release-Test AUS  (zurück zur Entwicklung)'
    Write-Host '  3  Release-ZIP bauen (zum Verschicken)'
    Write-Host '  0  Beenden'
    $c = Read-Host 'Auswahl'
    switch ($c) {
      '1' { Set-Release $true }
      '2' { Set-Release $false }
      '3' { Build-Zip }
      '0' { return }
      default { Write-Host 'Bitte 1, 2, 3 oder 0 eingeben.' }
    }
  }
}

try {
  switch ($Aktion.ToLower()) {
    'an' { Set-Release $true }
    'aus' { Set-Release $false }
    'zip' { Build-Zip }
    default { Show-Menu }
  }
} catch {
  Write-Host ''
  Write-Host ('Fehler: ' + $_.Exception.Message) -ForegroundColor Red
  if (-not $Aktion) { Read-Host 'Enter zum Schließen' | Out-Null }
  exit 1
}
