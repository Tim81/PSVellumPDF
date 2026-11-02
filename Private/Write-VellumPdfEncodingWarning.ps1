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

    # The 27 code points Windows-1252 maps into 0x80..0x9F (all others in
    # U+0080..U+009F are C1 controls the engine cannot encode).
    if (-not (Test-Path variable:script:WinAnsiExtras)) {
        $script:WinAnsiExtras = [System.Collections.Generic.HashSet[int]]::new(
            [int[]](0x20AC, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160,
                0x2039, 0x0152, 0x017D, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
                0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x017E, 0x0178))
    }
    foreach ($t in $Text) {
        if (-not $t) { continue }
        for ($i = 0; $i -lt $t.Length; $i++) {
            $c = $t[$i]
            if ([int]$c -le 255 -and ([int]$c -lt 0x80 -or [int]$c -gt 0x9F)) { continue }
            if ($script:WinAnsiExtras.Contains([int]$c)) { continue }

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
