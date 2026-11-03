function Assert-VellumPdfLanguageTag {
    <#
    .SYNOPSIS
        Throws unless the value looks like a BCP 47 language tag (en, en-US, nl-NL, zh-Hant-TW, x-private).
    .DESCRIPTION
        PDF/UA and PDF/A read a language tag from the catalog and from structure elements.
        VellumPdf writes whatever string it is given, and the in-process preflight only checks
        the catalog tag, so a typo would reach the file. This checks the syntax, not whether the
        subtags are registered.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()] [AllowEmptyString()] [string]$Value,
        [Parameter(Mandatory)] [string]$CommandName,
        [string]$Name = 'Language'
    )
    if ([string]::IsNullOrEmpty($Value)) { return }
    if ($Value -notmatch '^(?:[A-Za-z]{2,8}|[xXiI])(?:-[A-Za-z0-9]{1,8})*$') {
        throw (New-VellumPdfErrorRecord InvalidArgument "${CommandName}: -$Name '$Value' is not a BCP 47 language tag (for example en, en-US or nl-NL).")
    }
}
