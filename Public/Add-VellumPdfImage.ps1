function Add-VellumPdfImage {
    <#
    .SYNOPSIS
        Embeds an image into a VellumPdf document, from a file or from memory.
    .DESCRIPTION
        Wraps Document.Add(LayoutImage). Reads the image from -Path (loader chosen
        by file extension) or from -ImageBytes with an explicit -Format, constructs
        a LayoutImage, and adds it to the document. Formats: JPEG, PNG, BMP, GIF,
        TIFF, JBIG2, JPEG 2000.

        Supported extensions: .jpg/.jpeg, .png, .bmp, .gif, .tif/.tiff,
        .jbig2/.jb2, and .jp2/.jpx/.j2k/.jpf (JPEG 2000). For -ImageBytes, pass
        -Format (Jpeg/Png/Bmp/Gif/Tiff/Jbig2/Jpeg2000) since there is no extension.

        Note for PDF/A: JPEG 2000 and JBIG2 images compose with PDF/A-2. The
        bundled engine (VellumPdf 1.5.4+) embeds the JP2 box metadata that
        PDF/A-2 clause 6.2.8.3 requires, and CI validates a PDF/A-2b document
        with each image type through veraPDF. The JPEG 2000 source must still
        satisfy PDF/A-2's own rules - 1, 3, or 4 colour channels, all sharing a
        single bit depth.

        Optional -Width and -Height (in points) constrain the rendered size; when
        omitted the image renders at its natural size. -Alignment positions the
        image horizontally on the page. -AltText supplies alternate text that aids
        tagged PDF and PDF-A accessibility readers.

        -MarginTop and -MarginBottom apply spacing above and below the image
        without affecting the left/right margins already set on the element.

        The document flows through the pipeline for chaining with other
        Add-VellumPdf* functions.
    .PARAMETER Document
        The live VellumPdf document flowing through the pipeline. The same
        instance is returned after the image is added, enabling chaining.
    .PARAMETER Path
        File system path to the image file (parameter set 'Path'). Supported
        extensions are .jpg, .jpeg, .png, .bmp, .gif, .tif, .tiff, .jbig2, .jb2,
        .jp2, .jpx, .j2k, and .jpf. The path is resolved relative to the current
        PowerShell provider location. Mandatory and positional (position 0).
    .PARAMETER ImageBytes
        Raw image bytes to embed (parameter set 'Bytes'), for images produced in
        memory rather than read from disk. Requires -Format.
    .PARAMETER Format
        The format of -ImageBytes: Jpeg, Png, Bmp, Gif, Tiff, Jbig2, or Jpeg2000.
        Required with -ImageBytes (there is no extension to infer it from).
    .PARAMETER Width
        Rendered width of the image in points, between 1 and 100000. When
        omitted the image is rendered at its natural width.
    .PARAMETER Height
        Rendered height of the image in points, between 1 and 100000. When
        omitted the image is rendered at its natural height.
    .PARAMETER Alignment
        Horizontal alignment of the image on the page. Accepts Left, Center,
        Right, or Justify. Defaults to Left.
    .PARAMETER AltText
        Alternate text description for the image. Stored on the LayoutImage
        element and included in tagged PDF structure for accessibility readers
        and PDF/A compliance.
    .PARAMETER MarginTop
        Extra spacing in points above the image element. Does not affect the
        left/right page margins.
    .PARAMETER MarginBottom
        Extra spacing in points below the image element. Does not affect the
        left/right page margins.
    .PARAMETER Columns
        Pixel width of raw CCITT data (-Format Ccitt only; the fax bits have no header).
    .PARAMETER Rows
        Pixel height of raw CCITT data (-Format Ccitt only).
    .PARAMETER CcittK
        CCITT encoding: -1 Group 4 (default), 0 Group 3 one-dimensional, >0 Group 3
        two-dimensional.
    .PARAMETER BlackIs1
        CCITT: a 1 bit means black (default: 0 is black).
    .PARAMETER EncodedByteAlign
        CCITT: each encoded row starts on a byte boundary.
    .PARAMETER EndOfLine
        CCITT: the data contains end-of-line codes.
    .PARAMETER ReduceToEightBit
        Downsample high-bit-depth sources to 8 bits per component. Smaller file,
        less precision. PNG, TIFF, JBIG2, JPEG 2000 and CCITT only.
    .PARAMETER DecodeToRaster
        Decode the source image into a raster rather than embedding its
        codestream with the matching PDF filter (the default keeps the original
        compression). Supported for JBIG2; VellumPdf 2.3 refuses JPEG 2000 and
        CCITT Group 4 ("not yet supported") and PNG/TIFF are rasters already.
    .PARAMETER MarginLeft
        Extra space in points to the left of the image.
    .PARAMETER MarginRight
        Extra space in points to the right of the image.
    .EXAMPLE
        New-VellumPdfDocument |
            Add-VellumPdfImage -Path ./logo.png |
            Save-VellumPdfDocument -Path ./report.pdf
    .EXAMPLE
        $doc | Add-VellumPdfImage -Path ./photo.jpg -Width 200 -Height 150 `
               -Alignment Center -AltText 'Company photo'
    .EXAMPLE
        # Embed an in-memory PNG (e.g. a chart) without a temp file
        $doc | Add-VellumPdfImage -ImageBytes $pngBytes -Format Png -Width 150
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Path')]
        [string]$Path,

        # In-memory image bytes (e.g. a chart or QR rendered by another library).
        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [byte[]]$ImageBytes,

        # Image format of -ImageBytes, since there is no file extension to infer it.
        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [ValidateSet('Jpeg', 'Png', 'Bmp', 'Gif', 'Tiff', 'Jbig2', 'Jpeg2000', 'Ccitt')]
        [string]$Format,

        # --- CCITT Group 3/4 fax data (-Format Ccitt only): raw bits carry no header ---
        [Parameter(ParameterSetName = 'Bytes')]
        [ValidateRange(1, 100000)]
        [int]$Columns,

        [Parameter(ParameterSetName = 'Bytes')]
        [ValidateRange(1, 100000)]
        [int]$Rows,

        # CCITT K: -1 = Group 4 (default), 0 = Group 3 1-D, >0 = Group 3 2-D.
        [Parameter(ParameterSetName = 'Bytes')]
        [ValidateRange(-1, 1000)]
        [int]$CcittK = -1,

        [Parameter(ParameterSetName = 'Bytes')]
        [switch]$BlackIs1,

        [Parameter(ParameterSetName = 'Bytes')]
        [switch]$EncodedByteAlign,

        [Parameter(ParameterSetName = 'Bytes')]
        [switch]$EndOfLine,

        # Downsample 16-bit sources to 8 bits per component (smaller, less precise).
        # PNG, TIFF, JBIG2, JPEG 2000 and CCITT only.
        [switch]$ReduceToEightBit,

        # Decode the source into a raster instead of embedding the codestream as
        # a PDF-native filter. Works for JBIG2; JPEG 2000 and CCITT Group 4 are
        # refused by the engine.
        [switch]$DecodeToRaster,

        [ValidateRange(1, 100000)]
        [double]$Width,

        [ValidateRange(1, 100000)]
        [double]$Height,

        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string]$Alignment = 'Left',

        [string]$AltText,

        [ValidateRange(0, 10000)]
        [double]$MarginTop,

        [ValidateRange(0, 10000)]
        [double]$MarginBottom,

        [ValidateRange(0, 10000)]
        [double]$MarginLeft,

        [ValidateRange(0, 10000)]
        [double]$MarginRight
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfImage'

        # Resolve the bytes and a format key from either input set.
        if ($PSCmdlet.ParameterSetName -eq 'Bytes') {
            $bytes = $ImageBytes
            $formatKey = $Format.ToLowerInvariant()
            $source = 'the supplied image bytes'
        }
        else {
            $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
            if (-not [System.IO.File]::Exists($resolved)) {
                throw "Add-VellumPdfImage: file not found: '$resolved'. Verify the path and try again."
            }
            $bytes = [System.IO.File]::ReadAllBytes($resolved)
            $source = "'$resolved'"
            $ext = [System.IO.Path]::GetExtension($resolved).ToLowerInvariant()
            $formatKey = switch ($ext) {
                '.jpg' { 'jpeg' }   '.jpeg' { 'jpeg' }   '.png' { 'png' }
                '.bmp' { 'bmp' }    '.gif' { 'gif' }
                '.tif' { 'tiff' }   '.tiff' { 'tiff' }
                '.jbig2' { 'jbig2' } '.jb2' { 'jbig2' }
                '.jp2' { 'jpeg2000' } '.jpx' { 'jpeg2000' } '.j2k' { 'jpeg2000' } '.jpf' { 'jpeg2000' }
                default {
                    throw ("Add-VellumPdfImage: unsupported image extension '$ext'. " +
                        "Supported extensions are: .jpg, .jpeg, .png, .bmp, .gif, .tif, " +
                        ".tiff, .jbig2, .jb2, .jp2, .jpx, .j2k, .jpf.")
                }
            }
        }

        # Load options (bit depth / decode mode) exist only on some loaders.
        $wantsOptions = $ReduceToEightBit -or $DecodeToRaster
        if ($wantsOptions -and $formatKey -notin @('png', 'tiff', 'jbig2', 'jpeg2000', 'ccitt')) {
            throw ("Add-VellumPdfImage: -ReduceToEightBit and -DecodeToRaster apply to PNG, TIFF, JBIG2, JPEG 2000 " +
                "and CCITT images only, not $formatKey.")
        }
        $loadOptions = $null
        if ($wantsOptions) {
            $loadOptions = [VellumPdf.Images.ImageLoadOptions]::new()
            if ($ReduceToEightBit) { $loadOptions.BitDepth = [VellumPdf.Images.ImageBitDepth]::ReduceToEight }
            if ($DecodeToRaster)   { $loadOptions.DecodeMode = [VellumPdf.Images.ImageDecodeMode]::DecodeToRaster }
        }
        if ($formatKey -eq 'ccitt') {
            if (-not $PSBoundParameters.ContainsKey('Columns') -or -not $PSBoundParameters.ContainsKey('Rows')) {
                throw 'Add-VellumPdfImage: -Format Ccitt needs -Columns and -Rows (raw fax data has no header).'
            }
            $ccitt = [VellumPdf.Images.CcittOptions]::new()
            $ccitt.K = $CcittK
            $ccitt.BlackIs1 = $BlackIs1.IsPresent
            $ccitt.EncodedByteAlign = $EncodedByteAlign.IsPresent
            $ccitt.EndOfLine = $EndOfLine.IsPresent
        }
        elseif ($PSBoundParameters.ContainsKey('Columns') -or $PSBoundParameters.ContainsKey('Rows')) {
            throw 'Add-VellumPdfImage: -Columns/-Rows/-CcittK/-BlackIs1/-EncodedByteAlign/-EndOfLine apply to -Format Ccitt only.'
        }

        # Loader errors ("Not a PNG file.") do not mention the source; rethrow
        # with it so batch scripts can identify the culprit.
        try {
            $xObject = switch ($formatKey) {
                'jpeg'     { [VellumPdf.Images.JpegImageLoader]::Load($bytes) }
                'png'      { if ($loadOptions) { [VellumPdf.Images.PngImageLoader]::Load($bytes, $loadOptions) } else { [VellumPdf.Images.PngImageLoader]::Load($bytes) } }
                'bmp'      { [VellumPdf.Images.BmpImageLoader]::Load($bytes) }
                'gif'      { [VellumPdf.Images.GifImageLoader]::Load($bytes) }
                'tiff'     { if ($loadOptions) { [VellumPdf.Images.TiffImageLoader]::Load($bytes, $loadOptions) } else { [VellumPdf.Images.TiffImageLoader]::Load($bytes) } }
                'jbig2'    { if ($loadOptions) { [VellumPdf.Images.Jbig2ImageLoader]::Load($bytes, $loadOptions) } else { [VellumPdf.Images.Jbig2ImageLoader]::Load($bytes) } }
                'jpeg2000' { if ($loadOptions) { [VellumPdf.Images.JpxImageLoader]::Load($bytes, $loadOptions) } else { [VellumPdf.Images.JpxImageLoader]::Load($bytes) } }
                'ccitt'    { [VellumPdf.Images.CcittImageLoader]::Load($bytes, $Columns, $Rows, $ccitt, $loadOptions) }
            }
        }
        catch {
            if ($_.Exception.Message -like 'Add-VellumPdfImage:*') { throw }
            $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }
            throw "Add-VellumPdfImage: failed to load $($source): $inner"
        }

        $layoutImage = [VellumPdf.Layout.Elements.LayoutImage]::new($xObject)

        if ($PSBoundParameters.ContainsKey('Width')) {
            $layoutImage.Width = $Width
        }
        if ($PSBoundParameters.ContainsKey('Height')) {
            $layoutImage.Height = $Height
        }

        $layoutImage.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment

        if ($PSBoundParameters.ContainsKey('AltText')) {
            $layoutImage.AltText = $AltText
        }

        Set-VellumPdfElementMargin -Element $layoutImage -Top $MarginTop -Bottom $MarginBottom `
            -BoundParameters $PSBoundParameters -Document $Document
        if ($PSBoundParameters.ContainsKey('MarginLeft') -or $PSBoundParameters.ContainsKey('MarginRight')) {
            $cur = $layoutImage.Margins
            $layoutImage.Margins = [VellumPdf.Layout.Core.EdgeInsets]::new(
                $cur.Top, $(if ($PSBoundParameters.ContainsKey('MarginRight')) { $MarginRight } else { $cur.Right }),
                $cur.Bottom, $(if ($PSBoundParameters.ContainsKey('MarginLeft')) { $MarginLeft } else { $cur.Left }))
        }

        [void]$Document.Add($layoutImage)
        $Document
    }
}
