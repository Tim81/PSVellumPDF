<#
    Accessible tables and embedded fonts (1.4.0 features).

    Demonstrates: Register-VellumPdfFont, Add-VellumPdfTable with -FontHandle,
    rich header cells, per-cell Padding and Color, Add-VellumPdfList with
    -FontHandle and -Language, Add-VellumPdfHeading with -Color, a custom mm
    page size, and Save-VellumPdfDocument -PassThru with explicit Dispose.

    PDF/A-2b is used here because the embedded DejaVuSans font satisfies the
    embedding requirement. PDF/UA-1 (-Conformance PdfUA1) also composes with
    embedded fonts; switch the conformance and add -Tagged if you need it.

    Run from the repo root after ./build.ps1 Restore:
        ./examples/05-accessible-tables-and-fonts.ps1
#>
#requires -Version 7.6
Import-Module (Join-Path $PSScriptRoot '..' 'PSVellumPDF.psd1') -Force

$out = Join-Path $PSScriptRoot 'accessible-tables-and-fonts.pdf'
$ttf = Join-Path $PSScriptRoot '..' 'tests' 'assets' 'DejaVuSans.ttf'

# Custom A4-wide page at 210 x 280 mm (slightly shorter than standard A4).
$doc  = New-VellumPdfDocument -Conformance PdfA2b -Language 'en-US' `
            -PageWidthMm 210 -PageHeightMm 280 -Margin 40
$font = Register-VellumPdfFont -Document $doc -Path $ttf

# Rich header cells: first column in steelblue, rest in a lighter shade.
$header = @(
    @{ Text = 'Region'; Background = 'steelblue'; Color = 'white'; Padding = 6, 8, 6, 8 },
    @{ Text = 'Units';  Background = 'steelblue'; Color = 'white'; Padding = 6, 8, 6, 8 },
    @{ Text = 'Growth'; Background = 'steelblue'; Color = 'white'; Padding = 6, 8, 6, 8 }
)

$sales = @(
    [object[]]@('North', '1,204', '+8%'),
    [object[]]@('South', '987',   '+3%'),
    [object[]]@('EMEA',  '2,318', '+12%')
)

$doc |
    Set-VellumPdfDocumentInfo -Title 'Accessible Tables Demo' -Author 'Timothy van der Ham' |
    Add-VellumPdfHeading -Text 'Regional Sales Summary' -Level 1 `
        -FontHandle $font -Color 'darkblue' -Language 'en-US' |
    Add-VellumPdfParagraph -Text 'The table below uses an embedded TrueType font and rich header cells. Each data cell inherits the embedded font via -FontHandle.' `
        -FontHandle $font -Language 'en-US' |
    Add-VellumPdfTable -Header $header -Row $sales `
        -FontHandle $font -CellPadding 5, 8, 5, 8 `
        -ColumnWidth 160, 100, 100 -BorderWidth 0.5 |
    Add-VellumPdfHeading -Text 'Key Priorities' -Level 2 `
        -FontHandle $font -Color 'steelblue' -Language 'en-US' |
    Add-VellumPdfList -Item 'Grow EMEA coverage', 'Ship platform v2', 'Hire support engineers' `
        -FontHandle $font -Language 'en-US' |
    Save-VellumPdfDocument -Path $out -PassThru |
    ForEach-Object {
        # -PassThru returns the live Document so you can inspect or extend it
        # before saving again. The caller owns disposal.
        $_.Dispose()
    }

Write-Output "Wrote $out"
