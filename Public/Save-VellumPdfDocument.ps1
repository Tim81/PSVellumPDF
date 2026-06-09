function Save-VellumPdfDocument {
    <#
    .SYNOPSIS
        Writes a VellumPdf document to a .pdf file and disposes it.
    .DESCRIPTION
        Wraps Document.Save(path). The document is IDisposable; this function
        disposes it after a successful save (the terminal step of a build
        pipeline). Use -PassThru to keep the document alive for further edits,
        in which case you are responsible for disposing it.
    .EXAMPLE
        $doc | Save-VellumPdfDocument -Path ./out.pdf
    .OUTPUTS
        System.IO.FileInfo (only with -PassThru's sibling behavior off); none by default.
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
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        if ($PSCmdlet.ShouldProcess($resolved, 'Save PDF')) {
            try {
                $Document.Save($resolved)
                Get-Item -LiteralPath $resolved
            }
            finally {
                if (-not $KeepOpen) { $Document.Dispose() }
            }
        }
    }
}
