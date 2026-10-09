# Apply Korean translations to the merged Enhanced+V+ msg and assemble the translation mod (msg + Korean font).
$sp = $PSScriptRoot
Add-Type -Path "$sp\Msg.cs", "$sp\MsgWrite.cs"
$R = 'C:\bbport-windows\mods'
$G = 'C:\bbport-windows\GAME\CUSA03173-patch\dvdroot_ps4\msg'
$src = "$R\Korean msg - Enhanced + Vanilla Plus\dvdroot_ps4"
$dst = "$R\Korean Translation - Enhanced + Vanilla Plus\dvdroot_ps4"
$font = "$R\Font- 03173 normal hangul, eng embed\menu"

# template english -> korean: saved translations first, then any new batch outputs (keyed T0..).
$saved = @{}
if (Test-Path "$sp\translations.json") {
    (Get-Content "$sp\translations.json" -Raw -Encoding utf8 | ConvertFrom-Json).PSObject.Properties | % { $saved[$_.Name] = $_.Value }
}
$tko = @{}
foreach ($f in Get-ChildItem "$sp\batch_*.out.json" -ErrorAction SilentlyContinue) {
    $o = Get-Content $f.FullName -Raw -Encoding utf8 | ConvertFrom-Json
    foreach ($p in $o.PSObject.Properties) { $tko[$p.Name] = $p.Value }
}
# Terminology fixes across batches (official Korean terms, consistent wording).
function Fix-Term([string]$v) {
    $v = [regex]::Replace($v, '유령 변(종|형)(이다)?\.', '유령 변형이다.')
    $v = $v.Replace('연맹 서약', '리그의 맹약').Replace('연맹', '리그')
    $v = $v.Replace('통찰', '계몽')
    $v = $v.Replace('불꽃 지피기 의식', '점화의 의식')
    $v = $v.Replace('변형 무기', '장치 무기')
    $v = $v.Replace([string][char]0x201C, '"').Replace([string][char]0x201D, '"')
    return $v
}
foreach ($k in @($tko.Keys)) { $tko[$k] = Fix-Term $tko[$k] }
foreach ($k in @($saved.Keys)) { $saved[$k] = Fix-Term $saved[$k] }
$keyToEn = @{}
foreach ($t in (Get-Content "$sp\templates.json" -Raw -Encoding utf8 | ConvertFrom-Json)) { $keyToEn[$t.key] = $t.en }
$tplKo = @{}
foreach ($k in $saved.Keys) { $tplKo[$k] = $saved[$k] }
$added = 0
foreach ($k in $tko.Keys) { if ($keyToEn.ContainsKey($k)) { $tplKo[$keyToEn[$k]] = $tko[$k]; $added++ } }
"translations loaded: saved $($saved.Count) + new $added; templates needed $($keyToEn.Count)"
# Remember new translations for next time.
if ($added -gt 0) {
    $out = [ordered]@{}; foreach ($k in $tplKo.Keys) { $out[$k] = $tplKo[$k] }
    [IO.File]::WriteAllText("$sp\translations.json", ($out | ConvertTo-Json -Depth 2), (New-Object Text.UTF8Encoding $false))
}

# (bnd|fmg|id) -> korean
$byRef = @{}; $missing = 0
foreach ($u in (Get-Content "$sp\units.json" -Raw -Encoding utf8 | ConvertFrom-Json)) {
    $ko = $null
    if ($u.how -eq 'exact' -or $u.how -eq 'norm') { $ko = $u.ko }
    else {
        $suffix = ''; $core = $u.en
        if ($u.en -match '^(.*\S)(\s\+\d+)$') { $core = $Matches[1]; $suffix = $Matches[2] }
        $nums = @([regex]::Matches($core, '\d+(?:[.,]\d+)*') | % Value)
        $script:ni = 0
        $t = [regex]::Replace($core, '\d+(?:[.,]\d+)*', { param($m) $r = '{n' + $script:ni + '}'; $script:ni++; $r })
        if ($tplKo.ContainsKey($t)) {
            $ko = $tplKo[$t]
            for ($i = 0; $i -lt $nums.Count; $i++) { $ko = $ko.Replace('{n' + $i + '}', $nums[$i]) }
            $ko += $suffix
        }
    }
    if (-not $ko) { $missing++; continue }
    foreach ($r in $u.refs) { $byRef[$r] = $ko }
}
"refs translated: $($byRef.Count), units without translation: $missing"

foreach ($lang in 'engus', 'enggb') {
    foreach ($bnd in 'item', 'menu') {
        $data = [Msg]::ReadMsgBnd("$src\msg\$lang\$bnd.msgbnd.dcx")
        $n = 0
        foreach ($k in @($data.Keys)) { foreach ($id in @($data[$k].Keys)) {
            $r = "$bnd|$k|$id"
            if ($byRef.ContainsKey($r)) { $data[$k][$id] = $byRef[$r]; $n++ } } }
        [MsgWrite]::Save("$G\korkr\$bnd.msgbnd.dcx", $data, "$dst\msg\$lang\$bnd.msgbnd.dcx")
        # report leftover English that came from the mods
        $base = [Msg]::ReadMsgBnd("$G\korkr\$bnd.msgbnd.dcx"); $left = 0
        $chk = [Msg]::ReadMsgBnd("$dst\msg\$lang\$bnd.msgbnd.dcx")
        foreach ($k in $chk.Keys) { foreach ($id in $chk[$k].Keys) { $t = $chk[$k][$id]
            if ($t -and $t -notmatch '[\uAC00-\uD7A3]' -and -not ($base[$k].ContainsKey($id) -and $base[$k][$id] -eq $t) -and $t -notmatch '^\s*(\*|NOT NEEDED|en\d+|\d+|<\?[^>]*\?>|-|\.\.\.)\s*$') { $left++ } } }
        "$lang/$bnd : replaced $n, leftover English $left"
    }
    New-Item -ItemType Directory -Force "$dst\menu\$lang" | Out-Null
    Copy-Item "$font\$lang\font.gfx" "$dst\menu\$lang\font.gfx" -Force
}
Get-ChildItem -Recurse -File (Split-Path $dst) | % { "{0}  {1:N0}" -f ($_.FullName.Substring($R.Length + 1)), $_.Length }
