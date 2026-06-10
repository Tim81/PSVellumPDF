function Write-VellumPdfEncodingWarning {
    <#
    .SYNOPSIS
        Warns when text cannot be rendered by the base-14 (Standard14) fonts.
    .DESCRIPTION
        The Standard14 fonts cover (roughly) Latin-1. VellumPdf renders text
        containing characters outside that range SILENTLY MANGLED - no library
        exception, no missing-glyph marker (verified by probe). Cmdlets call
        this helper for any user text that will render with a Standard14 font
        (i.e. no -FontHandle in play) so the data loss at least surfaces as a
        PowerShell warning pointing at the fix.

        Emits at most one warning per call. Characters U+0000..U+00FF
        (ASCII + Latin-1, including tabs/newlines) never trigger the warning.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Text,

        [Parameter(Mandatory)]
        [string]$CommandName
    )

    foreach ($t in $Text) {
        if (-not $t) { continue }
        foreach ($c in $t.ToCharArray()) {
            if ([int]$c -gt 255) {
                Write-Warning ("${CommandName}: text contains characters outside Latin-1 " +
                    "(first: '$c', U+$(([int]$c).ToString('X4'))) that the base-14 PDF fonts " +
                    'cannot encode; they will render mangled. Embed a TrueType font with ' +
                    'Register-VellumPdfFont and pass its handle via -FontHandle.')
                return
            }
        }
    }
}
