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
        the document alive for inspection, in which case you are responsible
        for calling $doc.Dispose() yourself. A layout document is single-use:
        saving it a second time is refused, and after a FAILED save the document
        must be rebuilt (the engine can leave state from the failed attempt, so a
        retry could write a different file). With -WhatIf nothing is saved and the
        document is left open.

        After a successful save the engine's own diagnostics are reported:
        characters the base-14 fonts could not encode (written as '?') produce one
        warning, and a header or footer cut to fit the page produces one warning
        each. The same information is attached to the returned file object as
        the TextEncodingWarnings and BandTruncations properties.

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
        the stale instance fail with a clear error. Use -KeepOpen to suppress
        disposal.
    .PARAMETER Path
        File system path for the output PDF file. The parent directory must
        already exist; an existing file at this path is overwritten. Mandatory
        and positional (position 0).
    .PARAMETER KeepOpen
        When specified, the document is not disposed after saving. The caller is
        responsible for calling $doc.Dispose() when finished. Useful when the
        same document object must be inspected after the file is written. The
        document cannot be saved a second time.
    .PARAMETER PassThru
        Return the live document instead of the written file, and keep it open
        (implies -KeepOpen). The caller disposes it. The document still cannot be
        saved a second time; use it to read TextEncodingWarnings or BandTruncations.
    .PARAMETER Force
        Create the parent directory of -Path when it does not exist (without it a
        missing directory is an error).
    .EXAMPLE
        $doc | Save-VellumPdfDocument -Path ./out.pdf
    .OUTPUTS
        System.IO.FileInfo for the written file (VellumPdf.Layout.Document with
        -PassThru), with extra TextEncodingWarnings
        (CodePoint, Character) and BandTruncations (Band, PageNumber,
        DrawnCharacters, ResolvedCharacters, DroppedCharacters) properties.
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

        # Return the live document instead of the file. Implies -KeepOpen.
        [switch]$PassThru,

        # Create the parent directory when it does not exist.
        [switch]$Force
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Save-VellumPdfDocument'
        # A Layout document is single-use: layout runs inside Save, a second Save
        # throws, and a failed Save can leave pages from the failed attempt so a
        # retry may write a wrong file (VellumPdf #530). Say so plainly.
        if ($Document.PSObject.Properties['PSVellumFailed']) {
            throw ('Save-VellumPdfDocument: a previous save of this document failed, which can leave it in an ' +
                'inconsistent state (a retry could write a different file). Build a new document with ' +
                'New-VellumPdfDocument.')
        }
        if ($Document.PSObject.Properties['PSVellumSaved']) {
            throw ('Save-VellumPdfDocument: this document was already saved (-KeepOpen). A VellumPdf layout ' +
                'document can be written only once; build a new document with New-VellumPdfDocument.')
        }

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
                if ($parent -and $Force -and -not [System.IO.Directory]::Exists($parent)) {
                    [void][System.IO.Directory]::CreateDirectory($parent)
                }
                if ($parent -and -not [System.IO.Directory]::Exists($parent)) {
                    throw "Save-VellumPdfDocument: directory not found: '$parent'. Create it first or pass a path in an existing directory."
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
                        # The engine may keep state from the failed attempt: never let a retry write a file.
                        $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumFailed', $true))
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

                $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumSaved', $true))
                $diagnostics = Write-VellumPdfSaveDiagnostic -Document $Document
                if ($PassThru) {
                    $Document
                }
                else {
                    $file = Get-Item -LiteralPath $resolved
                    $file | Add-Member -NotePropertyName TextEncodingWarnings -NotePropertyValue $diagnostics.TextEncodingWarnings
                    $file | Add-Member -NotePropertyName BandTruncations -NotePropertyValue $diagnostics.BandTruncations
                    $file
                }
            }
        }
        finally {
            # Dispose after any save attempt (success or failure), but leave the
            # document open under -WhatIf, where no attempt was made. The stamp
            # lets the other cmdlets reject stale use of this document (VellumPdf
            # itself accepts Add() on a disposed document without complaint).
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
