function Register-VellumPdfFont {
    <#
    .SYNOPSIS
        Registers a TrueType font file with a VellumPdf document for embedding.
    .DESCRIPTION
        Loads a TrueType (.ttf) font into the document and returns an
        EmbeddedFontHandle. Pass the returned handle to the -FontHandle parameter
        of Add-VellumPdfHeading or Add-VellumPdfParagraph to use the embedded font
        instead of a Standard14 base-14 font.

        Use the 'Path' parameter set (default) to load the font from a file path.
        Use the 'Bytes' parameter set to supply raw font bytes directly (e.g. when
        the font is already in memory or was read from a stream).

        NOTE: This cmdlet returns the EmbeddedFontHandle, NOT the document.
        TrueType font embedding is required for Unicode text and PDF/A conformance;
        the Standard14 base-14 fonts cannot be embedded.

        A handle is only valid for the document it was registered on. Using it
        with a different document would silently produce a PDF whose text cannot
        render (the font resource is missing), so the content cmdlets reject
        foreign handles with a clear error.
    .PARAMETER Document
        The VellumPdf document to register the font on. Accepts pipeline input.
        The returned handle is only valid for this specific document instance.
    .PARAMETER Path
        File system path to a TrueType (.ttf) font file. Used in the default
        'Path' parameter set. The path is resolved relative to the current
        PowerShell provider location before reading.
    .PARAMETER FontBytes
        Raw TrueType font data as a byte array. Used in the 'Bytes' parameter
        set when the font is already in memory (e.g. read from a stream or
        embedded resource). Mutually exclusive with -Path.
    .EXAMPLE
        $doc = New-VellumPdfDocument -Conformance PdfA2b
        $handle = Register-VellumPdfFont -Document $doc -Path ./DejaVuSans.ttf
        $doc | Add-VellumPdfHeading -Text 'Unicode Heading' -FontHandle $handle |
               Add-VellumPdfParagraph -Text 'Body with embedded font.' -FontHandle $handle |
               Save-VellumPdfDocument -Path ./output.pdf
    .EXAMPLE
        $bytes = [System.IO.File]::ReadAllBytes('./DejaVuSans.ttf')
        $handle = Register-VellumPdfFont -Document $doc -FontBytes $bytes
    .OUTPUTS
        VellumPdf.Fonts.EmbeddedFontHandle
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([VellumPdf.Fonts.EmbeddedFontHandle])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Path')]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [byte[]]$FontBytes
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Register-VellumPdfFont'

        $handle = if ($PSCmdlet.ParameterSetName -eq 'Bytes') {
            $Document.UseTrueTypeFont($FontBytes)
        }
        else {
            $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
            if (-not [System.IO.File]::Exists($resolved)) {
                throw "Register-VellumPdfFont: font file not found: '$resolved'. Verify the path and try again."
            }
            $Document.LoadTrueTypeFont($resolved)
        }

        # Tag the handle with its owning document so the content cmdlets can
        # reject cross-document use (which silently breaks font rendering).
        $handle.PSObject.Properties.Add([psnoteproperty]::new('PSVellumOwner', $Document))
        $handle
    }
}
