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
      pdfa2b-charts.pdf - PDF/A-2b flow document with a pie chart, QR code,
                          1-D barcode caption, table and list (embedded font)
      pdfa2b-pages.pdf  - PDF/A-2b page-based document: shapes, text, gradient,
                          image, barcode, links and nested outline
      pdfua1.pdf        - PDF/UA-1 flow document (title, embedded font, alt text)
      pdfua1-pages.pdf  - tagged PDF/UA-1 page-based document (headings, text, figure,
                          barcode, artifacts)
      pdfua1-structure.pdf - PDF/UA-1 page-based document with a section, a table (header,
                          spans) and nested lists
      linearized.pdf    - page-based document written as "fast web view"
      forms.pdf         - page-based document with AcroForm fields
      encrypted.pdf     - password-protected (user password: validate)
    CI runs `qpdf --check` against all of them (and --check-linearization on
    linearized.pdf), veraPDF --flavour 2b against the PDF/A files and --flavour
    ua1 against pdfua1.pdf.
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

# --- pdfa2b-charts.pdf: pie chart, barcodes, table and list under PDF/A ---------
$charts = New-VellumPdfDocument -Conformance PdfA2b -Language 'en-US'
$chartFont = Register-VellumPdfFont -Document $charts -Path $ttf
$charts |
    Set-VellumPdfDocumentInfo -Title 'Charts and Codes Archival Sample' -Author 'PSVellumPDF CI' |
    Add-VellumPdfHeading -Text 'Charts and codes' -Level 1 -FontHandle $chartFont |
    Add-VellumPdfPieChart -Legend -FontHandle $chartFont -AltText 'Share by region' -Slice @(
        @{ Value = 45; Label = 'North' }, @{ Value = 30; Label = 'South' }, @{ Value = 25; Label = 'East' }) |
    Add-VellumPdfBarcode -Type QrCode -Content 'https://github.com/Tim81/PSVellumPDF' -TargetWidth 80 -AltText 'Project link' |
    Add-VellumPdfBarcode -Type Ean13 -Content '5901234123457' -Caption '5901234123457' -FontHandle $chartFont -AltText 'Product code' |
    Add-VellumPdfTable -Header 'Name', 'Qty' -Row @(, @('Alpha', '1')) -FontHandle $chartFont |
    Add-VellumPdfList -Item 'one', @{ Text = 'two'; Children = @('two-a') } -FontHandle $chartFont |
    Add-VellumPdfDrawing -Height 30 -AltText 'A blue bar' -ScriptBlock {
        param($canvas, $box)
        [void]$canvas.SetFillColorRgb(0, 0.2, 0.7).Rectangle($box.X, $box.Y, 120, 20).Fill()
    } |
    Save-VellumPdfDocument -Path (Join-Path $OutputPath 'pdfa2b-charts.pdf') -Validate | Out-Null

# --- pdfa2b-pages.pdf: page-based document under PDF/A --------------------------
$pages = New-VellumPdfPageDocument -Conformance PdfA2b -Language 'en-US' | Add-VellumPdfPage -Count 2
$pages |
    Set-VellumPdfDocumentInfo -Title 'Page Document Archival Sample' -Author 'PSVellumPDF CI' |
    Add-VellumPdfShape Rectangle -X 50 -Y 700 -Width 200 -Height 60 -FillColor navy -StrokeColor red -Opacity 0.6 |
    Add-VellumPdfShape Ellipse -X 300 -Y 700 -Width 120 -Height 60 -FillColor orange |
    Add-VellumPdfText 'Page document' -X 60 -Y 720 -FontSize 20 -Color white -Font HelveticaBold |
    Add-VellumPdfGradient -X 50 -Y 600 -Width 250 -Height 60 -StartColor navy -EndColor white |
    Add-VellumPdfPageImage $pngPath -X 320 -Y 600 -Width 40 |
    Add-VellumPdfPageBarcode QrCode 'https://github.com/Tim81/PSVellumPDF' -X 50 -Y 450 -TargetWidth 90 |
    Add-VellumPdfLink -X 50 -Y 560 -Width 120 -Height 14 -Uri 'https://github.com/Tim81/PSVellumPDF' |
    Add-VellumPdfLink -X 200 -Y 560 -Width 80 -Height 14 -TargetPage 2 |
    Add-VellumPdfOutlineEntry 'Overview' -TargetPage 1 |
    Add-VellumPdfOutlineEntry 'Details' -TargetPage 2 -Level 2 |
    Save-VellumPdfDocument -Path (Join-Path $OutputPath 'pdfa2b-pages.pdf') -Validate | Out-Null

# --- pdfua1.pdf: accessible flow document --------------------------------------
$ua = New-VellumPdfDocument -Conformance PdfUA1 -Language 'en-US'
$uaFont = Register-VellumPdfFont -Document $ua -Path $ttf
$ua |
    Set-VellumPdfDocumentInfo -Title 'Accessibility Validation Sample' -Author 'PSVellumPDF CI' |
    Add-VellumPdfHeading -Text 'Accessible report' -Level 1 -FontHandle $uaFont |
    Add-VellumPdfParagraph -Text 'Body text in an embedded font.' -FontHandle $uaFont |
    Add-VellumPdfList -Item 'one', 'two' -FontHandle $uaFont |
    Add-VellumPdfTable -Header 'A', 'B' -Row @(, @('1', '2')) -FontHandle $uaFont |
    Add-VellumPdfPieChart -Slice @(@{ Value = 1; Label = 'a' }, @{ Value = 2; Label = 'b' }) -AltText 'Two slices' |
    Add-VellumPdfBarcode -Type QrCode -Content 'https://github.com/Tim81/PSVellumPDF' -TargetWidth 70 -AltText 'Project link' |
    Save-VellumPdfDocument -Path (Join-Path $OutputPath 'pdfua1.pdf') -Validate | Out-Null

