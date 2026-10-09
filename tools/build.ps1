$sp = $PSScriptRoot
Add-Type -Path "$sp\Msg.cs", "$sp\MsgWrite.cs"
$R = 'C:\bbport-windows\mods'
$G = 'C:\bbport-windows\GAME\CUSA03173-patch\dvdroot_ps4\msg'
$E = "$R\bb_enhanced_0.11.5-fix3\dvdroot_ps4\msg"
$V = "$R\Vanilla_Plus_v1.20\dvdroot_ps4\msg"
$targets = @(
    @{ Name = 'Korean msg - Enhanced'; Layers = @($E); Apply = @($true) },
    @{ Name = 'Korean msg - Enhanced + Vanilla Plus'; Layers = @($E, $V); Apply = @($true, $false) }
)
foreach ($t in $targets) {
    "### $($t.Name)"
    foreach ($lang in 'engus', 'enggb') {
        foreach ($bnd in 'item', 'menu') {
            $layers = [string[]]@($t.Layers | ForEach-Object { "$_\$lang\$bnd.msgbnd.dcx" })
            $out = "$R\$($t.Name)\dvdroot_ps4\msg\$lang\$bnd.msgbnd.dcx"
            $log = [MsgWrite]::Merge("$G\korkr\$bnd.msgbnd.dcx", "$G\$lang\$bnd.msgbnd.dcx", $layers, [bool[]]$t.Apply, $out)
            if ($lang -eq 'engus') { "[$bnd]"; $log }

            # Verify: every non-empty mod entry has text in the output, and count Hangul entries.
            $res = [Msg]::ReadMsgBnd($out)
            $missing = 0
            foreach ($l in $layers) {
                $m = [Msg]::ReadMsgBnd($l)
                foreach ($k in $m.Keys) { foreach ($id in $m[$k].Keys) {
                    if ($m[$k][$id] -and -not $res[$k][$id]) { $missing++ } } }
            }
            $hangul = 0; $total = 0
            foreach ($k in $res.Keys) { foreach ($v in $res[$k].Values) { if ($v) { $total++; if ($v -match '[\uAC00-\uD7A3]') { $hangul++ } } } }
            "  verify $lang/$bnd : missing=$missing, non-empty=$total, hangul=$hangul"
        }
    }
}
