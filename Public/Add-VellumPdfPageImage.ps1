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

        In a tagged page document (New-VellumPdfPageDocument -Tagged, PdfA2a or PdfUA1)
        every image needs -AltText, or -Decorative to be treated as an artifact.
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
    .PARAMETER AltText
        Alternate text for the image in a tagged document.
    .PARAMETER Decorative
        Mark the image as an artifact (not read by assistive technology) in a tagged document.
    .PARAMETER Rotation
        Rotates the image about its centre, in degrees counter-clockwise. -X and -Y, -Width and
        -Height describe the unrotated image.
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

        [ValidateRange(0.01, 1000000.0)]
        [double]$Width,

        [ValidateRange(0.01, 1000000.0)]
        [double]$Height,

        # Tagged documents: alternate text for the image, or -Decorative to mark it as an artifact.
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) }, ErrorMessage = '-AltText must not be empty or whitespace.')]
        [string]$AltText,

        [switch]$Decorative,

        # Rotation about the image centre in degrees, counter-clockwise.
        [double]$Rotation
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfPageImage'
            $bound = $PSBoundParameters
            if ($bound.ContainsKey('Rotation') -and -not [double]::IsFinite($Rotation)) { throw 'Add-VellumPdfPageImage: -Rotation must be a finite number of degrees.' }
            $Page = Resolve-VellumPdfPageNumber -Document $Document -Page $Page -Bound $PSBoundParameters.ContainsKey('Page') -CommandName 'Add-VellumPdfPageImage'
            Assert-VellumPdfCoordinate $X 'X' 'Add-VellumPdfPageImage'; Assert-VellumPdfCoordinate $Y 'Y' 'Add-VellumPdfPageImage'
            $pdfPage = Get-VellumPdfPage -Document $Document -Page $Page -CommandName 'Add-VellumPdfPageImage'
            if ($Decorative -and $AltText) { throw 'Add-VellumPdfPageImage: -AltText and -Decorative cannot be combined.' }
            if ($Document.Tagged -and -not $Decorative -and -not $AltText) {
                throw ('Add-VellumPdfPageImage: this document is tagged, so every image needs -AltText (what it shows) ' +
                    'or -Decorative (assistive technology should skip it).')
            }

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
            try {
                $kind = if ($Decorative) { 'Artifact' } else { 'Structure' }
                Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind $kind -StructType Figure -AltText $AltText -Draw {
                    if ($bound.ContainsKey('Rotation') -and $Rotation -ne 0) {
                        # Rotate about the image centre: the unit square is scaled to w x h, turned, and put back.
                        $radians = $Rotation * [math]::PI / 180
                        $cos = [math]::Cos($radians); $sin = [math]::Sin($radians)
                        $cx = $X + $w / 2; $cy = $Y + $h / 2
                        $m = ($w * $cos), ($w * $sin), (0.0 - $h * $sin), ($h * $cos), ($cx - 0.5 * $w * $cos + 0.5 * $h * $sin), ($cy - 0.5 * $w * $sin - 0.5 * $h * $cos) |
                            ForEach-Object { [math]::Round($_, 8) + 0.0 }
                        [void]$canvas.Concat($m[0], $m[1], $m[2], $m[3], $m[4], $m[5]).DoXObject($name)
                    }
                    else { [void]$canvas.Concat($w, 0, 0, $h, $X, $Y).DoXObject($name) }
                }
            }
            finally { [void]$canvas.RestoreState() }
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
