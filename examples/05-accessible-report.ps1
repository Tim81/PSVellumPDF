<#
    An accessible PDF/UA-1 report: embedded font on every element (including
    tables and lists), a document title and language, alternate text for the
    chart and the QR code, and a custom page size. The finished file is checked
    in-process with Test-VellumPdfConformance.

    Run from the repo root after ./build.ps1 Restore:
        ./examples/05-accessible-report.ps1
#>
#requires -Version 7.6
Import-Module (Join-Path $PSScriptRoot '..' 'PSVellumPDF.psd1') -Force

$out = Join-Path $PSScriptRoot 'accessible-report.pdf'
$ttf = Join-Path $PSScriptRoot '..' 'tests' 'assets' 'DejaVuSans.ttf'

# PDF/UA needs every font embedded, so register one TrueType font and pass its
# handle to every text element. B5 portrait: 176 x 250 mm.
$doc = New-VellumPdfDocument -Conformance PdfUA1 -Language 'en-GB' -PageWidthMm 176 -PageHeightMm 250 -Margin 40
$font = Register-VellumPdfFont -Document $doc -Path $ttf

$doc |
    Set-VellumPdfDocumentInfo -Title 'Regional sales, Q2 2026' -Author 'Timothy van der Ham' |
    Add-VellumPdfHeading -Text 'Regional sales, Q2 2026' -FontHandle $font -Color navy |
    Add-VellumPdfParagraph -Text 'Sales grew in every region. The chart and table show the same figures.' -FontHandle $font |
    Add-VellumPdfPieChart -Diameter 150 -Legend -FontHandle $font -AltText 'Share of sales: North 45%, South 30%, East 25%.' -Slice @(
        @{ Value = 45; Label = 'North' }
        @{ Value = 30; Label = 'South' }
        @{ Value = 25; Label = 'East' }) |
    Add-VellumPdfTable -Header 'Region', @{ Text = 'Units'; Alignment = 'Right' } -FontHandle $font -CellPadding 4, 8 `
        -ColumnAlignment Left, Right -AlternateRowBackground '#f0f4ff' `
        -Row @(@('North', '1,204'), @('South', '987'), @('East', '2,318')) |
    Add-VellumPdfList -FontHandle $font -Style OrderedDecimal -Item 'Expand EAST coverage', 'Launch the v2 platform' |
    Add-VellumPdfBarcode -Type QrCode -Content 'https://github.com/Tim81/PSVellumPDF' -TargetWidth 60 -AltText 'Link to the PSVellumPDF project page' |
    Save-VellumPdfDocument -Path $out -Validate    # refuses to write a file that fails the PDF/UA-1 preflight

Test-VellumPdfConformance -Path $out | Format-Table Profile, IsCompliant, ErrorCount, WarningCount -AutoSize
