function Set-VellumPdfElementMargin {
    <#
    .SYNOPSIS
        Applies MarginTop and/or MarginBottom to a VellumPdf layout element.
    .DESCRIPTION
        Internal helper that reads the element's current .Margins EdgeInsets value,
        overrides only the sides passed via -Top or -Bottom, and assigns the result
        back to .Margins. This keeps the margin-override logic in one place rather
        than duplicating the EdgeInsets construction across every Add-VellumPdf*
        cmdlet that supports element-level spacing.

        Only the parameters present in -BoundParameters (the caller's
        $PSBoundParameters) are applied; unbound sides are left at their current
        value.
    .NOTES
        Callers pass their own $PSBoundParameters so this helper can test which
        parameters were actually bound versus simply holding a default value.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Mutates an in-memory layout element; performs no external/system state change.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Element,

        [double]$Top,

        [double]$Bottom,

        [Parameter(Mandatory)]
        [hashtable]$BoundParameters
    )

    $wantsTop    = $BoundParameters.ContainsKey('MarginTop')
    $wantsBottom = $BoundParameters.ContainsKey('MarginBottom')

    if (-not $wantsTop -and -not $wantsBottom) {
        return
    }

    $cur = $Element.Margins
    $newTop    = if ($wantsTop)    { $Top }    else { $cur.Top }
    $newRight  = $cur.Right
    $newBottom = if ($wantsBottom) { $Bottom } else { $cur.Bottom }
    $newLeft   = $cur.Left

    $Element.Margins = [VellumPdf.Layout.Core.EdgeInsets]::new($newTop, $newRight, $newBottom, $newLeft)
}
