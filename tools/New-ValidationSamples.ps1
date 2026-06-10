<#
.SYNOPSIS
    Generates sample PDFs for external conformance validation (qpdf, veraPDF).
.DESCRIPTION
    Produces three representative documents in -OutputPath:
      plain.pdf      - multi-page mixed content (headings/bookmarks, table,
                       list, image, hyperlink, header/footer page numbers)
      pdfa2b.pdf     - PDF/A-2b with embedded TrueType font, metadata, /Lang
      encrypted.pdf  - password-protected (user password: validate)
    CI runs `qpdf --check` against all of them and veraPDF (--flavour 2b)
    against pdfa2b.pdf.
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

# --- encrypted.pdf ------------------------------------------------------------
$pw = ConvertTo-SecureString 'validate' -AsPlainText -Force
New-VellumPdfDocument |
    Add-VellumPdfParagraph -Text 'Encrypted validation sample.' |
    Protect-VellumPdfDocument -UserPassword $pw -Permission Print |
    Save-VellumPdfDocument -Path (Join-Path $OutputPath 'encrypted.pdf') | Out-Null

Get-ChildItem $OutputPath -Filter '*.pdf' | ForEach-Object {
    Write-Output "generated: $($_.Name) ($($_.Length) bytes)"
}
