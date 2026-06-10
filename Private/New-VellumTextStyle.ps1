function New-VellumTextStyle {
    <#
    .SYNOPSIS
        Builds a VellumPdf.Layout.Core.TextStyle from simple scalar parameters.
    .DESCRIPTION
        Internal helper shared by the public Add-* functions so that font, size,
        and alignment handling stays in one place. Returns $null when no styling
        was requested, letting callers fall back to the document's default font.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Returns a new in-memory TextStyle object; performs no external/system state change.')]
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Core.TextStyle])]
    param(
        [string]$Font,
        [double]$FontSize,
        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle
    )

    if (-not $Font -and -not $PSBoundParameters.ContainsKey('FontSize') -and -not $FontHandle) {
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
    return $style
}
