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
        for calling $doc.Dispose() yourself. Every document is single-use: saving it
        a second time is refused, and so is adding content to it (-KeepOpen is for
        inspecting a saved document, not for drawing more). After a FAILED save the document
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
    .PARAMETER Validate
        Run the in-process preflight (see Test-VellumPdfConformance) on the rendered
        PDF against the document's own conformance level (PdfA2b/2u/2a/PdfUA1) and
        fail with the first findings - writing nothing - when it is not compliant.
        The document is then unusable, like after any failed save. Not available
        for encrypted documents.
    .PARAMETER Stream
        Write the PDF to this writable stream instead of a file (for example a
        response or blob stream). The PDF is rendered in memory first, so a failure
        never leaves a partial PDF in the stream. Nothing is returned.
    .PARAMETER AsByteArray
        Return the PDF as a byte[] instead of writing a file.
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
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Path')]
    [OutputType([System.IO.FileInfo], ParameterSetName = 'Path')]
    [OutputType([byte[]], ParameterSetName = 'Bytes')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'AsByteArray',
        Justification = 'Parameter-set selector: its presence picks the Bytes set; the value is never read.')]
    [OutputType([VellumPdf.Layout.Document], [VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Document,

        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Path')]
        [string]$Path,

        # Write the PDF to this writable stream instead of a file.
        [Parameter(Mandatory, ParameterSetName = 'Stream')]
        [System.IO.Stream]$Stream,

        # Return the PDF as a byte array instead of writing a file.
        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [switch]$AsByteArray,

        # Run the in-process PDF/A / PDF/UA preflight on the rendered PDF and fail
        # (writing nothing) when it is not compliant. Needs -Conformance on the document.
        [switch]$Validate,

        # Keep the document open after saving (caller must Dispose it).
        [switch]$KeepOpen,

        # Return the live document instead of the file. Implies -KeepOpen.
        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'Stream')]
        [switch]$PassThru,

        # Create the parent directory when it does not exist.
        [Parameter(ParameterSetName = 'Path')]
        [switch]$Force
    )

    process {
        try {
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
                $factory = if ($Document -is [VellumPdf.Document.PdfDocument]) { 'New-VellumPdfPageDocument' } else { 'New-VellumPdfDocument' }
                throw ('Save-VellumPdfDocument: this document was already saved (-KeepOpen). A VellumPdf document ' +
                    "can be written only once; build a new document with $factory.")
            }

            $validateProfile = $null
            if ($Validate) {
                $validateProfile = switch ($Document.Conformance) {
                    ([VellumPdf.Document.PdfConformance]::PdfA2b) { 'PdfA2b' }
                    ([VellumPdf.Document.PdfConformance]::PdfA2u) { 'PdfA2u' }
                    ([VellumPdf.Document.PdfConformance]::PdfA2a) { 'PdfA2a' }
                    ([VellumPdf.Document.PdfConformance]::PdfUA1) { 'PdfUA1' }
                    default { $null }
                }
                if (-not $validateProfile) {
                    throw ('Save-VellumPdfDocument: -Validate needs a document created with ' +
                        'New-VellumPdfDocument or New-VellumPdfPageDocument with -Conformance PdfA2b/PdfA2u/PdfA2a/PdfUA1.')
                }
                if ($Document.PSObject.Properties['PSVellumProtected']) {
                    throw 'Save-VellumPdfDocument: -Validate cannot read an encrypted PDF; validate before Protect-VellumPdfDocument or run Test-VellumPdfConformance -Password afterwards.'
                }
            }
            $toMemory = $PSCmdlet.ParameterSetName -ne 'Path'
            $resolved = if ($toMemory) {
                if ($PSCmdlet.ParameterSetName -eq 'Stream') {
                    if (-not $Stream.CanWrite) {
                        throw 'Save-VellumPdfDocument: -Stream must be a writable stream.'
                    }
                    '<stream>'
                }
                else { '<bytes>' }
            }
            else {
                if ($Path.IndexOfAny([System.IO.Path]::GetInvalidPathChars()) -ge 0) {
                    throw "Save-VellumPdfDocument: -Path contains a character that is not allowed in a file name (such as a NUL or control character)."
                }
                $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
            }

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

                    # Renders (or signs) the document into an open stream, mapping engine
                    # failures to messages with context for this operation.
                    $render = {
                        param([System.IO.Stream]$Target)
                        try {
                            # A page-based document accumulates its drawing in per-page canvases.
                            if ($Document -is [VellumPdf.Document.PdfDocument]) {
                                Complete-VellumPdfPageDocument -Document $Document
                                if ($Document.Linearize -and $signature) {
                                    Write-Warning ('Save-VellumPdfDocument: signing ignores -Linearize; the signed file is not linearized.')
                                }
                            }
                            if ($signature -and $signature.Value.ExternalSigner) {
                                # An external signer only supports the asynchronous path. Layout then runs on
                                # a thread-pool thread, which cannot execute Add-VellumPdfDrawing script blocks.
                                if ($Document.PSObject.Properties['PSVellumHasDrawing']) {
                                    throw ('an external signer signs asynchronously, which cannot run the script blocks of ' +
                                        'Add-VellumPdfDrawing elements in this document')
                                }
                                [void][VellumPdf.Signing.SigningExtensions]::SignAsync(
                                    $Document, $Target, $signature.Value, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult()
                            }
                            elseif ($signature) {
                                [VellumPdf.Signing.SigningExtensions]::Sign($Document, $Target, $signature.Value)
                            }
                            else {
                                $Document.Save($Target)
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
                                if ($signature.Value.Level -ge [VellumPdf.Signing.PadesLevel]::B_LT) {
                                    $hint += ' B-LT/B-LTA also need the OCSP/CRL servers named in the certificate chain to be reachable;' +
                                        ' if the signature does not fit, raise -EstimatedSignatureSize.'
                                }
                                if ($signature.Value.SignaturePage -gt 0) {
                                    $hint += " -SignaturePage $($signature.Value.SignaturePage + 1) must not exceed the document's page count."
                                }
                                throw "Save-VellumPdfDocument: failed to sign '$resolved': $reason $hint"
                            }
                            # Messages the module raised itself (balance check) already say what is wrong.
                            if ($reason -like 'Invoke-VellumPdfCanvas:*') { throw "Save-VellumPdfDocument: failed to render '$resolved': $reason" }
                            throw ("Save-VellumPdfDocument: failed to render '$resolved': $reason " +
                                'Check for extreme margin values or elements taller than the page.')
                        }
                    }

                    # Preflight the rendered bytes; nothing reaches the target if they fail.
                    $validateBytes = {
                        param([byte[]]$Data)
                        if (-not $validateProfile) { return }
                        $check = Invoke-VellumPdfPreflight -Bytes $Data -Level $validateProfile -Source $resolved
                        if (-not $check.IsCompliant) {
                            $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumFailed', $true))
                            $top = @($check.Assertions | Where-Object Severity -EQ 'Error' | Select-Object -First 5 |
                                    ForEach-Object { "  - $($_.RuleId): $($_.Message)" }) -join "`n"
                            $more = if ($check.ErrorCount -gt 5) { "`n  ... and $($check.ErrorCount - 5) more" } else { '' }
                            throw ("Save-VellumPdfDocument: the rendered PDF is not $validateProfile compliant " +
                                "($($check.ErrorCount) error(s)); nothing was written.`n$top$more")
                        }
                    }

                    $bytesResult = $null
                    if ($toMemory) {
                        # Render into memory first so a failure never leaves a partial
                        # PDF in the caller's stream.
                        $memory = [System.IO.MemoryStream]::new()
                        try {
                            & $render $memory
                            if ($validateProfile) { & $validateBytes $memory.ToArray() }
                            if ($PSCmdlet.ParameterSetName -eq 'Stream') {
                                try { $memory.WriteTo($Stream); $Stream.Flush() }
                                catch {
                                    throw "Save-VellumPdfDocument: rendered the PDF but could not write it to -Stream: $($_.Exception.Message)"
                                }
                            }
                            else { $bytesResult = $memory.ToArray() }
                        }
                        finally { $memory.Dispose() }
                    }
                    else {
                        $parent = [System.IO.Path]::GetDirectoryName($resolved)
                        if ($parent -and $Force -and -not [System.IO.Directory]::Exists($parent)) {
                            [void][System.IO.Directory]::CreateDirectory($parent)
                        }
                        if ($parent -and -not [System.IO.Directory]::Exists($parent)) {
                            throw "Save-VellumPdfDocument: directory not found: '$parent'. Create it first or pass a path in an existing directory."
                        }

                        # Render/sign to a temporary file beside the target, then move
                        # it into place only once it is complete. Writing straight to
                        # -Path would truncate an existing good file the moment a
                        # render/sign failure occurred.
                        $temp = "$resolved.$([guid]::NewGuid().ToString('N')).tmp"
                        try {
                            $fileStream = [System.IO.File]::Create($temp)
                            try { & $render $fileStream }
                            finally { $fileStream.Dispose() }
                            if ($validateProfile) { & $validateBytes ([System.IO.File]::ReadAllBytes($temp)) }

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
                    }

                    $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumSaved', $true))
                    $diagnostics = Write-VellumPdfSaveDiagnostic -Document $Document
                    if ($PassThru) {
                        $Document
                    }
                    elseif ($PSCmdlet.ParameterSetName -eq 'Bytes') {
                        , $bytesResult
                    }
                    elseif ($PSCmdlet.ParameterSetName -eq 'Stream') {
                        # Nothing to return: the PDF is in the caller's stream. Diagnostics were warned above.
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
                    foreach ($clientName in 'PSVellumTimestampHttpClient', 'PSVellumRevocationHttpClient') {
                        $clientProp = $Document.PSObject.Properties[$clientName]
                        if ($clientProp -and $clientProp.Value) {
                            $clientProp.Value.Dispose()
                            $clientProp.Value = $null
                        }
                    }
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
