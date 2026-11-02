function Unprotect-VellumPdfDocument {
    <#
    .SYNOPSIS
        Writes a decrypted copy of a password-protected PDF.
    .DESCRIPTION
        EXPERIMENTAL - built on VellumPdf.Reader, which is still a Preview package.

        Opens an encrypted PDF with its password and writes an unencrypted copy to
        -DestinationPath; the original is never modified. Use it to remove the
        password from files you are entitled to open, for example before handing
        them to a tool that cannot read encrypted PDFs.

        A digitally signed PDF cannot be decrypted without invalidating its
        signatures (they cover the encrypted bytes). The cmdlet refuses by default;
        pass -AllowInvalidatingSignatures to accept that.
    .PARAMETER Path
        The encrypted PDF.
    .PARAMETER LiteralPath
        The encrypted PDF, taken literally.
    .PARAMETER DestinationPath
        The decrypted copy to write. Must differ from the source.
    .PARAMETER Password
        The user or owner password (a SecureString).
    .PARAMETER AllowInvalidatingSignatures
        Decrypt even though existing digital signatures become invalid.
    .PARAMETER Force
        Overwrite an existing destination file.
    .EXAMPLE
        Unprotect-VellumPdfDocument ./locked.pdf -DestinationPath ./open.pdf -Password (Read-Host -AsSecureString)
    .OUTPUTS
        System.IO.FileInfo for the decrypted copy.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Path')]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName, ParameterSetName = 'Path')]
        [Alias('FullName')]
        [string]$Path,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LiteralPath')]
        [Alias('PSPath')]
        [string]$LiteralPath,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [securestring]$Password,

        [switch]$AllowInvalidatingSignatures,

        [switch]$Force
    )

    process {
        $sources = @(Get-VellumPdfInput -Path $Path -LiteralPath $LiteralPath -CommandName 'Unprotect-VellumPdfDocument')
        if ($sources.Count -ne 1) {
            throw "Unprotect-VellumPdfDocument: the path matches $($sources.Count) files; decrypt one file at a time (each needs its own -DestinationPath)."
        }
        $source = $sources[0]
        $target = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
        if ([string]::Equals($target, $source.Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Unprotect-VellumPdfDocument: -DestinationPath must be a different file than the source.'
        }
        if ((Test-Path -LiteralPath $target) -and -not $Force) {
            throw "Unprotect-VellumPdfDocument: '$target' exists; use -Force to overwrite."
        }
        $plain = if ($Password) { [System.Net.NetworkCredential]::new('', $Password).Password }
        $reader = Open-VellumPdfReader -Bytes $source.Data -Password $plain -CommandName 'Unprotect-VellumPdfDocument' -Source $source.Name
        try {
            if (-not $reader.Encryption) {
                throw "Unprotect-VellumPdfDocument: '$($source.Name)' is not encrypted; nothing to remove."
            }
            if ($PSCmdlet.ShouldProcess($target, "Write decrypted copy of '$($source.Name)'")) {
                $options = [VellumPdf.Reader.PdfSaveDecryptedOptions]::new()
                if ($AllowInvalidatingSignatures) { $options.AllowInvalidatingSignatures = $true }
                $temp = "$target.$([guid]::NewGuid().ToString('N')).tmp"
                try {
                    $stream = [System.IO.File]::Create($temp)
                    try { $reader.SaveDecrypted($stream, $options) }
                    catch {
                        throw "Unprotect-VellumPdfDocument: could not decrypt '$($source.Name)': $($_.Exception.Message)"
                    }
                    finally { $stream.Dispose() }
                    [System.IO.File]::Move($temp, $target, $true)
                }
                finally {
                    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
                }
                Get-Item -LiteralPath $target
            }
        }
        finally { $reader.Dispose() }
    }
}
