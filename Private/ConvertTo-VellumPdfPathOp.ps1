function ConvertTo-VellumPdfPathOp {
    <#
    .SYNOPSIS
        Parses path data or a point list into validated drawing operations.
    .DESCRIPTION
        -Data is a small subset of SVG path syntax in PDF points: absolute commands only,
        M x y (move), L x y (line), C x1 y1 x2 y2 x y (cubic Bezier) and Z (close). A
        command's numbers may repeat (L 1 2 3 4 draws two lines). -Point is a polyline /
        polygon given as x,y pairs; -Close closes it. Returns objects with Op (M, L, C or Z)
        and Args (doubles).
    #>
    [CmdletBinding()]
    param(
        [string]$Data,
        [object[]]$Point,
        [switch]$Close,
        [Parameter(Mandatory)] [string]$CommandName
    )
    $ops = [System.Collections.Generic.List[object]]::new()
    $number = '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?'
    if ($PSBoundParameters.ContainsKey('Point')) {
        if ($Point.Count -lt 2) { throw "${CommandName}: -Point needs at least two points." }
        $first = $true
        foreach ($p in $Point) {
            $pair = @($p)
            if ($pair.Count -ne 2) { throw "${CommandName}: each -Point must be an x,y pair." }
            foreach ($v in $pair) {
                if ($v -isnot [ValueType]) { throw "${CommandName}: -Point coordinates must be numbers." }
                Assert-VellumPdfCoordinate $v 'Point' $CommandName
            }
            $ops.Add([pscustomobject]@{ Op = $(if ($first) { 'M' } else { 'L' }); Args = [double[]]@($pair[0], $pair[1]) })
            $first = $false
        }
        if ($Close) { $ops.Add([pscustomobject]@{ Op = 'Z'; Args = [double[]]@() }) }
        return , $ops.ToArray()
    }
    $tokens = [regex]::Matches($Data, "[A-Za-z]|$number|[^\s,]")
    $arity = @{ M = 2; L = 2; C = 6; Z = 0 }
    $i = 0
    $cmd = $null
    $sawMove = $false
    while ($i -lt $tokens.Count) {
        $t = $tokens[$i].Value
        if ($t -match '^[A-Za-z]$') {
            $cmd = $t
            if ($cmd -cnotmatch '^[MLCZ]$') {
                throw "${CommandName}: unsupported path command '$t'. Use absolute M, L, C and Z only."
            }
            $i++
            if ($cmd -eq 'Z') {
                if (-not $sawMove) { throw "${CommandName}: path data must start with M." }
                $ops.Add([pscustomobject]@{ Op = 'Z'; Args = [double[]]@() })
                $cmd = $null
                continue
            }
        }
        elseif ($null -eq $cmd) {
            throw "${CommandName}: path data must start with a command (M), found '$t'."
        }
        $n = $arity[$cmd]
        if ($null -eq $n) { throw "${CommandName}: unsupported path command '$cmd'. Use absolute M, L, C and Z only." }
        if ($i + $n -gt $tokens.Count) { throw "${CommandName}: '$cmd' needs $n numbers." }
        $nums = [double[]]::new($n)
        for ($k = 0; $k -lt $n; $k++) {
            $tv = $tokens[$i + $k].Value
            if ($tv -notmatch "^$number$") { throw "${CommandName}: expected a number for '$cmd' but found '$tv'." }
            $nums[$k] = [double]::Parse($tv, [cultureinfo]::InvariantCulture)
            Assert-VellumPdfCoordinate $nums[$k] 'Data' $CommandName
        }
        $i += $n
        if ($cmd -ne 'M' -and -not $sawMove) { throw "${CommandName}: path data must start with M." }
        if ($cmd -eq 'M') {
            $sawMove = $true
            $ops.Add([pscustomobject]@{ Op = 'M'; Args = $nums })
            $cmd = 'L'   # further pairs after M are implicit line-tos, as in SVG
        }
        else { $ops.Add([pscustomobject]@{ Op = $cmd; Args = $nums }) }
    }
    if ($ops.Count -lt 2) { throw "${CommandName}: the path needs at least a move and one segment." }
    , $ops.ToArray()
}
