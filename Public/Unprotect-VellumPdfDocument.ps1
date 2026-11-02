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

        One file at a time: a path that matches several files is refused (counted before any
        file is read). A failure for the file itself (not found, unreadable, not encrypted,
        wrong or missing password, malformed) is a non-terminating error with the file as
        TargetObject, so it follows -ErrorAction (use -ErrorAction Stop to throw). Invalid
        parameters (a destination equal to the source, an existing destination without -Force)
        terminate.
    .PARAMETER Path
        The encrypted PDF. Accepts wildcards, but the path must match exactly one file. Piped strings bind here, and so do
        piped objects with a Path property; piped FileInfo objects bind to -LiteralPath through their PSPath.
    .PARAMETER LiteralPath
        The encrypted PDF, taken literally. Aliases PSPath and FullName, so objects with either property bind by name.
    .PARAMETER DestinationPath
        The decrypted copy to write. Must differ from the source.
    .PARAMETER Password
        The user or owner password (a SecureString).
    .PARAMETER AllowInvalidatingSignatures
        Decrypt even though existing digital signatures become invalid.
    .PARAMETER AllowReconstruction
        Try to recover a damaged file (missing or broken cross-reference table) by
        scanning for objects before decrypting it.
    .PARAMETER Force
        Overwrite an existing destination file.
    .PARAMETER MaxDecodedStreamBytes
        Refuse to decode any stream larger than this many bytes (1 MiB to 512 MiB, the
        default ceiling). Lower it for untrusted files.
    .PARAMETER MaxDiagnostics
        Stop collecting reader diagnostics after this many (1 to 1000).
    .PARAMETER MaxFormXObjectDepth
        Deepest nesting of form XObjects followed while reading content (1 to 32).
    .PARAMETER ReconstructionBudgetMultiplier
        How many times the file size reconstruction may scan (1 to 8); used with
        -AllowReconstruction.
    .EXAMPLE
        Unprotect-VellumPdfDocument ./locked.pdf -DestinationPath ./open.pdf -Password (Read-Host -AsSecureString)
    .OUTPUTS
        System.IO.FileInfo for the decrypted copy.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Path')]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Path')]
        [string]$Path,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LiteralPath')]
        [Alias('PSPath', 'FullName')]
        [string]$LiteralPath,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [securestring]$Password,

        [switch]$AllowInvalidatingSignatures,

        [switch]$Force,

        [switch]$AllowReconstruction,
        # Resource limits for hostile or huge files. They can only tighten the reader's
        # built-in ceilings (512 MiB decoded, 1000 diagnostics, 32 form levels, budget 8).
        [ValidateRange(1MB, 512MB)]
        [long]$MaxDecodedStreamBytes,

        [ValidateRange(1, 1000)]
        [int]$MaxDiagnostics,

        [ValidateRange(1, 32)]
        [int]$MaxFormXObjectDepth,

        [ValidateRange(1, 8)]
        [int]$ReconstructionBudgetMultiplier
    )

    process {
        try {
            $limits = @{}
            foreach ($n in 'MaxDecodedStreamBytes', 'MaxDiagnostics', 'MaxFormXObjectDepth', 'ReconstructionBudgetMultiplier') {
                if ($PSBoundParameters.ContainsKey($n)) { $limits[$n] = $PSBoundParameters[$n] }
            }
            # Resolve only; no file is read until the input count and the destination are checked.
            $sources = @(Get-VellumPdfInput -Path $Path -LiteralPath $LiteralPath -CommandName 'Unprotect-VellumPdfDocument')
            if ($sources.Count -ne 1) {
                throw "Unprotect-VellumPdfDocument: the path matches $($sources.Count) files; decrypt one file at a time (each needs its own -DestinationPath)."
            }
            $source = $sources[0]
            $target = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
            if (-not $source.Error) {
                if ([string]::Equals($target, $source.Name, [System.StringComparison]::OrdinalIgnoreCase)) {
                    throw 'Unprotect-VellumPdfDocument: -DestinationPath must be a different file than the source.'
                }
                if ((Test-Path -LiteralPath $target) -and -not $Force) {
                    throw "Unprotect-VellumPdfDocument: '$target' exists; use -Force to overwrite."
                }
            }
            $plain = if ($Password) { [System.Net.NetworkCredential]::new('', $Password).Password }
            try {
                Read-VellumPdfInput -Source $source   # a missing or unreadable file is a non-terminating error for that file
                $reader = Open-VellumPdfReader -Limit $limits -Bytes $source.Data -Password $plain -AllowReconstruction:$AllowReconstruction `
                    -CommandName 'Unprotect-VellumPdfDocument' -Source $source.Name
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
            catch {
                $PSCmdlet.WriteError((ConvertTo-VellumPdfFileError -ErrorRecord $_ -Target $source.Name -CommandName 'Unprotect-VellumPdfDocument'))
            }
            finally { $source.Data = $null }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
