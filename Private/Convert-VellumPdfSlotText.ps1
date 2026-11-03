function Convert-VellumPdfSlotText {
    <#
    .SYNOPSIS
        Turns the values of table cells or list items into the text to draw: number detection, format and culture.
    .DESCRIPTION
        Each slot is an object with Value (the raw value), Format ($null or a .NET format string), Parse
        (whether a string value may be read as a number), Group (a key: strings of one group are evidence for
        each other, a table column or the whole list) and What (a name for error messages, for example
        "column 2"). The function sets Text on every slot:

          * A string that consists only of a number is read as [decimal] (ConvertFrom-VellumPdfNumberText;
            with -InputCulture strictly by that culture, else detected, with the decimal mark of the group's
            other values resolving ambiguous ones such as '1,234') and then formatted like any other number.
          * Everything else is formatted by ConvertTo-VellumPdfText: strings unchanged, IFormattable values
            with the slot's format and the culture.

        Ambiguous strings that stay unchanged are named in ONE warning for the whole call.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$Slot,
        [Parameter(Mandatory)] [cultureinfo]$Culture,
        [AllowNull()] [cultureinfo]$InputCulture,
        [switch]$NoNumberParsing,
        [Parameter(Mandatory)] [string]$CommandName
    )

    # Cheap pre-filter so ordinary text never reaches the number functions.
    $numeric = [regex]::new('^\s*\S?[0-9]')
    $candidates = [System.Collections.Generic.List[object]]::new()
    if (-not $NoNumberParsing) {
        foreach ($slotItem in $Slot) {
            if ($slotItem.Parse -and $slotItem.Value -is [string] -and $numeric.IsMatch($slotItem.Value)) { $candidates.Add($slotItem) }
        }
    }

    $ambiguous = [System.Collections.Generic.List[string]]::new()
    foreach ($group in ($candidates | Group-Object { [string]$_.Group })) {
        $arguments = @{}
        if ($InputCulture) { $arguments['InputCulture'] = $InputCulture }
        else {
            $hint = Get-VellumPdfNumberHint -Text @($group.Group | ForEach-Object { $_.Value })
            if ($hint) { $arguments['Hint'] = $hint }
        }
        foreach ($candidate in $group.Group) {
            $number = ConvertFrom-VellumPdfNumberText -Text $candidate.Value @arguments
            if ($null -ne $number) { $candidate.Parsed = $number }
            elseif (-not $InputCulture -and (Get-VellumPdfNumberShape -Text $candidate.Value).Kind -eq 'Ambiguous') {
                if ($candidate.Value -notin $ambiguous) { $ambiguous.Add($candidate.Value) }
            }
        }
    }

    foreach ($slotItem in $Slot) {
        $source = if ($null -ne $slotItem.Parsed) { $slotItem.Parsed } else { $slotItem.Value }
        if ($source -is [string]) { $slotItem.Text = $source; continue }
        $slotItem.Text = ConvertTo-VellumPdfText -Value $source -Culture $Culture -Format $slotItem.Format -CommandName $CommandName -What $slotItem.What
    }

    if ($ambiguous.Count -gt 0) {
        Write-Warning ("${CommandName}: $($ambiguous.Count) number text(s) are ambiguous and were left unchanged: " +
            (($ambiguous | ForEach-Object { "'$_'" }) -join ', ') + '. A single separator followed by exactly three digits could be a decimal mark or ' +
            'thousands grouping, and no other value in the same column or list shows which. Pass -InputCulture, write the number unambiguously, ' +
            'or use -NoNumberParsing to draw text as given.')
    }
}
