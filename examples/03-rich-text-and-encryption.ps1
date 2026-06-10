<#
    Mixed-style paragraphs (runs), colour, hyperlinks, and password protection.

    Run from the repo root after ./build.ps1 Restore:
        ./examples/03-rich-text-and-encryption.ps1
    Open the result with password 'reader'.
#>
#requires -Version 7.6
Import-Module (Join-Path $PSScriptRoot '..' 'PSVellumPDF.psd1') -Force

$out = Join-Path $PSScriptRoot 'confidential.pdf'

$runs = @(
    (New-VellumPdfTextRun -Text 'Status: ')
    (New-VellumPdfTextRun -Text 'CONFIDENTIAL' -Font HelveticaBold -Color 0.8, 0, 0)
    (New-VellumPdfTextRun -Text ' - see ')
    (New-VellumPdfTextRun -Text 'the project page' -Color 0, 0, 0.8 -LinkUri 'https://github.com/Tim81/PSVellumPDF')
    (New-VellumPdfTextRun -Text ' for distribution rules.')
)

# Demo only: in real scripts take passwords from Read-Host -AsSecureString
# or a secrets store, never hard-coded.
$userPw  = ConvertTo-SecureString 'reader' -AsPlainText -Force
$ownerPw = ConvertTo-SecureString 'owner'  -AsPlainText -Force

New-VellumPdfDocument |
    Add-VellumPdfHeading -Text 'Distribution Notice' -Level 1 |
    Add-VellumPdfParagraph -Run $runs |
    Protect-VellumPdfDocument -UserPassword $userPw -OwnerPassword $ownerPw -Permission Print |
    Save-VellumPdfDocument -Path $out

Write-Output "Wrote $out (user password: reader)"
