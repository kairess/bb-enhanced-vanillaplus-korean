# Build translation units for the English entries in the merged Enhanced+V+ msg.
# Output: units.json = [{ en, ko, how, refs[] }]; ko is pre-filled when vanilla Korean can be reused.
$sp = $PSScriptRoot
Add-Type -Path "$sp\Msg.cs", "$sp\Tr.cs"
$R = 'C:\bbport-windows\mods'
$G = 'C:\bbport-windows\GAME\CUSA03173-patch\dvdroot_ps4\msg'
$merged = "$R\Korean msg - Enhanced + Vanilla Plus\dvdroot_ps4\msg\engus"

$gloss = @{}; $normGloss = @{}; $byFmg = @{}
foreach ($bnd in 'item', 'menu') {
    $ve = [Msg]::ReadMsgBnd("$G\engus\$bnd.msgbnd.dcx"); $vk = [Msg]::ReadMsgBnd("$G\korkr\$bnd.msgbnd.dcx")
    foreach ($k in $ve.Keys) {
        if (-not $byFmg.ContainsKey($k)) { $byFmg[$k] = New-Object 'System.Collections.Generic.List[string]' }
        foreach ($id in $ve[$k].Keys) {
            $e = $ve[$k][$id]; $ko = $vk[$k][$id]
            if ($e -and $ko -and $ko -match '[\uAC00-\uD7A3]') {
                if (-not $gloss.ContainsKey($e)) { $gloss[$e] = $ko; $byFmg[$k].Add($e) }
                $n = [Tr]::Norm($e); if ($n -and -not $normGloss.ContainsKey($n)) { $normGloss[$n] = $ko }
            }
        }
    }
}

$units = [ordered]@{}
foreach ($bnd in 'item', 'menu') {
    $m = [Msg]::ReadMsgBnd("$merged\$bnd.msgbnd.dcx"); $base = [Msg]::ReadMsgBnd("$G\korkr\$bnd.msgbnd.dcx")
    foreach ($k in $m.Keys) { foreach ($id in $m[$k].Keys) {
        $t = $m[$k][$id]
        if (-not $t -or $t -match '[\uAC00-\uD7A3]') { continue }
        if ($base[$k].ContainsKey($id) -and $base[$k][$id] -eq $t) { continue }
        if ($t -match '^\s*(\*|NOT NEEDED|en\d+|\d+|<\?[^>]*\?>|-|\.\.\.)\s*$') { continue }
        if (-not $units.Contains($t)) { $units[$t] = [pscustomobject]@{ en = $t; ko = $null; how = $null; fmg = $k; refs = @() } }
        $units[$t].refs += "$bnd|$k|$id"
    } }
}

$stats = @{}
foreach ($u in $units.Values) {
    $t = $u.en
    # " +N" upgrade suffix: translate the base name.
    $suffix = ''; $core = $t
    if ($t -match '^(.*\S)(\s\+\d+)$') { $core = $Matches[1]; $suffix = $Matches[2] }
    if ($gloss.ContainsKey($core)) { $u.ko = $gloss[$core] + $suffix; $u.how = 'exact' }
    elseif ($normGloss.ContainsKey([Tr]::Norm($core))) { $u.ko = $normGloss[[Tr]::Norm($core)] + $suffix; $u.how = 'norm' }
    elseif ($core.Length -gt 60 -and $byFmg.ContainsKey($u.fmg)) {
        $r = [Tr]::Best($core, $byFmg[$u.fmg])
        if ($r[0] -ge 0.80) { $u.ko = $gloss[$r[1]]; $u.how = 'fuzzy{0:N2}' -f $r[0]; $u | Add-Member match $r[1] }
    }
    $key = if ($u.how) { ($u.how -replace '[\d.]+$', '') } else { 'todo' }
    $stats[$key]++
}
$stats.GetEnumerator() | % { "$($_.Key): $($_.Value)" }
# Unique cores still needing translation (strip +N)
$cores = @{}
foreach ($u in $units.Values) { if (-not $u.ko) { $c = $u.en -replace '\s\+\d+$', ''; $cores[$c] = $u.fmg } }
"unique cores to translate: $($cores.Count), chars $(($cores.Keys | % Length | Measure-Object -Sum).Sum)"
@($units.Values) | ConvertTo-Json -Depth 4 | Out-File -Encoding utf8 "$sp\units.json"
