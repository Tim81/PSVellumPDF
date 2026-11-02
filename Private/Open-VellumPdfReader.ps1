function Open-VellumPdfReader {
    <#
    .SYNOPSIS
        Opens PDF bytes with VellumPdf.Reader and maps failures to clear errors.
    .DESCRIPTION
        The one place the module touches PdfReader.Open. VellumPdf.Reader is a
        Preview package whose API still changes between releases (the
        Open(bytes, string) overload was removed in 2.3.0), so every Reader cmdlet
        goes through this helper and a future API change touches one file.
        The caller owns the returned PdfDocumentReader and must Dispose it.
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Reader.PdfDocumentReader])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password',
        Justification = 'Internal helper: the public cmdlets take SecureString and convert at the boundary; the engine API needs the plain string.')]
    param(
        [Parameter(Mandatory)] [byte[]]$Bytes,
        [string]$Password,
        [switch]$AllowReconstruction,
        [hashtable]$Limit = @{},
        [Parameter(Mandatory)] [string]$CommandName,
        [string]$Source = '<bytes>'
    )

    $options = [VellumPdf.Reader.PdfReaderOptions]::new()
    if ($Password) { $options.Password = $Password }
    if ($AllowReconstruction) { $options.AllowReconstruction = $true }
    foreach ($name in $Limit.Keys) { $options.$name = $Limit[$name] }   # MaxDecodedStreamBytes, MaxDiagnostics, ...
    try {
        [VellumPdf.Reader.PdfReader]::Open($Bytes, $options)
    }
    catch [VellumPdf.Reader.PdfPasswordException] {
        throw "${CommandName}: '$Source' is encrypted and needs a password (or the one given is wrong). Pass -Password."
    }
    catch [System.IO.InvalidDataException] {
        throw ("${CommandName}: '$Source' is not a well-formed PDF: $($_.Exception.Message)" +
            $(if (-not $AllowReconstruction) { ' Try -AllowReconstruction to recover a damaged file.' }))
    }
    catch [VellumPdf.Reader.UnsupportedPdfFeatureException] {
        throw "${CommandName}: '$Source' uses a PDF feature the reader does not support yet: $($_.Exception.Message)"
    }
}
