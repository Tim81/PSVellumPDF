function Import-VellumPdfImage {
    <#
    .SYNOPSIS
        Loads image bytes into a PdfImageXObject; maps file extensions to formats.
    .DESCRIPTION
        One place for the format switch shared by Add-VellumPdfImage (flow layout) and
        Add-VellumPdfPageImage (page documents). -Format is one of jpeg, png, bmp, gif,
        tiff, jbig2, jpeg2000 or ccitt (lower case). LoadOptions (an ImageLoadOptions)
        applies to the formats whose loader has an overload; Ccitt needs -Columns, -Rows
        and -CcittOptions. Loader exceptions are rethrown naming -Source.
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Images.PdfImageXObject])]
    param(
        [Parameter(Mandatory)] [byte[]]$Bytes,
        [Parameter(Mandatory)] [ValidateSet('jpeg', 'png', 'bmp', 'gif', 'tiff', 'jbig2', 'jpeg2000', 'ccitt')] [string]$Format,
        [VellumPdf.Images.ImageLoadOptions]$LoadOptions,
        [int]$Columns,
        [int]$Rows,
        [VellumPdf.Images.CcittOptions]$CcittOptions,
        [Parameter(Mandatory)] [string]$CommandName,
        [Parameter(Mandatory)] [string]$Source
    )

    try {
        $withOptions = {
            param($loader)
            if ($LoadOptions) { $loader::Load($Bytes, $LoadOptions) } else { $loader::Load($Bytes) }
        }
        switch ($Format) {
            'jpeg' { [VellumPdf.Images.JpegImageLoader]::Load($Bytes) }
            'bmp' { [VellumPdf.Images.BmpImageLoader]::Load($Bytes) }
            'gif' { [VellumPdf.Images.GifImageLoader]::Load($Bytes) }
            'png' { & $withOptions ([VellumPdf.Images.PngImageLoader]) }
            'tiff' { & $withOptions ([VellumPdf.Images.TiffImageLoader]) }
            'jbig2' { & $withOptions ([VellumPdf.Images.Jbig2ImageLoader]) }
            'jpeg2000' { & $withOptions ([VellumPdf.Images.JpxImageLoader]) }
            'ccitt' { [VellumPdf.Images.CcittImageLoader]::Load($Bytes, $Columns, $Rows, $CcittOptions, $LoadOptions) }
        }
    }
    catch {
        $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }
        throw "${CommandName}: failed to load ${Source}: $inner"
    }
}
