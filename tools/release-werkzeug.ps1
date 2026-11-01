# Hashiriya Battle: Release-Werkzeug
# Start per Doppelklick auf tools\Release-Werkzeug.bat (oder: powershell -File tools\release-werkzeug.ps1)
#
#   1  Release-Test AN   -> data\build.json "release": true  (Spiel neu starten, dann gelten die Release-Sperren)
#   2  Release-Test AUS  -> data\build.json "release": false (Dev-Tools wieder da)
#   3  Release-ZIP bauen -> mods\hashiriya_battle_<version>.zip (neben unpacked\), mit Changelog und mod_info
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

# Changelog-Abschnitt einer Version (ab "## <Version>" bis zur nächsten "## "-Zeile)
function Get-ChangelogSection($text, $ver) {
  $m = [regex]::Match($text, '(?ms)^## ' + [regex]::Escape($ver) + '(?=[ \t(]|\r?\n)[^\n]*\n(.*?)(?=^## |\z)')
  if ($m.Success) { return $m.Groups[1].Value.Trim() }
  return $null
}

# Fehlt der Abschnitt für die Version, wird er aus den Commits seit dem letzten Changelog-Stand angelegt
function Add-ChangelogDraft($ver) {
  $subjects = @()
  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($git) {
    Push-Location $Root
    try {
      $base = (& git log -1 --format=%H -- CHANGELOG.md 2>$null)
      if ($base) { $subjects = @(& git log --no-merges --format=%s "$base..HEAD" 2>$null) }
    } finally { Pop-Location }
  }
  $subjects = @($subjects | Where-Object { $_ -and $_.Trim() } | ForEach-Object { '- ' + $_.Trim() })
  if ($subjects.Count -eq 0) { $subjects = @('- (bitte ergänzen / please fill in)') }
  $today = Get-Date
  $files = @(
    @{ name = 'CHANGELOG.md'; head = '## ' + $ver + ' (Stand ' + $today.ToString('dd.MM.yyyy') + ')'; note = 'Automatisch aus der Commit-Liste erstellt. Schöne Texte: Claude sagen „das ist jetzt Release-Version ' + $ver + '“.' },
    @{ name = 'CHANGELOG_EN.md'; head = '## ' + $ver + ' (as of ' + $today.ToString('yyyy-MM-dd') + ')'; note = 'Generated automatically from the commit list.' }
  )
  foreach ($f in $files) {
    $path = Join-Path $Root $f.name
    $text = Read-Text $path
    if (Get-ChangelogSection $text $ver) { continue }
    $block = $f.head + "`n`n" + $f.note + "`n`n" + ($subjects -join "`n") + "`n`n"
    $idx = $text.IndexOf("`n## ")
    if ($idx -ge 0) { $text = $text.Substring(0, $idx + 1) + $block + $text.Substring($idx + 1) }
    else { $text = $text.TrimEnd() + "`n`n" + $block }
    Write-Text $path $text
    Write-Host "Changelog-Abschnitt für '$ver' in $($f.name) angelegt ($($subjects.Count) Einträge)." -ForegroundColor Yellow
  }
}

# Markdown-Abschnitt (### Überschriften, - Punkte) als einfaches HTML für den Mod-Manager
function Convert-ChangesToHtml($md) {
  if (-not $md) { return '' }
  $html = New-Object System.Text.StringBuilder
  $inList = $false
  foreach ($raw in ($md -split "`n")) {
    $line = $raw.Trim()
    $enc = [System.Net.WebUtility]::HtmlEncode(($line -replace '^(###|-)\s*', ''))
    if ($line -like '- *') {
      if (-not $inList) { [void]$html.Append('<ul>'); $inList = $true }
      [void]$html.Append('<li>' + $enc + '</li>')
      continue
    }
    if ($inList) { [void]$html.Append('</ul>'); $inList = $false }
    if ($line -like '###*') { [void]$html.Append('<p><b>' + $enc + '</b></p>') }
    elseif ($line) { [void]$html.Append('<p>' + $enc + '</p>') }
  }
  if ($inList) { [void]$html.Append('</ul>') }
  return $html.ToString()
}

# mod_info/HASHIRIYABATTLE/info.json aus tools\mod_info\info.json (Titel, Bild, Beschreibung im Mod-Manager)
function Get-ModInfoJson($ver) {
  $tpl = Read-Text (Join-Path $PSScriptRoot 'mod_info\info.json')
  $changes = Convert-ChangesToHtml (Get-ChangelogSection (Read-Text (Join-Path $Root 'CHANGELOG_EN.md')) $ver)
  $obj = $tpl | ConvertFrom-Json
  $obj.PSObject.Properties.Remove('_hinweis')
  foreach ($p in $obj.PSObject.Properties) {
    if ($p.Value -is [string]) {
      $p.Value = $p.Value.Replace('{VERSION}', $ver).Replace('{DATE}', (Get-Date).ToString('yyyy-MM-dd')).Replace('{CHANGES}', $changes)
    }
  }
  return ($obj | ConvertTo-Json -Depth 10)
}

# Wohin die ZIP kommt: liegt der Mod in mods\unpacked\, direkt in den mods-Ordner (dann zeigt der Mod-Manager sie an)
function Get-OutputDir {
  $parent = Split-Path -Parent $Root
  if ((Split-Path -Leaf $parent) -eq 'unpacked') { return (Split-Path -Parent $parent) }
  return (Join-Path $Root 'dist')
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
  $outDir = Get-OutputDir
  if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
  $zipPath = Join-Path $outDir ("hashiriya_battle_" + $slug + ".zip")
  if (Test-Path $zipPath) {
    try { Remove-Item $zipPath -Force }
    catch { throw "$zipPath ist gerade in Benutzung. BeamNG schließen und nochmal bauen." }
  }

  foreach ($cl in @('CHANGELOG.md', 'CHANGELOG_EN.md')) {
    if (-not (Test-Path (Join-Path $Root $cl))) { throw "$cl fehlt im Mod-Ordner." }
  }
  Add-ChangelogDraft $ver
  $modInfo = Get-ModInfoJson $ver

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
    Add-Entry 'mod_info/HASHIRIYABATTLE/info.json' ($Utf8.GetBytes($modInfo))
    foreach ($img in @('icon.jpg', 'banner.jpg')) {
      Add-Entry ('mod_info/HASHIRIYABATTLE/' + $img) ([System.IO.File]::ReadAllBytes((Join-Path $PSScriptRoot ('mod_info\' + $img))))
    }
    $script:count += 3
  } finally {
    $zip.Dispose()
  }
  $kb = [math]::Round((Get-Item $zipPath).Length / 1024)
  Write-Host ''
  Write-Host "Fertig: $zipPath ($script:count Dateien, $kb KB)" -ForegroundColor Green
  Write-Host 'In der ZIP: release an, Version, beide Changelogs und mod_info (Logo + Beschreibung im Mod-Manager).'
  Write-Host 'Im Mod-Manager entweder die ZIP oder den Entwicklungs-Ordner aktivieren, nie beide gleichzeitig.'
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
    Write-Host '  3  Release-ZIP bauen (zum Verschicken und Testen im Mod-Manager)'
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
