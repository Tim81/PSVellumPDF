<#
    PDF/A-2b archival document with an embedded TrueType font.

    PDF/A requires every font to be embedded, so the base-14 fonts cannot be
    used for body text. Register a TrueType font and pass its handle to the
    content cmdlets via -FontHandle. This also unlocks full Unicode text.

    Run from the repo root after ./build.ps1 Restore:
        ./examples/02-pdfa-archival.ps1
#>
#requires -Version 7.6
Import-Module (Join-Path $PSScriptRoot '..' 'PSVellumPDF.psd1') -Force

$out = Join-Path $PSScriptRoot 'archival.pdf'
$ttf = Join-Path $PSScriptRoot '..' 'tests' 'assets' 'DejaVuSans.ttf'

$doc = New-VellumPdfDocument -Conformance PdfA2b -Language 'en-US'
$font = Register-VellumPdfFont -Document $doc -Path $ttf

$doc |
    Set-VellumPdfDocumentInfo -Title 'Archival Record 2026-001' -Author 'Records Office' |
    Add-VellumPdfHeading -Text 'Archival Record' -Level 1 -FontHandle $font |
    Add-VellumPdfParagraph -Text 'Unicode survives embedding: -- 100 EUR, naive cafe, Zurich.' -FontHandle $font |
    Save-VellumPdfDocument -Path $out

Write-Output "Wrote $out (PDF/A-2b)"
