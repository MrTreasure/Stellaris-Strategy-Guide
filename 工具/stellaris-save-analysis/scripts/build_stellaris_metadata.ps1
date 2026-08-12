<#!
.SYNOPSIS
    Build a reusable SQLite index of Stellaris game definitions and localization.

.DESCRIPTION
    Reads the installed game's common/*.txt and selected localization files once.
    It does not read or modify save files. The resulting database is reusable by
    save parsers and analysis tools for any compatible save.
#>

[CmdletBinding()]
param(
    [string]$GameRoot = 'E:\SteamLibrary\steamapps\common\Stellaris',
    [string]$DatabasePath = (Join-Path $PSScriptRoot '..\..\..\sqlite\stellaris_game_metadata.sqlite'),
    [string]$GameVersion = '4.4.6',
    [string]$Language = 'simp_chinese',
    [string]$SqlitePath = 'D:\platform-tools\sqlite3.exe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Sql-Quote {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return 'NULL' }
    $text = [string]$Value
    return "'" + $text.Replace("'", "''") + "'"
}

function Get-DefinitionKind {
    param([string]$RelativePath)
    $parts = $RelativePath -split '[\\/]'
    if ($parts.Count -ge 2) { return $parts[1] }
    return 'common'
}

function Unquote-Localization {
    param([string]$Value)
    $text = $Value.Trim()
    if ($text.Length -ge 2 -and $text[0] -eq '"' -and $text[$text.Length - 1] -eq '"') {
        $text = $text.Substring(1, $text.Length - 2)
        $text = $text -replace '\\"', '"'
        $text = $text -replace '\\\\', '\\'
        $text = $text -replace '\\n', "`n"
    }
    return $text
}

function Invoke-SqliteScript {
    param([string]$Database, [string]$Sql)
    $parent = Split-Path -Parent $Database
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $SqlitePath
    [void]$psi.ArgumentList.Add([IO.Path]::GetFullPath($Database))
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
    $psi.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $psi.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.Start()
    $process.StandardInput.Write($Sql)
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        throw "sqlite3 failed with exit code $($process.ExitCode): $stderr"
    }
    return $stdout
}

if (-not (Test-Path -LiteralPath $GameRoot)) { throw "Game root does not exist: $GameRoot" }
if (-not (Test-Path -LiteralPath $SqlitePath)) { throw "sqlite3 executable does not exist: $SqlitePath" }
$GameRoot = [IO.Path]::GetFullPath($GameRoot)
$DatabasePath = [IO.Path]::GetFullPath($DatabasePath)

$commonRoot = Join-Path $GameRoot 'common'
$localizationRoot = Join-Path $GameRoot 'localisation'
$commonFiles = @(Get-ChildItem -LiteralPath $commonRoot -Recurse -File -Filter '*.txt')
$languageRoot = Join-Path $localizationRoot $Language
$localizationFiles = @()
if (Test-Path -LiteralPath $languageRoot) {
    $localizationFiles = @(Get-ChildItem -LiteralPath $languageRoot -Recurse -File -Filter '*.yml')
}

