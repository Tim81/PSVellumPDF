function Set-VellumPdfOutputIntent {
    <#
    .SYNOPSIS
        Sets a custom ICC output intent on a PDF/A conformant VellumPdf document.
    .DESCRIPTION
        Wraps Document.SetPdfAOutputIntent(iccProfile, componentCount,
        outputConditionIdentifier, info) and the UseCmykOutputIntent convenience
        (the library's built-in generic CMYK profile). PDF/A documents embed an
        sRGB output intent by default; this cmdlet replaces it, which matters for
        archival workflows that mandate a specific output condition.

        REQUIRES PDF/A: the library only writes the output intent for conformant
        documents (it is silently ignored otherwise), so this cmdlet throws when
        the document's Conformance is None - create the document with
        New-VellumPdfDocument -Conformance PdfA2b (or another PDF/A level).

        CMYK CAVEAT: the layout engine renders text and table fills in DeviceRGB.
        A CMYK output intent is intended for documents that also carry CMYK
        content produced at the kernel level (not exposed by this module); strict
        PDF/A validators may flag DeviceRGB layout content combined with a pure
        CMYK output intent. Prefer a 3-component (RGB) profile for documents
        built with this module.

        The ICC profile bytes are embedded as-is; the library does not validate
        them at set time. Verify archival output with a PDF/A validator (e.g.
        veraPDF) as part of your workflow.
    .PARAMETER Document
        The live VellumPdf document flowing through the pipeline. The same
        instance is returned after the output intent is set, enabling chaining.
    .PARAMETER IccProfilePath
        Path to an ICC profile file (.icc/.icm) to embed as the output intent.
    .PARAMETER ComponentCount
        Number of colour components in the profile: 1 (Gray), 3 (RGB), or
        4 (CMYK).
    .PARAMETER OutputConditionIdentifier
        The OutputConditionIdentifier string written to the OutputIntent
        dictionary (e.g. 'sRGB IEC61966-2.1'). Defaults to 'Generic CMYK' when
        -Cmyk is used.
    .PARAMETER Info
        Optional human-readable /Info string describing the output condition.
    .PARAMETER Cmyk
        Use the library's built-in generic CMYK ICC profile instead of supplying
        a profile file. See the CMYK caveat above.
    .EXAMPLE
        New-VellumPdfDocument -Conformance PdfA2b |
            Set-VellumPdfOutputIntent -IccProfilePath ./sRGB-v4.icc -ComponentCount 3 `
                -OutputConditionIdentifier 'sRGB v4 ICC preference' |
            Set-VellumPdfDocumentInfo -Title 'Archive' -Author 'Acme' |
            Add-VellumPdfParagraph -Text 'Archival body.' -FontHandle $font |
            Save-VellumPdfDocument -Path ./archive.pdf
    .EXAMPLE
        # Built-in generic CMYK intent (for documents that add CMYK kernel content)
        $doc | Set-VellumPdfOutputIntent -Cmyk
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Mutates an in-memory document object only; no external/system state change.')]
    [CmdletBinding(DefaultParameterSetName = 'IccProfile')]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory, Position = 0, ParameterSetName = 'IccProfile')]
        [string]$IccProfilePath,

        [Parameter(Mandatory, ParameterSetName = 'IccProfile')]
        [ValidateSet(1, 3, 4)]
        [int]$ComponentCount,

        [Parameter(Mandatory, ParameterSetName = 'IccProfile')]
        [Parameter(ParameterSetName = 'Cmyk')]
        [string]$OutputConditionIdentifier,

        [Parameter(ParameterSetName = 'IccProfile')]
        [string]$Info,

        [Parameter(Mandatory, ParameterSetName = 'Cmyk')]
        [switch]$Cmyk
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Set-VellumPdfOutputIntent'

        # The library writes the output intent only for conformant documents
        # and silently ignores it otherwise - fail fast instead.
        if ($Document.Conformance -eq [VellumPdf.Document.PdfConformance]::None) {
            throw ('Set-VellumPdfOutputIntent: the output intent is only written for PDF/A conformant ' +
                'documents. Create the document with New-VellumPdfDocument -Conformance PdfA2b ' +
                '(or another PDF/A level) first.')
        }

        if ($PSCmdlet.ParameterSetName -eq 'Cmyk') {
            $identifier = if ($PSBoundParameters.ContainsKey('OutputConditionIdentifier')) {
                $OutputConditionIdentifier
            }
            else {
                'Generic CMYK'
            }
            $Document.UseCmykOutputIntent($identifier)
        }
        else {
            $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($IccProfilePath)
            if (-not [System.IO.File]::Exists($resolved)) {
                throw "Set-VellumPdfOutputIntent: ICC profile not found: '$resolved'."
            }
            $bytes = [System.IO.File]::ReadAllBytes($resolved)
            $infoValue = if ($PSBoundParameters.ContainsKey('Info')) { $Info } else { $null }
            $Document.SetPdfAOutputIntent($bytes, $ComponentCount, $OutputConditionIdentifier, $infoValue)
        }
        $Document
    }
}
