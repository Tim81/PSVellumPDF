function Add-VellumPdfOutlineEntry {
    <#
    .SYNOPSIS
        Adds a bookmark (outline entry) that jumps to a page of a page-based document.
    .DESCRIPTION
        Adds an entry to the document outline shown in a PDF viewer's bookmark pane.
        -Level nests entries: 1 is top level, 2 sits under the preceding level 1 entry,
        and so on (a level cannot skip ahead by more than one). -Collapsed starts the
        entry closed when it has children; flow-layout documents cannot control that.
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Title
        The bookmark text.
    .PARAMETER TargetPage
        The 1-based page the bookmark jumps to.
    .PARAMETER Level
        Nesting level, 1 (top) upwards. Default 1.
    .PARAMETER DestLeft
        Horizontal position on the target page in points (default 0).
    .PARAMETER DestTop
        Vertical position on the target page in points (default the top of the page).
    .PARAMETER Collapsed
        Start the entry collapsed (its children hidden).
    .EXAMPLE
        $doc | Add-VellumPdfOutlineEntry 'Chapter 1' -TargetPage 1 | Add-VellumPdfOutlineEntry 'Section 1.1' -TargetPage 2 -Level 2
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(Mandatory)]
        [ValidateRange(1, 1000000)]
        [int]$TargetPage,

        [ValidateRange(1, 64)]
        [int]$Level = 1,

        [double]$DestLeft = 0,
        [double]$DestTop,

        [switch]$Collapsed
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfOutlineEntry'
            $target = Get-VellumPdfPage -Document $Document -Page $TargetPage -CommandName 'Add-VellumPdfOutlineEntry'
            Assert-VellumPdfCoordinate $DestLeft 'DestLeft' 'Add-VellumPdfOutlineEntry'
            if ($PSBoundParameters.ContainsKey('DestTop')) { Assert-VellumPdfCoordinate $DestTop 'DestTop' 'Add-VellumPdfOutlineEntry' }

            # Track the deepest level so far: a level may be at most one deeper than the previous entry.
            $prop = $Document.PSObject.Properties['PSVellumOutlineLevel']
            $previous = if ($prop) { [int]$prop.Value } else { 0 }
            if ($Level -gt $previous + 1) {
                throw "Add-VellumPdfOutlineEntry: -Level $Level cannot follow an entry at level $previous; levels may deepen by one at a time."
            }
            if ($prop) { $prop.Value = $Level } else { $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumOutlineLevel', $Level)) }

            $entry = [VellumPdf.Annotations.PdfOutlineEntry]::new()
            $entry.Title = $Title
            $entry.DestPage = $target
            $entry.Level = $Level - 1   # the engine counts from 0
            $entry.DestLeft = $DestLeft
            $entry.DestTop = if ($PSBoundParameters.ContainsKey('DestTop')) { $DestTop } else { $target.MediaBox.UrY }
            if ($Collapsed) { $entry.IsExpanded = $false }
            $Document.AddOutlineEntry($entry)
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Add-VellumPdfOutlineEntry'))
        }
    }
}
