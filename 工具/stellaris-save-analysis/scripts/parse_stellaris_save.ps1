<#!
.SYNOPSIS
    Read-only analyzer for Stellaris 4.4.x save files.

.DESCRIPTION
    Finds the newest .sav under the normal Stellaris save locations, reads the
    ZIP gamestate, and reports player empire, owned colonies, jobs, buildings,
    technologies, traditions, ascension perks, crime, stability, and other
    useful save-state data. Experimental Sentencing is an optional focused
    section, enabled automatically when that civic is detected.

    The script never changes the save. It extracts to a temporary directory and
    removes that exact temporary directory after parsing.
#>

[CmdletBinding()]
param(
    [string]$SavePath,
    [string]$SaveRoot,
    [string]$OutputPath,
    [switch]$ListOnly,
    [switch]$ExperimentalSentencing
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SaveRoots {
    $roots = [System.Collections.Generic.List[string]]::new()
    if ($SaveRoot) { [void]$roots.Add($SaveRoot) }
    $docs = [Environment]::GetFolderPath('MyDocuments')
    if ($docs) {
        [void]$roots.Add((Join-Path $docs 'Paradox Interactive\Stellaris\save games'))
    }
    $oneDriveDocs = Join-Path $env:USERPROFILE 'OneDrive\Documents\Paradox Interactive\Stellaris\save games'
    [void]$roots.Add($oneDriveDocs)
    [void]$roots.Add((Join-Path $env:USERPROFILE 'Saved Games\Paradox Interactive\Stellaris'))
    return $roots | Select-Object -Unique
}

function Find-Saves {
    $found = foreach ($root in Get-SaveRoots) {
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.sav' -ErrorAction SilentlyContinue
        }
    }
    return @($found | Sort-Object LastWriteTime -Descending)
}

function Get-BlockFromIndex {
    param([string[]]$Lines, [int]$Index)
    $depth = 0
    $opened = $false
    $block = [System.Collections.Generic.List[string]]::new()
    for ($i = $Index; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        [void]$block.Add($line)
        $openCount = ([regex]::Matches($line, '\{')).Count
        $closeCount = ([regex]::Matches($line, '\}')).Count
        if ($openCount -gt 0) { $opened = $true }
        $depth += $openCount - $closeCount
        if ($opened -and $depth -eq 0) { return @($block) }
    }
    throw "Could not find the end of the save block at line $Index."
}

function Get-BlockEndIndex {
    param([string[]]$Lines, [int]$Index)
    $depth = 0
    $opened = $false
    for ($i = $Index; $i -lt $Lines.Count; $i++) {
        $openCount = ([regex]::Matches($Lines[$i], '\{')).Count
        $closeCount = ([regex]::Matches($Lines[$i], '\}')).Count
        if ($openCount -gt 0) { $opened = $true }
        $depth += $openCount - $closeCount
        if ($opened -and $depth -eq 0) { return $i }
    }
    throw "Could not find the end of the save block at line $Index."
}

function Get-TopLevelHeaders {
    param([string[]]$Lines, [string[]]$Names)
    $result = @{}
    foreach ($name in $Names) {
        $index = [Array]::IndexOf($Lines, $name)
        if ($index -ge 0) { $result[$name] = $index }
    }
    return $result
}

function Get-EntryIndexMap {
    param(
        [string[]]$Lines,
        [int]$SectionStart,
        [string]$Indent,
        [string[]]$WantedIds
    )
    $wanted = $null
    if ($null -ne $WantedIds -and $WantedIds.Count -gt 0) {
        $wanted = @{}
        foreach ($id in $WantedIds) { $wanted[[string]$id] = $true }
    }
    $result = @{}
    if ($null -ne $wanted) {
        foreach ($id in $wanted.Keys) {
            $index = [Array]::IndexOf($Lines, ($Indent + $id + '='), $SectionStart)
            if ($index -ge 0) { $result[$id] = $index }
        }
        return $result
    }
    $end = Get-BlockEndIndex -Lines $Lines -Index $SectionStart
    $pattern = '^' + [regex]::Escape($Indent) + '([0-9]+)=\s*$'
    for ($i = $SectionStart + 1; $i -lt $end; $i++) {
        if ($Lines[$i] -match $pattern) {
            $id = [string]$matches[1]
            if ($null -eq $wanted -or $wanted.ContainsKey($id)) {
                $result[$id] = $i
                if ($null -ne $wanted -and $result.Count -eq $wanted.Count) { break }
            }
        }
    }
    return $result
}

