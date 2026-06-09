function New-VellumTextStyle {
    <#
    .SYNOPSIS
        Builds a VellumPdf.Layout.Core.TextStyle from simple scalar parameters.
    .DESCRIPTION
        Internal helper shared by the public Add-* functions so that font, size,
        and alignment handling stays in one place. Returns $null when no styling
        was requested, letting callers fall back to the document's default font.
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Core.TextStyle])]
    param(
        [string]$Font,
        [double]$FontSize
    )

    if (-not $Font -and -not $PSBoundParameters.ContainsKey('FontSize')) {
        return $null
    }

    $style = [VellumPdf.Layout.Core.TextStyle]::new()
    if ($Font) {
        # Standard14 exposes one static field per base-14 font (Helvetica, etc.).
        $style.Font = [VellumPdf.Fonts.Standard14]::$Font
    }
    if ($PSBoundParameters.ContainsKey('FontSize')) {
        $style.FontSize = $FontSize
    }
    return $style
}
