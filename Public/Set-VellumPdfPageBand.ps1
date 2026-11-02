function Set-VellumPdfPageBand {
    <#
    .SYNOPSIS
        Adds a repeated header or footer, such as page numbers, to every page of a page-based document.
    .DESCRIPTION
        The page-document counterpart of Set-VellumPdfHeader / Set-VellumPdfFooter. The band is
        stamped on every page when the document is saved, so it also covers pages added after
        this call and knows the final page count.

        Template tokens:
          {page}   the page number (counted from -StartNumber)
          {pages}  the last page number

        'Page {page} of {pages}' gives "Page 2 of 9". A document can hold several bands:
        a band is identified by its -Position and -Align, so a footer with left-aligned
        'Confidential' and right-aligned 'Page {page} of {pages}' is two calls, and calling again
        for the same position and alignment replaces the earlier band.

        In a tagged document (PdfUA1, PdfA2a, -Tagged) the band is marked as an artifact, which
        is what PDF/UA requires of running headers and footers. In a PDF/A document base-14 text
        is embedded automatically with a metric-compatible Liberation font.

        Positions are measured from the page's unrotated edges; on a page with -Rotate the band
        follows the unrotated page, and a warning is written when the document is saved.
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Position
        Header (near the top edge) or Footer (near the bottom edge).
    .PARAMETER Template
        The band text with optional {page} and {pages} tokens. A single line.
    .PARAMETER Align
        Left, Center (default) or Right.
    .PARAMETER FontSize
        Size in points (default 9).
    .PARAMETER Font
        A base-14 font name (default Helvetica).
    .PARAMETER FontHandle
        An embedded TrueType font from Register-VellumPdfFont. Overrides -Font.
    .PARAMETER Color
        Text colour: RGB triple in 0..1, hex or name. Default black.
    .PARAMETER Inset
        Distance of left/right aligned text from the page's side edges, in points (default 36).
    .PARAMETER Offset
        Distance of the text baseline from the top (Header) or bottom (Footer) edge, in points
        (default 30).
    .PARAMETER StartNumber
        The number {page} shows on the first page (default 1).
    .PARAMETER SkipFirstPage
        Leave the first page without this band (cover pages). The numbering still counts it,
        so the second page shows StartNumber + 1.
    .PARAMETER Remove
        Remove the band with this -Position and -Align instead of setting one.
    .EXAMPLE
        $doc | Set-VellumPdfPageBand Footer 'Page {page} of {pages}' -Align Right
    .EXAMPLE
        $doc | Set-VellumPdfPageBand Header 'Quarterly report' -Align Left -Font HelveticaBold -SkipFirstPage
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Mutates an in-memory document object only; no external/system state change.')]
    [CmdletBinding(DefaultParameterSetName = 'Set')]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('Header', 'Footer')]
        [string]$Position,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'Set')]
        [ValidateNotNullOrEmpty()]
        [string]$Template,

        [ValidateSet('Left', 'Center', 'Right')]
        [string]$Align = 'Center',

        [Parameter(ParameterSetName = 'Set')]
        [ValidateRange(1, 1000)]
        [double]$FontSize = 9,

        [Parameter(ParameterSetName = 'Set')]
        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font = 'Helvetica',

        [Parameter(ParameterSetName = 'Set')]
        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [Parameter(ParameterSetName = 'Set')]
        [object]$Color,

        [Parameter(ParameterSetName = 'Set')]
        [ValidateRange(0, 10000)]
        [double]$Inset = 36,

        [Parameter(ParameterSetName = 'Set')]
        [ValidateRange(0, 10000)]
        [double]$Offset = 30,

        [Parameter(ParameterSetName = 'Set')]
        [ValidateRange(-1000000, 1000000)]
        [int]$StartNumber = 1,

        [Parameter(ParameterSetName = 'Set')]
        [switch]$SkipFirstPage,

        [Parameter(Mandatory, ParameterSetName = 'Remove')]
        [switch]$Remove
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Set-VellumPdfPageBand'
            $prop = $Document.PSObject.Properties['PSVellumPageBands']
            if (-not $prop) {
                $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumPageBands', [ordered]@{}))
                $prop = $Document.PSObject.Properties['PSVellumPageBands']
            }
            $key = "$Position|$Align"
            if ($PSCmdlet.ParameterSetName -eq 'Remove') {
                $prop.Value.Remove($key)
                return $Document
            }
            if ($Template -match '[\r\n]') { throw 'Set-VellumPdfPageBand: -Template must be a single line.' }
            $resolved = Get-VellumPdfPageFont -Document $Document -FontHandle $FontHandle -Font $Font -CommandName 'Set-VellumPdfPageBand'
            if (-not $resolved.Handle -and $Document.Conformance -eq [VellumPdf.Document.PdfConformance]::None) {
                Write-VellumPdfEncodingWarning -Text ($Template -replace '\{pages?\}', '0') -CommandName 'Set-VellumPdfPageBand'
            }
            $rgb = $null
            if ($PSBoundParameters.ContainsKey('Color')) { $rgb = ConvertTo-VellumColor $Color }
            $prop.Value[$key] = [pscustomobject]@{
                Position = $Position; Align = $Align; Template = $Template; FontSize = $FontSize
                Resolved = $resolved; Rgb = $rgb; Inset = $Inset; Offset = $Offset
                StartNumber = $StartNumber; SkipFirstPage = [bool]$SkipFirstPage
            }
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
