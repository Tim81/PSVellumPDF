function Set-VellumPdfBand {
    <#
    .SYNOPSIS
        Shared implementation of Set-VellumPdfHeader and Set-VellumPdfFooter.
    .DESCRIPTION
        Builds the band's text style (font or embedded font, size, colour) and
        assigns Document.Header/Footer. Without -Height the engine's own
        SetHeader/SetFooter is used; with -Height a RunningBand is built so the
        band height can be set.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Mutates an in-memory document; performs no external/system state change.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [VellumPdf.Layout.Document]$Document,
        [Parameter(Mandatory)] [ValidateSet('Header', 'Footer')] [string]$Kind,
        [Parameter(Mandatory)] [string]$Template,
        [string]$Font,
        [double]$FontSize,
        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,
        [object]$Color,
        [double]$Height,
        [Parameter(Mandatory)] [string]$Alignment,
        [Parameter(Mandatory)] [hashtable]$BoundParameters
    )

    $command = "Set-VellumPdf$Kind"
    Assert-VellumPdfDocumentOpen -Document $Document -CommandName $command
    if ($FontHandle) {
        Assert-VellumPdfFontHandle -FontHandle $FontHandle -Document $Document -CommandName $command
    }
    else {
        Write-VellumPdfEncodingWarning -Text $Template -CommandName $command
    }

    $wantsSize  = $BoundParameters.ContainsKey('FontSize')
    $wantsColor = $BoundParameters.ContainsKey('Color')
    $style = $null
    if ([bool]$Font -or $wantsSize -or $FontHandle -or $wantsColor) {
        $default = Resolve-VellumPdfDefault -Document $Document
        $styleArgs = @{ FontSize = if ($wantsSize) { $FontSize } else { $default.FontSize } }
        if ($FontHandle) { $styleArgs['FontHandle'] = $FontHandle }
        else { $styleArgs['Font'] = if ($Font) { $Font } else { $default.Font } }
        # The band colour is honoured by VellumPdf 2.x (1.x inherited whatever the page content left set).
        if ($wantsColor) { $styleArgs['Color'] = ConvertTo-VellumColor $Color }
        $style = New-VellumTextStyle @styleArgs
    }

    $halign = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
    if ($BoundParameters.ContainsKey('Height')) {
        $band = [VellumPdf.Layout.Elements.RunningBand]::new($Template, $style, $halign)
        $band.Height = $Height
        $Document.$Kind = $band
    }
    elseif ($Kind -eq 'Header') {
        [void]$Document.SetHeader($Template, $style, $halign)
    }
    else {
        [void]$Document.SetFooter($Template, $style, $halign)
    }
    $Document
}
