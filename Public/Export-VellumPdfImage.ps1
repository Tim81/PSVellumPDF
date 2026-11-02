function Export-VellumPdfImage {
    <#
    .SYNOPSIS
        Saves the images embedded in an existing PDF as files.
    .DESCRIPTION
        EXPERIMENTAL - built on VellumPdf.Reader, which is still a Preview package.

        Extracts every image XObject (and, by default, inline images and images in
        annotation appearances) and writes each to -DestinationPath. Images the
        reader can re-encode (Flate/raw samples, with their soft mask as alpha) are
        written as PNG. JPEG, JPEG 2000, JBIG2 and CCITT images are written as
        their original codestream with the matching extension (.jpg, .jp2, .jb2,
        .tif), which keeps them lossless; use those files directly.

        Files are named <pdf name>-p<page>-i<n>.<ext>. An existing file is not
        overwritten unless -Force is given.
    .PARAMETER Path
        The PDF file(s). Accepts wildcards and pipeline input by property name.
    .PARAMETER LiteralPath
        The PDF file(s), taken literally.
    .PARAMETER Bytes
        The PDF as a byte array (files are named 'pdf-p1-i1.png' ...; use -BaseName).
    .PARAMETER DestinationPath
        The folder to write into. Created if it does not exist.
    .PARAMETER BaseName
        Prefix of the file names. Default: the PDF's file name without extension.
    .PARAMETER Page
        1-based pages to extract from. Default: all.
    .PARAMETER ExcludeInline
        Skip inline images (BI/ID/EI) and annotation-appearance images.
    .PARAMETER Password
        Password for an encrypted PDF (a SecureString).
    .PARAMETER Force
        Overwrite existing files.
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
        Export-VellumPdfImage ./brochure.pdf -DestinationPath ./images
    .OUTPUTS
        System.IO.FileInfo for each file written.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Path')]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Path')]
        [Alias('FullName')]
        [string[]]$Path,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LiteralPath')]
        [Alias('PSPath')]
        [string[]]$LiteralPath,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [byte[]]$Bytes,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [string]$BaseName,

        [ValidateRange(1, 1000000)]
        [int[]]$Page,

        [switch]$ExcludeInline,

        [securestring]$Password,

        [switch]$Force,
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
        $limits = @{}
        foreach ($n in 'MaxDecodedStreamBytes', 'MaxDiagnostics', 'MaxFormXObjectDepth', 'ReconstructionBudgetMultiplier') {
            if ($PSBoundParameters.ContainsKey($n)) { $limits[$n] = $PSBoundParameters[$n] }
        }
        $plain = if ($Password) { [System.Net.NetworkCredential]::new('', $Password).Password }
        $destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
    }

    process {
        foreach ($source in Get-VellumPdfInput -Path $Path -LiteralPath $LiteralPath -Bytes $Bytes -CommandName 'Export-VellumPdfImage') {
            $prefix = if ($BaseName) { $BaseName }
                elseif ($source.Name -eq '<bytes>') { 'pdf' }
                else { [System.IO.Path]::GetFileNameWithoutExtension($source.Name) }

            $reader = Open-VellumPdfReader -Limit $limits -Bytes $source.Data -Password $plain -CommandName 'Export-VellumPdfImage' -Source $source.Name
            try {
                $options = [VellumPdf.Reader.PdfImageExtractionOptions]::new()
                if ($ExcludeInline) {
                    $options.IncludeInlineImages = $false
                    $options.IncludeAnnotationAppearances = $false
                }
                $result = $reader.ExtractImages($options)
                foreach ($d in $result.Diagnostics) { Write-Warning "Export-VellumPdfImage: $($d.Message)" }

                $counter = @{ }
                foreach ($image in $result.Images) {
                    $pageNumber = $image.PageIndex + 1
                    if ($Page -and $pageNumber -notin $Page) { continue }
                    $counter[$pageNumber] = 1 + [int]$counter[$pageNumber]

                    [byte[]]$png = $null
                    $data = $null
                    $ext = $image.FileExtension
                    if ($image.TryEncodePngWithAlpha([ref]$png) -or $image.TryEncodePng([ref]$png)) {
                        $data = $png
                        $ext = 'png'
                    }
                    else {
                        $data = $image.Data.ToArray()
                    }
                    $name = '{0}-p{1}-i{2}.{3}' -f $prefix, $pageNumber, $counter[$pageNumber], $ext.TrimStart('.')
                    $target = Join-Path $destination $name
                    if ((Test-Path -LiteralPath $target) -and -not $Force) {
                        # WriteError (not Write-Error -ErrorAction Continue) so the caller's -ErrorAction applies.
                        $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                                [System.IO.IOException]::new("Export-VellumPdfImage: '$target' exists; use -Force to overwrite."),
                                'ImageFileExists', [System.Management.Automation.ErrorCategory]::ResourceExists, $target))
                        continue
                    }
                    if ($PSCmdlet.ShouldProcess($target, 'Write image')) {
                        [void][System.IO.Directory]::CreateDirectory($destination)
                        [System.IO.File]::WriteAllBytes($target, $data)
                        Get-Item -LiteralPath $target
                    }
                }
            }
            finally { $reader.Dispose() }
        }
    }
}
