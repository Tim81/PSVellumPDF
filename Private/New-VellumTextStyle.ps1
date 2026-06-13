function New-VellumTextStyle {
    <#
    .SYNOPSIS
        Builds a VellumPdf.Layout.Core.TextStyle from simple scalar parameters.
    .DESCRIPTION
        Internal helper shared by the public Add-* functions so that font, size,
        color, and alignment handling stays in one place. Returns $null when no
        styling was requested, letting callers fall back to the document's default
        font.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Returns a new in-memory TextStyle object; performs no external/system state change.')]
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Core.TextStyle])]
    param(
        [string]$Font,
        [double]$FontSize,
        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [ValidateCount(3, 3)]
        [ValidateRange(0.0, 1.0)]
        [double[]]$Color,

        [string]$LinkUri,

        # Line leading (extra vertical space between lines), in points.
        [ValidateRange(0, 1000)]
        [double]$Leading
    )

    $wantsColor   = $PSBoundParameters.ContainsKey('Color')
    $wantsLeading = $PSBoundParameters.ContainsKey('Leading')

    # Link hygiene: whitespace-only URIs become no-link (a literal '/URI (   )'
    # annotation otherwise lands in the PDF), and the URI scheme is allowlisted
    # to http/https/mailto. An allowlist (not a blocklist) is used so a NEW
    # dangerous scheme - a future protocol handler, vbscript:, file:, data:, or a
    # scheme-relative '//host' that a reader resolves as https - cannot reach the
    # PDF just because it is not on a list of known-bad names. A generated /URI
    # action should only ever be an outbound web or mail link.
    #
    # The scheme is read from a copy with ALL whitespace and control characters
    # removed, not just leading ones, because lenient readers strip that noise
    # before dispatching the scheme. Reading the scheme from the raw value would
    # let 'java<TAB>script:', a mid-keyword no-break space, or a leading 0x01
    # byte present a different scheme to the reader than the one we validated.
    $LinkUri = if ($PSBoundParameters.ContainsKey('LinkUri')) { $LinkUri.Trim() } else { '' }
    $wantsLink = $LinkUri -ne ''
    if ($wantsLink) {
        $normalized = $LinkUri -replace '[\s\p{Cc}\p{Cf}]', ''
        $scheme = [regex]::Match($normalized, '^(?<s>[a-zA-Z][a-zA-Z0-9+.-]*):').Groups['s'].Value
        if ($scheme.ToLowerInvariant() -notin @('http', 'https', 'mailto')) {
            $what = if ($scheme) { "scheme '$scheme'" } else { 'a relative or scheme-less URI' }
            throw ("-LinkUri uses $what; only http, https, and mailto URLs are allowed in " +
                "generated documents (got '$LinkUri').")
        }
    }

    if (-not $Font -and -not $PSBoundParameters.ContainsKey('FontSize') -and -not $FontHandle `
            -and -not $wantsColor -and -not $wantsLink -and -not $wantsLeading) {
        return $null
    }

    $style = [VellumPdf.Layout.Core.TextStyle]::new()
    if ($FontHandle) {
        # Embedded TrueType font wins; do NOT also set Standard14 Font.
        $style.FontRef = [VellumPdf.Layout.Core.FontReference]::new($FontHandle)
    } elseif ($Font) {
        # Standard14 exposes one static field per base-14 font (Helvetica, etc.).
        $style.Font = [VellumPdf.Fonts.Standard14]::$Font
    }
    if ($PSBoundParameters.ContainsKey('FontSize')) {
        $style.FontSize = $FontSize
    }
    if ($wantsColor) {
        $style.Color = [VellumPdf.Layout.Core.ColorRgb]::new($Color[0], $Color[1], $Color[2])
    }
    if ($wantsLink) {
        $style.LinkUri = $LinkUri
    }
    if ($wantsLeading) {
        $style.Leading = $Leading
    }
    return $style
}
