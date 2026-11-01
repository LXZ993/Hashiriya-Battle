# Hashiriya Battle: Release-Werkzeug
# Start per Doppelklick auf tools\Release-Werkzeug.bat (oder: powershell -File tools\release-werkzeug.ps1)
#
#   1  Release-Test AN   -> data\build.json "release": true  (Spiel neu starten, dann gelten die Release-Sperren)
#   2  Release-Test AUS  -> data\build.json "release": false (Dev-Tools wieder da)
#   3  Release-ZIP bauen -> mods\hashiriya_battle_<version>.zip (neben unpacked\), mit Changelog und mod_info
#
# Die Versionsnummer bestimmt das Werkzeug selbst nach der Roadmap (tools\roadmap.json, Get-AutoVersion):
#   - Hauptnummer = letzter fertiger Meilenstein der Roadmap (oder oberste Version im CHANGELOG.md, falls höher)
#   - Zwischen-Builds davor: Alpha 0.3 -> Alpha 0.3.1 -> Alpha 0.3.2 ... (nie von selbst Alpha 0.4)
#   - seit dem letzten Build (tools\release-stand.json) nichts am Mod geändert -> gleiche Version nochmal
#   - steht ein neuer Meilenstein auf "fertig", bekommt die nächste ZIP seine Nummer (z. B. Alpha 0.4)
#
# Ohne Menü:  release-werkzeug.ps1 -Aktion an | aus | zip [-Version "Alpha 0.4"]  (-Version nur zum Erzwingen)
param(
  [string]$Aktion = '',
  [string]$Version = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$BuildJson = Join-Path $Root 'lua\ge\extensions\hashiriyaBattle\data\build.json'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
# Merkt sich den letzten Build (Version + Commit), nur auf diesem PC (steht in .gitignore)
$StandFile = Join-Path $PSScriptRoot 'release-stand.json'
# Nur Änderungen in diesen Ordnern zählen als neue Version (Doku/Werkzeuge nicht)
$ModPaths = @('lua', 'scripts', 'settings', 'ui', 'art', 'vehicles')
$RoadmapFile = Join-Path $PSScriptRoot 'roadmap.json'

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

# git im Mod-Ordner aufrufen; ohne git oder bei Fehler: $null
function Invoke-Git {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
  Push-Location $Root
  try {
    $out = & git @args 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $out
  } catch { return $null } finally { Pop-Location }
}

# Oberste Version im deutschen Changelog ("## Alpha 0.3 (Stand ...)" -> "Alpha 0.3")
function Get-ChangelogTopVersion {
  $text = Read-Text (Join-Path $Root 'CHANGELOG.md')
  $m = [regex]::Match($text, '(?m)^## ([^(\r\n]+?)\s*(\(|\r?$)')
  if ($m.Success) { return $m.Groups[1].Value.Trim() }
  return $null
}

# "Alpha 0.3" -> @{ prefix = 'Alpha'; nums = 0,3 }
function Split-Version($ver) {
  $m = [regex]::Match($ver, '^(.*?)\s*(\d+(?:\.\d+)*)$')
  if (-not $m.Success) { return @{ prefix = $ver; nums = @() } }
  return @{ prefix = $m.Groups[1].Value.Trim(); nums = @($m.Groups[2].Value.Split('.') | ForEach-Object { [int]$_ }) }
}

# Positiv, wenn a neuer als b ist (Alpha < Beta < RC < ohne Zusatz)
function Compare-Version($a, $b) {
  $rank = @{ 'alpha' = 0; 'beta' = 1; 'rc' = 2; '' = 3 }
  $va = Split-Version $a; $vb = Split-Version $b
  $ra = $rank[$va.prefix.ToLower()]; $rb = $rank[$vb.prefix.ToLower()]
  if ($null -eq $ra) { $ra = 0 }; if ($null -eq $rb) { $rb = 0 }
  if ($ra -ne $rb) { return $ra - $rb }
  $n = [math]::Max($va.nums.Count, $vb.nums.Count)
  for ($i = 0; $i -lt $n; $i++) {
    $x = 0; $y = 0
    if ($i -lt $va.nums.Count) { $x = $va.nums[$i] }
    if ($i -lt $vb.nums.Count) { $y = $vb.nums[$i] }
    if ($x -ne $y) { return $x - $y }
  }
  return 0
}

# Alpha 0.3 -> Alpha 0.3.1, Alpha 0.3.1 -> Alpha 0.3.2
function Step-Version($ver) {
  $v = Split-Version $ver
  $nums = @($v.nums)
  if ($nums.Count -eq 0) { return ($ver + ' 0.1') }
  if ($nums.Count -lt 3) { $nums += 1 } else { $nums[$nums.Count - 1]++ }
  return (($v.prefix + ' ' + ($nums -join '.')).Trim())
}

function Get-Stand {
  if (-not (Test-Path $StandFile)) { return $null }
  try { return ((Read-Text $StandFile) | ConvertFrom-Json) } catch { return $null }
}

# Anzahl Commits mit Mod-Änderungen seit $base (-1 = unbekannt)
function Get-ModChangeCount($base) {
  if (-not $base) { return -1 }
  $c = Invoke-Git rev-list --count "$base..HEAD" '--' @ModPaths
  if ($null -eq $c) { return -1 }
  return [int]("$c".Trim())
}

function Get-Roadmap {
  if (-not (Test-Path $RoadmapFile)) { return @() }
  try { return @(((Read-Text $RoadmapFile) | ConvertFrom-Json).meilensteine) } catch { return @() }
}

# Höchster fertiger Meilenstein bzw. erster offener
function Get-RoadmapDone { $d = @(Get-Roadmap | Where-Object { $_.fertig }); if ($d.Count) { return $d[$d.Count - 1] }; return $null }
function Get-RoadmapNext { $n = @(Get-Roadmap | Where-Object { -not $_.fertig }); if ($n.Count) { return $n[0] }; return $null }

# Versionsnummer automatisch: @{ version; base (letzter Changelog-Commit, ab dem der Entwurf zählt); reason }
function Get-AutoVersion {
  $top = Get-ChangelogTopVersion
  if (-not $top) { $top = Get-ModVersion }
  $done = Get-RoadmapDone
  if ($done -and (Compare-Version $done.version $top) -gt 0) { $top = $done.version }
  $stand = Get-Stand
  $changelogCommit = Invoke-Git log -1 --format=%H -- CHANGELOG.md
  if ($stand -and $stand.version) {
    if ((Compare-Version $top $stand.version) -gt 0) {
      return @{ version = $top; base = $changelogCommit; reason = "neuer Meilenstein laut Roadmap/Changelog (letzter Build: $($stand.version))" }
    }
    $changes = Get-ModChangeCount $stand.commit
    if ($changes -eq 0) {
      return @{ version = $stand.version; base = $changelogCommit; reason = 'seit dem letzten Build nichts am Mod geändert, gleiche Version' }
    }
    return @{ version = (Step-Version $stand.version); base = $changelogCommit; reason = "Zwischen-Build: letzter Build $($stand.version), seitdem Änderungen am Mod" }
  }
  # Erster Build auf diesem PC: Changelog-Version, außer der Mod hat sich seit dem Changelog-Eintrag geändert
  $changes = Get-ModChangeCount $changelogCommit
  if ($changes -gt 0) {
    return @{ version = (Step-Version $top); base = $changelogCommit; reason = "Zwischen-Build: $changes Änderungen seit $top" }
  }
  return @{ version = $top; base = $changelogCommit; reason = 'Version aus dem Changelog' }
}

function Save-Stand($ver) {
  $head = Invoke-Git rev-parse HEAD
  $obj = [ordered]@{ version = $ver; commit = "$head".Trim(); built = (Get-Date).ToString('yyyy-MM-dd HH:mm') }
  Write-Text $StandFile ($obj | ConvertTo-Json)
}

# Changelogs für die ZIP. Fehlt der Abschnitt für die Version, kommt ein Entwurf aus den Commits seit $base dazu.
# Die Changelog-Dateien im Mod-Ordner bleiben unverändert (keine offenen Änderungen auf dem PC).
function Get-ChangelogTexts($ver, $base) {
  $subjects = @()
  if ($base) { $subjects = @(Invoke-Git log --no-merges --format=%s "$base..HEAD" '--' @ModPaths) }
  $subjects = @($subjects | Where-Object { $_ -and $_.Trim() } | ForEach-Object { '- ' + $_.Trim() })
  if ($subjects.Count -eq 0) { $subjects = @('- (bitte ergänzen / please fill in)') }
  $today = Get-Date
  $since = Get-ChangelogTopVersion
  $files = @(
    @{ name = 'CHANGELOG.md'; head = '## ' + $ver + ' (Stand ' + $today.ToString('dd.MM.yyyy') + ')'; note = 'Automatisch aus der Commit-Liste erstellt (alles seit ' + $since + ').' },
    @{ name = 'CHANGELOG_EN.md'; head = '## ' + $ver + ' (as of ' + $today.ToString('yyyy-MM-dd') + ')'; note = 'Generated automatically from the commit list (everything since ' + $since + ').' }
  )
  $result = @{}
  foreach ($f in $files) {
    $text = (Read-Text (Join-Path $Root $f.name)) -replace "`r`n", "`n"
    if (-not (Get-ChangelogSection $text $ver)) {
      $block = $f.head + "`n`n" + $f.note + "`n`n" + ($subjects -join "`n") + "`n`n"
      $idx = $text.IndexOf("`n## ")
      if ($idx -ge 0) { $text = $text.Substring(0, $idx + 1) + $block + $text.Substring($idx + 1) }
      else { $text = $text.TrimEnd() + "`n`n" + $block }
      Write-Host "Changelog-Abschnitt '$ver' als Entwurf in die ZIP ($($f.name), $($subjects.Count) Einträge)." -ForegroundColor Yellow
    }
    $result[$f.name] = $text
  }
  return $result
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
function Get-ModInfoJson($ver, $changelogEn) {
  $tpl = Read-Text (Join-Path $PSScriptRoot 'mod_info\info.json')
  $changes = Convert-ChangesToHtml (Get-ChangelogSection $changelogEn $ver)
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
  $auto = Get-AutoVersion
  $ver = $Version
  if ($ver) {
    Write-Host "Version (vorgegeben): $ver"
  } else {
    $ver = $auto.version
    Write-Host "Version: $ver  ($($auto.reason))" -ForegroundColor Cyan
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
  $changelogs = Get-ChangelogTexts $ver $auto.base
  $modInfo = Get-ModInfoJson $ver $changelogs['CHANGELOG_EN.md']

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
    # Platzhalter für Dev-Apps (z. B. Builder): alte HUD-Layouts aus der Entwicklung verweisen noch darauf,
    # ohne App zeigt BeamNG dort "Unknown app" über den ganzen Bildschirm
    $stubRoot = Join-Path $PSScriptRoot 'release-stubs'
    if (Test-Path $stubRoot) {
      Get-ChildItem -Path $stubRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
        $rel = 'ui/modules/apps/' + ($_.FullName.Substring($stubRoot.Length).TrimStart('\', '/') -replace '\\', '/')
        Add-Entry $rel ([System.IO.File]::ReadAllBytes($_.FullName))
        $script:count++
      }
    }
    Add-Entry 'CHANGELOG_DE.md' ($Utf8.GetBytes($changelogs['CHANGELOG.md']))
    Add-Entry 'CHANGELOG_EN.md' ($Utf8.GetBytes($changelogs['CHANGELOG_EN.md']))
    # Zusätzlich unter data/changelog/ (eindeutiger Pfad) für den Changelog im Titelbildschirm
    Add-Entry 'lua/ge/extensions/hashiriyaBattle/data/changelog/CHANGELOG_DE.md' ($Utf8.GetBytes($changelogs['CHANGELOG.md']))
    Add-Entry 'lua/ge/extensions/hashiriyaBattle/data/changelog/CHANGELOG_EN.md' ($Utf8.GetBytes($changelogs['CHANGELOG_EN.md']))
    $script:count += 2
    $script:count += 2
    Add-Entry 'mod_info/HASHIRIYABATTLE/info.json' ($Utf8.GetBytes($modInfo))
    foreach ($img in @('icon.jpg', 'banner.jpg')) {
      Add-Entry ('mod_info/HASHIRIYABATTLE/' + $img) ([System.IO.File]::ReadAllBytes((Join-Path $PSScriptRoot ('mod_info\' + $img))))
    }
    $script:count += 3
  } finally {
    $zip.Dispose()
  }
  Save-Stand $ver
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
    $next = '?'
    try { $next = (Get-AutoVersion).version } catch { }
    Write-Host "Release-Test: $state      Nächste ZIP-Version: $next"
    $ms = Get-RoadmapNext
    if ($ms) { Write-Host "Nächster Meilenstein: $($ms.version) - $($ms.titel)" }
    Write-Host ''
    Write-Host '  1  Release-Test AN   (so testen, wie es die Tester bekommen)'
    Write-Host '  2  Release-Test AUS  (zurück zur Entwicklung)'
    Write-Host '  3  Release-ZIP bauen (Version automatisch, zum Verschicken und Testen im Mod-Manager)'
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
