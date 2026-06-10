function Set-VellumPdfFooter {
    <#
    .SYNOPSIS
        Sets a running footer band on a VellumPdf document.
    .DESCRIPTION
        Wraps Document.SetFooter(template, style, alignment). The footer band
        appears at the bottom of every page. The document flows through the
        pipeline for chaining.

        Template tokens:
          {page}  - replaced with the current page number (e.g. 2)
          {pages} - replaced with the total page count   (e.g. 9)

        Example template: 'Page {page} of {pages}'
    .EXAMPLE
        $doc | Set-VellumPdfFooter -Template 'Page {page} of {pages}'
    .EXAMPLE
        $doc | Set-VellumPdfFooter -Template '{page} / {pages}' `
               -Font TimesRoman -FontSize 9 -Alignment Right
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Mutates an in-memory document object only; no external/system state change.')]
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory)]
        [string]$Template,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font,

        [ValidateRange(1, 1000)]
        [double]$FontSize,

        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string]$Alignment = 'Center'
    )

    process {
        Write-VellumPdfEncodingWarning -Text $Template -CommandName 'Set-VellumPdfFooter'
        $wantsFont = [bool]$Font -or $PSBoundParameters.ContainsKey('FontSize')
        $style = if ($wantsFont) {
            $default = Resolve-VellumPdfDefault -Document $Document
            $effFont = if ($Font) { $Font } else { $default.Font }
            $effSize = if ($PSBoundParameters.ContainsKey('FontSize')) { $FontSize } else { $default.FontSize }
            New-VellumTextStyle -Font $effFont -FontSize $effSize
        } else {
            $null
        }

        $halign = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
        [void]$Document.SetFooter($Template, $style, $halign)
        $Document
    }
}
