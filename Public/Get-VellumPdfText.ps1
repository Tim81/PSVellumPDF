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
    .PARAMETER Path
        The PDF file(s). Accepts wildcards and pipeline input by property name.
    .PARAMETER LiteralPath
        The PDF file(s), taken literally.
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
        [Alias('FullName')]
        [string[]]$Path,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LiteralPath')]
        [Alias('PSPath')]
        [string[]]$LiteralPath,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [byte[]]$Bytes,

        [ValidateRange(1, 1000000)]
        [int[]]$Page,

        [switch]$PerPage,

        [securestring]$Password,

        [switch]$AllowReconstruction
    )

    begin {
        $plain = if ($Password) { [System.Net.NetworkCredential]::new('', $Password).Password }
    }

    process {
        foreach ($source in Get-VellumPdfInput -Path $Path -LiteralPath $LiteralPath -Bytes $Bytes -CommandName 'Get-VellumPdfText') {
            $reader = Open-VellumPdfReader -Bytes $source.Data -Password $plain -AllowReconstruction:$AllowReconstruction `
                -CommandName 'Get-VellumPdfText' -Source $source.Name
            try {
                $numbers = if ($Page) { $Page } else { 1..$reader.PageCount }
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
    }
}