$sql = [Text.StringBuilder]::new()
[void]$sql.AppendLine('PRAGMA busy_timeout=60000;')
[void]$sql.AppendLine('PRAGMA journal_mode=WAL;')
[void]$sql.AppendLine('BEGIN;')
[void]$sql.AppendLine('CREATE TABLE IF NOT EXISTS database_info (key TEXT PRIMARY KEY, value TEXT NOT NULL);')
[void]$sql.AppendLine('CREATE TABLE IF NOT EXISTS source_files (path TEXT PRIMARY KEY, category TEXT NOT NULL, size_bytes INTEGER NOT NULL, modified_utc TEXT NOT NULL);')
[void]$sql.AppendLine('CREATE TABLE IF NOT EXISTS definitions (kind TEXT NOT NULL, key TEXT NOT NULL, source_file TEXT NOT NULL, ordinal INTEGER NOT NULL, PRIMARY KEY(kind,key,source_file,ordinal));')
[void]$sql.AppendLine('CREATE TABLE IF NOT EXISTS localization (language TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, source_file TEXT NOT NULL, PRIMARY KEY(language,key,source_file));')
[void]$sql.AppendLine('CREATE INDEX IF NOT EXISTS idx_definitions_key ON definitions(key);')
[void]$sql.AppendLine('CREATE INDEX IF NOT EXISTS idx_localization_key_language ON localization(key,language);')
[void]$sql.AppendLine('DELETE FROM source_files;')
[void]$sql.AppendLine('DELETE FROM definitions;')
[void]$sql.AppendLine('DELETE FROM localization WHERE language=' + (Sql-Quote $Language) + ';')
[void]$sql.AppendLine('INSERT OR REPLACE INTO database_info(key,value) VALUES (' + (Sql-Quote 'schema_version') + ',' + (Sql-Quote '1') + ');')
[void]$sql.AppendLine('INSERT OR REPLACE INTO database_info(key,value) VALUES (' + (Sql-Quote 'game_version') + ',' + (Sql-Quote $GameVersion) + ');')
[void]$sql.AppendLine('INSERT OR REPLACE INTO database_info(key,value) VALUES (' + (Sql-Quote 'game_root') + ',' + (Sql-Quote $GameRoot) + ');')
[void]$sql.AppendLine('INSERT OR REPLACE INTO database_info(key,value) VALUES (' + (Sql-Quote 'indexed_utc') + ',' + (Sql-Quote ([DateTime]::UtcNow.ToString('o'))) + ');')

$definitionCount = 0
foreach ($file in $commonFiles) {
    $relative = [IO.Path]::GetRelativePath($GameRoot, $file.FullName).Replace('\', '/')
    $kind = Get-DefinitionKind $relative
    [void]$sql.AppendLine('INSERT OR REPLACE INTO source_files(path,category,size_bytes,modified_utc) VALUES (' + (Sql-Quote $relative) + ',' + (Sql-Quote 'common') + ',' + $file.Length + ',' + (Sql-Quote $file.LastWriteTimeUtc.ToString('o')) + ');')
    $ordinal = 0
    foreach ($match in [regex]::Matches([IO.File]::ReadAllText($file.FullName), '(?m)^(?<key>[A-Za-z0-9_][A-Za-z0-9_.-]*)\s*=\s*\{')) {
        $key = $match.Groups['key'].Value
        [void]$sql.AppendLine('INSERT OR IGNORE INTO definitions(kind,key,source_file,ordinal) VALUES (' + (Sql-Quote $kind) + ',' + (Sql-Quote $key) + ',' + (Sql-Quote $relative) + ',' + $ordinal + ');')
        $ordinal++
        $definitionCount++
    }
}

$localizationCount = 0
foreach ($file in $localizationFiles) {
    $relative = [IO.Path]::GetRelativePath($GameRoot, $file.FullName).Replace('\', '/')
    [void]$sql.AppendLine('INSERT OR REPLACE INTO source_files(path,category,size_bytes,modified_utc) VALUES (' + (Sql-Quote $relative) + ',' + (Sql-Quote 'localisation:' + $Language) + ',' + $file.Length + ',' + (Sql-Quote $file.LastWriteTimeUtc.ToString('o')) + ');')
    foreach ($line in [IO.File]::ReadLines($file.FullName, [Text.UTF8Encoding]::new($false))) {
        if ($line -match '^\s*(?<key>[A-Za-z0-9_][A-Za-z0-9_.-]*)\s*:\s*(?<value>.+?)\s*$') {
            $key = $matches['key']
            $value = Unquote-Localization $matches['value']
            if ($value -and $key -ne 'l_' -and $key -notmatch '^language$') {
                [void]$sql.AppendLine('INSERT OR REPLACE INTO localization(language,key,value,source_file) VALUES (' + (Sql-Quote $Language) + ',' + (Sql-Quote $key) + ',' + (Sql-Quote $value) + ',' + (Sql-Quote $relative) + ');')
                $localizationCount++
            }
        }
    }
}

[void]$sql.AppendLine('COMMIT;')
[void](Invoke-SqliteScript -Database $DatabasePath -Sql $sql.ToString())

[pscustomobject]@{
    Database = $DatabasePath
    GameVersion = $GameVersion
    CommonFiles = $commonFiles.Count
    LocalizationFiles = $localizationFiles.Count
    Definitions = $definitionCount
    LocalizationRows = $localizationCount
}
