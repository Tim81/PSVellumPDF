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

        Bottom margins on Paragraph, Heading, List and Table only limit the
        element's box in VellumPdf.Layout - they add NO space before the next
        element. Callers for those elements pass -Document and -DeferBottom: the
        requested bottom space is then remembered on the document
        (PSVellumPendingSpace) and added to the TOP margin of the next element.
        Every caller that passes -Document also consumes any pending space.
        Image, LineSeparator and PieChart honour bottom margins natively and do
        not use -DeferBottom.
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
        [hashtable]$BoundParameters,

        [object]$Document,

        [switch]$DeferBottom
    )

    # Space deferred by the previous element's -MarginBottom joins this
    # element's top margin (and is consumed whether or not margins were bound).
    $pending = 0.0
    if ($Document) {
        $prop = $Document.PSObject.Properties['PSVellumPendingSpace']
        if ($prop -and $prop.Value) {
            $pending = [double]$prop.Value
            $prop.Value = 0.0
        }
    }

    $wantsTop    = $BoundParameters.ContainsKey('MarginTop')
    $wantsBottom = $BoundParameters.ContainsKey('MarginBottom')

    if ($Document -and $DeferBottom -and $wantsBottom -and $Bottom -ne 0) {
        if ($Document.PSObject.Properties['PSVellumPendingSpace']) {
            $Document.PSVellumPendingSpace = [double]$Bottom
        } else {
            $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumPendingSpace', [double]$Bottom))
        }
    }

    if (-not $wantsTop -and -not $wantsBottom -and $pending -eq 0) {
        return
    }

    $cur = $Element.Margins
    $newTop    = ($(if ($wantsTop) { $Top } else { $cur.Top })) + $pending
    $newRight  = $cur.Right
    # A deferred bottom margin must not also shrink this element's own box.
    $newBottom = if ($wantsBottom -and -not ($Document -and $DeferBottom)) { $Bottom } else { $cur.Bottom }
    $newLeft   = $cur.Left

    $Element.Margins = [VellumPdf.Layout.Core.EdgeInsets]::new($newTop, $newRight, $newBottom, $newLeft)
}
