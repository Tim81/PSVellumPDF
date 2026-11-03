# Whole text: optional sign, digits, single '.' or ',' between digit runs. Compiled once per session.
$script:VellumPdfNumberRegex = [regex]::new('^([+-]?)([0-9]+(?:[.,][0-9]+)*)$', [System.Text.RegularExpressions.RegexOptions]::Compiled)

function Get-VellumPdfNumberShape {
    <#
    .SYNOPSIS
        Classifies a string as a number, an ambiguous number, or not a number, from its separators alone.
    .DESCRIPTION
        The lexical half of ConvertFrom-VellumPdfNumberText (auto-detection, no culture). The whole trimmed
        text must be an optional sign followed by digits with single '.' or ',' separators between digit
        runs. The rules:

          1. Both separators present: the LAST one is the decimal mark, the other is the grouping mark
             (1.444,50 and 1,976.08). The decimal mark may appear only once.
          2. One separator appearing more than once: grouping (1.234.567).
          3. One separator appearing once: a decimal mark, unless exactly three digits follow it and at
             most three precede it; with more than three digits before it grouping is impossible, so it is a
             decimal mark too (12345,678).
          4. Grouping must be valid: the first group has 1 to 3 digits, every later group exactly 3.
          5. Leading zeros in a multi-digit integer part (007, 01234) are not numbers.
          6. One separator, once, exactly three digits after and 1 to 3 (not starting with 0) before
             (1,234 and 1.234) is Ambiguous: the caller decides from other evidence.

        Returns an object with Kind ('None', 'Number' or 'Ambiguous'). A Number carries Sign, Integer (digits,
        no grouping), Fraction (digits or ''), Decimal (the decimal mark the text used, or '') and Group (the
        grouping mark the text used, or ''). An Ambiguous carries Sign, Separator, Left and Right.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()] [AllowEmptyString()] [string]$Text
    )

    $none = [pscustomobject]@{ Kind = 'None'; Sign = ''; Integer = ''; Fraction = ''; Decimal = ''; Group = ''; Separator = ''; Left = ''; Right = '' }
    if ([string]::IsNullOrEmpty($Text)) { return $none }
    $match = $script:VellumPdfNumberRegex.Match($Text.Trim())
    if (-not $match.Success) { return $none }
    $sign = $match.Groups[1].Value
    $body = $match.Groups[2].Value

    # Valid grouping: 1-3 digits, then groups of exactly 3, and no leading zero on a grouped integer.
    $validGroups = {
        param([string[]]$groups)
        if ($groups[0].Length -gt 3 -or $groups[0][0] -eq '0') { return $false }
        for ($i = 1; $i -lt $groups.Count; $i++) { if ($groups[$i].Length -ne 3) { return $false } }
        $true
    }
    $number = {
        param($integer, $fraction, $decimalMark, $groupMark)
        [pscustomobject]@{ Kind = 'Number'; Sign = $sign; Integer = $integer; Fraction = $fraction; Decimal = $decimalMark; Group = $groupMark; Separator = ''; Left = ''; Right = '' }
    }

    $dots = $body.Length - $body.Replace('.', '').Length
    $commas = $body.Length - $body.Replace(',', '').Length

    if ($dots -eq 0 -and $commas -eq 0) {
        if ($body.Length -gt 1 -and $body[0] -eq '0') { return $none }
        return (& $number $body '' '' '')
    }

    if ($dots -gt 0 -and $commas -gt 0) {
        $decimalMark = if ($body.LastIndexOf('.') -gt $body.LastIndexOf(',')) { '.' } else { ',' }
        $groupMark = if ($decimalMark -eq '.') { ',' } else { '.' }
        if ((($decimalMark -eq '.') ? $dots : $commas) -ne 1) { return $none }
        $parts = $body.Split($decimalMark)
        $groups = $parts[0].Split($groupMark)
        if (-not (& $validGroups $groups)) { return $none }
        return (& $number ($groups -join '') $parts[1] $decimalMark $groupMark)
    }

    $separator = if ($dots -gt 0) { '.' } else { ',' }
    $count = [Math]::Max($dots, $commas)
    $parts = $body.Split($separator)
    if ($count -gt 1) {
        if (-not (& $validGroups $parts)) { return $none }
        return (& $number ($parts -join '') '' '' $separator)
    }
    $left = $parts[0]
    $right = $parts[1]
    if ($left.Length -gt 1 -and $left[0] -eq '0') { return $none }
    if ($right.Length -eq 3 -and $left.Length -le 3 -and $left[0] -ne '0') {
        return [pscustomobject]@{ Kind = 'Ambiguous'; Sign = $sign; Integer = ''; Fraction = ''; Decimal = ''; Group = ''; Separator = $separator; Left = $left; Right = $right }
    }
    & $number $left $right $separator ''
}
