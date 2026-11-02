function Get-VellumPdfInfo {
    <#
    .SYNOPSIS
        Reads structural information from an existing PDF: pages, encryption, signatures, diagnostics.
    .DESCRIPTION
        EXPERIMENTAL - built on VellumPdf.Reader, which is still a Preview package:
        its API and reach may change between releases.

        Opens a PDF (any PDF, not only ones this module wrote) and reports its page
        count and page boxes, whether and how it is encrypted, the digital
        signatures it contains, which PDF/A and PDF/UA profiles it claims, and any
        problems the reader noticed. It never modifies the file.

        Signatures are listed with what the reader exposes: the sub-filter, the
        claimed signing time and the signed byte range. Catalog reports whether the
        document has a language, structure tree (tagged), XMP metadata, outline, form,
        output intents and named destinations. The reader does not verify
        a signature, so this does not tell you whether one is valid.
    .PARAMETER Path
        The PDF file(s). Accepts wildcards. Piped strings bind here; piped FileInfo objects (Get-ChildItem) bind to -LiteralPath through their PSPath, so names containing [ ] work.
    .PARAMETER LiteralPath
        The PDF file(s), taken literally.
    .PARAMETER Bytes
        The PDF as a byte array.
    .PARAMETER Password
        Password for an encrypted PDF (a SecureString). An empty user password is
        tried automatically.
    .PARAMETER AllowReconstruction
        Try to recover a damaged file (missing or broken cross-reference table) by
        scanning for objects. The result then has WasReconstructed = $true.
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
        Get-VellumPdfInfo ./report.pdf | Select-Object PageCount, IsEncrypted, ClaimedProfiles
    .EXAMPLE
        (Get-VellumPdfInfo ./contract.pdf).Signatures
    .OUTPUTS
        PSVellumPDF.PdfInfo
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType('PSVellumPDF.PdfInfo')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'Path')]
        [string[]]$Path,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LiteralPath')]
        [Alias('PSPath')]
        [string[]]$LiteralPath,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [AllowEmptyCollection()]
        [byte[]]$Bytes,

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
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    process {
        try {
            foreach ($source in Get-VellumPdfInput -Path $Path -LiteralPath $LiteralPath -Bytes $Bytes -CommandName 'Get-VellumPdfInfo') {
                $reader = Open-VellumPdfReader -Limit $limits -Bytes $source.Data -Password $plain -AllowReconstruction:$AllowReconstruction `
                    -CommandName 'Get-VellumPdfInfo' -Source $source.Name
                try {
                    $pages = @(foreach ($p in $reader.Pages) {
                            [pscustomobject]@{
                                PSTypeName = 'PSVellumPDF.PdfPageInfo'
                                Page       = $p.Index + 1
                                Width      = $p.MediaBox.Width
                                Height     = $p.MediaBox.Height
                                Rotate     = $p.Rotate
                                MediaBox   = @($p.MediaBox.LlX, $p.MediaBox.LlY, $p.MediaBox.UrX, $p.MediaBox.UrY)
                                CropBox    = @($p.CropBox.LlX, $p.CropBox.LlY, $p.CropBox.UrX, $p.CropBox.UrY)
                            }
                        })

                    $encryption = if ($reader.Encryption) {
                        $e = $reader.Encryption
                        [pscustomobject]@{
                            PSTypeName      = 'PSVellumPDF.PdfEncryptionInfo'
                            Version         = $e.V
                            Revision        = $e.R
                            KeyLengthBits   = $e.KeyLengthBits
                            StreamCipher    = [string]$e.StreamCipher
                            StringCipher    = [string]$e.StringCipher
                            Permissions     = [string]$e.Permissions
                            IsOwnerAccess   = $e.IsOwnerAccess
                            EncryptMetadata = $e.EncryptMetadata
                        }
                    }

                    $signatures = @(foreach ($sig in $reader.Signatures) {
                            $range = $sig.ByteRange.ToArray()
                            [pscustomobject]@{
                                PSTypeName     = 'PSVellumPDF.PdfSignatureInfo'
                                SubFilter      = if ($sig.SubFilter) { [string]$sig.SubFilter.Value } else { $null }
                                SigningTime    = $sig.SigningTime
                                ByteRange      = $range
                                ContentsLength = $sig.Contents.Length
                            }
                        })

                    $diagnostics = @(foreach ($d in $reader.Diagnostics) {
                            [pscustomobject]@{
                                PSTypeName = 'PSVellumPDF.PdfReaderDiagnostic'
                                Severity   = [string]$d.Severity
                                Code       = [string]$d.Code
                                Message    = $d.Message
                                Page       = if ($null -ne $d.PageIndex) { $d.PageIndex + 1 }
                                ObjectNumber = $d.ObjectNumber
                                Generation   = $d.Generation
                            }
                        })

                    # The catalog's entries cannot be enumerated through the public API, so report
                    # the presence of the ones that matter for accessibility and navigation.
                    $has = { param($key) $null -ne $reader.Catalog.Get([VellumPdf.Core.PdfName]::new($key)) }
                    $features = [pscustomobject]@{
                        PSTypeName       = 'PSVellumPDF.PdfCatalogInfo'
                        HasLanguage      = & $has 'Lang'
                        IsTagged         = & $has 'StructTreeRoot'
                        HasMetadata      = & $has 'Metadata'
                        HasOutline       = & $has 'Outlines'
                        HasForm          = & $has 'AcroForm'
                        HasOutputIntents = & $has 'OutputIntents'
                        HasNamedDests    = & $has 'Names'
                    }

                    $claimed = @()
                    try {
                        $claimed = @([VellumPdf.Conformance.PdfPreflight]::DetectClaimedProfiles($source.Data, $plain) |
                                ForEach-Object { switch ($_) { 'PdfA2B' { 'PdfA2b' } 'PdfA2U' { 'PdfA2u' } 'PdfA2A' { 'PdfA2a' } default { [string]$_ } } })
                    }
                    catch { Write-Verbose "Could not detect claimed profiles: $($_.Exception.Message)" }

                    [pscustomobject]@{
                        PSTypeName       = 'PSVellumPDF.PdfInfo'
                        Path             = $source.Name
                        SizeBytes        = $source.Data.Length
                        PageCount        = $reader.PageCount
                        Pages            = $pages
                        IsEncrypted      = [bool]$reader.Encryption
                        Encryption       = $encryption
                        Signatures       = $signatures
                        ClaimedProfiles  = $claimed
                        WasReconstructed = $reader.WasReconstructed
                        Diagnostics      = $diagnostics
                        Catalog          = $features
                    }
                }
                finally { $reader.Dispose() }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
