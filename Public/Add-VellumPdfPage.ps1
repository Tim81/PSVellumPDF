function Add-VellumPdfPage {
    <#
    .SYNOPSIS
        Adds a page to a page-based document.
    .DESCRIPTION
        Appends one page (or -Count pages) of the document's default size, or of
        -PageSize / -PageWidthMm x -PageHeightMm. -Rotate turns the page for display
        (the content is not re-flowed). Pages are addressed by their 1-based number
        in the other page cmdlets.
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER PageSize
        A named size for this page (A0-A6, Ledger, Legal, Letter).
    .PARAMETER PageWidthMm
        Custom width in millimetres (1..5080), with -PageHeightMm.
    .PARAMETER PageHeightMm
        Custom height in millimetres (1..5080).
    .PARAMETER Rotate
        Display rotation in degrees clockwise: 0, 90, 180 or 270.
    .PARAMETER Count
        Number of identical pages to add (default 1).
    .PARAMETER PassThru
        Return the new PdfPage object instead of the document.
    .EXAMPLE
        $doc | Add-VellumPdfPage -PageSize Letter -Rotate 90
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance), or PdfPage with -PassThru
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([VellumPdf.Document.PdfDocument])]
    [OutputType([VellumPdf.Document.PdfPage], ParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(ParameterSetName = 'Named')]
        [ValidateSet('A0', 'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'Ledger', 'Legal', 'Letter')]
        [string]$PageSize,

        [Parameter(Mandatory, ParameterSetName = 'Custom')]
        [ValidateRange(1.0, 5080.0)]
        [double]$PageWidthMm,

        [Parameter(Mandatory, ParameterSetName = 'Custom')]
        [ValidateRange(1.0, 5080.0)]
        [double]$PageHeightMm,

        [ValidateSet(0, 90, 180, 270)]
        [int]$Rotate = 0,

        [ValidateRange(1, 10000)]
        [int]$Count = 1,

        [switch]$PassThru
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfPage'
            $size = switch ($PSCmdlet.ParameterSetName) {
                'Named' { [VellumPdf.Document.PageSize]::$PageSize }
                'Custom' { [VellumPdf.Document.PageSize]::Mm($PageWidthMm, $PageHeightMm) }
                default { $Document.DefaultPageSize }
            }
            for ($i = 0; $i -lt $Count; $i++) {
                $page = $Document.AddPage($size)
                if ($Rotate -ne 0) { $page.Rotate = $Rotate }
            }
            if ($PassThru) { $page } else { $Document }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
