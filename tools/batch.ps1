# Turn units.json into translation templates + batches, and write a name glossary for translators.
$sp = $PSScriptRoot
Add-Type -Path "$sp\Msg.cs"
$G = 'C:\bbport-windows\GAME\CUSA03173-patch\dvdroot_ps4\msg'
$units = Get-Content "$sp\units.json" -Raw -Encoding utf8 | ConvertFrom-Json

# Glossary of short vanilla names (eng<TAB>kor) for consistent terminology.
$nameFmgs = 'アイテム名.fmg','武器名.fmg','防具名.fmg','アクセサリ名.fmg','魔法名.fmg','NPC名.fmg','地名.fmg','魔石名.fmg','イベントテキスト.fmg'
$lines = New-Object System.Collections.Generic.List[string]; $seen = @{}
foreach ($bnd in 'item','menu') {
    $ve = [Msg]::ReadMsgBnd("$G\engus\$bnd.msgbnd.dcx"); $vk = [Msg]::ReadMsgBnd("$G\korkr\$bnd.msgbnd.dcx")
    foreach ($k in $ve.Keys) { if ($nameFmgs -notcontains $k) { continue }
        foreach ($id in $ve[$k].Keys) { $e = $ve[$k][$id]; $ko = $vk[$k][$id]
            if ($e -and $ko -and $ko -match '[\uAC00-\uD7A3]' -and $e.Length -lt 80 -and -not $seen.ContainsKey($e)) {
                $seen[$e] = 1; $lines.Add(($e -replace '\s+', ' ') + "`t" + ($ko -replace '\s+', ' ')) } } }
}
[IO.File]::WriteAllLines("$sp\glossary.tsv", $lines, (New-Object Text.UTF8Encoding $false))

# Templates: strip " +N" and replace numbers with {n0},{n1}...
$tpl = [ordered]@{}
foreach ($u in $units) {
    if ($u.how -eq 'exact' -or $u.how -eq 'norm') { continue }
    $core = $u.en -replace '\s\+\d+$', ''
    $i = 0
    $t = [regex]::Replace($core, '\d+(?:[.,]\d+)*', { param($m) $script:dummy = 0; '{n' + ($script:ni++) + '}' })
    $script:ni = 0
    $t = [regex]::Replace($core, '\d+(?:[.,]\d+)*', { param($m) $r = '{n' + $script:ni + '}'; $script:ni++; $r })
    if (-not $tpl.Contains($t)) {
        $ref = $null
        if ($u.how -like 'fuzzy*') { $ref = [pscustomobject]@{ en = $u.match; ko = $null } }
        $tpl[$t] = [pscustomobject]@{ key = 'T' + $tpl.Count; fmg = $u.fmg; en = $t; example = $core; ref_en = $(if ($ref) { $u.match } else { $null }); ref_ko = $null }
    }
}
# Fill ref_ko from vanilla for fuzzy refs
$gl = @{}
foreach ($bnd in 'item','menu') {
    $ve = [Msg]::ReadMsgBnd("$G\engus\$bnd.msgbnd.dcx"); $vk = [Msg]::ReadMsgBnd("$G\korkr\$bnd.msgbnd.dcx")
    foreach ($k in $ve.Keys) { foreach ($id in $ve[$k].Keys) { $e = $ve[$k][$id]; if ($e -and -not $gl.ContainsKey($e) -and $vk[$k][$id] -match '[\uAC00-\uD7A3]') { $gl[$e] = $vk[$k][$id] } } }
}
foreach ($t in $tpl.Values) { if ($t.ref_en) { $t.ref_ko = $gl[$t.ref_en] } }

"templates: $($tpl.Count), chars $(($tpl.Keys | % Length | Measure-Object -Sum).Sum)"
$tpl.Values | Group-Object fmg | Sort-Object Count -Descending | % { "  $($_.Name): $($_.Count)" }
@($tpl.Values) | ConvertTo-Json -Depth 3 | Out-File -Encoding utf8 "$sp\templates.json"

# Only templates not yet in translations.json need translating -> batch_N.json (translate into batch_N.out.json).
$known = @{}
if (Test-Path "$sp\translations.json") {
    (Get-Content "$sp\translations.json" -Raw -Encoding utf8 | ConvertFrom-Json).PSObject.Properties | % { $known[$_.Name] = 1 }
}
Remove-Item "$sp\batch_*.json" -ErrorAction SilentlyContinue
$todo = @($tpl.Values | ? { -not $known.ContainsKey($_.en) } | % { [pscustomobject]@{ key = $_.key; fmg = $_.fmg; en = $_.en; ref_en = $_.ref_en; ref_ko = $_.ref_ko } })
"new templates to translate: $($todo.Count)"
for ($i = 0; $i -lt $todo.Count; $i += 150) {
    $part = $todo[$i..([Math]::Min($i + 149, $todo.Count - 1))]
    [IO.File]::WriteAllText("$sp\batch_$($i / 150).json", (ConvertTo-Json @($part) -Depth 3), (New-Object Text.UTF8Encoding $false))
}
