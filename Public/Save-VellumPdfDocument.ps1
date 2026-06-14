function Save-VellumPdfDocument {
    <#
    .SYNOPSIS
        Writes a VellumPdf document to a .pdf file and disposes it.
    .DESCRIPTION
        Wraps Document.Save(path) - or, when a signature has been staged with
        Set-VellumPdfSignature, SigningExtensions.Sign(document, stream,
        settings), which signs the document while writing it (PAdES).
        The document is IDisposable; this function
        disposes it after the save attempt (success or failure) because saving is
        the terminal step of a build pipeline, and marks it so later cmdlet calls
        against the stale document fail with a clear error. Use -KeepOpen to keep
        the document alive for further edits, in which case you are responsible
        for calling $doc.Dispose() yourself. With -WhatIf nothing is saved and the
        document is left open.

        Use -Force to automatically create a missing parent directory rather than
        throwing an error. Use -PassThru to receive the still-open Document object
        instead of a FileInfo; in this case the caller owns disposal (same
        responsibility as -KeepOpen).

        If the pipeline is aborted BEFORE this cmdlet runs (for example by an
        error in an earlier Add-VellumPdf* call, or -WarningAction Stop turning
        the encoding warning into a terminating error), the document is never
        saved or disposed - dispose it yourself in your catch block.

        The write is atomic: the PDF is rendered (and signed) to a temporary
        file beside -Path and only moved into place once it is complete, so a
        render or signing failure leaves any existing file at -Path untouched.
        On success an existing file at -Path is overwritten.
    .PARAMETER Document
        The live VellumPdf document to save. Accepts pipeline input. After saving,
        the document is disposed and stamped so subsequent cmdlet calls against
        the stale instance fail with a clear error. Use -KeepOpen or -PassThru to
        suppress disposal.
    .PARAMETER Path
        File system path for the output PDF file. An existing file at this path
        is overwritten. The parent directory must already exist unless -Force is
        specified. Mandatory and positional (position 0).
    .PARAMETER KeepOpen
        When specified, the document is not disposed after saving. The caller is
        responsible for calling $doc.Dispose() when finished. Useful when the
        same document object must be inspected or further manipulated after the
        file is written.
    .PARAMETER Force
        When specified and the parent directory of -Path does not exist, creates
        it (including any missing intermediate directories) before writing the
        file. Without -Force, a missing parent directory throws an error.
    .PARAMETER PassThru
        When specified, emits the still-open VellumPdf.Layout.Document instead of
        the System.IO.FileInfo for the written file. The document is NOT disposed
        (equivalent to -KeepOpen); the caller is responsible for calling
        $doc.Dispose() when finished. Useful when the document object itself is
        needed after saving (for example, to inspect properties or pass it to
        other tools). Note: the underlying library allows a Document to be saved
        only once; to produce a second PDF file, create a new document with
        New-VellumPdfDocument. Works with staged signatures (signing remains
        the write step).
    .EXAMPLE
        $doc | Save-VellumPdfDocument -Path ./out.pdf
    .EXAMPLE
        # Create a nested output directory automatically.
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Auto-dir.' |
            Save-VellumPdfDocument -Path ./reports/2024/out.pdf -Force
    .EXAMPLE
        # Receive the Document object after saving for downstream use, then Dispose it.
        $doc = New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Content.' |
            Save-VellumPdfDocument -Path ./out.pdf -PassThru
        # $doc is still open here; inspect or pass it as needed, then dispose.
        $doc.Dispose()
    .OUTPUTS
        System.IO.FileInfo for the written file, or VellumPdf.Layout.Document when
        -PassThru is specified.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        # Keep the document open after saving (caller must Dispose it).
        [switch]$KeepOpen,

        # Create a missing parent directory rather than throwing.
        [switch]$Force,

        # Return the still-open Document instead of a FileInfo; implies -KeepOpen.
        [switch]$PassThru
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Save-VellumPdfDocument'

        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

        # A signature staged by Set-VellumPdfSignature makes signing the write
        # step: VellumPdf signs at serialization time, so Sign() replaces Save().
        $signature = $Document.PSObject.Properties['PSVellumSignature']
        $action = if ($signature) { 'Save signed PDF' } else { 'Save PDF' }

        $attempted = $false
        try {
            # Everything below is skipped under -WhatIf (ShouldProcess returns
            # $false): nothing is written and the document is left open. The
            # directory check lives here too so a -WhatIf dry run never throws
            # or disposes the document.
            if ($PSCmdlet.ShouldProcess($resolved, $action)) {
                $attempted = $true

                $parent = [System.IO.Path]::GetDirectoryName($resolved)
                if ($parent -and -not [System.IO.Directory]::Exists($parent)) {
                    if ($Force) {
                        [void][System.IO.Directory]::CreateDirectory($parent)
                    } else {
                        throw "Save-VellumPdfDocument: directory not found: '$parent'. Create it first, pass a path in an existing directory, or use -Force to create it automatically."
                    }
                }

                # Render/sign to a temporary file beside the target, then move
                # it into place only once it is complete. File.Create and
                # Document.Save both open the destination for writing before any
                # content exists, so writing straight to -Path would truncate an
                # existing good file the moment a render/sign failure occurred.
                $temp = "$resolved.$([guid]::NewGuid().ToString('N')).tmp"
                try {
                    try {
                        if ($signature) {
                            $stream = [System.IO.File]::Create($temp)
                            try {
                                [VellumPdf.Signing.SigningExtensions]::Sign($Document, $stream, $signature.Value)
                            }
                            finally {
                                $stream.Dispose()
                            }
                        }
                        else {
                            $Document.Save($temp)
                        }
                    }
                    catch {
                        # Surface failures with context specific to the operation
                        # that failed instead of a bare library exception.
                        $reason = $_.Exception.Message
                        if ($_.Exception.InnerException) { $reason = $_.Exception.InnerException.Message }
                        if ($signature) {
                            $hint = 'Check that the signing certificate is valid and still holds its private key.'
                            if ($signature.Value.TimestampClient) {
                                $hint = 'Check that the signing certificate is valid and holds its private key, ' +
                                    'and that the timestamp authority (-TimestampUrl) is reachable.'
                            }
                            throw "Save-VellumPdfDocument: failed to sign '$resolved': $reason $hint"
                        }
                        throw ("Save-VellumPdfDocument: failed to render '$resolved': $reason " +
                            'Check for extreme margin values or elements taller than the page.')
                    }

                    # The rendered file is known good; replace the target now.
                    try {
                        [System.IO.File]::Move($temp, $resolved, $true)
                    }
                    catch {
                        $reason = $_.Exception.Message
                        throw ("Save-VellumPdfDocument: rendered the PDF but could not write it to '$resolved': $reason " +
                            'Check that -Path is a writable file location (not a directory) and is not locked by another process.')
                    }
                }
                finally {
                    # Clean up the temp file if a failure left it behind; on
                    # success it has already been moved onto the target.
                    if (Test-Path -LiteralPath $temp) {
                        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
                    }
                }

                if ($PassThru) {
                    $Document
                } else {
                    Get-Item -LiteralPath $resolved
                }
            }
        }
        finally {
            # Dispose after any save attempt (success or failure), but leave the
            # document open under -WhatIf, where no attempt was made. The stamp
            # lets the other cmdlets reject stale use of this document (VellumPdf
            # itself accepts Add() on a disposed document without complaint).
            # -PassThru implies keep-open: caller owns Dispose.
            if ($attempted -and -not $KeepOpen -and -not $PassThru) {
                $Document.Dispose()
                if (-not $Document.PSObject.Properties['PSVellumDisposed']) {
                    $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumDisposed', $true))
                }
                # An HttpClient stashed by Set-VellumPdfSignature -TimestampUrl was
                # only needed for this signing write; dispose it with the document.
                $clientProp = $Document.PSObject.Properties['PSVellumTimestampHttpClient']
                if ($clientProp -and $clientProp.Value) {
                    $clientProp.Value.Dispose()
                    $clientProp.Value = $null
                }
            }
        }
    }
}
