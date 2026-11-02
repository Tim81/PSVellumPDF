function Get-VellumPdfNumberHint {
    <#
    .SYNOPSIS
        Reads the decimal-mark convention revealed by a set of number strings.
    .DESCRIPTION
        Looks at the strings that are unambiguously numbers (see Get-VellumPdfNumberShape): a text with both
        separators, a repeated separator or a separator not followed by exactly three digits shows which
        character is the decimal mark. Returns '.' or ',' when all the evidence agrees, and $null when there is
        none or it conflicts (the ambiguous values then stay text).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()] [AllowEmptyCollection()] [AllowEmptyString()] [string[]]$Text
    )

    $marks = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($t in $Text) {
        $shape = Get-VellumPdfNumberShape -Text $t
        if ($shape.Kind -ne 'Number') { continue }
        if ($shape.Decimal) { [void]$marks.Add($shape.Decimal) }
        elseif ($shape.Group) { [void]$marks.Add($(if ($shape.Group -eq '.') { ',' } else { '.' })) }
    }
    if ($marks.Count -eq 1) { return @($marks)[0] }
    $null
}
