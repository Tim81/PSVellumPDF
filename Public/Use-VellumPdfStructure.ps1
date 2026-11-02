function Use-VellumPdfStructure {
    <#
    .SYNOPSIS
        Groups everything tagged inside a script block under one structure element.
    .DESCRIPTION
        In a tagged page document (PDF/UA-1, PDF/A-2a or -Tagged) every text, shape or image cmdlet adds
        its own element to the structure tree, side by side at the top. Use-VellumPdfStructure nests them:
        the elements created by the script block become children of one grouping element such as a
        section (Sect), a division (Div), an article (Art) or a part (Part), which gives assistive
        technology the outline of the page. Scopes nest, and tables and lists use the same mechanism
        for their rows and items.

        The group is added to the tree when the block ends, and only if something was tagged inside it
        (a warning says so otherwise). In an untagged document the block just runs.

        The block runs in the caller's scope with the document as $_. Its own output is discarded; the
        cmdlet writes the document to the pipeline, so the call chains.
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Type
        The grouping element: Sect (default), Div, Art, Part, BlockQuote, Index or TOC.
    .PARAMETER ScriptBlock
        The drawing whose elements are grouped.
    .PARAMETER Language
        BCP 47 language tag for the whole group.
    .EXAMPLE
        $doc | Use-VellumPdfStructure -Type Sect -ScriptBlock {
            $_ | Add-VellumPdfText 'Results' -X 72 -Y 760 -Role H1 |
                Add-VellumPdfTextBox 'The results are shown below.' -X 72 -Y 740 -Width 400
        }
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Mutates an in-memory document object only; no external/system state change.')]
    [CmdletBinding()]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [ValidateSet('Sect', 'Div', 'Art', 'Part', 'BlockQuote', 'Index', 'TOC')]
        [string]$Type = 'Sect',

        [Parameter(Mandatory, Position = 0)]
        [scriptblock]$ScriptBlock,

        [ValidateNotNullOrEmpty()]
        [string]$Language
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Use-VellumPdfStructure'
            Assert-VellumPdfLanguageTag -Value $Language -CommandName 'Use-VellumPdfStructure'
            if (-not $Document.Tagged) {
                $null = $Document | ForEach-Object -Process $ScriptBlock
                return $Document
            }
            $structType = Resolve-VellumPdfValidSetValue -Command $PSCmdlet.MyInvocation.MyCommand -Parameter 'Type' -Value $Type
            $group = [VellumPdf.Document.PdfStructElem]::new($structType)
            if ($Language) { $group.Language = $Language }
            Push-VellumPdfStructParent -Document $Document -Element $group
            $completed = $false
            try {
                $null = $Document | ForEach-Object -Process $ScriptBlock
                $completed = $true
            }
            finally {
                Pop-VellumPdfStructParent -Document $Document
                # Whatever was tagged before a failure stays in the tree: its marked content is already in the page.
                if ($group.Children.Count -gt 0) { Add-VellumPdfStructElement -Document $Document -Element $group }
                elseif ($completed) { Write-Warning "Use-VellumPdfStructure: nothing was tagged inside the $structType block, so no structure element was written." }
            }
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Use-VellumPdfStructure'))
        }
    }
}
