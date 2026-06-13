<#
.SYNOPSIS
    Generates sample PDFs for external conformance validation (qpdf, veraPDF).
.DESCRIPTION
    Produces four representative documents in -OutputPath:
      plain.pdf         - multi-page mixed content (headings/bookmarks, table,
                          list, image, hyperlink, header/footer page numbers)
      pdfa2b.pdf        - PDF/A-2b with embedded TrueType font, metadata, /Lang
      pdfa2b-signed.pdf - the same archival profile with a PAdES signature
                          (in-memory self-signed certificate)
      pdfa2b-jpx.pdf    - PDF/A-2b with an embedded JPEG 2000 image
      pdfa2b-jbig2.pdf  - PDF/A-2b with an embedded JBIG2 image
      encrypted.pdf     - password-protected (user password: validate)
    CI runs `qpdf --check` against all of them and veraPDF (--flavour 2b)
    against pdfa2b.pdf, pdfa2b-signed.pdf, pdfa2b-jpx.pdf, and pdfa2b-jbig2.pdf.
#>
#requires -Version 7.6
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $repoRoot 'PSVellumPDF.psd1') -Force
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

# Verified 1x1 grayscale PNG (same asset the image tests embed).
$pngBytes = [Convert]::FromBase64String(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAAEElEQVR4nGI4AQAAAP//AwAAygDJDlGudwAAAABJRU5ErkJggg==')
$pngPath = Join-Path $OutputPath 'sample.png'
[System.IO.File]::WriteAllBytes($pngPath, $pngBytes)

# --- plain.pdf: multi-page mixed content -------------------------------------
$rows = @(
    [object[]]@('Alpha', '1', 'OK'),
    [object[]]@('Beta',  '2', 'OK')
)
$link = New-VellumPdfTextRun -Text 'project page' -LinkUri 'https://github.com/Tim81/PSVellumPDF'
$doc = New-VellumPdfDocument -PageSize A4 -Margin 50 |
    Set-VellumPdfDocumentInfo -Title 'Validation Sample' -Author 'PSVellumPDF CI' |
    Set-VellumPdfHeader -Template 'Validation Sample' -FontSize 9 -Alignment Left |
    Set-VellumPdfFooter -Template 'Page {page} of {pages}' -FontSize 9 |
    Add-VellumPdfHeading -Text 'Mixed Content' -Level 1 -BookmarkTitle 'Mixed Content' |
    Add-VellumPdfTable -Header 'Name', 'Qty', 'State' -Row $rows -BorderWidth 0.5 |
    Add-VellumPdfList -Item 'first', 'second', 'third' -Style OrderedDecimal |
    Add-VellumPdfImage -Path $pngPath -Width 40 -Height 40 -AltText 'sample dot' |
    Add-VellumPdfParagraph -Run $link
1..80 | ForEach-Object {
    $doc = $doc | Add-VellumPdfParagraph -Text "Filler paragraph $_ to force pagination across multiple pages."
}
$doc | Save-VellumPdfDocument -Path (Join-Path $OutputPath 'plain.pdf') | Out-Null

# --- pdfa2b.pdf: archival with embedded font ---------------------------------
$ttf = Join-Path $repoRoot 'tests' 'assets' 'DejaVuSans.ttf'
$archive = New-VellumPdfDocument -Conformance PdfA2b -Language 'en-US'
$font = Register-VellumPdfFont -Document $archive -Path $ttf
$archive |
    Set-VellumPdfDocumentInfo -Title 'Archival Validation Sample' -Author 'PSVellumPDF CI' |
    Add-VellumPdfHeading -Text 'Archival Sample' -Level 1 -FontHandle $font |
    Add-VellumPdfParagraph -Text 'PDF/A-2b body text with an embedded TrueType font.' -FontHandle $font |
    Save-VellumPdfDocument -Path (Join-Path $OutputPath 'pdfa2b.pdf') | Out-Null

# --- pdfa2b-signed.pdf: archival + PAdES signature ----------------------------
$rsa = [System.Security.Cryptography.RSA]::Create(2048)
try {
    $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=PSVellumPDF Validation', $rsa,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $cert = $req.CreateSelfSigned(
        [DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddDays(7))

    $signed = New-VellumPdfDocument -Conformance PdfA2b -Language 'en-US'
    $signedFont = Register-VellumPdfFont -Document $signed -Path $ttf
    $signed |
        Set-VellumPdfDocumentInfo -Title 'Signed Archival Validation Sample' -Author 'PSVellumPDF CI' |
        Add-VellumPdfHeading -Text 'Signed Archival Sample' -Level 1 -FontHandle $signedFont |
        Add-VellumPdfParagraph -Text 'PDF/A-2b body signed with a PAdES baseline signature.' `
            -FontHandle $signedFont |
        Set-VellumPdfSignature -Certificate $cert -Reason 'CI validation' -Location 'GitHub Actions' |
        Save-VellumPdfDocument -Path (Join-Path $OutputPath 'pdfa2b-signed.pdf') | Out-Null
    $cert.Dispose()
}
finally {
    $rsa.Dispose()
}

# --- pdfa2b-jpx.pdf / pdfa2b-jbig2.pdf: archival with JPEG 2000 / JBIG2 image --
# Guards VellumPDF#91: a JPEG 2000 image must keep the JP2 ihdr/colr boxes that
# veraPDF reads for PDF/A-2 clause 6.2.8.3. tests/assets/sample.jp2 is a real
# 16x16 RGB JP2 (Pillow/OpenJPEG); sample.jb2 is a minimal valid JBIG2.
$jpx = Join-Path $repoRoot 'tests' 'assets' 'sample.jp2'
$docJpx = New-VellumPdfDocument -Conformance PdfA2b -Language 'en-US'
$jpxFont = Register-VellumPdfFont -Document $docJpx -Path $ttf
$docJpx |
    Set-VellumPdfDocumentInfo -Title 'JPEG 2000 Archival Sample' -Author 'PSVellumPDF CI' |
    Add-VellumPdfParagraph -Text 'PDF/A-2b with an embedded JPEG 2000 image.' -FontHandle $jpxFont |
    Add-VellumPdfImage -Path $jpx -Width 40 -AltText 'JPEG 2000 sample' |
    Save-VellumPdfDocument -Path (Join-Path $OutputPath 'pdfa2b-jpx.pdf') | Out-Null

$jb2 = Join-Path $repoRoot 'tests' 'assets' 'sample.jb2'
$docJb2 = New-VellumPdfDocument -Conformance PdfA2b -Language 'en-US'
$jb2Font = Register-VellumPdfFont -Document $docJb2 -Path $ttf
$docJb2 |
    Set-VellumPdfDocumentInfo -Title 'JBIG2 Archival Sample' -Author 'PSVellumPDF CI' |
    Add-VellumPdfParagraph -Text 'PDF/A-2b with an embedded JBIG2 image.' -FontHandle $jb2Font |
    Add-VellumPdfImage -Path $jb2 -Width 40 -AltText 'JBIG2 sample' |
    Save-VellumPdfDocument -Path (Join-Path $OutputPath 'pdfa2b-jbig2.pdf') | Out-Null

# --- encrypted.pdf ------------------------------------------------------------
$pw = ConvertTo-SecureString 'validate' -AsPlainText -Force
New-VellumPdfDocument |
    Add-VellumPdfParagraph -Text 'Encrypted validation sample.' |
    Protect-VellumPdfDocument -UserPassword $pw -Permission Print |
    Save-VellumPdfDocument -Path (Join-Path $OutputPath 'encrypted.pdf') | Out-Null

Get-ChildItem $OutputPath -Filter '*.pdf' | ForEach-Object {
    Write-Output "generated: $($_.Name) ($($_.Length) bytes)"
}
