<#
    Quarterly report: headings with bookmarks, justified body text, a styled
    table, a list, headers/footers with page numbers, and document metadata.

    Run from the repo root after ./build.ps1 Restore:
        ./examples/01-quarterly-report.ps1
#>
#requires -Version 7.6
Import-Module (Join-Path $PSScriptRoot '..' 'PSVellumPDF.psd1') -Force

$out = Join-Path $PSScriptRoot 'quarterly-report.pdf'

$sales = @(
    [object[]]@('North', '1.204', '+8%'),
    [object[]]@('South', '987', '+3%'),
    [object[]]@('EMEA',  '2.318', '+12%')
)

New-VellumPdfDocument -PageSize A4 -DefaultFont Helvetica -DefaultFontSize 11 -Margin 50 |
    Set-VellumPdfDocumentInfo -Title 'Quarterly Report Q2 2026' -Author 'Timothy van der Ham' |
    Set-VellumPdfHeader -Template 'Quarterly Report' -FontSize 9 -Alignment Left |
    Set-VellumPdfFooter -Template 'Page {page} of {pages}' -FontSize 9 |
    Add-VellumPdfHeading -Text 'Q2 2026 Results' -Level 1 -BookmarkTitle 'Results' |
    Add-VellumPdfParagraph -Text ('Revenue grew across all regions this quarter. ' * 8) -Alignment Justify |
    Add-VellumPdfHeading -Text 'Sales by Region' -Level 2 -BookmarkTitle 'Sales' |
    Add-VellumPdfTable -Header 'Region', 'Units', 'Growth' -Row $sales `
        -ColumnWidth 150, 100, 100 -BorderWidth 0.5 -HeaderBackground 0.9, 0.9, 0.9 |
    Add-VellumPdfHeading -Text 'Priorities' -Level 2 -BookmarkTitle 'Priorities' |
    Add-VellumPdfList -Item 'Expand EMEA coverage', 'Launch v2 platform', 'Hire support engineers' -Style OrderedDecimal |
    Save-VellumPdfDocument -Path $out

Write-Output "Wrote $out"
