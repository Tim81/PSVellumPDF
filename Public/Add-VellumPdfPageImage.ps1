function Add-VellumPdfPageImage {
    <#
    .SYNOPSIS
        Places an image at x/y on a page of a page-based document.
    .DESCRIPTION
        Loads a JPEG, PNG, BMP, GIF, TIFF, JBIG2 or JPEG 2000 image (from -Path or
        from -ImageBytes with -Format) and draws it with its lower-left corner at
        (-X, -Y), in points from the page's bottom-left. Give -Width, -Height or
        both: with one the aspect ratio is kept; with neither the image is drawn at
        one pixel per point. For load options (16-bit reduction, raster decoding) or
        CCITT fax data use the flow-layout Add-VellumPdfImage.

        Images in a page document carry no alternate text (the content is untagged).
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Path
        The image file; the format is taken from its extension.
    .PARAMETER ImageBytes
        In-memory image bytes; also give -Format.
    .PARAMETER Format
        Jpeg, Png, Bmp, Gif, Tiff, Jbig2 or Jpeg2000 for -ImageBytes.
    .PARAMETER Page
        The 1-based page number. Default 1.
    .PARAMETER X
        Left edge in points.
    .PARAMETER Y
        Bottom edge in points.
    .PARAMETER Width
        Drawn width in points.
    .PARAMETER Height
        Drawn height in points.
    .EXAMPLE
        $doc | Add-VellumPdfPageImage ./logo.png -X 72 -Y 740 -Width 120
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Path')]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [byte[]]$ImageBytes,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [ValidateSet('Jpeg', 'Png', 'Bmp', 'Gif', 'Tiff', 'Jbig2', 'Jpeg2000')]
        [string]$Format,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [Parameter(Mandatory)] [double]$X,
        [Parameter(Mandatory)] [double]$Y,

        [ValidateRange(0.01, 1000000)]
        [double]$Width,

        [ValidateRange(0.01, 1000000)]
        [double]$Height
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfPageImage'
        if (-not [double]::IsFinite($X) -or -not [double]::IsFinite($Y)) { throw 'Add-VellumPdfPageImage: -X and -Y must be finite.' }
        $pdfPage = Get-VellumPdfPage -Document $Document -Page $Page -CommandName 'Add-VellumPdfPageImage'

        if ($PSCmdlet.ParameterSetName -eq 'Bytes') {
            $bytes = $ImageBytes; $key = $Format.ToLowerInvariant(); $source = 'the supplied image bytes'
        }
        else {
            $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
            if (-not [System.IO.File]::Exists($resolved)) { throw "Add-VellumPdfPageImage: file not found: '$resolved'." }
            $bytes = [System.IO.File]::ReadAllBytes($resolved)
            $source = "'$resolved'"
            $key = Get-VellumPdfImageFormat -Extension ([System.IO.Path]::GetExtension($resolved)) -CommandName 'Add-VellumPdfPageImage'
        }
        $image = Import-VellumPdfImage -Bytes $bytes -Format $key -CommandName 'Add-VellumPdfPageImage' -Source $source

        $w = if ($PSBoundParameters.ContainsKey('Width')) { $Width } elseif ($PSBoundParameters.ContainsKey('Height')) { $Height * $image.Width / $image.Height } else { [double]$image.Width }
        $h = if ($PSBoundParameters.ContainsKey('Height')) { $Height } elseif ($PSBoundParameters.ContainsKey('Width')) { $Width * $image.Height / $image.Width } else { [double]$image.Height }

        $counterProp = $Document.PSObject.Properties['PSVellumImageCount']
        if (-not $counterProp) {
            $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumImageCount', 0))
            $counterProp = $Document.PSObject.Properties['PSVellumImageCount']
        }
        $counterProp.Value++
        $name = "VIm$($counterProp.Value)"
        [void]$Document.RegisterImageXObject($pdfPage, $image, $name)

        $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Add-VellumPdfPageImage'
        [void]$canvas.SaveState()
        try { [void]$canvas.Concat($w, 0, 0, $h, $X, $Y).DoXObject($name) }
        finally { [void]$canvas.RestoreState() }
        $Document
    }
}
