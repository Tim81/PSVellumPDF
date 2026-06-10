function Save-VellumPdfDocument {
    <#
    .SYNOPSIS
        Writes a VellumPdf document to a .pdf file and disposes it.
    .DESCRIPTION
        Wraps Document.Save(path). The document is IDisposable; this function
        disposes it after the save attempt (success or failure) because saving is
        the terminal step of a build pipeline. Use -KeepOpen to keep the document
        alive for further edits, in which case you are responsible for calling
        $doc.Dispose() yourself. With -WhatIf nothing is saved and the document
        is left open.

        An existing file at -Path is overwritten.
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
                $Document.Save($resolved)
                Get-Item -LiteralPath $resolved
            }
        }
        finally {
            # Dispose after any save attempt (success or failure), but leave the
            # document open under -WhatIf, where no attempt was made.
            if ($attempted -and -not $KeepOpen) { $Document.Dispose() }
        }
    }
}
