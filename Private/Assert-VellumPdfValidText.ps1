function Assert-VellumPdfValidText {
    <#
    .SYNOPSIS
        Throws when text contains an unpaired UTF-16 surrogate.
    .DESCRIPTION
        A lone surrogate is not a character. Embedded fonts (every PDF/A and PDF/UA document, which embed
        base-14 text too) look characters up by code point and fail inside the engine with a raw .NET
        exception, in the middle of a text object. Checking up front gives a cmdlet-named error before
        anything is drawn.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()] [AllowEmptyString()] [AllowEmptyCollection()] [string[]]$Text,
        [Parameter(Mandatory)] [string]$CommandName
    )
    foreach ($t in $Text) {
        if ([string]::IsNullOrEmpty($t)) { continue }
        $m = [regex]::Match($t, '[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]')
        if ($m.Success) {
            throw ("${CommandName}: the text contains an unpaired UTF-16 surrogate (U+{0:X4}) at position {1}, which is not a character. " -f [int][char]$m.Value, $m.Index) +
                'Check how the string was built (for example a substring that cut an emoji in half).'
        }
    }
}
