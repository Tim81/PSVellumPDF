function Write-VellumPdfEncodingWarning {
    <#
    .SYNOPSIS
        Warns when text cannot be rendered by the base-14 (Standard14) fonts.
    .DESCRIPTION
        Since VellumPdf 1.9 the Standard14 fonts encode text as Windows-1252
        (WinAnsi): Latin-1 plus the typographic block (euro sign, curly quotes,
        bullet, en/em dash, ellipsis, trademark, ...). Any other character is
        drawn as '?' - no library exception, no missing-glyph marker. Cmdlets
        call this helper for user text that will render with a Standard14 font
        (no -FontHandle in play) so the data loss surfaces as an early
        PowerShell warning pointing at the fix. After saving,
        Save-VellumPdfDocument also reports the engine's own authoritative list
        (Document.TextEncodingWarnings).

        Emits at most one warning per call. Characters encodable in
        Windows-1252 (and tabs/newlines) never trigger the warning.
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
        for ($i = 0; $i -lt $t.Length; $i++) {
            $c = $t[$i]
            if ([int]$c -lt 0x80 -or (Test-VellumPdfWinAnsiChar -CodeUnit ([int]$c))) { continue }   # ASCII fast path, no call

            # Report the real codepoint for supplementary-plane characters
            # (emoji etc.) instead of a bare UTF-16 surrogate half.
            if ([char]::IsHighSurrogate($c) -and ($i + 1) -lt $t.Length -and [char]::IsLowSurrogate($t[$i + 1])) {
                $codepoint = [char]::ConvertToUtf32($c, $t[$i + 1])
                $display = [char]::ConvertFromUtf32($codepoint)
            }
            else {
                $codepoint = [int]$c
                $display = [string]$c
            }

            Write-Warning ("${CommandName}: text contains characters outside Windows-1252 " +
                "(first: '$display', U+$($codepoint.ToString('X4'))) that the base-14 PDF fonts " +
                'cannot encode; they will render mangled. Embed a TrueType font with ' +
                'Register-VellumPdfFont and pass its handle via -FontHandle.')
            return
        }
    }
}
