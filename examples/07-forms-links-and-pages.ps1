<#
    A page-based document: pages placed by coordinates, with an AcroForm,
    a link to another page, a collapsible outline, a rotated landscape page and
    linearization ("fast web view"). Page documents are the tool for layouts
    flow documents cannot express.

    Run from the repo root after ./build.ps1 Restore:
        ./examples/07-forms-links-and-pages.ps1
#>
#requires -Version 7.6
Import-Module (Join-Path $PSScriptRoot '..' 'PSVellumPDF.psd1') -Force

$out = Join-Path $PSScriptRoot 'form-and-pages.pdf'

# Coordinates are points from the bottom-left of the page (72 pt = 1 inch).
New-VellumPdfPageDocument -Language 'en-US' -Linearize |
    Set-VellumPdfDocumentInfo -Title 'Registration form' |
    Add-VellumPdfPage -PageSize A4 |
    Add-VellumPdfPage -PageSize A4 -Rotate 90 |
    Add-VellumPdfGradient -X 0 -Y 770 -Width 595 -Height 72 -StartColor navy -EndColor '#4a6fd6' |
    Add-VellumPdfText 'Registration form' -X 50 -Y 800 -FontSize 24 -Font HelveticaBold -Color white |
    Add-VellumPdfText 'Name' -X 50 -Y 715 |
    Add-VellumPdfFormField Text -Name name -X 130 -Y 710 -Width 260 -Height 22 -Required |
    Add-VellumPdfText 'Plan' -X 50 -Y 675 |
    Add-VellumPdfFormField Choice -Name plan -X 130 -Y 670 -Width 160 -Height 22 -Option 'Basic', 'Pro', 'Team' -Selected 'Pro' |
    Add-VellumPdfText 'Newsletter' -X 50 -Y 635 |
    Add-VellumPdfFormField CheckBox -Name newsletter -X 130 -Y 633 -Width 14 -Height 14 -Checked |
    Add-VellumPdfText 'Size' -X 50 -Y 595 |
    Add-VellumPdfFormField Radio -Name size -Selected m -RadioOption @(
        @{ X = 130; Y = 593; Width = 14; Height = 14; ExportValue = 's' },
        @{ X = 170; Y = 593; Width = 14; Height = 14; ExportValue = 'm' },
        @{ X = 210; Y = 593; Width = 14; Height = 14; ExportValue = 'l' }) |
    Add-VellumPdfFormField PushButton -Name send -X 130 -Y 540 -Width 90 -Height 26 -Caption 'Send' |
    Add-VellumPdfText 'Terms are on page 2' -X 50 -Y 480 -Color blue |
    Add-VellumPdfLink -X 50 -Y 476 -Width 130 -Height 14 -TargetPage 2 |
    Add-VellumPdfText 'Terms and conditions' -Page 2 -X 50 -Y 780 -FontSize 18 -Font HelveticaBold |
    Add-VellumPdfLink -Page 2 -X 50 -Y 740 -Width 150 -Height 14 -Uri 'https://github.com/Tim81/PSVellumPDF' |
    Add-VellumPdfText 'Project page' -Page 2 -X 50 -Y 742 -Color blue |
    Add-VellumPdfOutlineEntry 'Form' -TargetPage 1 -Collapsed |
    Add-VellumPdfOutlineEntry 'Fields' -TargetPage 1 -Level 2 |
    Add-VellumPdfOutlineEntry 'Terms' -TargetPage 2 |
    Save-VellumPdfDocument -Path $out

"Wrote $out (open it in a viewer that supports forms)"
