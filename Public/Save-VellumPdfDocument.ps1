function Save-VellumPdfDocument {
    <#
    .SYNOPSIS
        Writes a VellumPdf document to a .pdf file and disposes it.
    .DESCRIPTION
        Wraps Document.Save(path). The document is IDisposable; this function
        disposes it after the save attempt (success or failure) because saving is
        the terminal step of a build pipeline, and marks it so later cmdlet calls
        against the stale document fail with a clear error. Use -KeepOpen to keep
        the document alive for further edits, in which case you are responsible
        for calling $doc.Dispose() yourself. With -WhatIf nothing is saved and the
        document is left open.

        If the pipeline is aborted BEFORE this cmdlet runs (for example by an
        error in an earlier Add-VellumPdf* call, or -WarningAction Stop turning
        the encoding warning into a terminating error), the document is never
        saved or disposed - dispose it yourself in your catch block.

        An existing file at -Path is overwritten.
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
        same document object must be inspected or further manipulated after the
        file is written.
    .EXAMPLE
        $doc | Save-VellumPdfDocument -Path ./out.pdf
    .OUTPUTS
        System.IO.FileInfo for the written file.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        # Keep the document open after saving (caller must Dispose it).
        [switch]$KeepOpen
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Save-VellumPdfDocument'

        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $attempted = $false
        try {
            $parent = [System.IO.Path]::GetDirectoryName($resolved)
            if ($parent -and -not [System.IO.Directory]::Exists($parent)) {
                $attempted = $true
                throw "Save-VellumPdfDocument: directory not found: '$parent'. Create it first or pass a path in an existing directory."
            }
            if ($PSCmdlet.ShouldProcess($resolved, 'Save PDF')) {
                $attempted = $true
                try {
                    $Document.Save($resolved)
                }
                catch {
                    # Surface layout/render failures with actionable context
                    # instead of a bare library exception.
                    $reason = $_.Exception.Message
                    if ($_.Exception.InnerException) { $reason = $_.Exception.InnerException.Message }
                    throw ("Save-VellumPdfDocument: failed to render '$resolved': $reason " +
                        'Check for extreme margin values or elements taller than the page.')
                }
                Get-Item -LiteralPath $resolved
            }
        }
        finally {
            # Dispose after any save attempt (success or failure), but leave the
            # document open under -WhatIf, where no attempt was made. The stamp
            # lets the other cmdlets reject stale use of this document (VellumPdf
            # itself accepts Add() on a disposed document without complaint).
            if ($attempted -and -not $KeepOpen) {
                $Document.Dispose()
                if (-not $Document.PSObject.Properties['PSVellumDisposed']) {
                    $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumDisposed', $true))
                }
            }
        }
    }
}
