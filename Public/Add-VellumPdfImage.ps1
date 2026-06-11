function Add-VellumPdfImage {
    <#
    .SYNOPSIS
        Embeds an image file into a VellumPdf document.
    .DESCRIPTION
        Wraps Document.Add(LayoutImage). Reads the image from -Path, selects the
        appropriate VellumPdf loader by file extension (JPEG, PNG, BMP, GIF, TIFF),
        constructs a LayoutImage, and adds it to the document.

        Supported extensions: .jpg/.jpeg, .png, .bmp, .gif, .tif/.tiff.

        Optional -Width and -Height (in points) constrain the rendered size; when
        omitted the image renders at its natural size. -Alignment positions the
        image horizontally on the page. -AltText supplies alternate text that aids
        tagged PDF and PDF-A accessibility readers.

        -MarginTop and -MarginBottom apply spacing above and below the image
        without affecting the left/right margins already set on the element.

        The document flows through the pipeline for chaining with other
        Add-VellumPdf* functions.
    .EXAMPLE
        New-VellumPdfDocument |
            Add-VellumPdfImage -Path ./logo.png |
            Save-VellumPdfDocument -Path ./report.pdf
    .EXAMPLE
        $doc | Add-VellumPdfImage -Path ./photo.jpg -Width 200 -Height 150 `
               -Alignment Center -AltText 'Company photo'
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

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
        [double]$MarginBottom
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfImage'

        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        if (-not [System.IO.File]::Exists($resolved)) {
            throw "Add-VellumPdfImage: file not found: '$resolved'. Verify the path and try again."
        }

        $ext = [System.IO.Path]::GetExtension($resolved).ToLowerInvariant()
        $bytes = [System.IO.File]::ReadAllBytes($resolved)

        # Loader errors ("Not a PNG file.") do not mention which file failed;
        # rethrow with the path so batch scripts can identify the culprit.
        try {
            $xObject = switch ($ext) {
                '.jpg'  { [VellumPdf.Images.JpegImageLoader]::Load($bytes) }
                '.jpeg' { [VellumPdf.Images.JpegImageLoader]::Load($bytes) }
                '.png'  { [VellumPdf.Images.PngImageLoader]::Load($bytes) }
                '.bmp'  { [VellumPdf.Images.BmpImageLoader]::Load($bytes) }
                '.gif'  { [VellumPdf.Images.GifImageLoader]::Load($bytes) }
                '.tif'  { [VellumPdf.Images.TiffImageLoader]::Load($bytes) }
                '.tiff' { [VellumPdf.Images.TiffImageLoader]::Load($bytes) }
                default {
                    throw ("Add-VellumPdfImage: unsupported image extension '$ext'. " +
                        "Supported extensions are: .jpg, .jpeg, .png, .bmp, .gif, .tif, .tiff.")
                }
            }
        }
        catch {
            if ($_.Exception.Message -like 'Add-VellumPdfImage:*') { throw }
            $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }
            throw "Add-VellumPdfImage: failed to load '$resolved': $inner"
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
            -BoundParameters $PSBoundParameters

        [void]$Document.Add($layoutImage)
        $Document
    }
}