function Find-HeaderIndex {
    param([string[]]$Lines, [string]$Header, [int]$Start = 0)
    for ($i = $Start; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim() -eq $Header) { return $i }
    }
    return -1
}

function Find-EntryIndex {
    param([string[]]$Lines, [int]$Start, [string]$Indent, [string]$Id)
    $pattern = '^' + [regex]::Escape($Indent) + [regex]::Escape($Id) + '=\s*$'
    for ($i = $Start; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $pattern) { return $i }
    }
    return -1
}

function Get-BlockValue {
    param([string[]]$Block, [string]$Key, [string]$Indent = "`t`t")
    $pattern = '^' + [regex]::Escape($Indent) + [regex]::Escape($Key) + '=([^\r\n]*)'
    foreach ($line in $Block) {
        if ($line -match $pattern) { return $matches[1].Trim().Trim('"') }
    }
    return $null
}

function Get-ListValues {
    param([string[]]$Block, [string]$Key, [string]$Indent = "`t`t")
    $text = $Block -join "`n"
    $pattern = '(?ms)^' + [regex]::Escape($Indent) + [regex]::Escape($Key) + '=\s*\{(.*?)\n' + [regex]::Escape($Indent) + '\}'
    $match = [regex]::Match($text, $pattern)
    if (-not $match.Success) { return @() }
    return @([regex]::Matches($match.Groups[1].Value, '(?<![A-Za-z_])[0-9]+(?![A-Za-z_])') | ForEach-Object Value)
}

