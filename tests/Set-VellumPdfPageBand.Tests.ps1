#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

param()

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'

    # The strings shown on each page, in page order (pages are separate content streams).
    function script:Get-PageTexts([string]$Path) {
        $content = Get-PdfContentText $Path
        , @([regex]::Matches($content, '\((.*?)\) Tj') | ForEach-Object { $_.Groups[1].Value })
    }
    function script:New-Pages([int]$Count, [hashtable]$DocParams = @{ Language = 'en' }) {
        $doc = New-VellumPdfPageDocument @DocParams
        1..$Count | ForEach-Object { $doc = $doc | Add-VellumPdfPage }
        $doc
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Set-VellumPdfPageBand' {
    It 'stamps "Page x of y" on every page, including pages added after the call' {
        $path = Join-Path $TestDrive 'numbers.pdf'
        $doc = New-VellumPdfPageDocument -Language en | Add-VellumPdfPage |
            Set-VellumPdfPageBand Footer 'Page {page} of {pages}' -Align Right
        $doc = $doc | Add-VellumPdfPage | Add-VellumPdfPage
        $doc | Save-VellumPdfDocument -Path $path | Out-Null
        (Get-PageTexts $path) | Should -Be 'Page 1 of 3', 'Page 2 of 3', 'Page 3 of 3'
    }

    It 'places headers near the top and footers near the bottom, with the requested alignment' {
        $path = Join-Path $TestDrive 'place.pdf'
        New-Pages 1 |
            Set-VellumPdfPageBand Header 'H' -Align Left -Inset 50 -Offset 20 |
            Set-VellumPdfPageBand Footer 'F' -Align Left -Inset 50 -Offset 25 |
            Save-VellumPdfDocument -Path $path | Out-Null
        $content = Get-PdfContentText $path
        # A4 is 595.27562 x 841.8898 points.
        $content | Should -Match '1 0 0 1 50 821\.89 Tm\r?\n\(H\) Tj'
        $content | Should -Match '1 0 0 1 50 25 Tm\r?\n\(F\) Tj'
    }

    It 'supports several bands, replacement by position and alignment, and removal' {
        $path = Join-Path $TestDrive 'multi.pdf'
        New-Pages 1 |
            Set-VellumPdfPageBand Footer 'old' -Align Left |
            Set-VellumPdfPageBand Footer 'Confidential' -Align Left |
            Set-VellumPdfPageBand Footer '{page}' -Align Right |
            Set-VellumPdfPageBand Header 'gone' -Align Center |
            Set-VellumPdfPageBand Header -Align Center -Remove |
            Save-VellumPdfDocument -Path $path | Out-Null
        (Get-PageTexts $path) | Should -Be 'Confidential', '1'
    }

    It 'honours -StartNumber and -SkipFirstPage' {
        $path = Join-Path $TestDrive 'start.pdf'
        New-Pages 3 | Set-VellumPdfPageBand Footer '{page}/{pages}' -StartNumber 5 -SkipFirstPage |
            Save-VellumPdfDocument -Path $path | Out-Null
        (Get-PageTexts $path) | Should -Be '6/7', '7/7'
    }

    It 'applies size, font and colour' {
        $path = Join-Path $TestDrive 'style.pdf'
        New-Pages 1 | Set-VellumPdfPageBand Header 'Styled' -FontSize 14 -Font TimesBold -Color '#ff0000' |
            Save-VellumPdfDocument -Path $path | Out-Null
        $content = Get-PdfContentText $path
        $content | Should -Match '1 0 0 rg'
        $content | Should -Match '/F\d+ 14 Tf'
        (Get-PdfText $path) | Should -Match '/BaseFont\s*/Times-Bold'
    }

    It 'draws in an embedded font and keeps content drawn on the page' {
        $path = Join-Path $TestDrive 'emb.pdf'
        $doc = New-Pages 1
        $font = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $doc | Set-VellumPdfPageBand Footer 'Zażółć {page}' -FontHandle $font |
            Add-VellumPdfText 'Body' -X 72 -Y 700 |
            Save-VellumPdfDocument -Path $path | Out-Null
        (Get-PdfText $path) | Should -Match '/FontFile2'
        (Get-PageTexts $path) | Should -Contain 'Body'
    }

    It 'rejects a multi-line template and a stale document' {
        $doc = New-Pages 1
        { $doc | Set-VellumPdfPageBand Footer "a`nb" -ErrorAction Stop } | Should -Throw '*single line*'
        $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'stale.pdf') | Out-Null
        { $doc | Set-VellumPdfPageBand Footer 'x' -ErrorAction Stop } | Should -Throw
    }

    It 'marks bands as artifacts and passes the PDF/UA-1 and PDF/A-2b preflights' {
        $ua = Join-Path $TestDrive 'band-ua.pdf'
        New-Pages 2 @{ Conformance = 'PdfUA1'; Language = 'en-US' } |
            Set-VellumPdfDocumentInfo -Title 'Bands' |
            Add-VellumPdfText 'Body' -X 72 -Y 700 |
            Set-VellumPdfPageBand Header 'Report' -Align Left |
            Set-VellumPdfPageBand Footer 'Page {page} of {pages}' -Align Right |
            Save-VellumPdfDocument -Path $ua | Out-Null
        (Test-VellumPdfConformance -Path $ua -Profile PdfUA1).IsCompliant | Should -BeTrue
        (Get-PdfContentText $ua) | Should -Match '/Artifact BMC'

        $a2b = Join-Path $TestDrive 'band-a2b.pdf'
        New-Pages 2 @{ Conformance = 'PdfA2b'; Language = 'en' } |
            Set-VellumPdfPageBand Footer 'Page {page} of {pages}' -Font TimesRoman |
            Save-VellumPdfDocument -Path $a2b | Out-Null
        (Test-VellumPdfConformance -Path $a2b -Profile PdfA2b).IsCompliant | Should -BeTrue
    }

    It 'works with -Validate and warns about rotated pages' {
        $path = Join-Path $TestDrive 'rot.pdf'
        $doc = New-VellumPdfPageDocument -Conformance PdfA2b -Language en | Add-VellumPdfPage -Rotate 90 |
            Set-VellumPdfPageBand Footer '{page}' -Font TimesRoman
        $null = $doc | Save-VellumPdfDocument -Path $path -Validate -WarningVariable w -WarningAction SilentlyContinue
        "$w" | Should -Match 'rotated page'
    }
}
