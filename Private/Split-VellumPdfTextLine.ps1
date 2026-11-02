function Split-VellumPdfTextLine {
    <#
    .SYNOPSIS
        Breaks text into lines that fit a width, using the real font metrics.
    .DESCRIPTION
        Greedy line breaking shared by the text box, table and list cmdlets. A line break in the text
        starts a new paragraph, an empty paragraph gives an empty line, only spaces and tabs separate
        words (a no-break space stays inside its word), and a word wider than the width is split at
        character boundaries. Returns objects with Words (string[]) and Last ($true for the last line of
        a paragraph, which justified text leaves ragged).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [AllowEmptyString()] [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [double]$Width,
        [Parameter(Mandatory)] $Resolved,
        [Parameter(Mandatory)] [double]$FontSize
    )
    $measure = { param($s) Measure-VellumPdfTextWidth -Resolved $Resolved -Text $s -FontSize $FontSize }
    $lines = [System.Collections.Generic.List[object]]::new()
    foreach ($paragraph in ($Text -split '\r?\n')) {
        $words = @($paragraph -split '[ \t]+' | Where-Object { $_ -ne '' })
        if ($words.Count -eq 0) { $lines.Add([pscustomobject]@{ Words = [string[]]@(); Last = $true }); continue }
        $current = [System.Collections.Generic.List[string]]::new()
        foreach ($word in $words) {
            $pieces = @($word)
            if ((& $measure $word) -gt $Width) {
                $pieces = [System.Collections.Generic.List[string]]::new()
                $chunk = ''
                foreach ($rune in $word.EnumerateRunes()) {
                    $next = $chunk + $rune.ToString()
                    if ($chunk -ne '' -and (& $measure $next) -gt $Width) { $pieces.Add($chunk); $chunk = $rune.ToString() }
                    else { $chunk = $next }
                }
                if ($chunk -ne '') { $pieces.Add($chunk) }
            }
            foreach ($piece in $pieces) {
                $candidate = if ($current.Count) { ($current -join ' ') + ' ' + $piece } else { $piece }
                if ($current.Count -and (& $measure $candidate) -gt $Width) {
                    $lines.Add([pscustomobject]@{ Words = $current.ToArray(); Last = $false })
                    $current = [System.Collections.Generic.List[string]]::new()
                }
                $current.Add($piece)
            }
        }
        $lines.Add([pscustomobject]@{ Words = $current.ToArray(); Last = $true })
    }
    , $lines.ToArray()
}
