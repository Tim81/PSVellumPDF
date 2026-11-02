function New-VellumPdfPageDocument {
    <#
    .SYNOPSIS
        Creates a page-based PDF document for precise placement: drawing, forms, links, outlines.
    .DESCRIPTION
        New-VellumPdfDocument builds flowing documents (text wraps and paginates
        for you). This cmdlet creates the other kind: a document made of explicit
        pages that you place content on by coordinates, using the VellumPdf.Kernel
        engine directly. Use it for what flow layout cannot express:

          Add-VellumPdfPage          add pages (any size, rotation)
          Add-VellumPdfShape / -Text / -Gradient / -PageImage / -PageBarcode
                                     draw at x/y positions
          Invoke-VellumPdfCanvas     full canvas access from a script block
          Add-VellumPdfFormField     fillable AcroForm fields
          Add-VellumPdfLink          link rectangles to URLs or other pages
          Add-VellumPdfOutlineEntry  bookmarks, collapsed or expanded

        then Save-VellumPdfDocument. Coordinates are PDF points with the origin at
        the page's bottom-left (72 points = 1 inch). Set-VellumPdfDocumentInfo,
        Set-VellumPdfOutputIntent, Register-VellumPdfFont, Protect-VellumPdfDocument
        and Set-VellumPdfSignature work on page documents too.

        Tagging: with -Tagged (implied by -Conformance PdfA2a and PdfUA1) the document
        gets a structure tree. Text is tagged (P, H1-H6, Span, Caption via
        Add-VellumPdfText -Role), shapes and gradients are artifacts unless given
        -AltText, images and barcodes need alternate text (or -Decorative), and
        Invoke-VellumPdfCanvas drawing is an artifact. Links and form fields cannot be
        tagged by VellumPdf, so a PDF/UA document containing them is not fully
        conformant (the cmdlets warn). PDF/A and PDF/UA need embedded fonts and, for
        PDF/UA, a title (Set-VellumPdfDocumentInfo -Title) and -Language; base-14 text
        is embedded automatically with a metric-compatible substitute font.

        -Linearize writes a "fast web view" file (first page readable while the rest
        downloads). It cannot be combined with -UseObjectStreams or encryption, and
        signing ignores it. -DocumentId and -Timestamp fix the otherwise random
        document ID and creation date, which makes the output byte-for-byte
        reproducible.
    .PARAMETER Conformance
        None (default), PdfA2b, PdfA2u, PdfA2a or PdfUA1.
    .PARAMETER Tagged
        Write a structure tree (tagged PDF). Implied by PdfA2a and PdfUA1.
    .PARAMETER PageSize
        The default size of added pages: A0-A6, Ledger, Legal, Letter. Default A4.
    .PARAMETER PageWidthMm
        Custom default page width in millimetres (1..5080), with -PageHeightMm.
    .PARAMETER PageHeightMm
        Custom default page height in millimetres (1..5080).
    .PARAMETER Language
        BCP 47 document language written as /Lang (e.g. 'en-US').
    .PARAMETER UseObjectStreams
        Compress the cross-reference data into object streams (smaller files).
    .PARAMETER Linearize
        Write a linearized ("fast web view") file.
    .PARAMETER DocumentId
        Exactly 16 bytes used as the document /ID. Default: derived from the content
        and the creation time.
    .PARAMETER Timestamp
        The creation/modification date written to the file. Default: now.
    .EXAMPLE
        $doc = New-VellumPdfPageDocument -Language en
        $doc | Add-VellumPdfPage | Add-VellumPdfText -Text 'Hello' -X 72 -Y 700 -FontSize 24 |
            Save-VellumPdfDocument -Path ./hello.pdf
    .EXAMPLE
        # Reproducible output
        New-VellumPdfPageDocument -DocumentId ([byte[]](1..16)) -Timestamp '2026-01-01T00:00:00Z' | ...
    .OUTPUTS
        VellumPdf.Document.PdfDocument
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Returns a new in-memory document object; performs no external/system state change.')]
    [CmdletBinding(DefaultParameterSetName = 'NamedPage')]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [ValidateSet('None', 'PdfA2b', 'PdfA2u', 'PdfA2a', 'PdfUA1')]
        [string]$Conformance = 'None',

        # Write a structure tree (tagged PDF). PdfA2a and PdfUA1 imply it.
        [switch]$Tagged,

        [Parameter(ParameterSetName = 'NamedPage')]
        [ValidateSet('A0', 'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'Ledger', 'Legal', 'Letter')]
        [string]$PageSize = 'A4',

        [Parameter(Mandatory, ParameterSetName = 'CustomPage')]
        [ValidateRange(1, 5080)]
        [double]$PageWidthMm,

        [Parameter(Mandatory, ParameterSetName = 'CustomPage')]
        [ValidateRange(1, 5080)]
        [double]$PageHeightMm,

        [string]$Language,

        [switch]$UseObjectStreams,

        [switch]$Linearize,

        [byte[]]$DocumentId,

        [System.DateTimeOffset]$Timestamp
    )

    try {
        if ($Linearize -and $UseObjectStreams) {
            throw 'New-VellumPdfPageDocument: -Linearize cannot be combined with -UseObjectStreams.'
        }
        if ($PSBoundParameters.ContainsKey('DocumentId') -and $DocumentId.Length -ne 16) {
            throw "New-VellumPdfPageDocument: -DocumentId must be exactly 16 bytes; got $($DocumentId.Length)."
        }

        $doc = [VellumPdf.Document.PdfDocument]::new()
        $doc.Conformance = [VellumPdf.Document.PdfConformance]::$Conformance
        if ($Tagged -or $Conformance -in 'PdfA2a', 'PdfUA1') { $doc.Tagged = $true }
        $doc.DefaultPageSize = if ($PSCmdlet.ParameterSetName -eq 'CustomPage') {
            [VellumPdf.Document.PageSize]::Mm($PageWidthMm, $PageHeightMm)
        } else {
            [VellumPdf.Document.PageSize]::$PageSize
        }
        if ($Language) { $doc.Language = $Language }
        if ($UseObjectStreams) { $doc.UseObjectStreams = $true }
        if ($Linearize) { $doc.Linearize = $true }
        if ($PSBoundParameters.ContainsKey('DocumentId')) { $doc.DocumentId = $DocumentId }
        if ($PSBoundParameters.ContainsKey('Timestamp')) { $doc.Timestamp = $Timestamp }
        $doc
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
