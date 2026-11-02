function ConvertTo-VellumPdfText {
    <#
    .SYNOPSIS
        Turns a cell, list-item or label value into the text to draw, with an explicit culture and format.
    .DESCRIPTION
        The one place where non-string values become text. A string is returned unchanged (the format does
        not apply to it). An IFormattable value (numbers, dates, TimeSpan, enums, Guid) becomes
        ToString(format, culture), where an empty format means the type's default; any other value is
        [string]-converted. $null becomes ''. A format string the value's type rejects throws a clear error
        naming -What (for example "column 2" or "item 3").
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()] $Value,
        [Parameter(Mandatory)] [cultureinfo]$Culture,
        [AllowNull()] [AllowEmptyString()] [string]$Format,
        [string]$CommandName = 'ConvertTo-VellumPdfText',
        [string]$What = 'the value'
    )

    if ($Value -is [string]) { return [string]$Value }
    if ($null -eq $Value) { return '' }
    $raw = $Value.PSObject.BaseObject
    if ($raw -is [System.IFormattable]) {
        $pattern = if ([string]::IsNullOrEmpty($Format)) { $null } else { $Format }
        try { return $raw.ToString($pattern, $Culture) }
        catch {
            $failure = $_.Exception
            if ($failure -is [System.FormatException] -or $failure.InnerException -is [System.FormatException]) {
                throw (New-VellumPdfErrorRecord InvalidArgument "${CommandName}: the format string '$Format' cannot format $What ($($raw.GetType().Name)): $($failure.InnerException?.Message ?? $failure.Message)")
            }
            throw
        }
    }
    [string]$raw
}
