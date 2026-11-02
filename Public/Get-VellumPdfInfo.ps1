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
        claimed signing time and the signed byte range. The reader does not verify
        a signature, so this does not tell you whether one is valid.
    .PARAMETER Path
        The PDF file(s). Accepts wildcards and pipeline input by property name.
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
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Path')]
        [Alias('FullName')]
        [string[]]$Path,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LiteralPath')]
        [Alias('PSPath')]
        [string[]]$LiteralPath,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [byte[]]$Bytes,

        [securestring]$Password,

        [switch]$AllowReconstruction
    )

    begin {
        $plain = if ($Password) { [System.Net.NetworkCredential]::new('', $Password).Password }
    }

    process {
        foreach ($source in Get-VellumPdfInput -Path $Path -LiteralPath $LiteralPath -Bytes $Bytes -CommandName 'Get-VellumPdfInfo') {
            $reader = Open-VellumPdfReader -Bytes $source.Data -Password $plain -AllowReconstruction:$AllowReconstruction `
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
                        }
                    })

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
                }
            }
            finally { $reader.Dispose() }
        }
    }
}
