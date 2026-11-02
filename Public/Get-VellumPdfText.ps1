function Get-VellumPdfText {
    <#
    .SYNOPSIS
        Extracts the text of an existing PDF.
    .DESCRIPTION
        EXPERIMENTAL - built on VellumPdf.Reader, which is still a Preview package.

        Returns the text of the whole document as one string, or of the pages given
        with -Page. Limits of the current reader: only simple (single-byte) fonts
        are decoded, so text set in composite/CID fonts such as many embedded
        TrueType subsets is not extracted; no spaces are inserted between text
        runs that the PDF positions apart; there is no OCR for scanned pages.
        Diagnostics about text it could not decode are written as warnings.

        Several files can be given (or piped); they are opened one at a time. A failure for
        one file (not found, unreadable, malformed, wrong password, ...) is a non-terminating
        error with that file as TargetObject and the next file is still processed; use
        -ErrorAction Stop to stop at the first one. A -Page beyond the end of a file counts as a failure for that file. Invalid parameters terminate.
    .PARAMETER Path
        The PDF file(s). Accepts wildcards. Piped strings bind here, and so do piped objects with a Path property;
        piped FileInfo objects (Get-ChildItem) bind to -LiteralPath through their PSPath, so names containing [ ] work.
    .PARAMETER LiteralPath
        The PDF file(s), taken literally. Aliases PSPath and FullName, so objects with either property
        (FileInfo, Select-Object FullName) bind by name.
    .PARAMETER Bytes
        The PDF as a byte array.
    .PARAMETER Page
        1-based page numbers to extract. Default: all pages.
    .PARAMETER PerPage
        Return one object per page (Page, Text) instead of a single string.
    .PARAMETER Password
        Password for an encrypted PDF (a SecureString).
    .PARAMETER AllowReconstruction
        Try to recover a damaged file.
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
        Get-VellumPdfText ./report.pdf -Page 1
    .EXAMPLE
        Get-VellumPdfText ./report.pdf -PerPage | Where-Object Text -match 'invoice'
    .OUTPUTS
        System.String, or PSVellumPDF.PdfPageText with -PerPage
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([string])]
    [OutputType('PSVellumPDF.PdfPageText')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Path')]
        [string[]]$Path,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LiteralPath')]
        [Alias('PSPath', 'FullName')]
        [string[]]$LiteralPath,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [AllowEmptyCollection()]
        [byte[]]$Bytes,

        [ValidateRange(1, 1000000)]
        [int[]]$Page,

        [switch]$PerPage,

        [securestring]$Password,

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

    begin {
        try {
            $limits = @{}
            foreach ($n in 'MaxDecodedStreamBytes', 'MaxDiagnostics', 'MaxFormXObjectDepth', 'ReconstructionBudgetMultiplier') {
                if ($PSBoundParameters.ContainsKey($n)) { $limits[$n] = $PSBoundParameters[$n] }
            }
            $plain = if ($Password) { [System.Net.NetworkCredential]::new('', $Password).Password }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Get-VellumPdfText'))
        }
    }

    process {
        try {
            foreach ($source in Get-VellumPdfInput -Path $Path -LiteralPath $LiteralPath -Bytes $Bytes -CommandName 'Get-VellumPdfText') {
                try {
                    Read-VellumPdfInput -Source $source
                    $reader = Open-VellumPdfReader -Limit $limits -Bytes $source.Data -Password $plain -AllowReconstruction:$AllowReconstruction `
                        -CommandName 'Get-VellumPdfText' -Source $source.Name
                    try {
                        $numbers = if ($Page) { $Page } elseif ($reader.PageCount -gt 0) { 1..$reader.PageCount } else { @() }   # 1..0 would count down to page 0
                        foreach ($n in $numbers) {
                            if ($n -gt $reader.PageCount) {
                                throw "Get-VellumPdfText: '$($source.Name)' has $($reader.PageCount) page(s); page $n does not exist."
                            }
                        }
                        $texts = foreach ($n in $numbers) {
                            $result = $reader.GetPage($n - 1).ExtractText()
                            foreach ($d in $result.Diagnostics) {
                                Write-Warning "Get-VellumPdfText: page ${n}: $($d.Message)"
                            }
                            [pscustomobject]@{ PSTypeName = 'PSVellumPDF.PdfPageText'; Page = $n; Text = $result.Text }
                        }
                        if ($PerPage) { $texts }
                        else {
                            $separator = [VellumPdf.Reader.PdfTextExtractionOptions]::new().PageSeparator
                            ($texts | ForEach-Object Text) -join $separator
                        }
                    }
                    finally { $reader.Dispose() }
                }
                catch {
                    Write-VellumPdfFileError -Cmdlet $PSCmdlet -ErrorRecord (ConvertTo-VellumPdfFileError -ErrorRecord $_ -Target $source.Name -CommandName 'Get-VellumPdfText') -ErrorActionPreferenceValue $ErrorActionPreference
                }
                finally { $source.Data = $null }   # one file in memory at a time
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Get-VellumPdfText'))
        }
    }
}
