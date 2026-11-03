function ConvertFrom-VellumPdfNumberText {
    <#
    .SYNOPSIS
        Reads a string that consists only of a number as a [decimal], or returns $null.
    .DESCRIPTION
        A pure function (no document, no current culture) used by the table and list cmdlets to recognise
        numbers in string input. The result is a [decimal] that keeps the scale of the text ('10.00' stays
        10.00), or $null when the text is not a number or cannot be read with certainty.

        Without -InputCulture the separators are detected from the text (see Get-VellumPdfNumberShape for
        the rules): '1.444,50' and '1,976.08' are read by their last separator, '1.234.567' is grouping,
        '55433.34' and '66443,85' are decimals, and '007', '10.0.0.1', '1 234', 'EUR5', '5%' and '1e5' are not
        numbers. An ambiguous text such as '1,234' or '1.234' (one separator, exactly three digits after
        it, at most three before) is read by -Hint, the decimal mark that other values showed (see
        Get-VellumPdfNumberHint); without a hint it returns $null.

        With -InputCulture the text is read strictly with that culture's decimal and grouping separators,
        no detection and no hint: 'de-DE' reads '1.234' as 1234 and '12.34' not at all. Leading zeros in a
        multi-digit integer part and invalid grouping are still refused.
    .PARAMETER Text
        The text to read.
    .PARAMETER InputCulture
        Read the text with this culture instead of detecting the separators.
    .PARAMETER Hint
        The decimal mark ('.' or ',') that other values of the same column or list revealed; only used to
        resolve an ambiguous text.
    #>
    [CmdletBinding()]
    [OutputType([decimal])]
    param(
        [AllowNull()] [AllowEmptyString()] [string]$Text,
        [AllowNull()] [cultureinfo]$InputCulture,
        [ValidateSet('.', ',')]
        [string]$Hint
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $trimmed = $Text.Trim()
    $result = [decimal]0
    $styles = [System.Globalization.NumberStyles]::AllowLeadingSign -bor [System.Globalization.NumberStyles]::AllowDecimalPoint
    $invariant = [cultureinfo]::InvariantCulture

    if ($InputCulture) {
        $format = $InputCulture.NumberFormat
        $decimalSeparator = [regex]::Escape($format.NumberDecimalSeparator)
        $groupSeparator = $format.NumberGroupSeparator
        # Culture group separators that are spaces (fr-FR uses U+202F) are also typed as a plain or no-break space.
        $groupPattern = if ($groupSeparator -eq '') { $null }
        elseif ([string]::IsNullOrWhiteSpace($groupSeparator)) { '[ \u00a0\u202f]' }
        else { [regex]::Escape($groupSeparator) }
        $signs = @('+', '-', $format.PositiveSign, $format.NegativeSign) | Where-Object { $_ } | Select-Object -Unique | ForEach-Object { [regex]::Escape($_) }
        $integerPattern = if ($groupPattern) { "[0-9]+(?:$groupPattern[0-9]+)*" } else { '[0-9]+' }
        $match = [regex]::Match($trimmed, "^(?<sign>$($signs -join '|'))?(?<int>$integerPattern)(?:$decimalSeparator(?<frac>[0-9]+))?$")
        if (-not $match.Success) { return $null }
        # @(...) around the if: an if-expression would unroll a one-element array into a string.
        $groups = @(if ($groupPattern) { [regex]::Split($match.Groups['int'].Value, $groupPattern) } else { $match.Groups['int'].Value })
        if ($groups.Count -gt 1) {
            if ($groups[0].Length -gt 3 -or $groups[0][0] -eq '0') { return $null }
            for ($i = 1; $i -lt $groups.Count; $i++) { if ($groups[$i].Length -ne 3) { return $null } }
        }
        elseif ($groups[0].Length -gt 1 -and $groups[0][0] -eq '0') { return $null }
        $negative = $match.Groups['sign'].Success -and $match.Groups['sign'].Value -in @('-', $format.NegativeSign)
        $normalized = ($negative ? '-' : '') + ($groups -join '') + $(if ($match.Groups['frac'].Success) { '.' + $match.Groups['frac'].Value })
        if ([decimal]::TryParse($normalized, $styles, $invariant, [ref]$result)) { return $result }
        return $null
    }

    $shape = Get-VellumPdfNumberShape -Text $trimmed
    if ($shape.Kind -eq 'None') { return $null }
    if ($shape.Kind -eq 'Ambiguous') {
        if (-not $Hint) { return $null }
        # The hint is the decimal mark: the separator is a decimal mark when it is the hint, grouping otherwise.
        $normalized = $shape.Sign + $(if ($shape.Separator -eq $Hint) { "$($shape.Left).$($shape.Right)" } else { $shape.Left + $shape.Right })
    }
    else {
        $normalized = $shape.Sign + $shape.Integer + $(if ($shape.Fraction -ne '') { '.' + $shape.Fraction })
    }
    if ([decimal]::TryParse($normalized, $styles, $invariant, [ref]$result)) { return $result }
    $null
}
