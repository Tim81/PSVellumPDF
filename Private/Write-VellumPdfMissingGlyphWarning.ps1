function Write-VellumPdfMissingGlyphWarning {
    <#
    .SYNOPSIS
        Warns about characters an embedded font has no glyph for.
    .DESCRIPTION
        VellumPdf maps text to glyph ids through the font's cmap and draws glyph 0 (.notdef,
        usually an empty box) for an unmapped character, without any warning. In PDF/A that is a
        conformance failure (ISO 19005-2, 6.2.11.8) the preflight reports only when -Validate is
        used. This helper checks every character with EmbeddedFontHandle.GetGlyphId and writes one
        warning per call naming the first few missing characters. Whitespace controls are skipped.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()] $Handle,
        [AllowEmptyCollection()] [AllowEmptyString()] [AllowNull()] [string[]]$Text,
        [Parameter(Mandatory)] [string]$CommandName
    )
    if ($null -eq $Handle) { return }
    $missing = [System.Collections.Generic.List[string]]::new()
    foreach ($t in $Text) {
        if (-not $t) { continue }
        foreach ($rune in $t.EnumerateRunes()) {
            if ($rune.Value -in 9, 10, 13) { continue }
            if ($Handle.GetGlyphId($rune.Value) -ne 0) { continue }
            $label = 'U+{0:X4} ({1})' -f $rune.Value, $rune.ToString()
            if (-not $missing.Contains($label)) { $missing.Add($label) }
        }
    }
    if ($missing.Count -eq 0) { return }
    $shown = ($missing | Select-Object -First 5) -join ', '
    $more = if ($missing.Count -gt 5) { " and $($missing.Count - 5) more" } else { '' }
    Write-Warning ("${CommandName}: the font has no glyph for $shown$more; those characters are drawn as an empty box " +
        '(.notdef), which also fails PDF/A. Use a font that covers them.')
}
