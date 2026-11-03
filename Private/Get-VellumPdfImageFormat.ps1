function Get-VellumPdfImageFormat {
    <#
    .SYNOPSIS
        Maps an image file extension to the format key used by Import-VellumPdfImage.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string]$Extension,
        [Parameter(Mandatory)] [string]$CommandName
    )
    switch ($Extension.ToLowerInvariant()) {
        { $_ -in '.jpg', '.jpeg' } { 'jpeg'; break }
        '.png' { 'png'; break }
        '.bmp' { 'bmp'; break }
        '.gif' { 'gif'; break }
        { $_ -in '.tif', '.tiff' } { 'tiff'; break }
        { $_ -in '.jbig2', '.jb2' } { 'jbig2'; break }
        { $_ -in '.jp2', '.jpx', '.j2k', '.jpf' } { 'jpeg2000'; break }
        default {
            throw (New-VellumPdfErrorRecord InvalidArgument ("${CommandName}: unsupported image extension '$Extension'. Supported extensions are: " +
                '.jpg, .jpeg, .png, .bmp, .gif, .tif, .tiff, .jbig2, .jb2, .jp2, .jpx, .j2k, .jpf.'))
        }
    }
}