# --- pdfua1-pages.pdf: tagged page-based document --------------------------------
$uaPages = New-VellumPdfPageDocument -Conformance PdfUA1 -Language 'en-US' | Add-VellumPdfPage
$uaPages |
    Set-VellumPdfDocumentInfo -Title 'Tagged Page Document Sample' -Author 'PSVellumPDF CI' |
    Add-VellumPdfText 'Tagged page document' -X 72 -Y 760 -FontSize 22 -Font HelveticaBold -Role H1 |
    Add-VellumPdfText 'Text, figures and decoration are tagged or marked as artifacts.' -X 72 -Y 730 |
    Add-VellumPdfShape Rectangle -X 72 -Y 640 -Width 200 -Height 40 -FillColor navy |
    Add-VellumPdfPageImage $pngPath -X 72 -Y 560 -Width 40 -AltText 'A single grey pixel' |
    Add-VellumPdfPageBarcode QrCode 'https://github.com/Tim81/PSVellumPDF' -X 300 -Y 540 -TargetWidth 80 -AltText 'Project link' |
    Save-VellumPdfDocument -Path (Join-Path $OutputPath 'pdfua1-pages.pdf') -Validate | Out-Null

# --- pdfua1-structure.pdf: nested structure (section, table, list) --------------
New-VellumPdfPageDocument -Conformance PdfUA1 -Language 'en-US' | Add-VellumPdfPage |
    Set-VellumPdfDocumentInfo -Title 'Structure Sample' -Author 'PSVellumPDF CI' |
    Use-VellumPdfStructure -Type Sect -ScriptBlock {
        $_ | Add-VellumPdfText 'Quarterly summary' -X 72 -Y 760 -FontSize 20 -Font HelveticaBold -Role H1 |
            Add-VellumPdfPageTable -X 72 -Y 730 -Width 450 -Header 'Item', 'Qty', 'Price' -ColumnAlignment Left, Right, Right `
                -HeaderBackground '#e8f0fe' -AlternateRowBackground '#f4f4f4' -Row @(
                @('Widget with a long description that wraps onto a second line', '2', '10.00'),
                @('Gadget', '1', '24.50'),
                @(@{ Text = 'Total'; ColSpan = 2 }, '44.50')) |
            Add-VellumPdfPageList -X 72 -Y 560 -Width 300 -Item 'Review the figures', @{ Text = 'Plan the next quarter'; Children = 'Budget', 'Hiring' }, 'Share the summary'
    } |
    Save-VellumPdfDocument -Path (Join-Path $OutputPath 'pdfua1-structure.pdf') -Validate | Out-Null

# --- linearized.pdf / forms.pdf: page documents ---------------------------------
New-VellumPdfPageDocument -Linearize -Language 'en-US' | Add-VellumPdfPage -Count 3 |
    Add-VellumPdfText 'Fast web view' -X 72 -Y 700 -FontSize 18 |
    Add-VellumPdfOutlineEntry 'First' -TargetPage 1 |
    Save-VellumPdfDocument -Path (Join-Path $OutputPath 'linearized.pdf') | Out-Null

New-VellumPdfPageDocument -Language 'en-US' | Add-VellumPdfPage |
    Add-VellumPdfText 'Form sample' -X 72 -Y 740 -FontSize 18 |
    Add-VellumPdfFormField Text -Name name -X 72 -Y 690 -Width 220 -Height 22 -Value 'Your name' |
    Add-VellumPdfFormField CheckBox -Name agree -X 72 -Y 655 -Width 14 -Height 14 -Checked |
    Add-VellumPdfFormField Choice -Name plan -X 72 -Y 620 -Width 150 -Height 22 -Option basic, pro -Selected pro |
    Add-VellumPdfFormField Radio -Name size -Selected m -RadioOption @(
        @{ X = 72; Y = 580; Width = 14; Height = 14; ExportValue = 's' },
        @{ X = 110; Y = 580; Width = 14; Height = 14; ExportValue = 'm' }) |
    Add-VellumPdfFormField PushButton -Name send -X 72 -Y 540 -Width 80 -Height 24 -Caption 'Send' |
    Save-VellumPdfDocument -Path (Join-Path $OutputPath 'forms.pdf') | Out-Null

# --- encrypted.pdf ------------------------------------------------------------
$pw = ConvertTo-SecureString 'validate' -AsPlainText -Force
New-VellumPdfDocument |
    Add-VellumPdfParagraph -Text 'Encrypted validation sample.' |
    Protect-VellumPdfDocument -UserPassword $pw -Permission Print |
    Save-VellumPdfDocument -Path (Join-Path $OutputPath 'encrypted.pdf') | Out-Null

Get-ChildItem $OutputPath -Filter '*.pdf' | ForEach-Object {
    Write-Output "generated: $($_.Name) ($($_.Length) bytes)"
}
