function Export-VellumPdfImage {
    <#
    .SYNOPSIS
        Saves the images embedded in an existing PDF as files.
    .DESCRIPTION
        EXPERIMENTAL - built on VellumPdf.Reader, which is still a Preview package.

        Extracts every image XObject (and, by default, inline images and images in
        annotation appearances) and writes each to -DestinationPath. Images the
        reader can re-encode (Flate/raw samples, with their soft mask as alpha) are
        written as PNG. Compressed images keep their original data, which keeps them
        lossless: JPEG (.jpg) and JPEG 2000 (.jp2, .j2k) are written as they are;
        CCITT fax images are wrapped in a single-strip TIFF (.tif); JBIG2 images are
        joined with their shared "global" segments into a standalone sequential JBIG2
        file (.jb2). A CCITT image TIFF cannot describe (Group 4 with byte-aligned rows,
        Group 3 without end-of-line codes unless it is one-dimensional and byte-aligned) and any other image that cannot be written as a PNG (for example CMYK
        or indexed samples) are skipped with a warning.
        Each file object carries Page, Encoding, Width, Height, BitsPerComponent,
        ColorSpace, ComponentCount, IsInline, IsStencilMask and HasSoftMask.

        Files are named <pdf name>-p<page>-i<n>.<ext> (<n> counts the images of that page
        in that PDF; -BaseName replaces <pdf name>). Names are unique within one call: when
        several PDFs would produce the same name (a/report.pdf and b/report.pdf, or any
        input with -BaseName) the later file gets a numeric suffix, for example
        report-p1-i1-2.png, and a file written earlier in the same call is never
        overwritten. A file that already existed before the call is not overwritten
        unless -Force is given.

        A failure for one PDF (not found, unreadable, malformed, wrong password, ...) is a
        non-terminating error for that file: the other PDFs are still processed. Use
        -ErrorAction Stop to stop at the first one. Inputs are read one at a time.
    .PARAMETER Path
        The PDF file(s). Accepts wildcards. Piped strings bind here, and so do piped objects with a Path property;
        piped FileInfo objects (Get-ChildItem) bind to -LiteralPath through their PSPath, so names containing [ ] work.
    .PARAMETER LiteralPath
        The PDF file(s), taken literally. Aliases PSPath and FullName, so objects with either property bind by name.
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
    .PARAMETER AllowReconstruction
        Try to recover a damaged file (missing or broken cross-reference table) by
        scanning for objects.
    .PARAMETER Force
        Overwrite files that existed before the call. Files written earlier in the same call
        are never overwritten (see the naming rules above).
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
        System.IO.FileInfo for each file written, with the image's details as note properties.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Path')]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Path')]
        [string[]]$Path,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LiteralPath')]
        [Alias('PSPath', 'FullName')]
        [string[]]$LiteralPath,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [AllowEmptyCollection()]
        [byte[]]$Bytes,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [string]$BaseName,

        [ValidateRange(1, 1000000)]
        [int[]]$Page,

        [switch]$ExcludeInline,

        [securestring]$Password,

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

    begin {
        try {
            $limits = @{}
            foreach ($n in 'MaxDecodedStreamBytes', 'MaxDiagnostics', 'MaxFormXObjectDepth', 'ReconstructionBudgetMultiplier') {
                if ($PSBoundParameters.ContainsKey($n)) { $limits[$n] = $PSBoundParameters[$n] }
            }
            $plain = if ($Password) { [System.Net.NetworkCredential]::new('', $Password).Password }
            $destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
            $usedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)   # names given out by this call
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Export-VellumPdfImage'))
        }
    }

    process {
        try {
            foreach ($source in Get-VellumPdfInput -Path $Path -LiteralPath $LiteralPath -Bytes $Bytes -CommandName 'Export-VellumPdfImage') {
                try {
                    Read-VellumPdfInput -Source $source
                    $prefix = if ($BaseName) { $BaseName }
                        elseif ($source.Name -eq '<bytes>') { 'pdf' }
                        else { [System.IO.Path]::GetFileNameWithoutExtension($source.Name) }

                    $reader = Open-VellumPdfReader -Limit $limits -Bytes $source.Data -Password $plain -AllowReconstruction:$AllowReconstruction `
                        -CommandName 'Export-VellumPdfImage' -Source $source.Name
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
                            $ext = $null
                            if ($image.TryEncodePngWithAlpha([ref]$png) -or $image.TryEncodePng([ref]$png)) {
                                $data = $png
                                $ext = 'png'
                            }
                            else {
                                switch ($image.Encoding) {
                                    'Jpeg' { $data = $image.Data.ToArray(); $ext = 'jpg' }
                                    'Jpx' { $data = $image.Data.ToArray(); $ext = $image.FileExtension.TrimStart('.') }
                                    'CcittFax' {
                                        # A PDF stores bare CCITT data. Wrap it in a single-strip TIFF so that any viewer opens it.
                                        $fax = $image.CcittFax
                                        $decode = @($image.Decode)
                                        $inverted = $decode.Count -ge 2 -and $decode[0] -gt $decode[1]
                                        $columns = if ($fax.Columns -gt 0) { $fax.Columns } else { $image.Width }
                                        $data = [PSVellumPDF.Interop.ImageContainers]::BuildCcittTiff(
                                            $columns, $image.Height, $fax.K, ($fax.BlackIs1 -xor $inverted), $fax.EncodedByteAlign, $fax.EndOfLine, $image.Data.ToArray())
                                        $ext = 'tif'
                                        if ($null -eq $data) {
                                            Write-Warning ("Export-VellumPdfImage: the CCITT image on page $pageNumber ($columns x $($image.Height), K=$($fax.K), " +
                                                "EndOfLine=$($fax.EndOfLine), EncodedByteAlign=$($fax.EncodedByteAlign)) has no TIFF equivalent " +
                                                '(Group 3 needs end-of-line codes, Group 4 cannot be byte-aligned, and the size must stay within 100,000 pixels); it was skipped.')
                                        }
                                    }
                                    'Jbig2' {
                                        # A PDF stores JBIG2 segments without a file header and keeps shared ("global") segments in a
                                        # separate stream; join them into a standalone sequential file.
                                        $data = [PSVellumPDF.Interop.ImageContainers]::BuildJbig2File($image.Data.ToArray(), $image.Jbig2.Globals.ToArray())
                                        $ext = 'jb2'
                                        if ($null -eq $data) {
                                            Write-Warning "Export-VellumPdfImage: the JBIG2 data of the image on page $pageNumber could not be parsed; it was skipped."
                                        }
                                    }
                                    default {
                                        Write-Warning ("Export-VellumPdfImage: the $($image.ColorSpace.Family) image on page $pageNumber ($($image.Width) x $($image.Height), " +
                                            "$($image.BitsPerComponent) bits per component) cannot be written as a PNG and has no file format of its own; it was skipped.")
                                    }
                                }
                                if ($null -eq $data) { $counter[$pageNumber] = $counter[$pageNumber] - 1; continue }
                            }
                            $stem = '{0}-p{1}-i{2}' -f $prefix, $pageNumber, $counter[$pageNumber]
                            $extension = $ext.TrimStart('.')
                            # Several inputs can share a base name (a/report.pdf, b/report.pdf) or -BaseName: later ones get -2, -3 ...
                            $name = "$stem.$extension"
                            for ($suffix = 2; -not $usedNames.Add($name); $suffix++) { $name = "$stem-$suffix.$extension" }
                            $target = Join-Path $destination $name
                            if ((Test-Path -LiteralPath $target) -and -not $Force) {
                                # WriteError (not Write-Error -ErrorAction Continue) so the caller's -ErrorAction applies.
                                $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                                        [System.IO.IOException]::new("Export-VellumPdfImage: '$target' exists; use -Force to overwrite."),
                                        'PSVellumPDF.FileExists', [System.Management.Automation.ErrorCategory]::ResourceExists, $target))
                                continue
                            }
                            if ($PSCmdlet.ShouldProcess($target, 'Write image')) {
                                [void][System.IO.Directory]::CreateDirectory($destination)
                                [System.IO.File]::WriteAllBytes($target, $data)
                                $details = [ordered]@{
                                    Page             = $pageNumber
                                    Encoding         = [string]$image.Encoding
                                    Width            = $image.Width
                                    Height           = $image.Height
                                    BitsPerComponent = $image.BitsPerComponent
                                    ColorSpace       = [string]$image.ColorSpace.Family
                                    ComponentCount   = $image.ColorSpace.ComponentCount
                                    IsInline         = $image.IsInline
                                    IsStencilMask    = $image.IsStencilMask
                                    HasSoftMask      = $null -ne $image.SoftMask
                                }
                                $file = Get-Item -LiteralPath $target
                                foreach ($key in $details.Keys) { $file | Add-Member -NotePropertyName $key -NotePropertyValue $details[$key] }
                                $file
                            }
                        }
                    }
                    finally { $reader.Dispose() }
                }
                catch {
                    if ($_.Exception -is [System.Management.Automation.ActionPreferenceStopException]) { throw }   # -ErrorAction Stop on an image-level error
                    Write-VellumPdfFileError -Cmdlet $PSCmdlet -ErrorRecord (ConvertTo-VellumPdfFileError -ErrorRecord $_ -Target $source.Name -CommandName 'Export-VellumPdfImage') -ErrorActionPreferenceValue $ErrorActionPreference
                }
                finally { $source.Data = $null }   # one file in memory at a time
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Export-VellumPdfImage'))
        }
    }
}
