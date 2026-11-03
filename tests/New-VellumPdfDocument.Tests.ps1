#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    function script:Get-PdfText([string]$Path) { [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::Latin1) }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'New-VellumPdfDocument custom page size' {
    It 'writes a MediaBox in points for -PageWidthMm/-PageHeightMm' {
        $out = Join-Path $TestDrive 'custom.pdf'
        New-VellumPdfDocument -PageWidthMm 100 -PageHeightMm 150 -Margin 10 | Add-VellumPdfParagraph -Text 'x' |
            Save-VellumPdfDocument -Path $out | Out-Null
        $m = [regex]::Match((Get-PdfText $out), '/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]')
        [math]::Round([double]$m.Groups[1].Value, 1) | Should -Be 283.5   # 100 mm
        [math]::Round([double]$m.Groups[2].Value, 1) | Should -Be 425.2   # 150 mm
    }

    It 'rejects sizes beyond 5080 mm and mixing with -PageSize' {
        { New-VellumPdfDocument -PageWidthMm 5081 -PageHeightMm 10 } | Should -Throw
        { New-VellumPdfDocument -PageSize A4 -PageWidthMm 100 -PageHeightMm 100 } | Should -Throw
    }

    It 'keeps the named page sizes working' {
        $doc = New-VellumPdfDocument -PageSize Letter
        try { $doc.PageSize.Width | Should -Be 612 } finally { $doc.Dispose() }
    }
}

Describe 'New-VellumPdfDocument -Conformance PdfUA1' {
    It 'creates a PDF/UA-1 document and flags it in the XMP' {
        $out = Join-Path $TestDrive 'ua.pdf'
        New-VellumPdfDocument -Conformance PdfUA1 -Language en-US |
            Add-VellumPdfHeading -Text 'Accessible' | Add-VellumPdfParagraph -Text 'Body' |
            Save-VellumPdfDocument -Path $out | Out-Null
        Get-PdfText $out | Should -Match 'pdfuaid'
    }

    It 'warns once that hyperlinks are not tagged in a PDF/UA document' {
        $doc = New-VellumPdfDocument -Conformance PdfUA1 -Language en
        try {
            $doc | Add-VellumPdfParagraph -Text 'a' -LinkUri 'https://example.com' -WarningVariable w1 -WarningAction SilentlyContinue | Out-Null
            $doc | Add-VellumPdfParagraph -Text 'b' -LinkUri 'https://example.com' -WarningVariable w2 -WarningAction SilentlyContinue | Out-Null
            @($w1).Count | Should -Be 1
            @($w1[0].Message) | Should -Match 'not tagged'
            @($w2).Count | Should -Be 0
        }
        finally { $doc.Dispose() }
    }

    It 'does not warn about links in an ordinary document' {
        $doc = New-VellumPdfDocument
        try {
            $doc | Add-VellumPdfParagraph -Text 'a' -LinkUri 'https://example.com' -WarningVariable w | Out-Null
            @($w).Count | Should -Be 0
        }
        finally { $doc.Dispose() }
    }
}