function Get-QuotedValues {
    param([string[]]$Block, [string]$Key)
    $text = $Block -join "`n"
    $pattern = '(?ms)^\s*' + [regex]::Escape($Key) + '=\s*\{(.*?)\n\s*\}'
    $match = [regex]::Match($text, $pattern)
    if (-not $match.Success) { return @() }
    return @([regex]::Matches($match.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
}

function Get-RepeatedQuotedValues {
    param([string[]]$Block, [string]$Key)
    $pattern = '^\s*' + [regex]::Escape($Key) + '="([^"]+)"'
    return @($Block | ForEach-Object { if ($_ -match $pattern) { $matches[1] } })
}

function Get-JobRecords {
    param([string[]]$Lines, [hashtable]$EntryIndices)
    $records = @{}
    foreach ($entry in $EntryIndices.GetEnumerator()) {
        $type = $null; $workforce = $null; $maxWorkforce = $null; $bonus = $null
        $block = Get-BlockFromIndex -Lines $Lines -Index $entry.Value
        foreach ($line in $block) {
            if ($line -match '^\t\ttype="([^"]+)"') { $type = $matches[1] }
            elseif ($line -match '^\t\tworkforce=([-0-9.]+)') { $workforce = [double]$matches[1] }
            elseif ($line -match '^\t\tmax_workforce=([-0-9.]+)') { $maxWorkforce = [double]$matches[1] }
            elseif ($line -match '^\t\tbonus_workforce=([-0-9.]+)') { $bonus = [double]$matches[1] }
        }
        if ($null -ne $type) {
            $records[[string]$entry.Key] = [pscustomobject]@{ Type = $type; Workforce = $workforce; Max = $maxWorkforce; Bonus = $bonus }
        }
    }
    return $records
}

function Get-BuildingTypes {
    param([string[]]$Lines, [hashtable]$EntryIndices)
    $result = @{}
    foreach ($entry in $EntryIndices.GetEnumerator()) {
        $type = $null
        $end = [Math]::Min((Get-BlockEndIndex -Lines $Lines -Index $entry.Value), $entry.Value + 12)
        for ($i = $entry.Value + 1; $i -le $end; $i++) {
            if ($Lines[$i] -match '^\t\ttype="([^"]+)"') { $type = $matches[1]; break }
        }
        if ($type) { $result[[string]$entry.Key] = $type }
    }
    return $result
}

function Get-ResourceTotals {
    param([string[]]$Block)
    $result = @{}
    foreach ($line in $Block) {
        if ($line -match '^\s+(energy|minerals|food|physics_research|society_research|engineering_research|influence|unity|trade|consumer_goods|alloys|volatile_motes|exotic_gases|rare_crystals|sr_zro|sr_dark_matter|minor_artifacts|astral_threads)=([-0-9.]+)') {
            $key = $matches[1]
            if (-not $result.ContainsKey($key)) { $result[$key] = 0.0 }
            $result[$key] += [double]$matches[2]
        }
    }
    return $result
}

function Find-BlockIndexByKey {
    param([string[]]$Block, [string]$Key, [int]$Start = 0)
    for ($i = $Start; $i -lt $Block.Count; $i++) {
        if ($Block[$i].Trim() -eq ($Key + '=')) { return $i }
    }
    return -1
}

function Get-PlanetName {
    param([string[]]$Block)
    foreach ($line in $Block) {
        if ($line -match '^\s*key="([^"]+)"') {
            $key = $matches[1]
            if ($key -notmatch 'PLANET_NAME_FORMAT|NAME_FORMAT|STAR_NAME') { return $key }
        }
    }
    return $null
}

function Format-Number {
    param($Value)
    if ($null -eq $Value) { return '-' }
    return ('{0:N1}' -f [double]$Value)
}

if (-not $SavePath) {
    $saves = Find-Saves
    if ($saves.Count -eq 0) { throw 'No .sav files were found in the normal Stellaris save locations.' }
    if ($ListOnly) {
        $saves | Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize
        exit 0
    }
    $SavePath = $saves[0].FullName
} elseif (-not (Test-Path -LiteralPath $SavePath)) {
    throw "Save file does not exist: $SavePath"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$tempDir = Join-Path ([IO.Path]::GetTempPath()) ('stellaris-save-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir | Out-Null

try {
    [IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path -LiteralPath $SavePath), $tempDir)
    $metaPath = Join-Path $tempDir 'meta'
    $gameStatePath = Join-Path $tempDir 'gamestate'
    if (-not (Test-Path -LiteralPath $gameStatePath)) { throw 'The save does not contain a gamestate entry.' }

    $parseStarted = Get-Date
    $lines = [IO.File]::ReadAllLines($gameStatePath)
    $version = ([regex]::Match(($lines[0..20] -join "`n"), '(?m)^version="([^"]+)"')).Groups[1].Value
    $date = ([regex]::Match(($lines[0..20] -join "`n"), '(?m)^date="([^"]+)"')).Groups[1].Value
    $saveName = ([regex]::Match(($lines[0..20] -join "`n"), '(?m)^name="([^"]+)"')).Groups[1].Value

    $headers = Get-TopLevelHeaders -Lines $lines -Names @(
        'player=','country=','colony=','pop_jobs=','buildings=','planets=',
        'fleet=','war=','megastructures='
    )
    foreach ($required in @('player=','country=','colony=','pop_jobs=','buildings=','planets=')) {
        if (-not $headers.ContainsKey($required)) { throw "Could not locate required save section: $required" }
    }

    $playerHeader = $headers['player=']
    $playerBlock = Get-BlockFromIndex -Lines $lines -Index $playerHeader
    $playerCountry = ([regex]::Match(($playerBlock -join "`n"), '(?m)^\s*country=([0-9]+)')).Groups[1].Value
    if (-not $playerCountry) { $playerCountry = '0' }

    $countryHeader = $headers['country=']
    $countryEntries = Get-EntryIndexMap -Lines $lines -SectionStart $countryHeader -Indent "`t" -WantedIds @($playerCountry)
    if (-not $countryEntries.ContainsKey($playerCountry)) { throw "Could not locate player country $playerCountry." }
    $countryEntry = $countryEntries[$playerCountry]
    $countryBlock = Get-BlockFromIndex -Lines $lines -Index $countryEntry
    $ownedColonies = Get-ListValues -Block $countryBlock -Key 'owned_planets'
    $civics = Get-QuotedValues -Block $countryBlock -Key 'civics'
    $ethics = Get-RepeatedQuotedValues -Block $countryBlock -Key 'ethic'
    $perks = Get-QuotedValues -Block $countryBlock -Key 'ascension_perks'
    $traditions = Get-QuotedValues -Block $countryBlock -Key 'traditions'
    $technologies = Get-RepeatedQuotedValues -Block $countryBlock -Key 'technology'
    $hasExperimental = $ExperimentalSentencing -or @($civics | Where-Object { $_ -in @('civic_twisted_experimenters','civic_twisted_experimenters_hive_mind') }).Count -gt 0

    $colonyHeader = $headers['colony=']
    $popJobsHeader = $headers['pop_jobs=']
    $buildingHeader = $headers['buildings=']
    $planetHeader = Find-HeaderIndex -Lines $lines -Header 'planet=' -Start $headers['planets=']

    $colonyEntries = Get-EntryIndexMap -Lines $lines -SectionStart $colonyHeader -Indent "`t" -WantedIds $ownedColonies
    $wantedJobIds = [System.Collections.Generic.HashSet[string]]::new()
    $wantedBuildingIds = [System.Collections.Generic.HashSet[string]]::new()
    $wantedPlanetIds = [System.Collections.Generic.HashSet[string]]::new()
    $colonySources = [System.Collections.Generic.List[object]]::new()

    foreach ($colonyId in $ownedColonies) {
        if (-not $colonyEntries.ContainsKey($colonyId)) { continue }
        $colonyBlock = Get-BlockFromIndex -Lines $lines -Index $colonyEntries[$colonyId]
        $carrierMatch = [regex]::Match(($colonyBlock -join "`n"), '(?m)^\t\t\t?reference=([0-9]+)')
        $carrier = if ($carrierMatch.Success) { $carrierMatch.Groups[1].Value } else { '-' }
        $jobIds = @(Get-ListValues -Block $colonyBlock -Key 'pop_jobs')
        $buildingIds = @(Get-ListValues -Block $colonyBlock -Key 'buildings_cache')
        foreach ($id in $jobIds) { [void]$wantedJobIds.Add([string]$id) }
        foreach ($id in $buildingIds) { [void]$wantedBuildingIds.Add([string]$id) }
        if ($carrier -ne '-') { [void]$wantedPlanetIds.Add([string]$carrier) }
        [void]$colonySources.Add([pscustomobject]@{
            ColonyId = [string]$colonyId; Block = $colonyBlock; Carrier = $carrier
            JobIds = $jobIds; BuildingIds = $buildingIds
        })
    }

    $jobEntries = Get-EntryIndexMap -Lines $lines -SectionStart $popJobsHeader -Indent "`t" -WantedIds @($wantedJobIds)
    $buildingEntries = Get-EntryIndexMap -Lines $lines -SectionStart $buildingHeader -Indent "`t" -WantedIds @($wantedBuildingIds)
    $planetEntries = Get-EntryIndexMap -Lines $lines -SectionStart $planetHeader -Indent "`t`t" -WantedIds @($wantedPlanetIds)
    $jobs = Get-JobRecords -Lines $lines -EntryIndices $jobEntries
    $allBuildingTypes = Get-BuildingTypes -Lines $lines -EntryIndices $buildingEntries

    $reports = [System.Collections.Generic.List[string]]::new()
    [void]$reports.Add('# 群星存档解析报告')
    [void]$reports.Add('')
    [void]$reports.Add("- 存档：$saveName")
    [void]$reports.Add("- 版本：$version")
    [void]$reports.Add("- 日期：$date")
    [void]$reports.Add("- 文件：$([IO.Path]::GetFullPath($SavePath))")
    [void]$reports.Add("- 玩家国家 ID：$playerCountry")
    [void]$reports.Add('')
    [void]$reports.Add('## 帝国配置')
    [void]$reports.Add("- 思潮：$($ethics -join '、')")
    [void]$reports.Add("- 国民理念：$($civics -join '、')")
    [void]$reports.Add("- 飞升天赋：$($perks -join '、')")
    [void]$reports.Add("- 已记录科技数量：$($technologies.Count)")
    [void]$reports.Add("- 已采用传统数量：$($traditions.Count)")
    [void]$reports.Add('')
    [void]$reports.Add('## 已拥有星球与通用状态')
    [void]$reports.Add('| 殖民地 ID | 星球名/编号 | 定位 | 人口 | 稳定度 | 犯罪 | 建筑数 | 主要岗位 |')
    [void]$reports.Add('|---:|---|---|---:|---:|---:|---:|---|')

    $colonyReports = [System.Collections.Generic.List[object]]::new()

    foreach ($source in $colonySources) {
        $colonyId = $source.ColonyId
        $colonyBlock = $source.Block
        $carrier = $source.Carrier
        $planetName = $carrier
        if ($carrier -ne '-' -and $planetEntries.ContainsKey($carrier)) {
            $planetName = Get-PlanetName -Block (Get-BlockFromIndex -Lines $lines -Index $planetEntries[$carrier])
            if (-not $planetName) { $planetName = $carrier }
        }
        $jobItems = foreach ($jobId in $source.JobIds) { if ($jobs.ContainsKey($jobId)) { $jobs[$jobId] } }
        $byType = @{}
        foreach ($item in $jobItems) {
            if (-not $byType.ContainsKey($item.Type)) { $byType[$item.Type] = [pscustomobject]@{ Workforce = 0; Bonus = 0 } }
            if ($null -ne $item.Workforce -and $item.Workforce -ge 0) { $byType[$item.Type].Workforce += $item.Workforce }
            if ($null -ne $item.Bonus -and $item.Bonus -ge 0) { $byType[$item.Type].Bonus += $item.Bonus }
        }
        $buildingIds = $source.BuildingIds
        $buildingTypes = @{}
        foreach ($buildingId in $buildingIds) {
            if ($allBuildingTypes.ContainsKey($buildingId)) { $buildingTypes[$buildingId] = $allBuildingTypes[$buildingId] }
        }
        $experimentBuildings = @($buildingTypes.Values | Where-Object { $_ -like 'building_experimentation_chambers_*' }).Count
        $designation = Get-BlockValue -Block $colonyBlock -Key 'final_designation'
        $stability = Get-BlockValue -Block $colonyBlock -Key 'stability'
        $crime = Get-BlockValue -Block $colonyBlock -Key 'crime'
        $population = Get-BlockValue -Block $colonyBlock -Key 'num_sapient_pops'
        $getWork = { param($type) if ($byType.ContainsKey($type)) { $byType[$type].Workforce } else { 0 } }
        $topJobs = @($byType.GetEnumerator() | Where-Object { $_.Value.Workforce -ge 0 } | Sort-Object { $_.Value.Workforce } -Descending | Select-Object -First 5 | ForEach-Object { '{0}={1}' -f $_.Key,(Format-Number $_.Value.Workforce) })
        [void]$colonyReports.Add([pscustomobject]@{
            ColonyId=$colonyId; PlanetName=$planetName; Designation=$designation; Population=$population
            Stability=$stability; Crime=$crime; BuildingCount=$buildingIds.Count; ExperimentBuildings=$experimentBuildings
            Jobs=$byType; TopJobs=($topJobs -join ', ')
        })
    }

    foreach ($report in $colonyReports) {
        [void]$reports.Add("| $($report.ColonyId) | $($report.PlanetName) | $($report.Designation) | $(Format-Number $report.Population) | $(Format-Number $report.Stability) | $(Format-Number $report.Crime) | $($report.BuildingCount) | $($report.TopJobs) |")
    }

    if ($hasExperimental) {
        [void]$reports.Add('')
        [void]$reports.Add('## 实验审判专项（检测到相关理念）')
        [void]$reports.Add('| 殖民地 ID | 实验工程师 | 测试对象 | 杂勤 | 犯罪 | 执法官 | 实验研究所 |')
        [void]$reports.Add('|---:|---:|---:|---:|---:|---:|---:|')
        foreach ($report in $colonyReports) {
            $get = { param($type) if ($report.Jobs.ContainsKey($type)) { $report.Jobs[$type].Workforce } else { 0 } }
            [void]$reports.Add("| $($report.ColonyId) | $(Format-Number (&$get 'experiment_engineer')) | $(Format-Number (&$get 'test_subject')) | $(Format-Number (&$get 'slave_orderly')) | $(Format-Number $report.Crime) | $(Format-Number (&$get 'enforcer')) | $($report.ExperimentBuildings) |")
        }
    }

    $empireSize = Get-BlockValue -Block $countryBlock -Key 'empire_size'
    $populationTotal = Get-BlockValue -Block $countryBlock -Key 'num_sapient_pops'
    $militaryPower = Get-BlockValue -Block $countryBlock -Key 'military_power'
    $economyPower = Get-BlockValue -Block $countryBlock -Key 'economy_power'
    $techPower = Get-BlockValue -Block $countryBlock -Key 'tech_power'
    $fleetSize = Get-BlockValue -Block $countryBlock -Key 'fleet_size'
    $usedNavalCapacity = Get-BlockValue -Block $countryBlock -Key 'used_naval_capacity'

    $budgetTotals = @{}
    $currentMonthIndex = Find-BlockIndexByKey -Block $countryBlock -Key 'current_month'
    if ($currentMonthIndex -ge 0) {
        $currentMonthBlock = Get-BlockFromIndex -Lines $countryBlock -Index $currentMonthIndex
        $balanceIndex = Find-BlockIndexByKey -Block $currentMonthBlock -Key 'balance'
        if ($balanceIndex -ge 0) {
            $budgetTotals = Get-ResourceTotals -Block (Get-BlockFromIndex -Lines $currentMonthBlock -Index $balanceIndex)
        }
    }

    $stockpile = @{}
    $economyModuleIndex = Find-BlockIndexByKey -Block $countryBlock -Key 'standard_economy_module'
    if ($economyModuleIndex -ge 0) {
        $economyModule = Get-BlockFromIndex -Lines $countryBlock -Index $economyModuleIndex
        $resourcesIndex = Find-BlockIndexByKey -Block $economyModule -Key 'resources'
        if ($resourcesIndex -ge 0) {
            $stockpile = Get-ResourceTotals -Block (Get-BlockFromIndex -Lines $economyModule -Index $resourcesIndex)
        }
    }

    [void]$reports.Add('')
    [void]$reports.Add('## 帝国规模、科研与财政')
    [void]$reports.Add("- 帝国规模：$(Format-Number $empireSize)；智慧人口内部单位：$(Format-Number $populationTotal)")
    [void]$reports.Add("- 军力：$(Format-Number $militaryPower)；经济评分：$(Format-Number $economyPower)；科技评分：$(Format-Number $techPower)")
    [void]$reports.Add("- 舰队规模：$(Format-Number $fleetSize)；已用海军容量：$(Format-Number $usedNavalCapacity)")
    [void]$reports.Add('| 资源 | 月度净变动 | 库存 |')
    [void]$reports.Add('|---|---:|---:|')
    foreach ($resource in @('energy','minerals','food','consumer_goods','alloys','physics_research','society_research','engineering_research','unity','volatile_motes','exotic_gases','rare_crystals')) {
        $monthly = if ($budgetTotals.ContainsKey($resource)) { $budgetTotals[$resource] } else { 0 }
        $stored = if ($stockpile.ContainsKey($resource)) { $stockpile[$resource] } else { 0 }
        [void]$reports.Add("| $resource | $(Format-Number $monthly) | $(Format-Number $stored) |")
    }

    $fleetReports = [System.Collections.Generic.List[object]]::new()
    if ($headers.ContainsKey('fleet=')) {
        $ownedFleetIndex = Find-BlockIndexByKey -Block $countryBlock -Key 'owned_fleets'
        if ($ownedFleetIndex -ge 0) {
            $ownedFleetBlock = Get-BlockFromIndex -Lines $countryBlock -Index $ownedFleetIndex
            $ownedFleetIds = @($ownedFleetBlock | ForEach-Object { if ($_ -match '^\s*fleet=([0-9]+)') { $matches[1] } })
            $fleetEntries = Get-EntryIndexMap -Lines $lines -SectionStart $headers['fleet='] -Indent "`t" -WantedIds $ownedFleetIds
            foreach ($fleetId in $ownedFleetIds) {
                if (-not $fleetEntries.ContainsKey($fleetId)) { continue }
                $fleetBlock = Get-BlockFromIndex -Lines $lines -Index $fleetEntries[$fleetId]
                $power = Get-BlockValue -Block $fleetBlock -Key 'military_power'
                if (-not $power -or [double]$power -le 0) { continue }
                $fleetName = Get-PlanetName -Block $fleetBlock
                $returnDate = Get-BlockValue -Block $fleetBlock -Key 'return_date'
                $miaType = Get-BlockValue -Block $fleetBlock -Key 'mia_type'
                $shipIds = @(Get-ListValues -Block $fleetBlock -Key 'ships')
                [void]$fleetReports.Add([pscustomobject]@{
                    Id=$fleetId; Name=$fleetName; Power=[double]$power; Ships=$shipIds.Count
                    ReturnDate=$returnDate; MiaType=$miaType
                })
            }
        }
    }
    if ($fleetReports.Count -gt 0) {
        [void]$reports.Add('')
        [void]$reports.Add('## 主要舰队')
        [void]$reports.Add('| 舰队 | 战力 | 舰船数 | 返回日期 | 状态 |')
        [void]$reports.Add('|---|---:|---:|---|---|')
        foreach ($fleet in $fleetReports | Sort-Object Power -Descending | Select-Object -First 12) {
            [void]$reports.Add("| $($fleet.Name) [$($fleet.Id)] | $(Format-Number $fleet.Power) | $($fleet.Ships) | $($fleet.ReturnDate) | $($fleet.MiaType) |")
        }
    }

    $warReports = [System.Collections.Generic.List[object]]::new()
    if ($headers.ContainsKey('war=')) {
        $warEntries = Get-EntryIndexMap -Lines $lines -SectionStart $headers['war='] -Indent "`t"
        foreach ($entry in $warEntries.GetEnumerator()) {
            $warBlock = Get-BlockFromIndex -Lines $lines -Index $entry.Value
            $warText = $warBlock -join "`n"
            if ($warText -notmatch ('(?m)^\s*country=' + [regex]::Escape($playerCountry) + '\s*$')) { continue }
            $warName = Get-PlanetName -Block $warBlock
            $startDate = ([regex]::Match($warText, '(?m)^\s*start_date=\s*"([^"]+)"')).Groups[1].Value
            $attackerExhaustion = Get-BlockValue -Block $warBlock -Key 'attacker_war_exhaustion'
            $defenderExhaustion = Get-BlockValue -Block $warBlock -Key 'defender_war_exhaustion'
            $goals = @([regex]::Matches($warText, '(?m)^\s*type="(wg_[^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
            [void]$warReports.Add([pscustomobject]@{
                Id=$entry.Key; Name=$warName; Start=$startDate; AttackerExhaustion=$attackerExhaustion
                DefenderExhaustion=$defenderExhaustion; Goals=($goals -join ', ')
            })
        }
    }
    if ($warReports.Count -gt 0) {
        [void]$reports.Add('')
        [void]$reports.Add('## 当前战争')
        [void]$reports.Add('| 战争 | 开始日期 | 进攻方疲劳 | 防守方疲劳 | 战争目标 |')
        [void]$reports.Add('|---|---|---:|---:|---|')
        foreach ($war in $warReports) {
            [void]$reports.Add("| $($war.Name) [$($war.Id)] | $($war.Start) | $(Format-Number $war.AttackerExhaustion) | $(Format-Number $war.DefenderExhaustion) | $($war.Goals) |")
        }
    }

    if ($headers.ContainsKey('megastructures=')) {
        $ownedMegaIds = @(Get-ListValues -Block $countryBlock -Key 'owned_megastructures')
        if ($ownedMegaIds.Count -gt 0) {
            $megaEntries = Get-EntryIndexMap -Lines $lines -SectionStart $headers['megastructures='] -Indent "`t" -WantedIds $ownedMegaIds
            $megaTypes = [System.Collections.Generic.List[string]]::new()
            foreach ($megaId in $ownedMegaIds) {
                if (-not $megaEntries.ContainsKey($megaId)) { continue }
                $megaBlock = Get-BlockFromIndex -Lines $lines -Index $megaEntries[$megaId]
                $typeMatch = [regex]::Match(($megaBlock -join "`n"), '(?m)^\s*type="?([^"\s]+)"?')
                if ($typeMatch.Success) { [void]$megaTypes.Add("$($typeMatch.Groups[1].Value) [$megaId]") }
            }
            if ($megaTypes.Count -gt 0) {
                [void]$reports.Add('')
                [void]$reports.Add('## 已拥有巨构')
                foreach ($mega in $megaTypes) { [void]$reports.Add("- $mega") }
            }
        }
    }

    [void]$reports.Add('')
    [void]$reports.Add('## 判读提醒')
    [void]$reports.Add('- 先用通用表判断星球分工、人口、建筑和主要岗位，再根据具体玩法读取专项表。')
    if ($hasExperimental) {
        [void]$reports.Add('- `experiment_engineer` 是主要科研岗位；`test_subject` 是附带岗位，不要把测试对象数量当成主要倍率。')
        [void]$reports.Add('- 实验审判实验星通常要同时检查犯罪、杂勤奴隶、实验工程师、测试对象和执法官。')
        [void]$reports.Add('- 4.4.x 中实验研究所升级不会按普通研究所逻辑增加大量实验工程师；升级前先检查测试对象和战略资源维护。')
    }

    $elapsed = (Get-Date) - $parseStarted
    [void]$reports.Add("- 解析耗时：$([Math]::Round($elapsed.TotalSeconds, 2)) 秒；只解析最新或明确指定的单个存档。")
    $reportText = $reports -join "`r`n"
    if (-not $OutputPath) {
        $stamp = if ($date) { $date.Replace('.','-') } else { (Get-Date -Format 'yyyyMMdd-HHmmss') }
        $OutputPath = Join-Path (Split-Path -Parent $PSCommandPath) ("..\..\存档解析报告_$stamp.md")
    }
    $OutputPath = [IO.Path]::GetFullPath($OutputPath)
    $outputDir = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    [IO.File]::WriteAllText($OutputPath, $reportText, [Text.UTF8Encoding]::new($false))
    $reportText
    Write-Output "`nReport written to: $OutputPath"
}
finally {
    if (Test-Path -LiteralPath $tempDir) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
